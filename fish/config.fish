set fish_greeting
#set TERM "xterm-256color"
set -gx PATH ~/bin/ $PATH

set -g fish_ambiguous_width 1
set -g fish_emoji_width 1
set -g fish_width 1
# set -U fish_features qmark-noglob 

set -g fish_color_normal b9b9b9
set -g fish_color_command 5fa
set -g fish_color_keyword fa5
set -g fish_color_quote ff0
set -g fish_color_redirection b9b9b9
set -g fish_color_end fa5
set -g fish_color_error f5a
set -g fish_color_param f5a
set -g fish_color_comment 0af
set -g fish_color_selection --background=000
set -g fish_color_search_match --background=000
set -g fish_color_operator 5fa
set -g fish_color_escape f5a
set -g fish_color_autosuggestion 777
set -g fish_color_cancel f09 --reverse
set -g fish_color_option fa5
set -g fish_color_history_current --bold
set -g fish_color_status f5a
set -g fish_color_valid_path --underline
set -g fish_pager_color_progress 5fa

set -g fish_color_cwd af5
set -g fish_color_cwd_root f00
set -g fish_color_host f0f
set -g fish_color_host_remote f0f
set -g fish_color_user 0ff

set -g fish_pager_color_progress 999
set -g fish_pager_color_background 
set -g fish_pager_color_prefix ccc
set -g fish_pager_color_completion 999
set -g fish_pager_color_description 999
set -g fish_pager_color_selected_background --background=000
set -g fish_pager_color_selected_prefix ccc
set -g fish_pager_color_selected_completion f5a
set -g fish_pager_color_selected_description f0f
set -g fish_pager_color_secondary_background 
set -g fish_pager_color_secondary_prefix ccc
set -g fish_pager_color_secondary_completion 999
set -g fish_pager_color_secondary_description 999

#set -g fish_color_normal normal
#set -g fish_color_command green
#set -g fish_color_param cyan
#set -g fish_color_comment green
#set -g fish_color_error red
#set -g fish_color_keyword magenta
#set -g fish_color_quote yellow
#set -g fish_color_redirection blue
#set -g fish_color_path cyan
#set -g fish_color_valid_path --underline magenta
#set -g fish_color_invalid_path red
#set -g fish_color_selection blue
#set -g fish_color_search_match yellow
#set -g fish_color_autosuggestion 777

#set -l cyan (set_color cyan)
#set -l yellow (set_color yellow)
#set -l red (set_color red)
#set -l blue (set_color blue)
#set -l green (set_color green)
#set -l magenta (set_color magenta)
#set -l normal (set_color normal)
#set -l greyback (set_color -b "3c3c3c")
## https://fishshell.com/docs/current/cmds/set_color.html

bind \cP 'kill-bigword'
bind \co 'backward-kill-bigword'

bind \e\[1\;5D 'backward-bigword'
bind \e\[1\;5C 'forward-bigword'

#export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden --color=always"
#export FZF_DEFAULT_OPTS="--ansi --height 100%"
#export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
#export FZF_ALT_C_COMMAND="fd -t d --hidden"

#alias .='cd ../'
#alias ..='cd ../../'
#alias ...='cd ../../../'
alias notor='yt-dlp --proxy ""'
alias mpv "mpv.exe"
alias vcurl "curl -x socks5h://localhost:10808"
alias stream "streamlink"
alias gitunset "git config --global --unset https.proxy; git config --global --unset http.proxy"
alias gitv2ray "git config --global http.proxy 'socks5://127.0.0.1:10808'; git config --global https.proxy 'socks5://127.0.0.1:10808'"
alias gitfod "git config --global http.proxy fodev.org:8118; git config --global https.proxy fodev.org:8118"

function ttyd+
    ttyd -B -o -p 8080 -t cursorStyle=bar -t disableLeaveAlert=true -t fontSize=20 -t fontweight=normal -t fontWeightBold=normal -t 'theme={"foreground":"#ccc","blue":"#459ee0","green":"#82b414","cyan":"#00c2f5","red":"#fe0094","magenta":"#A376FE","yellow":"#FD971F","brightBlue":"#459ee0","brightGreen":"#82b414","brightCyan":"#00c2f5","brightRed":"#fe0094","brightMagenta":"#A376FE","brightYellow":"#FD971F","brightWhite":"#ccc","background":"#1e1e1e"}' fish
end

function notor+
    yt-dlp --proxy "" -f worst $argv -o - | mpv -
end

function vmpv
    set http_proxy "http://127.0.0.1:10808"
    mpv.com $argv
end

function vmpv+
    set http_proxy "http://127.0.0.1:10808"
    mpv.com --ytdl-format="$argv[1]" "$argv[2]"
end

function tiny
    yt-dlp $argv -f 160+140
    while test $status -ne 0
        torip
        yt-dlp $argv -f 160+140
    end
end

function audi
    yt-dlp $argv -f 140
    while test $status -ne 0
        torip
        yt-dlp $argv -f 140
    end
end

function vide
    yt-dlp $argv -f 18
    while test $status -ne 0
        torip
        yt-dlp $argv -f 18
    end
end

function yout
    yt-dlp $argv
    while test $status -ne 0
        torip
        yt-dlp $argv
    end
end

function vstream
    streamlink --http-proxy "http://127.0.0.1:10808" $argv
    while test $status -ne 0 
        torip 
        streamlink --http-proxy "http://127.0.0.1:10808" $argv 
    end 
end

function ffspace
    set -x http_proxy http://127.0.0.1:10808
    ffmpeg -i "$argv[1]" -codec copy "$argv[2].mp4"
end

function sh_c
    set quoted_args
    for arg in $argv
        set safe (string replace -a "'" "'\"'\"'" $arg)
        set quoted_args $quoted_args "'$safe'"
    end

    set cmd (string join " " $quoted_args)

    bash -c "$cmd"
end

function humanize_duration -d "Make a time interval human readable"
    if not string length --quiet $argv
         set --erase argv
         read --line argv
    end
    set hours (math --scale=0 $argv/\(3600 \*1000\))
    set mins (math --scale=0 $argv/\(60 \*1000\) % 60)
    set secs (math --scale=0 $argv/1000 % 60)
    if test $hours -gt 0
        set --append output $hours"h"
    end
    if test $mins -gt 0
        set --append output $mins"m"
    end
    if test $secs -gt 0
        set --append output $secs"s"
    end
    if not set --query output
        echo $argv"ms"
    else
        echo $output
    end
end

function fish_prompt
	set -l last_status $status
		set_color -b (random choice 000 111 222 333)
		#set_color -b (random choice 000 111 222 333 444)
		#echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		#echo -n (random choice "┃" "┇" "┋" "║" "╽" "╿")
		#set_color (random choice red green blue cyan yellow magenta)
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (date +%I:%M)
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color -b (random choice 000 111 222 333)
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (basename $PWD)
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color -b (random choice 000 111 222 333)
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		if test $CMD_DURATION
    		set -l human_command (echo $CMD_DURATION | humanize_duration) 	
		echo -n $human_command
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color -b (random choice 000 111 222 333)
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n $last_status
		echo -n " "
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color (random choice af5 5fa 0ff 0af f0f f5a fa5 ff0)
		echo -n (random choice "┏" "┓" "┗" "┛" "┣" "┫" "┻" "┳" "╋")
		set_color normal
		echo -n " "
		end
end

fzf --fish | source

# starship init fish | source




#function fish_prompt
#	set -l last_status $status
#	set_color -b "3c3c3c"
#	if test $last_status = 0
#    	echo -n "   "
#	else
#		echo -n "   "
#	end
#	set_color "f4c100" 
#	echo -n ""
#	set_color "efa500" 
#	echo -n " "
#	set_color normal
#	set_color -b "3c3c3c" 
#	echo -n (date +%I:%M:%S)" "
#	set_color "5fbe47"
#	echo -n ""
#	set_color "008982" 
#	echo -n " "
#	set_color normal 
#	set_color -b "3c3c3c"
#	echo -n (prompt_pwd)" "
#	set_color "00a8ec"
#	echo -n ""
#	set_color "0070b9"
#	echo -n " "
#	set_color normal
#	set_color -b "3c3c3c"
#    if test $CMD_DURATION
#    	set -l human_command (echo $CMD_DURATION | humanize_duration) 	
# 		echo -n $human_command
# 		echo -n " "
# 		set_color normal
# 		set_color -b "3c3c3c"
# 		set_color "d583ae"
#		echo -n ""
#		set_color "db2b86"
#		echo -n " "
#		set_color normal
# 		echo -n " "
# 	end
#end

# LOOP_CONSTRUCT; [COMMANDS...] break; [COMMANDS...] end

#function fish_prompt
#	set -l last_status $status
#	if test $last_status = 0
#		set_color -b "3c3c3c"
#		set_color "f4c100" 
#		echo -n " "
#		set_color "efa500" 
#		echo -n " "
#		set_color normal
#		set_color -b "3c3c3c" 
#		echo -n (date +%I:%M:%S)
#		set_color "5fbe47"
#		echo -n ""
#		set_color "008982" 
#		echo -n "  "
#		set_color normal 
#		set_color -b "3c3c3c"
#		echo -n (prompt_pwd)
#		set_color "00a8ec"
#		echo -n " "
#		set_color "0070b9"
#		echo -n " "
#		set_color normal
#		set_color -b "3c3c3c"
#		if test $CMD_DURATION
#    		set -l human_command (echo $CMD_DURATION | humanize_duration) 	
# 		echo -n $human_command
# 		set_color -b "3c3c3c"
# 		set_color "d583ae"
#		echo -n ""
#		set_color "db2b86"
#		echo -n "   "
#		set_color normal
#		set_color -b "3c3c3c"
#		set_color normal
#		echo -n " "
#		end
#	else
#		set_color -b "3c3c3c"
#		echo -n "  "
#		echo -n (date +%I:%M:%S)
#		echo -n "  "
#		echo -n (prompt_pwd)
#		echo -n "  "
#		if test $CMD_DURATION
#    		set -l human_command (echo $CMD_DURATION | humanize_duration) 	
# 		echo -n $human_command
#		echo -n "  "
#		set_color normal
#		echo -n " "
#	end
# 	end
#end
