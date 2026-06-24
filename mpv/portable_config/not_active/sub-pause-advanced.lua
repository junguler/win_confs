local UnpauseMode = {
  TEXT = 1,
  TIME = 2,
}

local DefaultKeys = {
  ["replay"] = "Ctrl+r",
}

local options = {
  setup = "",
  ["min-sub-duration"] = 1,
  ["min-sub-text-length"] = 5, -- NOTE: Only in effect if length > `0`
  ["min-pause-duration"] = 0.5,
  ["unpause-base"] = 0.4,
  ["unpause-text-multiplier"] = 0.017,
  ["unpause-time-multiplier"] = 0.57,
  ["unpause-exponent"] = 1.2,
  ["pair-sub-max-delta"] = 0.9,
  ["sub-delay"] = "no", -- String to support empty value
}
local cfg = {}
local state = {}

--- GENERAL UTILITIES ------------------------------------------------------------------------------

local function debug_dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k.. '"'
      end
      s = s .. "[" .. k .. "] = " .. debug_dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

local function lines(s)
  return s:gmatch("[^\r\n]+")
end

local function strlen(s)
  local _, len = s:gsub("[^\128-\193]", "")
  return len
end

--- CONFIG UTILITIES -----------------------------------------------------------------------------------

local function sub_track_cfg(sub_track, sub_pos, key)
  local track_cfg = cfg[sub_track]
  if track_cfg == nil then
    return nil
  end
  if sub_pos == nil then
    if key == nil then
      return track_cfg
    else
      return track_cfg[key]
    end
  end
  local track_pos_cfg = track_cfg[sub_pos]
  if track_pos_cfg == nil then
    return nil
  end
  if key == nil then
    return track_pos_cfg
  end
  return track_pos_cfg[key]
end

--- SUB TRACK UTILITIES ----------------------------------------------------------------------------

local function sub_track_property(sub_track, property_base)
  local property = property_base
  if sub_track == 2 then
    property = "secondary-" .. property
  end
  return property
end

local function for_each_sub_track(cb)
  for sub_track=1,2 do
    cb(sub_track)
  end
end

local function other_sub_track(track)
  return (track % 2) + 1
end

--- SUB TEXT UTILITIES -----------------------------------------------------------------------------

local special_ass_codes = {"pos", "move", "kf", "fad"}

local function has_special_ass_code(s)
  for _, c in pairs(special_ass_codes) do
    -- PERF: Pre-create the patterns
    if s:find("%\\" .. c) then
      return true
    end
  end
  return false
end

local function suspected_special_sub(ass_text)
  if not ass_text or #ass_text == 0 then
    return false
  end
  -- Consider as special sub only if *all* lines have certain ASS codes
  for line in lines(ass_text) do
    if not has_special_ass_code(line) then
      return false
    end
  end
  return true
end

local function current_nospecial_sub_text_length()
  -- If ASS subtitle available, count only lines not containing 'special' ASS codes
  local ass_text = mp.get_property("sub-text-ass")
  if ass_text and #ass_text > 0 then
    local len = 0

    for line in lines(ass_text) do
      if not has_special_ass_code(line) then
        local noass_line = line:gsub("%b{}", "")
        len = len + strlen(noass_line)
      end
    end

    return len
  end

  return strlen(mp.get_property("sub-text"))
end


--- VARIOUS UTILITIES ------------------------------------------------------------------------------

local function message(s, duration_secs)
  mp.osd_message(s, duration_secs)
  state.last_message_time_ts = os.time()
  state.last_message_duration_secs = duration_secs
end

local function is_displaying_message()
  return os.time() <= state.last_message_time_ts + state.last_message_duration_secs
end

local function set_sub_visibility(sub_track, visible)
  mp.set_property_bool(sub_track_property(sub_track, "sub-visibility"), visible)
  if not is_displaying_message() then
    mp.osd_message(" ", 0.001) -- Force redraw
  end
end

local function seek_to_current_or_last_sub_start(sub_track)
  local start_wo_delay = mp.get_property_number(sub_track_property(sub_track, "sub-start"))
  if not start_wo_delay then
    start_wo_delay = state.last_sub_start_time[sub_track]
  end
  if not start_wo_delay then
    return
  end
  mp.set_property(
    "time-pos",
    start_wo_delay
      + mp.get_property_number("sub-delay")
      + cfg.sub_start_seek_offset_secs
  )
end

local function invalidate_unpause_timer()
  if state.unpause_timer ~= nil then
    state.unpause_timer:kill()
    state.unpause_timer = nil
  end
end

--- PAUSE/UNPAUSE FUNCTIONS ------------------------------------------------------------------------

local function unpause_interval(sub_track, mode, scale)
  local length = nil
  local multiplier = nil
  if mode == UnpauseMode.TEXT then
    length = state.curr_sub_text_length[sub_track]
    multiplier = cfg.unpause_text_multiplier
  elseif mode == UnpauseMode.TIME then
    length = state.curr_sub_time_length[sub_track]
    multiplier = cfg.unpause_time_multiplier
  end
  return scale * (cfg.unpause_base_secs + (multiplier * length^cfg.unpause_exponent))
end

local function pause(sub_track, sub_pos)
  if state.override then
    return
  end

  mp.set_property_bool("pause", true)
  for_each_sub_track(function (track)
    if sub_track_cfg(track, nil, "hide_while_playing")
      and not (
        track ~= sub_track
        and sub_track_cfg(track, nil, "hide_also_while_paused_for_other_track")
      ) then
        set_sub_visibility(track, true)
    end
  end)

  if sub_track then
    state.last_pause_time_pos[sub_track] = mp.get_property_number("time-pos")
    state.last_pause_sub_pos[sub_track] = sub_pos
  end
end

local function unpause()
  invalidate_unpause_timer()

  -- NOTE: If both true, honors only first
  if state.replay_on_unpause[1] then
    seek_to_current_or_last_sub_start(1)
  elseif state.replay_on_unpause[2] then
    seek_to_current_or_last_sub_start(2)
  end
  state.replay_on_unpause = {false, false}

  mp.set_property_bool("pause", false)
end

local function unpause_after(duration)
  state.unpause_timer = mp.add_timeout(duration, unpause)
end

local function pause_wait_unpause(sub_track, sub_pos, part_cfg)
  local pause_duration =
    unpause_interval(sub_track, part_cfg.unpause_mode, part_cfg.unpause_scale)
  if pause_duration >= cfg.min_pause_duration_secs then
    pause(sub_track, sub_pos)
    unpause_after(pause_duration)
  end
end

local function should_skip_because_special_sub(part_cfg)
  return not part_cfg.consider_special_subs
    and suspected_special_sub(mp.get_property("sub-text-ass"))
end

local function should_skip_general(sub_start_time, sub_end_time)
  -- Skip if sub too short in terms of both time and text length
  local sub_time_length = sub_end_time - sub_start_time
  if sub_time_length < cfg.min_sub_time_length_secs then
    return true, nil, nil
  end
  local sub_text_length = current_nospecial_sub_text_length()

  -- Ignore `0`, since image-based subs have the length of `0`
  if sub_text_length > 0 and sub_text_length < cfg.min_sub_text_length then
    return true, nil, nil
  end

  return false, sub_time_length, sub_text_length
end

local function should_skip_for_position(sub_pos, part_cfg)
  if part_cfg == nil then
    return true
  end
  if sub_pos == "end" and part_cfg.on_request then
    return true
  end
  return should_skip_because_special_sub(part_cfg)
end

local function on_pause_skip(sub_track)
  -- NOTE: We need to reveal when skipping, because otherwise having "hide while playing" enabled
  --       would mean that the sub is never displayed
  -- TODO: Honor manual visibility changes? (Applies to other places throughout the script where
  --       the visibility is changed.)
  set_sub_visibility(sub_track, true)
end

local function just_paused_for_sub_end_on_other_track(sub_track)
  local other_track = other_sub_track(sub_track)
  if state.last_pause_sub_pos[other_track] == "end" then
    local other_last_pause_time = state.last_pause_time_pos[other_track]
    if other_last_pause_time then
      local now = mp.get_property_number("time-pos")
      local delta = now - other_last_pause_time
      if delta > 0 and delta <= cfg.pair_sub_max_delta_secs then
        return true
      end
    end
  end
  return false
end

local function maybe_perform_start_pause(sub_track)
  local cfg_start = sub_track_cfg(sub_track, "start")

  if should_skip_for_position("start", cfg_start) then
    on_pause_skip(sub_track)
    return
  end

  if cfg_start.unpause then
    pause_wait_unpause(sub_track, "start", cfg_start)
  else
    pause(sub_track, "start")
  end
end

local function maybe_queue_end_pause(sub_track)
  if should_skip_for_position("end", sub_track_cfg(sub_track, "end")) then
    on_pause_skip(sub_track)
    return
  end

  state.pause_at_sub_end[sub_track] = true
end

--- CORE FUNCTIONS ---------------------------------------------------------------------------------

local function replay_sub(sub_track)
  seek_to_current_or_last_sub_start(sub_track)
  unpause()
end

local function invalidate_state_due_to_seek()
  invalidate_unpause_timer()
  state.curr_sub_end         = {nil, nil}
  state.curr_sub_time_length = {nil, nil}
  state.curr_sub_text_length = {nil, nil}
  state.last_sub_start_time  = {nil, nil}
  state.last_pause_time_pos  = {nil, nil}
  state.last_pause_sub_pos   = {nil, nil}
  state.pause_at_sub_end     = {false, false}
  state.replay_on_unpause    = {false, false}
end

--- CORE EVENTS ------------------------------------------------------------------------------------

local function handle_sub_end_time(sub_track, sub_end_time)
  if not sub_end_time then
    return
  end
  state.last_sub_start_time[sub_track] = mp.get_property_number("time-pos")
  if sub_end_time == state.curr_sub_end[sub_track] then
    -- Already handled this pause spot
    return
  end

  state.curr_sub_end[sub_track] = sub_end_time

  local sub_start_time = mp.get_property_number(sub_track_property(sub_track, "sub-start"))
  if not sub_start_time then
    return
  end

  local skip, sub_time_length, sub_text_length = should_skip_general(sub_start_time, sub_end_time)
  if skip then
    on_pause_skip(sub_track)
    return
  end
  state.curr_sub_time_length[sub_track] = sub_time_length
  state.curr_sub_text_length[sub_track] = sub_text_length

  maybe_perform_start_pause(sub_track)
  maybe_queue_end_pause(sub_track)
end

local function handle_sub_text(sub_track, sub_text)
  if sub_text == nil then
    return
  end
  -- Sometimes, for overlapping subs, we receive `sub-text` but no `sub-end`. In that case, a pause
  -- won't happen (see known issue #I in README), but we can at least reveal the subtitle in case
  -- it's hidden, so that it's not missed completely
  set_sub_visibility(sub_track, true)
end

local function handle_sub_end_reached(sub_track)
  if not state.pause_at_sub_end[sub_track] then
    return
  end
  state.pause_at_sub_end[sub_track] = false

  local cfg_end = sub_track_cfg(sub_track, "end")

  if cfg_end.race and just_paused_for_sub_end_on_other_track(sub_track) then
    return
  end

  if cfg_end.unpause then
    pause_wait_unpause(sub_track, "end", cfg_end)
  else
    pause(sub_track, "end")
  end
end

local function handle_pause(_, paused)
  if not paused then
    invalidate_unpause_timer()

    if not state.override then
      for_each_sub_track(function (track)
        if sub_track_cfg(track, nil, "hide_while_playing") then
          set_sub_visibility(track, false)
        end
      end)
    end
  end
end

local function handle_seeking(_, seeking)
  if seeking then
    invalidate_state_due_to_seek()
  end
end

local handle_sub_end_time_for_track = {
  function(_, sub_end_time) handle_sub_end_time(1, sub_end_time) end,
  function(_, sub_end_time) handle_sub_end_time(2, sub_end_time) end,
}

local handle_sub_text_for_track = {
  function(_, sub_text) handle_sub_text(1, sub_text) end,
  function(_, sub_text) handle_sub_text(2, sub_text) end,
}

local function handle_time_pos(_, time_pos)
	if time_pos == nil then
    return
  end

  for_each_sub_track(function (track)
    if state.curr_sub_end[track] then
      local sub_end_with_delay = state.curr_sub_end[track] + mp.get_property_number("sub-delay")
      if sub_end_with_delay - time_pos <= cfg.sub_end_delta_secs then
        handle_sub_end_reached(track)
      end
    end
  end)
end

--- SECONDARY EVENTS -------------------------------------------------------------------------------

local function handle_request_pause_pressed()
  if mp.get_property_bool("pause") then
    unpause()
  elseif not state.enabled then
    pause()
  else
    state.pause_at_sub_end = {
      sub_track_cfg(1, "end", "on_request") or false,
      sub_track_cfg(2, "end", "on_request") or false,
    }
    if not state.pause_at_sub_end[1] and not state.pause_at_sub_end[2] then
      pause()
    else
      state.replay_on_unpause = {
        sub_track_cfg(1, "end", "replay") or false,
        sub_track_cfg(2, "end", "replay") or false,
      }
    end
  end
end

--- INIT/DEINIT ------------------------------------------------------------------------------------

local function init_state()
  state = {
    enabled                    = false,
    override                   = false,
    unpause_timer              = nil,
    curr_sub_end               = {nil, nil},
    curr_sub_time_length       = {nil, nil},
    last_sub_start_time        = {nil, nil},
    last_pause_time_pos        = {nil, nil},
    last_pause_sub_pos         = {nil, nil},
    pause_at_sub_end           = {false, false},
    replay_on_unpause          = {false, false},
    last_message_time_ts       = 0,
    last_message_duration_secs = 0
  }
end

local function reset_state()
  invalidate_unpause_timer()
  state.enabled                    = false
  state.override                   = false
  state.unpause_timer              = nil
  state.curr_sub_end               = {nil, nil}
  state.curr_sub_time_length       = {nil, nil}
  state.curr_sub_text_length       = {nil, nil}
  state.last_sub_start_time        = {nil, nil}
  state.last_pause_time_pos        = {nil, nil}
  state.last_pause_sub_pos         = {nil, nil}
  state.pause_at_sub_end           = {false, false}
  state.replay_on_unpause          = {false, false}
  state.last_message_time_ts       = 0
  state.last_message_duration_secs = 0
end

local function deinit()
  mp.unobserve_property(handle_pause)
  mp.unobserve_property(handle_seeking)
  for_each_sub_track(function (track)
    mp.unobserve_property(handle_sub_end_time_for_track[track])
    mp.unobserve_property(handle_sub_text_for_track[track])
  end)
  mp.unobserve_property(handle_time_pos)
  reset_state()

  for_each_sub_track(function (track) set_sub_visibility(track, true) end)
end

local function init()
  deinit()

  local paused = mp.get_property_bool("pause")

  for_each_sub_track(function (track)
    local track_cfg = sub_track_cfg(track)
    if track_cfg then
      state.enabled = true

      mp.observe_property(
        sub_track_property(track, "sub-end"),
        "number",
        handle_sub_end_time_for_track[track]
      )

      if track_cfg["start"] then
        mp.observe_property(
          sub_track_property(track, "sub-text"),
          "string",
          handle_sub_text_for_track[track]
        )
      end

      if not paused and cfg[track].hide_while_playing then
        set_sub_visibility(track, false)
      end
    end
  end)

  if sub_track_cfg(1) or sub_track_cfg(2) then
    mp.observe_property("pause", "bool", handle_pause)
    mp.observe_property("seeking", "bool", handle_seeking)

    local delay_number = tonumber(cfg.sub_delay_secs)
    if delay_number then
      mp.set_property("sub-delay", delay_number)
    end
  end

  if sub_track_cfg(1, "end") or sub_track_cfg(2, "end") then
    mp.observe_property("time-pos", "number", handle_time_pos)
  end
end

local function handle_toggle_pressed()
  local state_str
  if state.enabled then
    -- Disable
    deinit()
    state.enabled = false
    state_str = "off"
  else
    -- Enable
    init()
    state.enabled = true -- NOTE: Don't move this outside the condition
    state_str = "on"
  end
  message("Subtitle pause " .. state_str, 3)
end

local function handle_override_binding(info)
  if info.event == "down" then
    state.override = true
    unpause()
  elseif info.event == "up" then
    state.override = false
  end
end

--- CONFIG PARSE -----------------------------------------------------------------------------------

local function parse_cfg()
  local new_cfg = {
    sub_end_delta_secs         = 0.1,
    sub_start_seek_offset_secs = -0.05,

    min_sub_time_length_secs = options["min-sub-duration"],
    min_sub_text_length      = options["min-sub-text-length"],
    min_pause_duration_secs  = options["min-pause-duration"],
    unpause_base_secs        = options["unpause-base"],
    unpause_text_multiplier  = options["unpause-text-multiplier"],
    unpause_time_multiplier  = options["unpause-time-multiplier"],
    unpause_exponent         = options["unpause-exponent"],
    pair_sub_max_delta_secs  = options["pair-sub-max-delta"],
    sub_delay_secs           = options["sub-delay"],
  }

  for part in options.setup:gmatch("[%w%_-%!%.]+") do
    local c = {
      on_request = false,
      replay = false,
      unpause = false,
      unpause_mode = UnpauseMode.TEXT,
      unpause_scale = 1,
      consider_special_subs = false,
      race = false,
    }

    local segs = part:gmatch("[^%!]+")

    -- Parse first seg
    local first_seg = segs()
    local sub_track = 1
    if first_seg:find("2", 1) then
      sub_track = 2
    end
    local sub_pos = first_seg:gmatch("%d?(.+)")()
    if sub_pos ~= "start" and sub_pos ~= "end" then
      goto skip
    end

    if new_cfg[sub_track] == nil then
      new_cfg[sub_track] = {
        hide_while_playing = false,
        hide_also_while_paused_for_other_track = false,
      }
    end

    -- Parse rest segs
    for seg in segs do
      local subsegs = seg:gmatch("[^-]+")
      local main = subsegs()
      if main == "request" and sub_pos == "end" then
        c.on_request = true
        if subsegs() == "replay" then
          c.replay = true
        end
      elseif main == "unpause" then
        c.unpause = true
        for arg in subsegs do
          if arg == "time" then
            c.unpause_mode = UnpauseMode.TIME
          else
            local numarg = tonumber(arg)
            if numarg ~= nil then
              c.unpause_scale = numarg
            end
          end
        end
      elseif main == "hide" then
        new_cfg[sub_track].hide_while_playing = true
        if subsegs() == "more" and sub_track == 2 then
          new_cfg[sub_track].hide_also_while_paused_for_other_track = true
        end
      elseif main == "special" and sub_track == 1 then
        c.consider_special_subs = true
      elseif main == "race" and sub_pos == "end" then
        c.race = true
      end
    end

    new_cfg[sub_track][sub_pos] = c

    ::skip::
  end

  return new_cfg
end

--- MAIN ------------------------------------------------------------------------------------------

local function main()
  require("mp.options").read_options(options, "sub-pause")
  cfg = parse_cfg()

  if sub_track_cfg(1) or sub_track_cfg(2) then
    init_state()

    mp.observe_property("current-tracks/sub/id", "number", init)

    mp.add_key_binding(nil, "toggle-pausing", handle_toggle_pressed)
    mp.add_key_binding(nil, "override-pausing", handle_override_binding, {complex = true})
    mp.add_key_binding(nil, "request-pause", handle_request_pause_pressed)
    mp.add_key_binding(DefaultKeys["replay"], "replay", function() replay_sub(1) end)
    mp.add_key_binding(nil, "replay-secondary", function() replay_sub(2) end)
  end
end

main()
