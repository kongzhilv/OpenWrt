#!/bin/bash
set -e

echo "===== DIY part1: add Argon, Lucky, Turbo ACC no-SFE, EQOS Plus and wrtbwmon ====="

echo "===== Remove known conflicting third-party feed leftovers from feeds.conf.default ====="
if [ -f feeds.conf.default ]; then
  sed -i '/helloworld/d' feeds.conf.default || true
  sed -i '/openclash/d' feeds.conf.default || true
  sed -i '/passwall/d' feeds.conf.default || true
  sed -i '/ssr-plus/d' feeds.conf.default || true
  sed -i '/small/d' feeds.conf.default || true
fi

echo "===== Add luci-theme-argon source ====="
rm -rf package/luci-theme-argon
git clone --depth 1 -b master https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

if [ ! -f package/luci-theme-argon/Makefile ]; then
  echo "ERROR: luci-theme-argon Makefile missing"
  find package/luci-theme-argon -maxdepth 4 -type f -name Makefile -print || true
  exit 1
fi

echo "===== Add Lucky source ====="
rm -rf package/lucky
git clone --depth 1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

if [ ! -f package/lucky/luci-app-lucky/Makefile ]; then
  echo "ERROR: luci-app-lucky Makefile missing"
  find package/lucky -maxdepth 4 -type f -name Makefile -print || true
  exit 1
fi

if [ ! -f package/lucky/lucky/Makefile ]; then
  echo "ERROR: lucky core Makefile missing"
  find package/lucky -maxdepth 4 -type f -name Makefile -print || true
  exit 1
fi

echo "===== Add Turbo ACC source - no SFE stable mode ====="
rm -rf package/turboacc
rm -rf /tmp/turboacc-luci

git clone --depth 1 --single-branch --branch luci https://github.com/chenmozhijin/turboacc.git /tmp/turboacc-luci

if [ ! -f /tmp/turboacc-luci/add_turboacc.sh ]; then
  echo "ERROR: turboacc add_turboacc.sh missing"
  find /tmp/turboacc-luci -maxdepth 4 -type f | sort || true
  exit 1
fi

chmod +x /tmp/turboacc-luci/add_turboacc.sh

# Use no-SFE first:
# - keep luci-app-turboacc
# - keep nft-fullcone
# - do not add shortcut-fe
bash /tmp/turboacc-luci/add_turboacc.sh --no-sfe

rm -rf /tmp/turboacc-luci

if [ ! -f package/turboacc/luci-app-turboacc/Makefile ]; then
  echo "ERROR: luci-app-turboacc Makefile missing"
  find package/turboacc -maxdepth 5 -type f -name Makefile -print || true
  exit 1
fi

if [ ! -f package/turboacc/nft-fullcone/Makefile ]; then
  echo "ERROR: nft-fullcone Makefile missing"
  find package/turboacc -maxdepth 5 -type f -name Makefile -print || true
  exit 1
fi

if find package/turboacc -maxdepth 3 -type d -iname '*shortcut*' | grep -q .; then
  echo "ERROR: shortcut-fe exists, but this build uses Turbo ACC no-SFE mode"
  find package/turboacc -maxdepth 4 -type d -iname '*shortcut*' -print || true
  exit 1
fi

echo "===== Add EQOS Plus source ====="
rm -rf package/luci-app-eqosplus
git clone --depth 1 https://github.com/sirpdboy/luci-app-eqosplus.git package/luci-app-eqosplus

if [ ! -f package/luci-app-eqosplus/Makefile ]; then
  echo "ERROR: luci-app-eqosplus Makefile missing"
  find package/luci-app-eqosplus -maxdepth 4 -type f -name Makefile -print || true
  exit 1
fi

echo "===== Add wrtbwmon realtime monitor: brvphoenix backend + LuCI ====="

rm -rf package/wrtbwmon package/luci-wrtbwmon package/luci-app-wrtbwmon
rm -rf /tmp/wrtbwmon-src /tmp/luci-app-wrtbwmon-src

git clone --depth 1 https://github.com/brvphoenix/wrtbwmon.git /tmp/wrtbwmon-src

if [ ! -f /tmp/wrtbwmon-src/wrtbwmon/Makefile ]; then
  echo "ERROR: wrtbwmon Makefile missing"
  find /tmp/wrtbwmon-src -maxdepth 5 -type f -name Makefile -print || true
  exit 1
fi

cp -a /tmp/wrtbwmon-src/wrtbwmon package/wrtbwmon
rm -rf /tmp/wrtbwmon-src

if [ ! -f package/wrtbwmon/Makefile ]; then
  echo "ERROR: package/wrtbwmon/Makefile missing after copy"
  exit 1
fi

# OpenWrt 25.12 uses firewall4/nftables.
# Force nft-compatible iptables userspace for wrtbwmon.
sed -i 's/DEPENDS:=+iptables +@BUSYBOX_CONFIG_IP/DEPENDS:=+iptables-nft +ip6tables-nft +xtables-nft +ip-full/g' package/wrtbwmon/Makefile
sed -i 's/DEPENDS:=+iptables +ip-full/DEPENDS:=+iptables-nft +ip6tables-nft +xtables-nft +ip-full/g' package/wrtbwmon/Makefile

git clone --depth 1 https://github.com/brvphoenix/luci-app-wrtbwmon.git /tmp/luci-app-wrtbwmon-src

if [ ! -f /tmp/luci-app-wrtbwmon-src/luci-app-wrtbwmon/Makefile ]; then
  echo "ERROR: luci-app-wrtbwmon Makefile missing"
  find /tmp/luci-app-wrtbwmon-src -maxdepth 5 -type f -name Makefile -print || true
  exit 1
fi

cp -a /tmp/luci-app-wrtbwmon-src/luci-app-wrtbwmon package/luci-app-wrtbwmon
rm -rf /tmp/luci-app-wrtbwmon-src

echo "===== DIY part1 package tree check ====="
find package/luci-theme-argon -maxdepth 3 -type f -name Makefile -print || true
find package/lucky -maxdepth 3 -type f -name Makefile -print || true
find package/turboacc -maxdepth 4 -type f -name Makefile -print || true
find package/luci-app-eqosplus -maxdepth 4 -type f -name Makefile -print || true
find package/wrtbwmon -maxdepth 4 -type f -name Makefile -print || true
find package/luci-app-wrtbwmon -maxdepth 4 -type f -name Makefile -print || true

echo "===== DIY part1 done ====="
