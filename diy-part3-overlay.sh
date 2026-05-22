#!/bin/bash
set -e

echo "===== DIY part3: copy repository files overlay, LuCI Chinese temperature and wrtbwmon ====="

if [ ! -d "$GITHUB_WORKSPACE/files" ]; then
  echo "ERROR: repository files overlay missing: $GITHUB_WORKSPACE/files"
  exit 1
fi

echo "===== Force required configs after diy-part2 rewrites .config ====="

for key in \
  CONFIG_PACKAGE_rpcd-mod-file \
  CONFIG_PACKAGE_wrtbwmon \
  CONFIG_PACKAGE_luci-app-wrtbwmon \
  CONFIG_PACKAGE_ip-full \
  CONFIG_PACKAGE_iptables-nft \
  CONFIG_PACKAGE_ip6tables-nft \
  CONFIG_PACKAGE_xtables-nft
do
  sed -i "/^# ${key} is not set/d" .config || true
  sed -i "/^${key}=/d" .config || true
  echo "${key}=y" >> .config
done

# Do not build the old Kiougar package.
# It conflicts with wrtbwmon on /etc/config/wrtbwmon under OpenWrt 25.12 apk rootfs install.
# Disable flow offloading because luci-app-wrtbwmon documents it as incompatible.
for key in \
  CONFIG_PACKAGE_luci-wrtbwmon \
  CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING \
  CONFIG_PACKAGE_kmod-nft-offload
do
  sed -i "/^${key}=y/d" .config || true
  sed -i "/^# ${key} is not set/d" .config || true
  echo "# ${key} is not set" >> .config
done

mkdir -p files
cp -a "$GITHUB_WORKSPACE/files/." files/

chmod +x files/etc/uci-defaults/01-enable-wifi 2>/dev/null || true
chmod +x files/etc/uci-defaults/02-set-argon-theme 2>/dev/null || true
chmod +x files/etc/uci-defaults/03-disable-lucky-autostart 2>/dev/null || true
chmod +x files/etc/uci-defaults/04-config-turboacc 2>/dev/null || true
chmod +x files/etc/uci-defaults/05-enable-wrtbwmon 2>/dev/null || true

echo "===== Overlay files after copy ====="
find files -type f | sort

echo "===== Validate temperature overview files ====="
test -f files/www/luci-static/resources/view/status/include/10_system.js
grep -q "fs.trimmed(path)" files/www/luci-static/resources/view/status/include/10_system.js
! grep -q "fs.read_direct(path)" files/www/luci-static/resources/view/status/include/10_system.js
grep -q "温度" files/www/luci-static/resources/view/status/include/10_system.js

echo "===== Validate LuCI temperature ACL ====="
test -f files/usr/share/rpcd/acl.d/luci-overview-extra.json
grep -q "thermal_zone" files/usr/share/rpcd/acl.d/luci-overview-extra.json
! grep -q "rx_bytes" files/usr/share/rpcd/acl.d/luci-overview-extra.json
! grep -q "tx_bytes" files/usr/share/rpcd/acl.d/luci-overview-extra.json

echo "===== Validate wrtbwmon package tree and config ====="
test -f package/wrtbwmon/Makefile
test -f package/luci-app-wrtbwmon/Makefile
grep -q "^CONFIG_PACKAGE_wrtbwmon=y" .config
grep -q "^CONFIG_PACKAGE_luci-app-wrtbwmon=y" .config
grep -q "^CONFIG_PACKAGE_iptables-nft=y" .config
grep -q "^CONFIG_PACKAGE_ip6tables-nft=y" .config
grep -q "^CONFIG_PACKAGE_xtables-nft=y" .config
! grep -q "^CONFIG_PACKAGE_luci-wrtbwmon=y" .config

echo "===== DIY part3 done ====="
