#!/usr/bin/env bash
set -Eeuo pipefail

# Local Flutter preview for phonek-app.
# Keeps one stable URL and syncs the selected Git branch from GitHub.
# Usage: ./tool/local_preview.sh [branch] [port]

BRANCH="${1:-main}"
PORT="${2:-8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${PREVIEW_PULL_INTERVAL:-5}"
PID=""
LAST_HEAD=""

cleanup() {
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

cd "${ROOT}"
command -v flutter >/dev/null || { echo "Flutter is required. Install Flutter and run this script again." >&2; exit 1; }
command -v git >/dev/null || { echo "Git is required." >&2; exit 1; }

if [[ ! -d .git ]]; then
  echo "Run this script from inside the cloned phonek-app repository." >&2
  exit 1
fi

echo "Syncing branch ${BRANCH} from GitHub..."
git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git merge --ff-only "origin/${BRANCH}"
flutter pub get

start_server() {
  echo "Starting Flutter preview at http://localhost:${PORT}"
  flutter run -d web-server \
    --web-hostname 0.0.0.0 \
    --web-port "${PORT}" \
    --target lib/main.dart \
    >/tmp/phonek-flutter-preview.log 2>&1 &
  PID="$!"
  sleep 2
  if ! kill -0 "${PID}" 2>/dev/null; then
    cat /tmp/phonek-flutter-preview.log >&2 || true
    exit 1
  fi
}

LAST_HEAD="$(git rev-parse HEAD)"
start_server

echo "Preview is running. Keep this terminal open."
echo "Press Ctrl+C to stop. Pull interval: ${INTERVAL}s"

while true; do
  sleep "${INTERVAL}"
  git fetch origin "${BRANCH}" >/dev/null 2>&1 || { echo "GitHub fetch failed; retrying..."; continue; }
  REMOTE_HEAD="$(git rev-parse "origin/${BRANCH}")"
  if [[ "${REMOTE_HEAD}" != "${LAST_HEAD}" ]]; then
    echo "New GitHub commit detected; updating preview..."
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "Local uncommitted changes detected; skipping automatic pull." >&2
      continue
    fi
    git merge --ff-only "origin/${BRANCH}"
    flutter pub get
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
    PID=""
    LAST_HEAD="${REMOTE_HEAD}"
    start_server
    echo "Preview updated at http://localhost:${PORT}"
  fi
done
