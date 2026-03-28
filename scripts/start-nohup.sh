#!/bin/sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOG_FILE="${LOG_FILE:-$REPO_DIR/fizze-assistant.log}"
PID_FILE="${PID_FILE:-$REPO_DIR/.data/fizze-assistant.pid}"

mkdir -p "$(dirname -- "$PID_FILE")"

cd "$REPO_DIR"

if [ -f "$PID_FILE" ]; then
  EXISTING_PID=$(cat "$PID_FILE")
  if [ -n "$EXISTING_PID" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    echo "Fizze Assistant is already running with PID $EXISTING_PID" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi

echo "Starting Fizze Assistant in the background..."
nohup "$REPO_DIR/scripts/setup.sh" > "$LOG_FILE" 2>&1 &
BOT_PID=$!
printf '%s\n' "$BOT_PID" > "$PID_FILE"

echo "Fizze Assistant started."
echo "PID: $BOT_PID"
echo "Log: $LOG_FILE"
echo "PID file: $PID_FILE"
