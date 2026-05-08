#!/bin/bash
set -e

echo "===== DIY part1: stage P1A - add Argon and Lucky only ====="

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

echo "===== Add Lucky source - stage P1A ====="
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

echo "===== EQOS Plus is intentionally not cloned in P1A ====="

echo "===== DIY part1 package tree check ====="
find package/luci-theme-argon -maxdepth 3 -type f -name Makefile -print || true
find package/lucky -maxdepth 3 -type f -name Makefile -print || true

echo "===== DIY part1 done ====="
