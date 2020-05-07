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
	local dir=${LBUFFER[(w)-1]}
	# local dir="~/.pcap"
	[[ -d $dir ]] || dir=
    command find -P $dir \
		-mindepth 1  \
		-printf $FIND_PRINTF \
		2> /dev/null |
	 $(__fzfcmd) \
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
	setopt localoptions noglobsubst noposixbuiltins 
	local query="${LBUFFER//$/\\$}"
	local -r time_format='%a %F %T' 
	local -r aborted_id="ABRT"
	local -r mode_switch_key=ctrl-space
	# TODO: rename local to path-local
	# TODO: add local mode in the sense of zsh terminology
	# TODO: add path-local-recursive
	local -a modes
	modes=("global" "local" "internal")
	# TODO: make mode persistent across invocation of widget
	# : ${mode_index:=1}
	local -i mode_index=1
	local fzf_prompt="zsh history"
	local mode_fd_param=""
	local -a fzf_result
	while :; do
		fzf_result=("${(f)$(
			( 
			# TODO: Add support for nested abortion
				[[ -n $ZLE_LINE_ABORTED ]] && 
					echo -e $aborted_id\\t$(date +$time_format)\ $ZLE_LINE_ABORTED ;
				fc $=mode_fd_param -rlEDt '%a %F  %T' 1 2> /dev/null | sed 's:[[:space:]]$::' | uniq -f 6
			) |
			# TODO: re-enable tmux support
			# $(__fzfcmd) \
			fzf \
			--multi \
			--no-sort \
			--preview "
				echo COMMAND: {7..} | pygmentize -l zsh;
				# echo EVENT ID: {3..4};
				tmux-log.sh {1}" \
			--preview-window up:45%:wrap \
			--bind "ctrl-v:execute(tmux split -v vim ~/.tmux-log/{1})" \
			--tiebreak=begin,index  \
			--print-query \
			--expect=ctrl-m,$mode_switch_key \
			--query=$query \
			--prompt="$modes[$mode_index] $fzf_prompt: "
		)}") 

		query=$fzf_result[1]
		local key=$fzf_result[2]
		case "$key" in
			"ctrl-m")
				local new_cmd_line
				local separator
				local events=(${fzf_result:2})
				for event in $events; do
					local event_id=$event[(w)1]
					[ ${event_id: -1} = "*" ] && { event_id=${event_id: : -1} }
					if [[ $event_id == $aborted_id ]]; then
						new_cmd_line+=$ZLE_LINE_ABORTED
					elif (( event_id )) then
						new_cmd_line+="$separator$history[$event_id]"
					else
						zle -M "fc returned illegal event id (event_id = \"$event_id\")."
					fi
					separator='; ' 
					# separator=$'\n'
				done
				BUFFER=$new_cmd_line
				CURSOR=$#new_cmd_line
				return
				;;
			"$mode_switch_key")
				mode_index=$((mode_index % $#modes + 1))
				case "$modes[$mode_index]" in
					"global") 
						mode_fd_param=""
						fc -P 
						;;
					"local") 
						mode_fd_param=""
						fc -ap $(zloc_file)
						;;
					"internal") 
						mode_fd_param="-I"
						fc -P 
						;;
					*)
						print "Illegal mode encountered"; sleep 5
				esac
				;;
			*)
				# zle redisplay
				# zle -M "fzf returned empty key."
				return
		esac
	done
}
zle     -N   fzf-history-widget
bindkey '^R' fzf-history-widget

fi
