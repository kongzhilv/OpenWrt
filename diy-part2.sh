#!/bin/bash
set -e

echo "===== DIY part2: force RAX3000M minimal F50 WiFi SFTP config ====="

# 默认 IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true

# 清掉旧 files，避免旧 F50/extroot/OpenClash 脚本进入固件
rm -rf files
mkdir -p files/etc/uci-defaults

# 关键：不要在旧 .config 上 sed 修，直接重写，避免 openwrt_one 残留
cat > .config <<'EOF_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y

# LuCI
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# SFTP
CONFIG_PACKAGE_openssh-sftp-server=y

# WiFi
CONFIG_PACKAGE_kmod-mt76=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_wireless-regdb=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y

# USB / F50
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y

# Disabled
# CONFIG_PACKAGE_kmod-usb-net-cdc-mbim is not set
# CONFIG_PACKAGE_kmod-usb-net-qmi-wwan is not set
# CONFIG_PACKAGE_kmod-usb-wdm is not set
# CONFIG_PACKAGE_kmod-usb-serial is not set
# CONFIG_PACKAGE_kmod-usb-serial-option is not set
# CONFIG_PACKAGE_kmod-usb-serial-wwan is not set
# CONFIG_PACKAGE_kmod-usb-acm is not set
# CONFIG_PACKAGE_usb-modeswitch is not set
# CONFIG_PACKAGE_kmod-usb-net-ipheth is not set
# CONFIG_PACKAGE_usbmuxd is not set
# CONFIG_PACKAGE_libimobiledevice is not set
# CONFIG_PACKAGE_openlist is not set
# CONFIG_PACKAGE_luci-app-openlist is not set
# CONFIG_PACKAGE_luci-app-openclash is not set
# CONFIG_PACKAGE_luci-app-diskman is not set
# CONFIG_PACKAGE_luci-app-turboacc is not set
# CONFIG_PACKAGE_luci-app-lucky is not set
# CONFIG_PACKAGE_luci-app-eqosplus is not set
# CONFIG_PACKAGE_dockerd is not set
# CONFIG_PACKAGE_docker-compose is not set
# CONFIG_PACKAGE_luci-app-dockerman is not set
# CONFIG_PACKAGE_block-mount is not set
# CONFIG_PACKAGE_e2fsprogs is not set
# CONFIG_PACKAGE_parted is not set
# CONFIG_PACKAGE_kmod-fs-ext4 is not set
# CONFIG_PACKAGE_kmod-usb-storage is not set
# CONFIG_PACKAGE_kmod-usb-storage-uas is not set
EOF_CONFIG

cat > files/etc/uci-defaults/01-enable-wifi <<'EOF_WIFI'
#!/bin/sh

logger -t enable-wifi "start"

[ -s /etc/config/wireless ] || wifi config || true

uci show wireless 2>/dev/null | grep -q '=wifi-device' || {
    logger -t enable-wifi "no wifi-device found, retry next boot"
    exit 1
}

for dev in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-device/\1/p"); do
    uci -q set "${dev}.disabled=0"
    uci -q set "${dev}.country=CN"

    band="$(uci -q get "${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${dev}.channel=1"
        uci -q set "${dev}.htmode=HE40"
    elif [ "$band" = "5g" ]; then
        uci -q set "${dev}.channel=36"
        uci -q set "${dev}.htmode=HE80"
    fi
done

i=0
for iface in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-iface/\1/p"); do
    uci -q set "${iface}.disabled=0"
    uci -q set "${iface}.mode=ap"
    uci -q set "${iface}.network=lan"

    dev="$(uci -q get "${iface}.device" || true)"
    band="$(uci -q get "wireless.${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2G"
    elif [ "$band" = "5g" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5G"
    elif [ "$i" = "0" ]; then
        uci -q set "${iface}.ssid=OpenWrt_2G"
    elif [ "$i" = "1" ]; then
        uci -q set "${iface}.ssid=OpenWrt_5G"
    else
        uci -q set "${iface}.ssid=OpenWrt_WiFi_$i"
    fi

    # 测试阶段默认无密码
    uci -q set "${iface}.encryption=none"
    uci -q delete "${iface}.key"

    i=$((i + 1))
done

uci commit wireless
wifi reload || wifi || true

logger -t enable-wifi "done"
exit 0
EOF_WIFI

chmod +x files/etc/uci-defaults/01-enable-wifi

echo "===== DIY part2 done ====="
