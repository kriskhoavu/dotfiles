#!/bin/zsh -f
# Status-bar weather from wttr.in, fetched at most every 15 min. Between
# fetches it only reads a cache file; a failed fetch keeps the last value.
zmodload zsh/datetime
cache=${TMPDIR:-/tmp}/tmux-weather
[[ -r $cache ]] && { read -r at; read -r value; } < $cache
if (( EPOCHSECONDS - ${at:-0} >= 900 )); then
  fresh=$(curl -fsm5 'https://wttr.in/?m&format=1') && [[ -n $fresh ]] &&
    value=${fresh// km/km} && print -r -- $EPOCHSECONDS$'\n'$value > $cache
fi
print -rn -- $value
