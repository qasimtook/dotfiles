#!/usr/bin/env bash
# Dotfiles installer — runs automatically in every new GitHub Codespace
# when "Automatically install dotfiles" is enabled at
# https://github.com/settings/codespaces

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1;34m[dotfiles]\033[0m %s\n' "$*"; }

# 1. Install Claude Code CLI if missing
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code CLI via npm..."
  npm install -g @anthropic-ai/claude-code
else
  log "Claude Code already installed: $(claude --version)"
fi

# 2. Symlink ~/.claude/settings.json to the version-controlled one
mkdir -p "$HOME/.claude"
SETTINGS_TARGET="$HOME/.claude/settings.json"
SETTINGS_SOURCE="$DOTFILES_DIR/.claude/settings.json"

if [[ -L "$SETTINGS_TARGET" ]]; then
  log "Replacing existing symlink at $SETTINGS_TARGET"
  rm "$SETTINGS_TARGET"
elif [[ -e "$SETTINGS_TARGET" ]]; then
  backup="$SETTINGS_TARGET.backup.$(date +%s)"
  log "Backing up existing $SETTINGS_TARGET -> $backup"
  mv "$SETTINGS_TARGET" "$backup"
fi
ln -s "$SETTINGS_SOURCE" "$SETTINGS_TARGET"
log "Linked $SETTINGS_SOURCE -> $SETTINGS_TARGET"

# 3. Ensure the Anthropic plugin marketplace is registered, then install plugins
# listed in settings.json. Both commands are idempotent.
if command -v claude >/dev/null 2>&1; then
  log "Registering claude-plugins-official marketplace..."
  claude plugin marketplace add anthropics/claude-plugins-official || true

  for plugin in superpowers ralph-loop; do
    log "Installing $plugin@claude-plugins-official..."
    claude plugin install "$plugin@claude-plugins-official" || true
  done
fi

# 4. Install Google Cloud SDK if missing
if ! command -v gcloud >/dev/null 2>&1 && [[ ! -x "$HOME/google-cloud-sdk/bin/gcloud" ]]; then
  log "Installing Google Cloud SDK..."
  curl -sSL https://sdk.cloud.google.com > /tmp/gcloud-install.sh
  bash /tmp/gcloud-install.sh --disable-prompts --install-dir="$HOME" >/dev/null
  rm -f /tmp/gcloud-install.sh
  log "Google Cloud SDK installed to $HOME/google-cloud-sdk"
else
  log "Google Cloud SDK already installed."
fi

# Ensure gcloud is on PATH in new shells
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] || continue
  if ! grep -q "google-cloud-sdk/path.bash.inc" "$rc" 2>/dev/null; then
    printf '\n[ -f "$HOME/google-cloud-sdk/path.bash.inc" ] && source "$HOME/google-cloud-sdk/path.bash.inc"\n' >> "$rc"
    log "Added gcloud PATH source to $rc"
  fi
done

# 5. Materialize GCP service-account credentials from Codespaces secret, if set.
# The secret itself is stored in GitHub Codespaces secrets, NOT in this repo.
# Scope the secret to the repos where you need it at
# https://github.com/settings/codespaces
if [[ -n "${SERVICE_ACCOUNT_KEY:-}" ]]; then
  GCP_KEY_PATH="$HOME/.config/gcloud/service-account.json"
  mkdir -p "$(dirname "$GCP_KEY_PATH")"
  umask 077
  printf '%s' "$SERVICE_ACCOUNT_KEY" > "$GCP_KEY_PATH"
  chmod 600 "$GCP_KEY_PATH"
  log "Wrote GCP service-account key to $GCP_KEY_PATH"

  # Activate the service account in gcloud, if available
  GCLOUD_BIN="$(command -v gcloud || true)"
  [[ -z "$GCLOUD_BIN" && -x "$HOME/google-cloud-sdk/bin/gcloud" ]] && GCLOUD_BIN="$HOME/google-cloud-sdk/bin/gcloud"
  if [[ -n "$GCLOUD_BIN" ]]; then
    "$GCLOUD_BIN" auth activate-service-account --key-file="$GCP_KEY_PATH" >/dev/null 2>&1 \
      && log "Activated gcloud service account." \
      || log "gcloud service-account activation failed (non-fatal)."
  fi

  # Configure rclone 'gdrive' remote using the same service account
  if ! command -v rclone >/dev/null 2>&1; then
    log "Installing rclone..."
    curl -sSL https://rclone.org/install.sh | sudo bash >/dev/null 2>&1 || log "rclone install failed (non-fatal)."
  fi
  if command -v rclone >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/rclone"
    cat > "$HOME/.config/rclone/rclone.conf" <<EOF_RCLONE
[gdrive]
type = drive
scope = drive
service_account_file = $GCP_KEY_PATH
shared_with_me = true
EOF_RCLONE
    log "Configured rclone remote 'gdrive' via service account."
  fi

  # Persist GOOGLE_APPLICATION_CREDENTIALS so gcloud/SDKs pick it up in new shells
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -q "GOOGLE_APPLICATION_CREDENTIALS=" "$rc" 2>/dev/null; then
      printf '\nexport GOOGLE_APPLICATION_CREDENTIALS="%s"\n' "$GCP_KEY_PATH" >> "$rc"
      log "Added GOOGLE_APPLICATION_CREDENTIALS export to $rc"
    fi
  done
  export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEY_PATH"
else
  log "SERVICE_ACCOUNT_KEY not set — skipping GCP credential setup."
fi

log "Dotfiles setup complete."
