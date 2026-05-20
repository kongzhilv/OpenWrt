#!/bin/bash
set -e

echo "===== DIY part3: copy repository files overlay ====="

if [ ! -d "$GITHUB_WORKSPACE/files" ]; then
    echo "ERROR: repository files overlay missing: $GITHUB_WORKSPACE/files"
    exit 1
fi

mkdir -p files
cp -a "$GITHUB_WORKSPACE/files/." files/

echo "===== Overlay files after copy ====="
find files -type f | sort

echo "===== Validate temperature overview files ====="
test -f files/www/luci-static/resources/view/status/include/10_system.js
grep -q "fs.trimmed(path)" files/www/luci-static/resources/view/status/include/10_system.js
! grep -q "fs.read_direct(path)" files/www/luci-static/resources/view/status/include/10_system.js

echo "===== Validate realtime speed overview files ====="
test -f files/www/luci-static/resources/view/status/include/15_realtime_speed.js
grep -q "实时上下行" files/www/luci-static/resources/view/status/include/15_realtime_speed.js
grep -q "rx_bytes" files/www/luci-static/resources/view/status/include/15_realtime_speed.js
grep -q "tx_bytes" files/www/luci-static/resources/view/status/include/15_realtime_speed.js

echo "===== Validate LuCI ACL ====="
test -f files/usr/share/rpcd/acl.d/luci-overview-extra.json
grep -q "thermal_zone" files/usr/share/rpcd/acl.d/luci-overview-extra.json
grep -q "rx_bytes" files/usr/share/rpcd/acl.d/luci-overview-extra.json
grep -q "tx_bytes" files/usr/share/rpcd/acl.d/luci-overview-extra.json

echo "===== DIY part3 done ====="
