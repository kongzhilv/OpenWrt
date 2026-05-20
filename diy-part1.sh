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

echo "===== Add wrtbwmon backend source ====="
rm -rf package/wrtbwmon
rm -rf /tmp/wrtbwmon-src

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

echo "===== Add luci-wrtbwmon source ====="
rm -rf package/luci-wrtbwmon
rm -rf /tmp/luci-wrtbwmon-src

git clone --depth 1 https://github.com/Kiougar/luci-wrtbwmon.git /tmp/luci-wrtbwmon-src

if [ ! -f /tmp/luci-wrtbwmon-src/CONTROL/control ]; then
    echo "ERROR: luci-wrtbwmon CONTROL/control missing"
    find /tmp/luci-wrtbwmon-src -maxdepth 4 -type f | sort || true
    exit 1
fi

if [ ! -d /tmp/luci-wrtbwmon-src/luci-wrtbwmon ]; then
    echo "ERROR: luci-wrtbwmon payload directory missing"
    find /tmp/luci-wrtbwmon-src -maxdepth 3 -type d | sort || true
    exit 1
fi

mkdir -p package/luci-wrtbwmon
cp -a /tmp/luci-wrtbwmon-src/luci-wrtbwmon package/luci-wrtbwmon/root
rm -rf /tmp/luci-wrtbwmon-src

cat > package/luci-wrtbwmon/Makefile <<'EOF_LUCI_WRTBWMON_MAKEFILE'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-wrtbwmon
PKG_VERSION:=0.8.3
PKG_RELEASE:=1
PKG_MAINTAINER:=Kiougar <https://github.com/Kiougar/luci-wrtbwmon>
PKG_LICENSE:=MIT
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-wrtbwmon
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI support for wrtbwmon realtime bandwidth usage
	DEPENDS:=+luci +luci-compat +wrtbwmon
endef

define Package/luci-wrtbwmon/description
LuCI module that uses wrtbwmon to track per-client bandwidth usage and realtime upload/download speed.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-wrtbwmon/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci $(1)/www
	if [ -d ./root/luasrc ]; then cp -a ./root/luasrc/* $(1)/usr/lib/lua/luci/; fi
	if [ -d ./root/htdocs ]; then cp -a ./root/htdocs/* $(1)/www/; fi
endef

$(eval $(call BuildPackage,luci-wrtbwmon))
EOF_LUCI_WRTBWMON_MAKEFILE

if [ ! -f package/luci-wrtbwmon/Makefile ]; then
    echo "ERROR: package/luci-wrtbwmon/Makefile missing after rewrite"
    exit 1
fi

echo "===== DIY part1 package tree check ====="
find package/luci-theme-argon -maxdepth 3 -type f -name Makefile -print || true
find package/lucky -maxdepth 3 -type f -name Makefile -print || true
find package/turboacc -maxdepth 4 -type f -name Makefile -print || true
find package/luci-app-eqosplus -maxdepth 4 -type f -name Makefile -print || true
find package/wrtbwmon -maxdepth 4 -type f -name Makefile -print || true
find package/luci-wrtbwmon -maxdepth 4 -type f -name Makefile -print || true

echo "===== DIY part1 done ====="
