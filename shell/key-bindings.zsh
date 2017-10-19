# Key bindings
# ------------
if [[ $- == *i* ]]; then

# CTRL-T - Paste the selected file path(s) into the command line
__fsel() {
    # local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
	  local cmd="${FZF_CTRL_T_COMMAND:-"command find -P . -mindepth 1  \
			-printf '%y%m %n %TY-%Tm-%Td %TH:%TM %u:%g %kk %p\n' 2> /dev/null" }"
	  setopt localoptions pipefail 2> /dev/null
	  # eval "$cmd" | $(__fzfcmd) +s --preview="file {}; ~/.config/ranger/scope.sh {}" -m | while read item; do
	  eval "$cmd" | $(__fzfcmd) +s --tac -m --preview-window=top:50% --preview="echo -n \"file: \"; file --brief --preserve-date --special-files --uncompress {7..}; strings {7..}" -m | while read item; do
		  local file=$(echo $item | cut -d ' ' -f 7-)
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
  local selected num
  setopt localoptions noglobsubst noposixbuiltins pipefail 2> /dev/null
  selected=( $(fc -rlEDt '%a %F  %T' 1 |
		$(__fzfcmd) \
		--no-sort \
		--preview 'echo {6..} | pygmentize -l zsh; tmux-log.sh {1}' \
		--preview-window up:5:wrap \
		--tiebreak=begin,index  \
		--toggle-sort=ctrl-r  \
		${=FZF_CTRL_R_OPTS} \
		-q "${LBUFFER//$/\\$}"
		)
	    )
  # selected=( $(fc -liED 1 | $(__fzfcmd) +s --tac +m -n4.. --tiebreak=index --toggle-sort=ctrl-r ${=FZF_CTRL_R_OPTS} -q "${LBUFFER//$/\\$}") )
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
