#!/bin/bash
set -e

echo "===== DIY part3: copy repository files overlay, LuCI Chinese temperature and realtime speed ====="

if [ ! -d "$GITHUB_WORKSPACE/files" ]; then
    echo "ERROR: repository files overlay missing: $GITHUB_WORKSPACE/files"
    exit 1
fi

echo "===== Enable rpcd-mod-file for LuCI fs.trimmed / ubus file read ====="
sed -i '/^# CONFIG_PACKAGE_rpcd-mod-file is not set/d' .config || true
sed -i '/^CONFIG_PACKAGE_rpcd-mod-file=/d' .config || true
echo 'CONFIG_PACKAGE_rpcd-mod-file=y' >> .config

mkdir -p files
cp -a "$GITHUB_WORKSPACE/files/." files/

echo "===== Overlay files after copy ====="
find files -type f | sort

echo "===== Validate temperature overview files ====="
test -f files/www/luci-static/resources/view/status/include/10_system.js
grep -q "fs.trimmed(path)" files/www/luci-static/resources/view/status/include/10_system.js
! grep -q "fs.read_direct(path)" files/www/luci-static/resources/view/status/include/10_system.js
grep -q "温度" files/www/luci-static/resources/view/status/include/10_system.js

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
