#!/usr/bin/env bash

extract () {
  if [ -f $1 ] ; then
      case $1 in
          *.tar.bz2)   tar xvjf $1    ;;
          *.tar.gz)    tar xvzf $1    ;;
          *.bz2)       bunzip2 $1     ;;
          *.rar)       rar x $1       ;;
          *.gz)        gunzip $1      ;;
          *.tar)       tar xvf $1     ;;
          *.tbz2)      tar xvjf $1    ;;
          *.tgz)       tar xvzf $1    ;;
          *.zip)       unzip $1       ;;
          *.Z)         uncompress $1  ;;
          *.7z)        7z x $1        ;;
          *)           echo "don't know how to extract '$1'..." ;;
      esac
  else
      echo "'$1' is not a valid file!"
  fi
}

roll () {
  if [ "$#" -ne 0 ] ; then
    FILE="$1"
    case "$FILE" in
      *.tar.bz2|*.tbz2) shift && tar cjf "$FILE" $* ;;
      *.tar.gz|*.tgz)   shift && tar czf "$FILE" $* ;;
      *.tar)            shift && tar cf "$FILE" $* ;;
      *.zip)            shift && zip "$FILE" $* ;;
      *.rar)            shift && rar "$FILE" $* ;;
      *.7z)             shift && 7zr a "$FILE" $* ;;
      *)                echo "'$1' cannot be rolled via roll()" ;;
    esac
  else
    echo "usage: roll [file] [contents]"
  fi
}

pwgen () {
  if [ "$#" -ne 2 -o -z "$(echo "$2" | grep -E '^[0-9]+$')" ] ; then
    echo "usage: pwgen [regex] [int]"
  else
    echo "$(tr -dc "$1" < /dev/urandom | head -c "$2")"
  fi
}

calc () {
  echo "$*" | bc -l
}

start () {
  SERVICES="$@"
  for s in $SERVICES
  do
    #sudo service ${s} start
    sudo systemctl start ${s}.service
    sudo systemctl enable ${s}.service
  done
}

stop () {
  SERVICES="$@"
  for s in $SERVICES
  do
    #sudo service ${s} stop
    sudo systemctl stop ${s}.service
  done
  #sudo service "$1" stop
}

say () {
  if [[ "${1}" =~ -[a-z]{2} ]]; 
    then local lang=${1#-}; 
    local text="${*#$1}"; 
  else
    local lang=${LANG%_*};
    local text="$*";
  fi;
  mplayer "http://translate.google.com/translate_tts?ie=UTF-8&tl=${lang}&q=${text}" &> /dev/null ;
}

