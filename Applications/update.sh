#!/usr/bin/env zsh

# Basic setup without strict mode initially
NAME="$(basename "$0")"
HOST=$(hostname -s | tr '[:upper:]' '[:lower:]' 2>/dev/null || hostname -s)
LOCATION="$HOME/Applications"
LOG_DIR="$HOME/Library/Logs"
LOG="$LOG_DIR/updateApps.log"
TIME=$(date +"%Y-%m-%d at %H:%M:%S")

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" 2>/dev/null || true

# Enhanced logging with colors and better formatting
function fancy_echo() {
  local fmt="$1"; shift
  # Add colors for better readability (but make them optional)
  if [[ -t 1 ]]; then  # Only use colors if outputting to a terminal
    local green='\033[0;32m'
    local blue='\033[0;34m' 
    local yellow='\033[1;33m'
    local red='\033[0;31m'
    local nc='\033[0m' # No Color
    
    case "$fmt" in
      *"Going to update"*) printf "\n${blue}$fmt${nc}\n" "$@" ;;
      *"up-to-date"*) printf "${green}$fmt${nc}\n" "$@" ;;
      *"Upgrading"*|*"Updating"*) printf "${yellow}$fmt${nc}\n" "$@" ;;
      *"timeout"*|*"failed"*|*"Error"*) printf "${red}$fmt${nc}\n" "$@" ;;
      *) printf "\n$fmt\n" "$@" ;;
    esac
  else
    printf "\n$fmt\n" "$@"
  fi
}

function log_header() {
  fancy_echo "========================================"
  fancy_echo " $NAME [$TIME] on $HOST"
  fancy_echo "========================================"
}

function log_footer() {
  local end_time=$(date +"%Y-%m-%d at %H:%M:%S")
  fancy_echo "========================================"
  fancy_echo "Update completed at [$end_time]"
  fancy_echo "========================================"
}

function log() {
  {
    log_header
    while IFS= read -r line; do
      echo "$line"
    done
    log_footer
  } | tee -a "$LOG"
}

# Enhanced error handling
function handle_error() {
  local exit_code=$?
  local line_number=$1
  fancy_echo "Error occurred in script at line $line_number. Exit code: $exit_code"
  # Don't exit immediately, let the script continue
  return $exit_code
}

function enable_strict_mode() {
  # Use a gentler approach - only exit on command failures, not variable issues
  set -e  # Exit on error
  trap 'handle_error $LINENO' ERR
}

# Check if a command exists - simplified
function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

function check_if_touchid_exists() {
  # Check if the bioutil command exists
  if ! command -v bioutil &> /dev/null; then
      echo "not_supported"
      return 1
  fi

  # Get Touch ID configuration status - search for multiple possible strings
  local TouchIDStatus=$(bioutil -rs 2>/dev/null | grep -E "(Biometrics for unlock|Touch ID for unlock)" | awk '{print $NF}')

  # Interpret the status and return standardized values
  if [[ "$TouchIDStatus" == "1" ]]; then
      echo "enabled"
      return 0
  elif [[ "$TouchIDStatus" == "0" ]]; then
      echo "disabled"
      return 0
  else
      # If the grep command doesn't find the Touch ID/Biometrics unlock line,
      # it likely means Touch ID hardware is not present.
      echo "not_available"
      return 1
  fi
}

# Determine the best cask strategy based on Touch ID status and environment
function determine_cask_strategy() {
  # If user explicitly set a strategy, respect it
  if [[ -n "${BREW_CASK_STRATEGY:-}" ]]; then
    echo "${BREW_CASK_STRATEGY}"
    return 0
  fi
  
  # Check Touch ID status
  local touchid_status=$(check_if_touchid_exists)
  local touchid_exit_code=$?
  
  fancy_echo "Touch ID Status: $touchid_status"
  
  # Check if Touch ID is configured for sudo
  local sudo_touchid_configured=false
  if grep -q "auth.*pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
    sudo_touchid_configured=true
  fi
  
  # Determine strategy based on Touch ID status and configuration
  case "$touchid_status" in
    "enabled")
      if [[ "$sudo_touchid_configured" == "true" ]]; then
        echo "touchid"
        fancy_echo "Using Touch ID strategy (Touch ID enabled and configured for sudo)"
      else
        echo "sudo-askpass"
        fancy_echo "Using GUI password strategy (Touch ID enabled but not configured for sudo)"
      fi
      ;;
    "disabled")
      if [[ -t 0 ]]; then  # Interactive terminal
        echo "prompt"
        fancy_echo "Using prompt strategy (Touch ID disabled, running interactively)"
      else
        echo "schedule"
        fancy_echo "Using schedule strategy (Touch ID disabled, running non-interactively)"
      fi
      ;;
    "not_available"|"not_supported")
      if [[ -t 0 ]]; then  # Interactive terminal
        echo "prompt"
        fancy_echo "Using prompt strategy (No Touch ID hardware, running interactively)"
      else
        echo "skip"
        fancy_echo "Using skip strategy (No Touch ID hardware, running non-interactively)"
      fi
      ;;
    *)
      echo "skip"
      fancy_echo "Using skip strategy (Unable to determine Touch ID status)"
      ;;
  esac
}

# Check and update Homebrew
function brew_update() {
  if ! command_exists brew; then
    fancy_echo "Homebrew not installed. Skipping."
    return 0
  fi

  fancy_echo "Updating Homebrew..."
  brew update
  
  local brew_outdated cask_outdated
  brew_outdated=$(brew outdated 2>/dev/null) || true
  cask_outdated=$(brew outdated --cask --greedy 2>/dev/null) || true
  
  if [[ -z "$brew_outdated" && -z "$cask_outdated" ]]; then
    fancy_echo 'Homebrew packages and casks are up-to-date'
    return 0
  fi

  # Update regular packages first (these don't need sudo)
  if [[ -n "$brew_outdated" ]]; then
    fancy_echo 'Upgrading Homebrew packages (no password required)...'
    
    # Check for Terminus before upgrading
    local terminus_check
    terminus_check=$(echo "$brew_outdated" | grep terminus || true)
    
    brew upgrade
    
    # Handle Terminus plugin reload if needed
    if [[ -n "$terminus_check" ]] && command_exists terminus; then
      fancy_echo 'Reloading Terminus plugins'
      terminus self:plugin:reload || true
    fi
  fi

  # Handle casks that may require password
  if [[ -n "$cask_outdated" ]]; then
    # Determine the best strategy based on Touch ID status
    local strategy=$(determine_cask_strategy)
    fancy_echo "Using cask update strategy: $strategy"
    handle_cask_updates "$cask_outdated" "$strategy"
  fi
  
  fancy_echo "Running brew maintenance..."
  brew doctor || true
  brew autoremove || true
  brew cleanup || true
}

# Handle cask updates with dynamic strategy selection
function handle_cask_updates() {
  local cask_list="$1"
  local strategy="${2:-skip}"  # Use passed strategy or default to skip
  
  case "$strategy" in
    "sudo-askpass")
      handle_casks_with_askpass "$cask_list"
      ;;
    "touchid")
      handle_casks_with_touchid_timeout "$cask_list"
      ;;
    "schedule")
      schedule_cask_updates "$cask_list"
      ;;
    "prompt")
      handle_casks_with_prompt "$cask_list"
      ;;
    "skip"|*)
      handle_casks_without_password "$cask_list"
      ;;
  esac
  
  # Rebuild Open With menu after any cask updates
  fancy_echo "Rebuilding Open With menu..."
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain user || true
  killall Finder 2>/dev/null || true
  fancy_echo "Open With menu rebuilt, Finder relaunched"
}

# Touch ID with timeout fallback to non-interactive mode
function handle_casks_with_touchid_timeout() {
  local cask_list="$1"
  local timeout_duration=30
  
  # Double-check Touch ID configuration (redundant safety check)
  if ! grep -q "auth.*pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
    fancy_echo "Touch ID not configured for sudo, falling back to non-interactive mode"
    handle_casks_without_password "$cask_list"
    return 0
  fi
  
  fancy_echo "Updating casks with Touch ID authentication (30 second timeout)..."
  
  # Create a temporary script for the brew command
  local temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
exec brew upgrade --cask --greedy
EOF
  chmod +x "$temp_script"
  
  # Use timeout with the brew command
  local update_success=false
  
  if command_exists timeout; then
    # GNU timeout (from coreutils)
    if timeout ${timeout_duration}s sudo "$temp_script"; then
      update_success=true
    fi
  elif command_exists gtimeout; then
    # GNU timeout with g prefix
    if gtimeout ${timeout_duration}s sudo "$temp_script"; then
      update_success=true
    fi
  else
    # Fallback using expect-like behavior with read timeout
    fancy_echo "Using fallback timeout method..."
    if run_with_timeout ${timeout_duration} sudo "$temp_script"; then
      update_success=true
    fi
  fi
  
  # Clean up temp script
  rm -f "$temp_script"
  
  # If Touch ID failed or timed out, fallback to non-interactive mode
  if [[ "$update_success" == "false" ]]; then
    fancy_echo "Touch ID authentication timed out or failed, falling back to non-interactive mode..."
    handle_casks_without_password "$cask_list"
  else
    fancy_echo "Cask updates completed successfully with Touch ID"
  fi
}

# Fallback timeout function for systems without GNU timeout
function run_with_timeout() {
  local timeout_duration=$1
  shift
  local cmd=("$@")
  
  # Start the command in background
  "${cmd[@]}" &
  local cmd_pid=$!
  
  # Start a timeout process
  (
    sleep ${timeout_duration}
    kill -TERM $cmd_pid 2>/dev/null
    sleep 2
    kill -KILL $cmd_pid 2>/dev/null
  ) &
  local timeout_pid=$!
  
  # Wait for either the command or timeout
  if wait $cmd_pid 2>/dev/null; then
    # Command completed successfully
    kill $timeout_pid 2>/dev/null
    return 0
  else
    # Command failed or was killed by timeout
    kill $timeout_pid 2>/dev/null
    return 1
  fi
}

# Strategy 1: Use GUI password prompt (best for automated runs)
function handle_casks_with_askpass() {
  local cask_list="$1"
  
  # Create a simple AppleScript-based askpass helper
  local askpass_script="/tmp/brew_askpass_$$"
  cat > "$askpass_script" << 'EOF'
#!/usr/bin/env osascript
on run argv
    return text returned of (display dialog "Homebrew cask update requires admin password:" with title "Homebrew Update" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK")
end run
EOF
  
  chmod +x "$askpass_script"
  
  fancy_echo "Updating casks with GUI password prompt..."
  SUDO_ASKPASS="$askpass_script" sudo -A brew upgrade --cask --greedy || {
    fancy_echo "Cask update failed or was cancelled"
  }
  
  rm -f "$askpass_script"
}

# Strategy 3: Schedule for later (using launchd)
function schedule_cask_updates() {
  local cask_list="$1"
  local plist="$HOME/Library/LaunchAgents/com.user.brew-cask-update.plist"
  local script="$HOME/.brew-cask-update.sh"
  
  # Create the update script
  cat > "$script" << EOF
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
/opt/homebrew/bin/brew upgrade --cask --greedy
# Clean up the scheduled job
launchctl unload "$plist" 2>/dev/null || true
rm -f "$plist" "$script"
EOF
  chmod +x "$script"
  
  # Create the launchd plist for interactive execution
  cat > "$plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.brew-cask-update</string>
    <key>Program</key>
    <string>$script</string>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/brew-cask-update.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/brew-cask-update.log</string>
</dict>
</plist>
EOF
  
  fancy_echo "Cask updates scheduled. Run manually when convenient:"
  fancy_echo "  launchctl load '$plist' && launchctl start com.user.brew-cask-update"
  fancy_echo "Or simply run: $script"
}

# Strategy 4: Interactive prompt (default)
function handle_casks_with_prompt() {
  local cask_list="$1"
  
  if [[ -t 0 ]]; then  # Only prompt if running interactively
    fancy_echo "The following casks need updates and may require admin password:"
    echo "$cask_list" | while read -r cask; do
      echo "  - $cask"
    done
    
    echo
    read -p "Update casks now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      fancy_echo "Updating casks (password may be required)..."
      brew upgrade --cask --greedy || {
        fancy_echo "Some cask updates may have failed"
      }
    else
      fancy_echo "Cask updates skipped"
      schedule_cask_updates "$cask_list"
    fi
  else
    fancy_echo "Running non-interactively - scheduling cask updates for later"
    schedule_cask_updates "$cask_list"
  fi
}

# Strategy 5: Skip updating casks that require password
function handle_casks_without_password() {
  local cask_list="$1"

  fancy_echo "Updating casks in non-interactive mode..."
  NONINTERACTIVE=1 brew upgrade --cask --greedy || {
    fancy_echo "Some cask updates that require password were skipped"
  }
}

# Check and update Composer packages
function composer_update() {
  if ! command_exists composer; then
    fancy_echo "Composer not installed. Skipping."
    return 0
  fi

  local composer_outdated
  composer_outdated=$(composer global outdated --direct 2>/dev/null) || true
  
  if [[ -z "$composer_outdated" ]]; then
    fancy_echo 'Composer packages are up-to-date'
  else
    fancy_echo 'Upgrading Composer packages'
    composer global update || true
  fi
}

# Check and update Ruby Gems
function gem_update() {
  if ! command_exists gem; then
    fancy_echo "Ruby/gem not installed. Skipping."
    return 0
  fi

  fancy_echo "Updating Ruby gems..."
  gem update --system --quiet --no-document --no-post-install-message || true
}

# Check and update Node packages
function node_update() {
  if ! command_exists npm; then
    fancy_echo "Node/npm not installed. Skipping."
    return 0
  fi

  local node_outdated
  node_outdated=$(npm outdated -g --depth=0 2>/dev/null) || true
  
  if [[ -z "$node_outdated" ]]; then
    fancy_echo 'Node packages are up-to-date'
  else
    fancy_echo 'Upgrading Node packages'
    npm update -g || true
  fi
}

# Update Oh My Zsh
function omz_update() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    fancy_echo "Oh My Zsh not installed. Skipping."
    return 0
  fi

  fancy_echo 'Updating Oh My Zsh'
  # Source oh-my-zsh first
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && source "$HOME/.oh-my-zsh/oh-my-zsh.sh"
  
  if command_exists omz; then
    omz update --unattended || true
  else
    fancy_echo "omz command not found, trying legacy update method"
    cd "$HOME/.oh-my-zsh" && git pull origin master || true
  fi
}

# Check and update RVM
function rvm_update() {
  if ! command_exists rvm; then
    fancy_echo "RVM not installed. Skipping."
    return 0
  fi

  local local_version latest_version
  local_version=$(rvm --version 2>/dev/null | awk '{print $2}') || return 0
  latest_version=$(curl -s --connect-timeout 10 https://raw.githubusercontent.com/rvm/rvm/stable/VERSION 2>/dev/null) || {
    fancy_echo "Could not check RVM version. Skipping update."
    return 0
  }

  if [[ "$local_version" != "$latest_version" ]]; then
    fancy_echo 'Upgrading RVM'
    rvm get stable --auto-dotfiles --autolibs=enable || true
  else
    fancy_echo "RVM is already up-to-date ($latest_version)"
  fi
}

# Update Pantheon Terminus
function terminus_update() {
  local terminus_dir="$LOCATION/terminus"
  
  if [[ ! -d "$terminus_dir" ]]; then
    fancy_echo "Terminus directory not found. Skipping."
    return 0
  fi

  fancy_echo 'Updating Pantheon Terminus'
  pushd "$terminus_dir" >/dev/null || return 1
  
  # Update Composer first, then packages
  composer self-update --2 || true
  composer update || true
  
  popd >/dev/null || return 1
  
  # Reload plugins if terminus command exists
  if command_exists terminus; then
    terminus self:plugin:reload || true
  fi
}

# Check for updates to Vagrant
function vagrant_update() {
  if ! command_exists vagrant; then
    fancy_echo "Vagrant not installed. Skipping."
    return 0
  fi

  local local_version latest_version
  local_version=$(vagrant --version 2>/dev/null | awk '{print $2}') || return 0
  latest_version=$(vagrant version --machine-readable 2>/dev/null | grep ',version-current,' | cut -d',' -f4) || {
    fancy_echo "Could not check Vagrant version. Updating plugins only."
    vagrant plugin update || true
    return 0
  }

  if [[ "$local_version" != "$latest_version" ]]; then
    fancy_echo "Vagrant update available: $local_version -> $latest_version"
    # Only notify, don't auto-update
    if command_exists terminal-notifier; then
      terminal-notifier -title 'Vagrant' -message "Vagrant needs updating. Installed: $local_version, Latest: $latest_version" -open 'https://www.vagrantup.com/downloads.html' || true
    fi
  else
    fancy_echo "Vagrant is up-to-date ($latest_version)"
  fi

  # Always update plugins
  vagrant plugin update || true
}

# Check for updates to VirtualBox
function vbox_update() {
  if ! command_exists VBoxManage; then
    fancy_echo "VirtualBox not installed. Skipping."
    return 0
  fi

  local local_version latest_version
  local_version=$(VBoxManage --version 2>/dev/null | cut -d'r' -f1) || return 0
  latest_version=$(curl -s --connect-timeout 10 http://download.virtualbox.org/virtualbox/LATEST.TXT 2>/dev/null) || {
    fancy_echo "Could not check VirtualBox version. Skipping."
    return 0
  }

  if [[ "$local_version" != "$latest_version" ]]; then
    fancy_echo "VirtualBox update available: $local_version -> $latest_version"
    if command_exists terminal-notifier; then
      terminal-notifier -title 'VirtualBox' -message "VirtualBox needs updating. Installed: $local_version, Latest: $latest_version" -open 'https://www.virtualbox.org/wiki/Downloads' || true
    fi
  else
    fancy_echo "VirtualBox is up-to-date ($latest_version)"
  fi
}

# Update Vim plugins - reuse existing vim update script if available
function vim_update() {
  local vim_script="$HOME/bin/update-vim.sh"
  
  if [[ -x "$vim_script" ]]; then
    fancy_echo "Running vim update script..."
    "$vim_script" || true
    return 0
  fi

  # Fallback to inline vim update
  local pathogen_dir="$HOME/.vim/autoload"
  local bundles_dir="$HOME/.vim/bundle"

  if [[ -d "$pathogen_dir" ]]; then
    fancy_echo "Updating pathogen..."
    curl -Sso "$pathogen_dir/pathogen.vim" \
      https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim || true
  fi

  if [[ -d "$bundles_dir" ]]; then
    fancy_echo "Updating vim bundles..."
    for bundle in "$bundles_dir"/*; do
      if [[ -d "$bundle/.git" ]]; then
        fancy_echo "Updating bundle: $(basename "$bundle")..."
        (cd "$bundle" && git pull) || true
      fi
    done
  else
    fancy_echo "No Vim bundles to update"
  fi
}

# Update VS Code and similar editor extensions
function code_update() {
  local editors=("code" "cursor" "kiro" "trae" "windsurf")

  for editor in "${editors[@]}"; do
    if command_exists "$editor"; then
      fancy_echo "Updating $editor extensions"
      # Run in background with timeout alternative for macOS
      if command_exists timeout; then
        # Use GNU timeout if available
        timeout 300 "$editor" --update-extensions || {
          fancy_echo "Warning: $editor extension update timed out or failed"
        }
      elif command_exists gtimeout; then
        # Use GNU timeout if available (brew install coreutils)
        gtimeout 300 "$editor" --update-extensions || {
          fancy_echo "Warning: $editor extension update timed out or failed"
        }
      else
        # Fallback without timeout
        "$editor" --update-extensions || {
          fancy_echo "Warning: $editor extension update failed"
        }
      fi
    fi
  done
}

# Python package updates (pip)
function pip_update() {
  if command_exists pip3; then
    fancy_echo "Updating pip and global packages..."
    pip3 install --upgrade pip || true
    # Update commonly used global packages
    pip3 install --upgrade setuptools wheel virtualenv || true
  fi
  
  if command_exists pipx; then
    fancy_echo "Updating pipx packages..."
    pipx upgrade-all || true
  fi
}

# Rust updates
function rust_update() {
  if command_exists rustup; then
    fancy_echo "Updating Rust toolchain..."
    rustup update || true
  fi
  
  if command_exists cargo; then
    fancy_echo "Updating cargo packages..."
    cargo install-update -a || true
  fi
}

# Main update function
function update_all() {
  # Define update commands in order of preference
  # Brew last as it may require user interaction
  local commands=(
    'node'
    #'pip' 
    'composer'
    'code'
    #'vim'
    #'rust'
    #'gem'
    #'rvm'
    'omz'
    'terminus'
    #'vagrant'
    #'vbox'
    'brew'
  )

  local total=${#commands[@]}
  local current=1

  for cmd in "${commands[@]}"; do
    fancy_echo "[$current/$total] Checking $cmd updates..."
    
    # Call the corresponding update function
    "${cmd}_update" || {
      fancy_echo "Warning: $cmd update failed, continuing with other updates..."
    }
    
    fancy_echo "========================================"
    
    # Increment counter (safer way)
    current=$((current + 1))
  done
}

# Parse command line arguments
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        cat << EOF
Usage: $NAME [OPTIONS] [COMMANDS...]

Update various development tools and packages.

OPTIONS:
  --help, -h     Show this help message
  --list, -l     List available update commands
  --verbose, -v  Enable verbose output
  --dry-run, -n  Show what would be updated without making changes

BREW CASK PASSWORD STRATEGIES:
  Set BREW_CASK_STRATEGY environment variable to override auto-detection:
  - touchid: Use Touch ID with 30s timeout, fallback to non-interactive
  - prompt: Ask interactively, schedule if non-interactive
  - skip: Skip all cask updates that require password
  - sudo-askpass: Use GUI password dialog (best for automation)
  - schedule: Create a launchd job to run later

  If not set, strategy is automatically determined based on Touch ID status:
  - Touch ID enabled + sudo configured → touchid strategy
  - Touch ID enabled but sudo not configured → sudo-askpass strategy
  - Touch ID disabled + interactive → prompt strategy
  - Touch ID disabled + non-interactive → schedule strategy
  - No Touch ID + interactive → prompt strategy
  - No Touch ID + non-interactive → skip strategy

COMMANDS:
  If specific commands are provided, only those will be updated.
  Available commands: brew, composer, node, gem, rvm, omz, terminus, vagrant, vbox, vim, code, pip, rust

EXAMPLES:
  $NAME                                    # Update everything (auto-detect strategy)
  $NAME brew node                          # Update only Homebrew and Node
  $NAME --dry-run                          # Show what would be updated
  BREW_CASK_STRATEGY=skip $NAME           # Force skip casks requiring password
  BREW_CASK_STRATEGY=sudo-askpass $NAME   # Force GUI password prompt
  BREW_CASK_STRATEGY=prompt $NAME         # Force interactive prompts

TOUCH ID SETUP:
  To enable Touch ID for sudo (recommended):
  1. sudo vim /etc/pam.d/sudo
  2. Add this line at the top: auth sufficient pam_tid.so
  3. Save and restart terminal
  
  The script now automatically detects Touch ID status and chooses the best strategy.
EOF
        exit 0
        ;;
      --list|-l)
        echo "Available update commands:"
        echo "  brew, composer, node, gem, rvm, omz, terminus, vagrant, vbox, vim, code, pip, rust"
        echo ""
        echo "Brew cask password strategies (auto-detected by default):"
        echo "  touchid, prompt, skip, sudo-askpass, schedule"
        echo ""
        echo "Touch ID detection logic:"
        echo "  • Checks if Touch ID hardware exists and is enabled"
        echo "  • Verifies if Touch ID is configured for sudo authentication"
        echo "  • Determines if running in interactive or non-interactive mode"
        echo "  • Automatically selects the most appropriate strategy"
        exit 0
        ;;
      --verbose|-v)
        set -x
        shift
        ;;
      --dry-run|-n)
        fancy_echo "DRY RUN MODE - No actual updates will be performed"
        # Set dry run flag instead of overriding functions immediately
        DRY_RUN=true
        shift
        ;;
      --*)
        fancy_echo "Unknown option: $1"
        exit 1
        ;;
      *)
        # Remaining arguments are specific commands to run
        break
        ;;
    esac
  done

  # If specific commands provided, only run those
  if [[ $# -gt 0 ]]; then
    for cmd in "$@"; do
      if command -v "${cmd}_update" >/dev/null; then
        fancy_echo "Running specific update: $cmd"
        "${cmd}_update" || true
        fancy_echo "========================================"
      else
        fancy_echo "Unknown update command: $cmd"
      fi
    done
  else
    update_all
  fi
}

# Setup dry run mode if requested
function setup_dry_run() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    # Override update functions to just echo what would be done
    function brew_update() { fancy_echo "Would update: Homebrew packages"; }
    function composer_update() { fancy_echo "Would update: Composer packages"; }
    function node_update() { fancy_echo "Would update: Node packages"; }
    function gem_update() { fancy_echo "Would update: Ruby gems"; }
    function rvm_update() { fancy_echo "Would update: RVM"; }
    function omz_update() { fancy_echo "Would update: Oh My Zsh"; }
    function terminus_update() { fancy_echo "Would update: Pantheon Terminus"; }
    function vagrant_update() { fancy_echo "Would update: Vagrant"; }
    function vbox_update() { fancy_echo "Would update: VirtualBox"; }
    function vim_update() { fancy_echo "Would update: Vim plugins"; }
    function code_update() { fancy_echo "Would update: VS Code extensions"; }
    function pip_update() { fancy_echo "Would update: Python packages"; }
    function rust_update() { fancy_echo "Would update: Rust toolchain"; }
  fi
}

# Main execution
main() {
  # Parse arguments first to check for dry-run mode
  local has_dry_run=false
  
  # Quick scan for dry-run flag
  for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
      has_dry_run=true
      break
    fi
  done
  
  # Only enable strict mode if not in dry-run mode and not already enabled
  if [[ "$has_dry_run" == "false" ]] && [[ ! -o errexit ]]; then
    enable_strict_mode
  fi
  
  fancy_echo "Starting system updates on $HOST at $TIME"
  
  # Setup dry run mode after initial setup
  setup_dry_run
  
  if [[ $# -eq 0 ]]; then
    update_all 2>&1 | log
  else
    parse_args "$@" 2>&1 | log
  fi
}

# Run main function with all arguments
main "$@"

exit 0
