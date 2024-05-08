#!/usr/bin/env bash
export LC_ALL=C
alias dotfiles='git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
