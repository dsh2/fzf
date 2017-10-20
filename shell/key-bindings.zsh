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
  local ret=$?
  zle reset-prompt
  return $ret
}
zle     -N   fzf-file-widget
bindkey '^T' fzf-file-widget

# Ensure precmds are run after cd
fzf-redraw-prompt() {
  local precmd
  for precmd in $precmd_functions; do
    $precmd
  done
  zle reset-prompt
}
zle -N fzf-redraw-prompt

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
  zle fzf-redraw-prompt
  return $ret
}
zle     -N    fzf-cd-widget
bindkey '\ec' fzf-cd-widget

# CTRL-R - Paste the selected command from history into the command line
# TODO: allow --multi and add binding to vimdiff the outputs

fzf-history-widget() {
	setopt localoptions noglobsubst noposixbuiltins pipefail
	local -r time_format='%a %F %T (%s)' 
	local -r ABORTED="ABORTED"
	local -r mode_switch_key=ctrl-space
	# selected=( $(([[ -n $ZLE_LINE_ABORTED ]] && echo -e $ABORTED\\t$(date +$time_format)\  ABRT\  $ZLE_LINE_ABORTED; fc -rlEDt $time_format 1) |
	local query="${LBUFFER//$/\\$}"
	local -a modes=("global" "local" "internal")
	local fzf_prompt="zsh history"
	local -i mode_index=1
	local mode_param=""
	while true; do 
		# TODO: use special word splitting instead of tie?
		local -T RESULT result $'\n'
		RESULT=$(fc ${=mode_fd_param} -rlEDt '%a %F  %T' 1 |
			$(__fzfcmd) \
			--no-sort \
			--preview "
				echo COMMAND: {7..} | pygmentize -l zsh;
				# echo EVENT ID: {3..4};
				tmux-log.sh {1}" \
			--preview-window up:45%:wrap \
			--bind "ctrl-v:execute(tmux split -v vim ~/.tmux-log/{1})" \
			--tiebreak=begin,index  \
			--print-query \
			--expect=$mode_switch_key \
			--query=$query \
			--prompt="$modes[$mode_index] $fzf_prompt: " 
			) || { (( ? == 130 )) && return ; }

		# if [ $num = $ABORTED ]; then
			# zle kill-whole-line
			# zle -U "$ZLE_LINE_ABORTED"
		# elif [ -n "$num" ]; then
			# zle vi-fetch-history -n $num
		query=$result[1]
		local key=$result[2]
		local selection=$result[3]
		if [ -z $key ]; then
			if [ -n $selection[1] ]; then
				zle vi-fetch-history -n ${selection[(w)1]}
				zle redisplay
				return $ret
			else
				print "When does this happen?"
				sleep 5
			fi
		fi
		mode_index=$((mode_index % $#modes + 1))
		case "$modes[$mode_index]" in
			"global") mode_fd_param=""; fc -P ;;
			"local") mode_fd_param=""; fc -ap $(zloc_file) ;;
			"internal") mode_fd_param="-I" ;;
		esac
	done 
}
zle     -N   fzf-history-widget
bindkey '^R' fzf-history-widget

fi
