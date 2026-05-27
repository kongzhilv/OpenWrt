#!/bin/bash
set -e

echo "===== DIY part3: copy repository files overlay and enforce Netdata/EQOS config ====="

check_file() {
  local f="$1"
  [ -f "$f" ] || { echo "ERROR: missing file: $f"; exit 1; }
}

check_grep() {
  local pattern="$1"
  local f="$2"
  grep -q "$pattern" "$f" || { echo "ERROR: pattern not found in $f: $pattern"; exit 1; }
}

check_no_grep() {
  local pattern="$1"
  local f="$2"
  if grep -q "$pattern" "$f"; then
    echo "ERROR: forbidden pattern found in $f: $pattern"
    exit 1
  fi
}

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

# Remove only the old wrtbwmon monitor stack. Keep offload packages/features available,
# but disable runtime offload by default through files/etc/uci-defaults/10-network-accel-defaults.
for key in \
  CONFIG_PACKAGE_wrtbwmon \
  CONFIG_PACKAGE_luci-app-wrtbwmon \
  CONFIG_PACKAGE_luci-wrtbwmon
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
check_file files/etc/uci-defaults/01-enable-wifi
check_file files/etc/uci-defaults/02-set-argon-theme
check_file files/etc/uci-defaults/10-network-accel-defaults
check_file files/etc/uci-defaults/20-enable-netdata
check_file files/etc/uci-defaults/21-app-service-defaults
check_file files/etc/uci-defaults/30-netdata-zh
check_file files/etc/uci-defaults/40-enable-netdata-openwrt-clients
check_file files/etc/config/netdata_clients
check_file files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin

check_grep "keep offload available but disabled by default" files/etc/uci-defaults/10-network-accel-defaults
check_grep "flow_offloading='0'" files/etc/uci-defaults/10-network-accel-defaults
check_grep "flow_offloading_hw='0'" files/etc/uci-defaults/10-network-accel-defaults
check_grep "sw_flow='0'" files/etc/uci-defaults/10-network-accel-defaults
check_grep "hw_flow='0'" files/etc/uci-defaults/10-network-accel-defaults
check_grep "netdata" files/etc/uci-defaults/20-enable-netdata
check_grep "skip Netdata static web asset translation" files/etc/uci-defaults/30-netdata-zh
check_grep "update_every='3'" files/etc/uci-defaults/40-enable-netdata-openwrt-clients
check_grep "option update_every '3'" files/etc/config/netdata_clients
check_grep "1/3/5/10" files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
check_grep "OpenWrt 客户端下载速率" files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
check_grep 'TABLE="openwrt_clients"' files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
check_grep 'nft add table inet "\$TABLE"' files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
check_grep 'nft add chain inet "\$TABLE" "\$CHAIN"' files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin

echo "===== Validate selected config ====="
check_grep "^CONFIG_PACKAGE_netdata=y" .config
check_grep "^CONFIG_PACKAGE_luci-app-eqosplus=y" .config
check_grep "^CONFIG_PACKAGE_iptables-nft=y" .config
check_grep "^CONFIG_PACKAGE_ip6tables-nft=y" .config
check_grep "^CONFIG_PACKAGE_xtables-nft=y" .config
check_no_grep "^CONFIG_PACKAGE_wrtbwmon=y" .config
check_no_grep "^CONFIG_PACKAGE_luci-app-wrtbwmon=y" .config
check_no_grep "^CONFIG_PACKAGE_luci-wrtbwmon=y" .config

echo "===== DIY part3 done ====="
