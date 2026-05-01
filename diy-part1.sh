#!/bin/bash
# Minimal build: do not add third-party feeds.
# Keep official OpenWrt 25.12.1 feeds only.

set -e

echo "===== DIY part1: minimal official feeds only ====="
echo "No third-party feeds added."
echo "===== feeds.conf.default ====="
cat feeds.conf.default
echo "===== DIY part1 done ====="
