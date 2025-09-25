#!/usr/bin/env zsh
set -euo pipefail
IFS=$'\n\t'

NAME="$(basename "$0")"
HOST=$(hostname -s | tr '[:upper:]' '[:lower:]' 2>/dev/null || hostname -s)
LOCATION="${LOCATION:-$HOME/Applications}"
LOG_DIR="${LOG_DIR:-$HOME/Library/Logs}"
LOG="$LOG_DIR/updateApps.log"
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

mkdir -p "$LOG_DIR" 2>/dev/null || true

# Load RVM if available (non-fatal)
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" 2>/dev/null || true

# Colors (only when stdout is a tty)
if [[ -t 1 ]]; then
  _C_GREEN=$'\033[0;92m'
  #_C_BLUE=$'\033[0;34m'
  _C_BLUE=$'\033[1;94m'
  _C_YELLOW=$'\033[1;33m'
  _C_RED=$'\033[0;31m'
  _C_NC=$'\033[0m'
else
  _C_GREEN='' _C_BLUE='' _C_YELLOW='' _C_RED='' _C_NC=''
fi

# Logging helpers
log_header() {
  printf "\n%s\n" "========================================" | tee -a "$LOG"
  printf " %s [%s] on %s\n" "$NAME" "$START_TIME" "$HOST" | tee -a "$LOG"
  printf "%s\n\n" "========================================" | tee -a "$LOG"
}

log_footer() {
  local end_time
  end_time=$(date +"%Y-%m-%d %H:%M:%S")
  printf "\n%s\n" "========================================" | tee -a "$LOG"
  printf "Update completed at [%s]\n" "$end_time" | tee -a "$LOG"
  printf "%s\n" "========================================" | tee -a "$LOG"
}

color_echo() {
  local level="$1"; shift
  local msg="$*"
  case "$level" in
    info) printf "%b%s%b\n" "$_C_BLUE" "$msg" "$_C_NC" ;;
    ok)   printf "%b%s%b\n" "$_C_GREEN" "$msg" "$_C_NC" ;;
    warn) printf "%b%s%b\n" "$_C_YELLOW" "$msg" "$_C_NC" ;;
    err)  printf "%b%s%b\n" "$_C_RED" "$msg" "$_C_NC" ;;
    *)    printf "%s\n" "$msg" ;;
  esac | tee -a "$LOG"
}

# Error handling
_handle_error() {
  local exit_code=$?
  local lineno=${1:-unknown}
  color_echo err "Error at line ${lineno}: exit code ${exit_code}"
}
trap '_handle_error $LINENO' ERR

# Utilities
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_if_touchid_exists() {
  if ! command_exists bioutil; then
    echo "not_supported"
    return 1
  fi
  # Prefer robust parsing; fall back to not_available
  local out
  out=$(bioutil -rs 2>/dev/null || true)
  if echo "$out" | grep -Eqi "Touch ID|Biometrics"; then
    if echo "$out" | grep -Eqi "Touch ID.*enabled|Biometrics.*enabled|1$"; then
      echo "enabled"
      return 0
    else
      echo "disabled"
      return 0
    fi
  fi
  echo "not_available"
  return 1
}

determine_cask_strategy() {
  if [[ -n "${BREW_CASK_STRATEGY:-}" ]]; then
    echo "$BREW_CASK_STRATEGY"
    return 0
  fi

  local touchid_status
  touchid_status=$(check_if_touchid_exists) || true
  color_echo info "Touch ID Status: $touchid_status"

  local sudo_touchid_configured=false
  if grep -q "pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
    sudo_touchid_configured=true
  fi

  case "$touchid_status" in
    enabled)
      if [[ "$sudo_touchid_configured" == "true" ]]; then
        color_echo info "Using Touch ID strategy (Touch ID enabled and configured for sudo)"
      else
        color_echo info "Using GUI password strategy (Touch ID enabled but not configured for sudo)"
      fi
      ;;
    disabled)
      if [[ -t 0 ]]; then
        color_echo info "Using prompt strategy (Touch ID disabled, running interactively)"
      else
        color_echo info "Using schedule strategy (Touch ID disabled, running non-interactively)"
      fi
      ;;
    not_available|not_supported)
      if [[ -t 0 ]]; then
        color_echo info "Using prompt strategy (No Touch ID hardware, running interactively)"
      else
        color_echo info "Using skip strategy (No Touch ID hardware, running non-interactively)"
      fi
      ;;
    *)
      color_echo warn "Unable to determine Touch ID status; defaulting to skip"
      ;;
  esac
}

# Wrapper to run each update step: logs, respects DRY_RUN, isolates failures
run_step() {
  local label="$1"; shift
  local fn="$1"; shift

  color_echo info "---- [$label] START ----"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    color_echo warn "DRY RUN: Would run $fn"
    color_echo info "---- [$label] SKIPPED (dry run) ----"
    return 0
  fi

  # Run the function in a subshell capturing output so individual failures don't stop whole script
  if ( "$fn" ) 2>&1 | tee -a "$LOG"; then
    color_echo ok "---- [$label] SUCCESS ----"
    return 0
  else
    color_echo err "---- [$label] FAILED (continuing) ----"
    return 1
  fi
}

# ---- Begin update task implementations (mostly unchanged, trimmed for clarity) ----

brew_update() {
  if ! command_exists brew; then
    color_echo warn "Homebrew not installed. Skipping."
    return 0
  fi

  color_echo info "Updating Homebrew..."
  brew update || true

  local brew_outdated cask_outdated
  brew_outdated=$(brew outdated 2>/dev/null) || true
  cask_outdated=$(brew outdated --cask --greedy 2>/dev/null) || true

  if [[ -z "$brew_outdated" && -z "$cask_outdated" ]]; then
    color_echo ok "Homebrew packages and casks are up-to-date"
    return 0
  fi

  if [[ -n "$brew_outdated" ]]; then
    color_echo info "Upgrading Homebrew packages..."
    brew upgrade || true
  fi

  if [[ -n "$cask_outdated" ]]; then
    local strategy
    strategy=$(determine_cask_strategy)
    color_echo info "Using cask update strategy: $strategy"
    handle_cask_updates "$cask_outdated" "$strategy"
  fi

  brew doctor || true
  brew autoremove || true
  brew cleanup || true
}

handle_cask_updates() {
  local cask_list="$1"
  local strategy="${2:-skip}"

  case "$strategy" in
    sudo-askpass) handle_casks_with_askpass "$cask_list" ;;
    touchid)      handle_casks_with_touchid_timeout "$cask_list" ;;
    schedule)     schedule_cask_updates "$cask_list" ;;
    prompt)       handle_casks_with_prompt "$cask_list" ;;
    *)            handle_casks_without_password "$cask_list" ;;
  esac

  color_echo info "Rebuilding Open With menu..."
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -r -domain local -domain user || true
  killall Finder 2>/dev/null || true
  color_echo ok "Open With menu rebuilt, Finder relaunched"
}

handle_casks_with_touchid_timeout() {
  local cask_list="$1"
  local timeout_duration=30

  if ! grep -q "pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
    color_echo warn "Touch ID not configured for sudo, falling back to non-interactive"
    handle_casks_without_password "$cask_list"
    return 0
  fi

  color_echo info "Updating casks with Touch ID authentication (timeout ${timeout_duration}s)..."

  local temp_script
  temp_script=$(mktemp)
  cat > "$temp_script" <<'EOF'
#!/bin/bash
exec brew upgrade --cask --greedy
EOF
  chmod +x "$temp_script"

  local update_success=false
  if command_exists timeout; then
    if timeout ${timeout_duration}s sudo "$temp_script"; then update_success=true; fi
  elif command_exists gtimeout; then
    if gtimeout ${timeout_duration}s sudo "$temp_script"; then update_success=true; fi
  else
    if run_with_timeout ${timeout_duration} sudo "$temp_script"; then update_success=true; fi
  fi

  rm -f "$temp_script"

  if [[ "$update_success" == "false" ]]; then
    color_echo warn "Touch ID timed out or failed, falling back to non-interactive"
    handle_casks_without_password "$cask_list"
  else
    color_echo ok "Cask updates completed with Touch ID"
  fi
}

run_with_timeout() {
  local timeout_duration=$1; shift
  local cmd=("$@")
  "${cmd[@]}" &
  local pid=$!
  ( sleep "$timeout_duration"; kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null ) &
  local to_pid=$!
  if wait "$pid"; then kill "$to_pid" 2>/dev/null || true; return 0; else kill "$to_pid" 2>/dev/null || true; return 1; fi
}

handle_casks_with_askpass() {
  local cask_list="$1"
  local askpass_script="/tmp/brew_askpass_$$.applescript"
  cat > "$askpass_script" <<'EOF'
#!/usr/bin/env osascript
on run argv
  return text returned of (display dialog "Homebrew cask update requires admin password:" with title "Homebrew Update" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK")
end run
EOF
  chmod +x "$askpass_script"
  color_echo info "Updating casks with GUI password prompt..."
  SUDO_ASKPASS="$askpass_script" sudo -A brew upgrade --cask --greedy || color_echo warn "Cask update failed or was cancelled"
  rm -f "$askpass_script"
}

schedule_cask_updates() {
  local cask_list="$1"
  local plist="$HOME/Library/LaunchAgents/com.user.brew-cask-update.plist"
  local script="$HOME/.brew-cask-update.sh"

  cat > "$script" <<EOF
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
/opt/homebrew/bin/brew upgrade --cask --greedy
launchctl unload "$plist" 2>/dev/null || true
rm -f "$plist" "$script"
EOF
  chmod +x "$script"

  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.user.brew-cask-update</string>
  <key>Program</key><string>$script</string>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/brew-cask-update.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/brew-cask-update.log</string>
</dict></plist>
EOF

  color_echo info "Cask updates scheduled. To run now:"
  color_echo info "  launchctl load '$plist' && launchctl start com.user.brew-cask-update"
  color_echo info "Or run: $script"
}

handle_casks_with_prompt() {
  local cask_list="$1"
  if [[ -t 0 ]]; then
    color_echo info "The following casks need updates (may require admin password):"
    echo "$cask_list" | sed -n '1,200p' | sed 's/^/  - /' | tee -a "$LOG"
    printf "\n"
    read -p "Update casks now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      color_echo info "Updating casks..."
      brew upgrade --cask --greedy || color_echo warn "Some cask updates may have failed"
    else
      color_echo info "Cask updates skipped; scheduling for later"
      schedule_cask_updates "$cask_list"
    fi
  else
    color_echo info "Non-interactive: scheduling cask updates"
    schedule_cask_updates "$cask_list"
  fi
}

handle_casks_without_password() {
  local cask_list="$1"
  color_echo info "Updating casks in non-interactive mode (will skip password-required installs)..."
  NONINTERACTIVE=1 brew upgrade --cask --greedy || color_echo warn "Some cask updates requiring password were skipped"
}

composer_update() {
  if ! command_exists composer; then color_echo warn "Composer not installed. Skipping."; return 0; fi
  local composer_outdated
  composer_outdated=$(composer global outdated --direct 2>/dev/null) || true
  if [[ -z "$composer_outdated" ]]; then color_echo ok "Composer packages are up-to-date"; else color_echo info "Upgrading Composer packages"; composer global update || true; fi
}

node_update() {
  if ! command_exists npm; then color_echo warn "Node/npm not installed. Skipping."; return 0; fi
  local node_outdated
  node_outdated=$(npm outdated -g --depth=0 2>/dev/null) || true
  if [[ -z "$node_outdated" ]]; then color_echo ok "Node packages are up-to-date"; else color_echo info "Upgrading Node packages"; npm update -g || true; fi
}

omz_update() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then color_echo warn "Oh My Zsh not installed. Skipping."; return 0; fi
  color_echo info "Updating Oh My Zsh"
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && source "$HOME/.oh-my-zsh/oh-my-zsh.sh"
  if command_exists omz; then omz update --unattended || true; else (cd "$HOME/.oh-my-zsh" && git pull origin master) || true; fi
}

terminus_update() {
  local terminus_dir="$LOCATION/terminus"
  if [[ ! -d "$terminus_dir" ]]; then color_echo warn "Terminus directory not found. Skipping."; return 0; fi
  color_echo info "Updating Pantheon Terminus"
  pushd "$terminus_dir" >/dev/null || return 1
  composer self-update --2 || true
  composer update || true
  popd >/dev/null || true
  command_exists terminus && terminus self:plugin:reload || true
}

# Keep other update functions (vagrant_update, vbox_update, vim_update, etc.) as in your original
# For brevity they are left unchanged, but should be included in the script similarly modularized.
# ...existing code...
vagrant_update() {
  if ! command_exists vagrant; then color_echo warn "Vagrant not installed. Skipping."; return 0; fi
  local local_version latest_version
  local_version=$(vagrant --version 2>/dev/null | awk '{print $2}') || return 0
  latest_version=$(vagrant version --machine-readable 2>/dev/null | grep ',version-current,' | cut -d',' -f4) || {
    color_echo warn "Could not check Vagrant version. Updating plugins only."
    vagrant plugin update || true
    return 0
  }
  if [[ "$local_version" != "$latest_version" ]]; then
    color_echo warn "Vagrant update available: $local_version -> $latest_version"
    if command_exists terminal-notifier; then
      terminal-notifier -title 'Vagrant' -message "Vagrant needs updating. Installed: $local_version, Latest: $latest_version" -open 'https://www.vagrantup.com/downloads.html' || true
    fi
  else
    color_echo ok "Vagrant is up-to-date ($latest_version)"
  fi
  vagrant plugin update || true
}

vbox_update() {
  if ! command_exists VBoxManage; then color_echo warn "VirtualBox not installed. Skipping."; return 0; fi
  local local_version latest_version
  local_version=$(VBoxManage --version 2>/dev/null | cut -d'r' -f1) || return 0
  latest_version=$(curl -s --connect-timeout 10 http://download.virtualbox.org/virtualbox/LATEST.TXT 2>/dev/null) || { color_echo warn "Could not check VirtualBox version. Skipping."; return 0; }
  if [[ "$local_version" != "$latest_version" ]]; then
    color_echo warn "VirtualBox update available: $local_version -> $latest_version"
    command_exists terminal-notifier && terminal-notifier -title 'VirtualBox' -message "VirtualBox needs updating. Installed: $local_version, Latest: $latest_version" -open 'https://www.virtualbox.org/wiki/Downloads' || true
  else
    color_echo ok "VirtualBox is up-to-date ($latest_version)"
  fi
}

vim_update() {
  local vim_script="$HOME/bin/update-vim.sh"
  if [[ -x "$vim_script" ]]; then color_echo info "Running vim update script..."; "$vim_script" || true; return 0; fi
  local pathogen_dir="$HOME/.vim/autoload"
  local bundles_dir="$HOME/.vim/bundle"
  if [[ -d "$pathogen_dir" ]]; then
    color_echo info "Updating pathogen..."
    curl -Sso "$pathogen_dir/pathogen.vim" https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim || true
  fi
  if [[ -d "$bundles_dir" ]]; then
    color_echo info "Updating vim bundles..."
    for bundle in "$bundles_dir"/*; do
      if [[ -d "$bundle/.git" ]]; then
        color_echo info "Updating bundle: $(basename "$bundle")"
        (cd "$bundle" && git pull) || true
      fi
    done
  else
    color_echo warn "No Vim bundles to update"
  fi
}

code_update() {
  local editors=("code" "cursor" "kiro" "trae" "windsurf")
  for editor in "${editors[@]}"; do
    if command_exists "$editor"; then
      color_echo info "Updating $editor extensions"
      if command_exists timeout; then
        timeout 300 "$editor" --update-extensions || color_echo warn "$editor extension update timed out or failed"
      elif command_exists gtimeout; then
        gtimeout 300 "$editor" --update-extensions || color_echo warn "$editor extension update timed out or failed"
      else
        "$editor" --update-extensions || color_echo warn "$editor extension update failed"
      fi
    fi
  done
}

pip_update() {
  if command_exists pip3; then color_echo info "Updating pip and global packages..."; pip3 install --upgrade pip || true; pip3 install --upgrade setuptools wheel virtualenv || true; fi
  if command_exists pipx; then color_echo info "Updating pipx packages..."; pipx upgrade-all || true; fi
}

rust_update() {
  if command_exists rustup; then color_echo info "Updating Rust toolchain..."; rustup update || true; fi
  if command_exists cargo; then color_echo info "Updating cargo packages..."; cargo install-update -a || true; fi
}

# ---- End task implementations ----

# Available commands array
declare -a AVAILABLE_COMMANDS=(brew composer node gem rvm omz terminus vagrant vbox vim code pip rust)

# Dry run setup: set DRY_RUN=true to skip actual execution
setup_dry_run() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    color_echo warn "DRY RUN MODE enabled: no destructive actions will be taken"
  fi
}

# Orchestrator using run_step to modularize execution and logging
update_all() {
  local commands_to_run=(node composer code omz brew)
  local total=${#commands_to_run[@]}
  local i=1
  for cmd in "${commands_to_run[@]}"; do
    color_echo info "[$i/$total] Preparing: $cmd"
    run_step "$cmd" "${cmd}_update" || true
    i=$((i + 1))
  done
}

parse_args_and_run() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        cat <<EOF
Usage: $NAME [OPTIONS] [COMMANDS...]
Options:
  --help|-h        Show help
  --list|-l        List available update commands
  --verbose|-v     Enable shell trace
  --dry-run|-n     Don't perform changes, only show what would be done
Commands:
  Available: ${AVAILABLE_COMMANDS[*]}
EOF
        exit 0
        ;;
      --list|-l)
        color_echo info "Available update commands: ${AVAILABLE_COMMANDS[*]}"
        exit 0
        ;;
      --verbose|-v)
        set -x
        shift
        ;;
      --dry-run|-n)
        DRY_RUN=true
        shift
        ;;
      --*)
        color_echo err "Unknown option: $1"; exit 1 ;;
      *)
        args+=("$1"); shift ;;
    esac
  done

  setup_dry_run

  if [[ ${#args[@]} -gt 0 ]]; then
    for cmd in "${args[@]}"; do
      local fn="${cmd}_update"
      if command_exists "$fn" || typeset -f "$fn" >/dev/null 2>&1; then
        run_step "$cmd" "$fn" || true
      else
        color_echo warn "Unknown update command: $cmd"
      fi
    done
  else
    update_all
  fi
}

main() {
  log_header
  parse_args_and_run "$@"
  log_footer
}

main "$@"

exit 0
