#!/usr/bin/env bash

# shellcheck source=/dev/null
[ -n "$PS1" ] && source ~/.bash_profile

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$PATH:$HOME/.rvm/bin"
### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/nickmathew/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
