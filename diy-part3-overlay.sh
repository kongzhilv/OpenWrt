#!/bin/bash
set -e

echo "===== DIY part3: copy repository files overlay and enforce Netdata/EQOS config ====="

if [ ! -d "$GITHUB_WORKSPACE/files" ]; then
  echo "ERROR: repository files overlay missing: $GITHUB_WORKSPACE/files"
  exit 1
fi

echo "===== Force required configs after diy-part2 rewrites .config ====="

for key in \
  CONFIG_PACKAGE_rpcd-mod-file \
  CONFIG_PACKAGE_netdata \
  CONFIG_PACKAGE_ip-full \
  CONFIG_PACKAGE_iptables-nft \
  CONFIG_PACKAGE_ip6tables-nft \
  CONFIG_PACKAGE_xtables-nft \
  CONFIG_PACKAGE_luci-app-eqosplus \
  CONFIG_PACKAGE_kmod-ifb \
  CONFIG_PACKAGE_tc-tiny \
  CONFIG_PACKAGE_bc
do
  sed -i "/^# ${key} is not set/d" .config || true
  sed -i "/^${key}=/d" .config || true
  echo "${key}=y" >> .config
done

# Remove the old wrtbwmon monitor stack and flow offloading.
for key in \
  CONFIG_PACKAGE_wrtbwmon \
  CONFIG_PACKAGE_luci-app-wrtbwmon \
  CONFIG_PACKAGE_luci-wrtbwmon \
  CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING \
  CONFIG_PACKAGE_kmod-nft-offload
do
  sed -i "/^${key}=y/d" .config || true
  sed -i "/^# ${key} is not set/d" .config || true
  echo "# ${key} is not set" >> .config
done

echo "===== Copy repository files overlay ====="
mkdir -p files
cp -a "$GITHUB_WORKSPACE/files/." files/

chmod +x files/etc/uci-defaults/* 2>/dev/null || true
chmod +x files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin 2>/dev/null || true

echo "===== Overlay files after copy ====="
find files -type f | sort

echo "===== Validate overlay defaults ====="
test -f files/etc/uci-defaults/01-enable-wifi
test -f files/etc/uci-defaults/02-set-argon-theme
test -f files/etc/uci-defaults/10-network-accel-defaults
test -f files/etc/uci-defaults/20-enable-netdata
test -f files/etc/uci-defaults/21-app-service-defaults
test -f files/etc/uci-defaults/30-netdata-zh
test -f files/etc/uci-defaults/40-enable-netdata-openwrt-clients
test -f files/etc/config/netdata_clients
test -f files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin

grep -q "flow_offloading='0'" files/etc/uci-defaults/10-network-accel-defaults
grep -q "netdata" files/etc/uci-defaults/20-enable-netdata
grep -q "skip Netdata static web asset translation" files/etc/uci-defaults/30-netdata-zh
grep -q "update_every='3'" files/etc/uci-defaults/40-enable-netdata-openwrt-clients
grep -q "option update_every '3'" files/etc/config/netdata_clients
grep -q "1/3/5/10" files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
grep -q "OpenWrt 客户端下载速率" files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
grep -q "nft add table inet openwrt_clients" files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin

echo "===== Validate selected config ====="
grep -q "^CONFIG_PACKAGE_netdata=y" .config
grep -q "^CONFIG_PACKAGE_luci-app-eqosplus=y" .config
grep -q "^CONFIG_PACKAGE_iptables-nft=y" .config
grep -q "^CONFIG_PACKAGE_ip6tables-nft=y" .config
grep -q "^CONFIG_PACKAGE_xtables-nft=y" .config
! grep -q "^CONFIG_PACKAGE_wrtbwmon=y" .config
! grep -q "^CONFIG_PACKAGE_luci-app-wrtbwmon=y" .config
! grep -q "^CONFIG_PACKAGE_luci-wrtbwmon=y" .config
! grep -q "^CONFIG_PACKAGE_kmod-nft-offload=y" .config

echo "===== DIY part3 done ====="
