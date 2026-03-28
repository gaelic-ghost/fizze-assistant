#!/bin/sh

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PID_FILE="${PID_FILE:-$REPO_DIR/.data/fizze-assistant.pid}"

if [ ! -f "$PID_FILE" ]; then
  echo "No PID file found at $PID_FILE" >&2
  exit 1
fi

BOT_PID=$(cat "$PID_FILE")

if [ -z "$BOT_PID" ]; then
  echo "PID file is empty: $PID_FILE" >&2
  rm -f "$PID_FILE"
  exit 1
fi

if ! kill -0 "$BOT_PID" 2>/dev/null; then
  echo "No running process found for PID $BOT_PID" >&2
  rm -f "$PID_FILE"
  exit 1
fi

echo "Stopping Fizze Assistant (PID $BOT_PID)..."
kill "$BOT_PID"
rm -f "$PID_FILE"
echo "Stopped."
