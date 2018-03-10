# Key bindings
# ------------
if [[ $- == *i* ]]; then

# CTRL-T - Paste the selected file path(s) into the command line
# TODO: Use a more advanced preview than strings (ranger scope?)
__fsel() {
    setopt localoptions pipefail 
    REPORTTIME=-1
    FIND_PRINTF='%y%m\t%n\t%TY-%Tm-%Td\t%TH:%TM\t%u:%g\t%kk\t%p\n'
    FIND_COLUMNS=${(ws:\t:)#FIND_PRINTF}
    command find -P ${(%)LBUFFER[(w)-1]:r} \
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
LBUFFER="${LBUFFER[(w)0,(w)-2]} $(__fsel)"
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
# TODO: allow --multi and add binding to vimdiff the outputs
fzf-history-widget() {
    setopt localoptions noglobsubst noposixbuiltins pipefail 
    local selected num
    selected=( $(fc -rlEDt '%a %F  %T' 1 |
		$(__fzfcmd) \
		--no-sort \
		--preview "
		    echo COMMAND: {6..} | pygmentize -l zsh;
		    tmux-log.sh {1}" \
		--preview-window up:45%:wrap \
		--bind "ctrl-v:execute(tmux split -v vim ~/.tmux-log/{1})" \
		--tiebreak=begin,index  \
		--toggle-sort=ctrl-r  \
		${=FZF_CTRL_R_OPTS} \
		-q "${LBUFFER//$/\\$}"
		)
	    )
    local ret=$?
    if [ -n "$selected" ]; then
	num=$selected[1]
	if [ -n "$num" ]; then
	    zle vi-fetch-history -n $num
	fi
    fi
    zle redisplay
}
zle     -N   fzf-history-widget
bindkey '^R' fzf-history-widget

fi
