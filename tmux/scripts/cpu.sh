#!/bin/bash
# Fast CPU usage via ps — ~50ms vs iostat's ~1100ms
ncpu=$(sysctl -n hw.logicalcpu)
ps -A -o pcpu | awk -v n="$ncpu" 'NR>1{s+=$1} END{printf "%.0f", s/n}'
