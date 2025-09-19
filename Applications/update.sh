#!/usr/bin/env zsh

NAME="$0"

#export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
#export PATH="/usr/local/sbin:$PATH"

# Load RVM into a shell session *as a function*
# shellcheck disable=SC1091
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

#TIME=$(strftime "%Y-%m-%d-at-%H.%M.%S" "$EPOCHSECONDS")

HOST=$(hostname -s)
HOST="$HOST:l"

LOCATION="$HOME/Applications"
LOG="$HOME/Library/Logs/updateApps.log"

#[[ -d "$LOG:h" ]] || mkdir -p "$LOG:h"
#[[ -e "$LOG" ]]   || touch "$LOG"

#zmodload zsh/datetime

TIME=$(date +"%Y-%m-%d at %H:%M:%S")

#function timestamp { date +"%Y-%m-%d at %H:%M:%S" }
#function log { 	echo "$NAME [`timestamp`]: $@" | tee -a "$LOG" }
function fancy_echo() {
  local FMT="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$FMT\n" "$@"
}

function log() {
  fancy_echo "========================================\n $NAME [$TIME]: \n========================================" | tee -a "$LOG";
  while read -r DATA
  do
    echo -e "$DATA" | tee -a "$LOG";
  done
  fancy_echo "Update completed at [$TIME]\n========================================" | tee -a "$LOG";
}

# Check and update Homebrew
function brew_update() {
  # Greedy flag will include casks
  brew update
  BREW_CHECK="$(brew outdated --greedy 2> /dev/null)"
  BREW_CASK_CHECK="$(brew outdated --cask --greedy 2> /dev/null)"
  if [ -z "$BREW_CHECK" ]; then
    fancy_echo 'Homebrew and other apps are up-to-date'
  else
    fancy_echo 'Upgrading Homebrew apps'
    TERMINUS_CHECK="$(brew outdated | grep terminus)"
    brew upgrade --greedy
    if [ "$TERMINUS_CHECK" ]; then
      fancy_echo 'Reload Terminus plugins'
      terminus self:plugin:reload
    fi
    # Rebuild the Open With menu it tends to have duplicates after an update.
    if [ -z "$BREW_CASK_CHECK" ]; then
      /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain user
      killall Finder
      fancy_echo "Open With has been rebuilt, Finder will relaunch"
    fi
    #for APP in $(brew list); do brew postinstall "$APP"; done;
    brew doctor
    brew autoremove
    brew cleanup
  fi
}

# Check and update Composer packages
function composer_update() {
  COMPOSER_CHECK="$(composer global outdated 2> /dev/null)"
  if [ -z "$COMPOSER_CHECK" ]; then
    fancy_echo 'Composer packages are up-to-date'
  else
    fancy_echo 'Upgrading Composer packages'
    composer global update
  fi
}

# Check and update Ruby Gems
function gem_update() {
  fancy_echo "Updating Ruby gems:"
  gem update --system --quiet --no-document --no-post-install-message
}

# Check and update Node
function node_update() {
  NODE_CHECK="$(npm outdated -g --depth=0 2> /dev/null)"
  if [ -z "$NODE_CHECK" ]; then
    fancy_echo 'Node and other packages are up-to-date'
  else
    fancy_echo 'Upgrading Node and packages'
    npm update -g
  fi
}

# Update Oh My Zsh
function omz_update() {
  fancy_echo 'Updating Oh My Zsh'
  # upgrade_oh_my_zsh
  . ~/.oh-my-zsh/oh-my-zsh.sh
  omz update
}

# Check and update RVM
function rvm_update() {
  #LOCAL_VERSION="$(rvm --version 2> /dev/null | awk '$2 != ""{print $2}')"
  LOCAL_VERSION="$(rvm --version 2> /dev/null | awk '{print $2}')"
  #curl -sS  https://api.github.com/repos/rvm/rvm/git/refs/tags | awk -F": |\"" '$2=="ref"{sub(/.*\//,"",$5); print $5}' | sort -V | tail -n 1
  LATEST_VERSION="$(curl -s https://raw.githubusercontent.com/rvm/rvm/stable/VERSION)"

  if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
    fancy_echo 'Upgrading RVM'
    rvm get stable --auto-dotfiles --autolibs=enable
  else
    fancy_echo "RVM is already up-to-date ($LATEST_VERSION)"
  fi
}

# Update Pantheon Terminus
function terminus_update() {
  # Note: This only works for the self-contained version of Terminus.
  fancy_echo 'Updating Pantheon Terminus'
  pushd "$LOCATION/terminus" || exit
  composer self-update --2
  composer update
  composer self-update --1
  popd || exit
  # terminus self:update
  # Reload the plugins.
  terminus self:plugin:reload
}

# Check for updates to Vagrant
function vagrant_update() {
  LOCAL_VERSION="$(vagrant -v 2> /dev/null | awk '$2 != ""{print $2}')"
  #LATEST_VERSION="$(curl -s https://raw.githubusercontent.com/mitchellh/vagrant/master/version.txt)"
  #LATEST_VERSION="$(curl -s https://teknikqa:af511006c5f1d3a7b647db70bb4076291c651a15@api.bintray.com/packages/mitchellh/vagrant/vagrant/versions/_latest | jsawk 'return this.name')"
  LATEST_VERSION="$(vagrant version 2> /dev/null | awk 'FNR ==2 {print $3}')"

  if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
    # This is currently a manual step. Needs more testing before we can safely auto-update
    terminal-notifier -title 'Vagrant' -message "Vagrant needs updating Installed Version: $LOCAL_VERSION  Latest Version: $LATEST_VERSION" -open 'https://www.vagrantup.com/downloads.html'
    fancy_echo 'Vagrant needs updating'
  else
    fancy_echo "Vagrant is already up-to-date ($LATEST_VERSION)"
  fi

  vagrant plugin update
}

# Check for updates to Virtual Box
function VBoxManage_update() {
  # Get version and strip unnecessary characters
  LOCAL_VERSION="$(VBoxManage -v 2> /dev/null | awk -F'r' '{print $1}')"
  LATEST_VERSION="$(curl -s http://download.virtualbox.org/virtualbox/LATEST.TXT)"

  if [ "$LOCAL_VERSION" != "$LATEST_VERSION" ]; then
    # This is currently a manual step. Needs more testing before we can safely auto-update
    terminal-notifier -title 'VirtualBox' -message "VirtualBox needs updating. Installed Version: $LOCAL_VERSION  Latest Version: $LATEST_VERSION" -open 'https://www.virtualbox.org/wiki/Downloads'
    fancy_echo 'VirtualBox needs updating'
    #http://download.virtualbox.org/virtualbox/$LATEST_VERSION/VirtualBox-$LATEST_VERSION-98988-OSX.dmg
  else
    fancy_echo "VirtualBox is already up-to-date ($LATEST_VERSION)"
  fi
}

# Update Vim plugins
function vim_update() {
  PATHOGEN_DIR="${HOME}/.vim/autoload"
  BUNDLES_DIR="${HOME}/.vim/bundle"

  if [[ -d "${PATHOGEN_DIR}" ]]; then
    fancy_echo "Updating pathogen"
    curl -Sso "${PATHOGEN_DIR}/pathogen.vim" \
      https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim
  else
    fancy_echo "No pathogen plugins to update"
  fi

  if [[ -d "${BUNDLES_DIR}" ]]; then
    fancy_echo "Updating vim bundles"
    for BUNDLE in "${BUNDLES_DIR}/"*; do
      if [[ -d "${BUNDLE}/.git" ]]; then
        fancy_echo "Bundle: ${BUNDLE}..."
        cd "${BUNDLE}" || exit
        git pull
      fi
    done
  else
    fancy_echo "No Vim bundle plugins to update"
  fi
}

RET=FALSE
# Check if a command exists
function command_exists() {
  # This is Bash specific.
  # type -P "$1" &>/dev/null && RET=TRUE || RET=FALSE
  #which "$1" &>/dev/null && RET=TRUE || RET=FALSE
  command -v "$1" >/dev/null 2>&1 && RET=TRUE || RET=FALSE
}

# Update extensions of VS Code and other editors based on the same engine
function code_update() {
  editors=("code" "cursor" "kiro" "trae" "windsurf")

  # Loop through each editor
  for editor in "${editors[@]}"; do
    if command_exists "$editor"; then
      fancy_echo "Updating $editor extensions"
      "$editor" --update-extensions
    else
      fancy_echo "$editor not installed. Skipping extensions update."
    fi
  done
}

# Update apps declared in the COMMANDS array
function update_all() {
  # Ensure brew is the last item on this list. Updating some casks require user
  # password. If this script is run automatically, there is potential for it to
  # not complete. Updating brew packages towards the end will ensure that almost
  # everything else is updated.
  # Updates availabe for:
  #   brew
  #   code # Extensions for VS Code and other editors based on the same engine
  #   composer
  #   gem
  #   node
  #   omz # Oh-My-Zsh
  #   rvm
  #   terminus
  #   vagrant
  #   VBoxManage
  #   vim #plugins
  COMMANDS=('node' 'composer' 'code' 'brew' 'omz' )
  NUMBER_COMMANDS=${#COMMANDS[@]}
  # bash starts arrays at 0, zsh at 1.
  for (( i=1; i<=NUMBER_COMMANDS; i++ ))
  do
    local cmd="${COMMANDS[$i]}"
    
    # Special handling for omz (Oh My Zsh) since it's not a regular command
    if [ "$cmd" = "omz" ]; then
      if [[ -d "$HOME/.oh-my-zsh" ]]; then
        fancy_echo "Going to update $cmd:"
        "${cmd}_update"
        fancy_echo "========================================"
      else
        fancy_echo "Oh My Zsh not installed. Skipping."
      fi
    else
      # Check if command exists for all other commands
      if command_exists "$cmd"; then
        fancy_echo "Going to update $cmd:"
        "${cmd}_update"
        fancy_echo "========================================"
      else
        fancy_echo "$cmd not installed. Skipping."
      fi
    fi
    # Original code
    : '
    RET=FALSE
    if [ "${COMMANDS[$i]}" != omz ]
    then
      command_exists "${COMMANDS[$i]}"
    fi
    # Ignore the above check and update everything.
    RET=TRUE
    if [ "${RET}" = "TRUE" ]
    then
      fancy_echo "Going to update ${COMMANDS[$i]}:"
      "${COMMANDS[$i]}"_update
      fancy_echo "========================================"
    fi
    '
  done
}

(update_all) 2>&1 | log "$@"

exit 0
