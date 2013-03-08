#!/usr/bin/env bash

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# enable prompt before removal/overwritten of files/folders
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Easier navigation: .., ..., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias -- -="cd -"

#Shortcuts
alias g="git"

# We want a 256-color tmux.
alias tmux="TERM=screen-256color-bce tmux"

# List all files colorized in long format
alias l="ls -Gl"

# List all files colorized in long format, including dot files
alias la="ls -Gla"

# List only directories
alias lsd='ls -l | grep "^d"'

# Open files in default applications
alias open="xdg-open"

# yii commandl line tool
alias yii='$HOME/Apps/yii/framework/yiic'

# PHP Composer package management
alias composer='$HOME/Apps/composer/composer.phar'

# Enable aliases to be sudo’ed
# Ref: http://www.gnu.org/software/bash/manual/bashref.html#Aliases
alias sudo='sudo '

# Gzip-enabled `curl`
alias gurl="curl --compressed"

# URL-encode strings
alias urlencode='python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1]);"'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en1"
alias ips="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"

# View HTTP traffic
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

# ROT13-encode text. Works for decoding, too! ;)
alias rot13='tr a-zA-Z n-za-mN-ZA-M'

# Run Vim instead of Vi
alias vi='vim'

# Start a Python Server in the current directory
alias serve='python -m SimpleHTTPServer 8000'

# MAC manipulators
alias random_mac='sudo ifconfig wlan0 ether `openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//"`'
alias restore_mac='sudo ifconfig wlan0 ether cc:af:78:9a:e0:a7'
