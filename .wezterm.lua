local wezterm = require 'wezterm'
local mux = wezterm.mux
local act = wezterm.action
local config = wezterm.config_builder()

config.default_prog = {"C:\\cygwin64\\bin\\fish.exe", "--login", "-i"}
config.color_scheme = 'GitHub Dark'
config.font = wezterm.font('SauceCodePro NFM', {weight = 'Regular', italic = false, bold=false})
config.window_close_confirmation = 'NeverPrompt'
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600
config.font_size = 11
config.line_height = 0.9
config.bold_brightens_ansi_colors = false
config.check_for_updates = false
config.show_update_window = false
config.pane_focus_follows_mouse = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'NONE'
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.initial_rows = 13
config.initial_cols = 142
-- config.disable_default_key_bindings = true
-- config.disable_default_mouse_bindings = true
config.use_fancy_tab_bar = false
config.tab_max_width = 32

config.font_rules = { { intensity = "Bold", font = wezterm.font("SauceCodePro NFM", { weight = "Regular", italic = false }) } }

config.colors = {
    background = '#1e1e1e',
    foreground = '#b9b9b9',
    cursor_bg = '#b9b9b9',
    cursor_fg = '#1e1e1e',
    cursor_border = '#b9b9b9',
    selection_bg = '#777777',
    selection_fg = '#b9b9b9',
    ansi = {
      '#1e1e1e', -- black
      '#fe0094', -- red
      '#82b414', -- green
      '#FD971F', -- yellow
      '#459ee0', -- blue
      '#A376FE', -- magenta
      '#00c2f5', -- cyan
      '#b9b9b9', -- white
    },
    brights = {
      '#777777', -- bright black
      '#fe0094', -- bright red
      '#82b414', -- bright green
      '#FD971F', -- bright yellow
      '#459ee0', -- bright blue
      '#A376FE', -- bright magenta
      '#00c2f5', -- bright cyan
      '#b9b9b9', -- bright white
    },
}

wezterm.on("gui-startup", function(cmd)
  local main_screen = wezterm.gui.screens().main
  local position = {
  	x = 0,
    y = 826,
}
   cmd = cmd or { position = position }
   wezterm.mux.spawn_window(cmd)
end)

config.keys = {
  {key="v", mods="ALT",
    action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
  {key="h", mods="ALT",
    action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
  {key="t", mods="ALT",
    action=wezterm.action{SpawnTab="CurrentPaneDomain"}},
  {key = 'v', mods = 'CTRL', action=act.PasteFrom 'Clipboard'},
  {key="LeftArrow", mods="ALT", action=wezterm.action{ActivatePaneDirection="Left"}},
  {key="DownArrow", mods="ALT", action=wezterm.action{ActivatePaneDirection="Down"}},
  {key="UpArrow", mods="ALT", action=wezterm.action{ActivatePaneDirection="Up"}},
  {key="RightArrow", mods="ALT", action=wezterm.action{ActivatePaneDirection="Right"}},
}

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.Multiple {
    act.SendString ' ',
    act.PasteFrom 'Clipboard',
    }
  },
}

return config

-- https://github.com/junguler/dotfiles/blob/7f20ab737b9db65106de81ba853d7d16d7342c1e/wezterm/wezterm.lua