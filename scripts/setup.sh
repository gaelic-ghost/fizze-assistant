#!/bin/sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${ENV_FILE:-$REPO_DIR/.env.local}"
CONFIG_FILE="${CONFIG_FILE:-$REPO_DIR/fizze-assistant.json}"
BINARY_PATH="${BINARY_PATH:-$REPO_DIR/.build/release/fizze-assistant}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  echo "Create it with: export DISCORD_BOT_TOKEN=\"your_bot_token\"" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$ENV_FILE"

if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
  echo "DISCORD_BOT_TOKEN is not set after loading $ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing configuration file: $CONFIG_FILE" >&2
  echo "Expected the committed non-secret config file at fizze-assistant.json." >&2
  exit 1
fi

cd "$REPO_DIR"

if [ ! -x "$BINARY_PATH" ]; then
  echo "Release binary not found. Building..."
  swift build -c release
fi

echo "Validating bot configuration..."
"$BINARY_PATH" check --config "$CONFIG_FILE"

echo "Registering guild commands..."
"$BINARY_PATH" register-commands --config "$CONFIG_FILE"

echo "Starting Fizze Assistant..."
exec "$BINARY_PATH" run --config "$CONFIG_FILE"
