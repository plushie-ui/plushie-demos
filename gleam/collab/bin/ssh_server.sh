#!/usr/bin/env bash
# Mode 5: SSH server with shared state
cd "$(dirname "$0")/.."
echo "SSH server on port 2222"
gleam run -m demo/ssh_server
