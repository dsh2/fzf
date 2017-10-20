# Key bindings
# ------------
if [[ $- == *i* ]]; then

# CTRL-T - Paste the selected file path(s) into the command line
# TODO: Use a more advanced preview than strings
__fsel() {
    setopt localoptions pipefail 
    REPORTTIME=-1
    FIND_PRINTF='%y%m\t%n\t%TY-%Tm-%Td\t%TH:%TM\t%u:%g\t%kk\t%p\n'
    FIND_COLUMNS=${(ws:\t:)#FIND_PRINTF}
    command find \
		-P . \
		-mindepth 1  \
		-printf $FIND_PRINTF |
	 $(__fzfcmd) \
	     --bind "ctrl-r:execute(tmux split -h ranger {$FIND_COLUMNS..})" \
	     --bind "ctrl-v:execute(tmux split -h vim {$FIND_COLUMNS..})" \
	     --sort \
	     --multi \
	     --tabstop=6 \
	     --preview-window=top:50% \
	     --preview="
		    echo -n \"file: \";
		    file --brief \
			    --preserve-date \
			    --special-files \
			    --uncompress {$FIND_COLUMNS..}; \
		    strings {$FIND_COLUMNS..}" |
    while read item; do
	local file=$(echo $item | cut -f 7-)
	echo -n "${(q)file} "
    done
    echo
}

__fzf_use_tmux__() {
  [ -n "$TMUX_PANE" ] && [ "${FZF_TMUX:-0}" != 0 ] && [ ${LINES:-40} -gt 15 ]
}

__fzfcmd() {
  __fzf_use_tmux__ &&
    echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

fzf-file-widget() {
  LBUFFER="${LBUFFER}$(__fsel)"
  zle redisplay
}
zle     -N   fzf-file-widget
bindkey '^T' fzf-file-widget

# ALT-C - cd into the selected directory
fzf-cd-widget() {
  local cmd="${FZF_ALT_C_COMMAND:-"command find -L . -mindepth 1 -maxdepth 5 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type d -print 2> /dev/null | cut -b3-"}"
  setopt localoptions pipefail 2> /dev/null
  local dir="$(eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS" $(__fzfcmd) +m)"
  if [[ -z "$dir" ]]; then
    zle redisplay
    return 0
  fi
  cd "$dir"
  local ret=$?
  zle reset-prompt
}
zle     -N    fzf-cd-widget
bindkey '\ec' fzf-cd-widget

# CTRL-R - Paste the selected command from history into the command line
fzf-history-widget() {
    setopt localoptions noglobsubst noposixbuiltins pipefail 
    local -r mode_switch_key=ctrl-space
    local query="${LBUFFER//$/\\$}"
    local -a modes=(global local internal)
    local mode=$modes[1]
    # TODO: check if the following is zsh idiomtic. 
    local -T RESULT result $'\n'
    RESULT=$(fc -rlEDt '%a %F  %T' 1 |
		$(__fzfcmd) \
		--no-sort \
		--preview "
		    echo {6..} | pygmentize -l zsh;
		    tmux-log.sh {1}" \
		--preview-window up:5:wrap \
		--multi
		--tiebreak=begin,index  \
		--print-query \
		--expect=$mode_switch_key \
		--prompt="zsh history ($mode): " \
		--query=$query \
		)
    query=$result[1]
    local key=$result[2]
    local selection=$result[3,-1]
    local -p > /dev/stderr
    if [ -z $key ]; then
	if [ -n $selection[1] ]; then
	    zle vi-fetch-history -n $selection[1]
	fi
    else
	# TODO: iterate over modes and re-run fzf
    fi
    # zle redisplay
}
zle     -N   fzf-history-widget
bindkey '^R' fzf-history-widget

fi
