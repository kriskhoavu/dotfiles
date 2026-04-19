#!/bin/bash
# Get memory free percentage for tmux status bar
/usr/bin/memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print $2}'
