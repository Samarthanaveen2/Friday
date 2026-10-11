#!/bin/bash
# Installs the Swift toolchain in a Claude Code cloud session so `swift test` works for FridayCore.
set -euo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
if [ ! -x /opt/swift/usr/bin/swift ]; then
  tmp=$(mktemp -d)
  curl -sSfL -o "$tmp/swift.tar.gz" \
    https://download.swift.org/swift-6.1.2-release/ubuntu2404/swift-6.1.2-RELEASE/swift-6.1.2-RELEASE-ubuntu24.04.tar.gz
  mkdir -p /opt/swift
  tar -xzf "$tmp/swift.tar.gz" -C /opt/swift --strip-components=1
  rm -rf "$tmp"
fi
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="/opt/swift/usr/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi
