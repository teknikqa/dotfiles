#!/usr/bin/env bash
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
      . /etc/bashrc
fi

# If not running interactively, do not do anything
[[ $- != *i* ]] && return
[[ $TERM != screen* ]] && exec tmux
# TMUX
#if which tmux 2>&1 >/dev/null; then
#    #if not inside a tmux session, and if no session is started, start a new session
#    test -z "$TMUX" && (tmux attach || tmux new-session)
#
#    # when quitting tmux, try to attach
#    while test -z ${TMUX}; do
#        tmux attach || break
#    done
#fi

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# When displaying prompt, write previous command to history file so that,
# any new shell immediately gets the history lines from all previous shells.
PROMPT_COMMAND='history -a'

# Set history file length.(See HISTSIZE and HISTFILESIZE in bash(1)
HISTFILESIZE=32768
HISTSIZE=32768

# Make some commands not show up in history
HISTIGNORE="ls:ls *:cd:cd -:pwd;exit:date:* --help"

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

force_color_prompt=yes

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
if [ -f ~/.bash_aliases ]; then
      . ~/.bash_aliases
fi

# Bash functions
if [ -f ~/.bash_functions ]; then
      . ~/.bash_functions
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
      . /etc/bash_completion
fi

# Misc settings
export EDITOR=vim
# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"
# Highlight section titles in manual pages
export LESS_TERMCAP_md="$ORANGE"
export TERM=xterm-color
export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1
export LSCOLORS=ExGxFxDxCxHxHxCbCeEbEb
# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US"
export LC_CTYPE=en_US.utf-8
#export PATH=~/bin:/usr/local/bin:/home/mn/Labs/go/bin:$PATH
export IGNOREEOF=1
#export PYTHONDONTWRITEBYTECODE=1
export LESS=FRSX

# User specific aliases and functions
# Add RVM to PATH for scripting
PATH=$HOME/Apps:$PATH:$HOME/.rvm/bin
# Android ADB
PATH=$PATH:$HOME/Apps/android-sdks/tools:$HOME/Apps/android-sdks/platform-tools

# Colored Bash prompt
if [ -f ~/.bash_prompt ]; then
      . ~/.bash_prompt
fi
