#!/bin/bash
# Minimal RAX3000M + F50 + WiFi + SFTP build.
# Important:
# - Do not copy repository files/ into firmware.
# - Do not add extroot scripts.
# - Do not add f50-bind scripts.
# - Do not add usb-no-autosuspend scripts.
# - Do not add OpenClash/OpenList/Docker/DiskMan/Turbo ACC.
# - Only generate a clean WiFi enable uci-defaults script.

set -e

echo "===== DIY part2: minimal RAX3000M + F50 USB Ethernet + WiFi + SFTP ====="

# Optional: default LAN IP
# If you want official default 192.168.1.1, comment this line.
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true

# Remove old embedded files first to avoid old scripts.
echo ">>> Remove old embedded files directory"
rm -rf files

# Create only clean WiFi uci-defaults directory.
mkdir -p files/etc/uci-defaults

# Normalize target and packages in .config
if [ -f .config ]; then
    echo ">>> Normalize .config"

    # Remove target leftovers
    sed -i '/^CONFIG_TARGET_DEVICE_/d' .config
    sed -i '/^CONFIG_TARGET_PROFILE=/d' .config
    sed -i '/^CONFIG_TARGET_BOARD=/d' .config
    sed -i '/^CONFIG_TARGET_SUBTARGET=/d' .config
    sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_/d' .config
    sed -i '/^# CONFIG_TARGET_mediatek_filogic_DEVICE_/d' .config

    # Remove package lines we want to control
    for p in \
        luci luci-i18n-base-zh-cn openssh-sftp-server \
        kmod-mt76 kmod-mt7915e iw iwinfo wireless-regdb wpad-basic-mbedtls \
        kmod-mt_wifi luci-app-mtwifi-cfg mtwifi-cfg-ucode \
        usbutils \
        kmod-usb-core kmod-usb2 kmod-usb3 \
        kmod-usb-net kmod-usb-net-cdc-ether kmod-usb-net-rndis \
        kmod-usb-net-cdc-ncm kmod-usb-net-cdc-eem kmod-usb-net-cdc-subset \
        kmod-usb-net-cdc-mbim kmod-usb-net-qmi-wwan kmod-usb-wdm \
        kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan kmod-usb-acm \
        usb-modeswitch kmod-usb-net-ipheth usbmuxd libimobiledevice \
        openlist luci-app-openlist luci-app-openclash \
        luci-app-diskman luci-app-turboacc luci-app-lucky luci-app-eqosplus \
        dockerd docker-compose luci-app-dockerman \
        block-mount e2fsprogs parted kmod-fs-ext4 \
        kmod-usb-storage kmod-usb-storage-uas \
    ; do
        sed -i "/^CONFIG_PACKAGE_${p}=/d" .config
        sed -i "/^# CONFIG_PACKAGE_${p} is not set/d" .config
    done

    cat >> .config <<'EOF_CONFIG'

# ===== target =====
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y

# ===== LuCI basic =====
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# ===== SFTP =====
CONFIG_PACKAGE_openssh-sftp-server=y

# ===== WiFi =====
CONFIG_PACKAGE_kmod-mt76=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_wireless-regdb=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y

# Use open-source mt76, not proprietary mt_wifi
# CONFIG_PACKAGE_kmod-mt_wifi is not set
# CONFIG_PACKAGE_luci-app-mtwifi-cfg is not set
# CONFIG_PACKAGE_mtwifi-cfg-ucode is not set

# ===== USB tools =====
CONFIG_PACKAGE_usbutils=y

# ===== USB host =====
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y

# ===== F50 USB Ethernet minimal drivers =====
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y

# ===== disabled during F50 cold-boot test =====
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

# ===== disabled custom stack =====
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
fi

echo ">>> Generate clean first-boot WiFi enable script"

cat > files/etc/uci-defaults/01-enable-wifi <<'EOF_WIFI'
#!/bin/sh

logger -t enable-wifi "start minimal wifi enable script"

# Generate /etc/config/wireless if missing.
[ -s /etc/config/wireless ] || wifi config || true

# If no wifi-device exists yet, keep this script for next boot.
uci show wireless 2>/dev/null | grep -q '=wifi-device' || {
    logger -t enable-wifi "no wifi-device found, retry next boot"
    exit 1
}

# Enable all radios and set safe channels.
for dev in $(uci show wireless | sed -n "s/^\(wireless\.[^=]*\)=wifi-device/\1/p"); do
    uci -q set "${dev}.disabled=0"
    uci -q set "${dev}.country=CN"

    band="$(uci -q get "${dev}.band" || true)"

    if [ "$band" = "2g" ]; then
        uci -q set "${dev}.channel=1"
        uci -q set "${dev}.htmode=HE40"
    elif [ "$band" = "5g" ]; then
        # Use non-DFS channel to avoid 5G waiting for radar check.
        uci -q set "${dev}.channel=36"
        uci -q set "${dev}.htmode=HE80"
    fi
done

# Enable all AP interfaces and bridge them to LAN.
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

    # Open network for test only.
    # After confirming F50 cold boot works, change to psk2/sae-mixed.
    uci -q set "${iface}.encryption=none"
    uci -q delete "${iface}.key"

    i=$((i + 1))
done

uci commit wireless
wifi reload || wifi || true

logger -t enable-wifi "wifi enabled successfully"
exit 0
EOF_WIFI

chmod +x files/etc/uci-defaults/01-enable-wifi

echo "===== DIY part2 done ====="
