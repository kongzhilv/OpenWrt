#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置和修复冲突

# 1. 修改默认后台 IP 为 192.168.2.1
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 物理删除 kenzok8/small 源中引发“死循环”报错的无用插件
rm -rf feeds/small/*homeproxy*
rm -rf feeds/small/*momo*
rm -rf feeds/small/*fchomo*
rm -rf feeds/small/*nikki*
rm -rf feeds/kenzo/*homeproxy*
rm -rf feeds/kenzo/*momo*
rm -rf feeds/kenzo/*fchomo*
rm -rf feeds/kenzo/*nikki*

# 3. 单独拉取最新的 Argon 主题源码
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

# 4. 强制将默认主题由 bootstrap 替换为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 5. 暴力修复 Rust 编译交叉冲突
sed -i '/download-ci-llvm/d' feeds/packages/lang/rust/Makefile
sed -i '/\[llvm\]/a \download-ci-llvm = false' feeds/packages/lang/rust/Makefile

# 6. 强制修改系统默认语言为简体中文 (统一使用 zh_cn 标签)
sed -i 's/auto/zh_cn/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 7. 注入 NX30 Pro 高功率 EEPROM 文件，替换默认的 Wi-Fi 射频参数
mkdir -p package/base-files/files/lib/firmware/mediatek
curl -sLo package/base-files/files/lib/firmware/mediatek/mt7981_eeprom_mt7976_dbdc.bin \
    "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"

# =========================================================
# 修复 CMCC RAX3000M eMMC 版本的 MAC 地址寻址，并覆盖 Wi-Fi MAC
# =========================================================
echo "Patching CMCC RAX3000M to map native MAC addresses..."

# 自动查找源码中的 RAX3000M 基础设备树文件
DTS_FILE=$(find target/linux/mediatek -name "mt7981b-cmcc-rax3000m.dts" -type f | head -n 1)

if [ -f "$DTS_FILE" ]; then
    # 1. 彻底删除干扰的 &spi0 节点 (NAND 专属配置)
    awk '
    BEGIN { skip=0; brace_count=0 }
    /^[ \t]*&spi0 \{/ { skip=1; brace_count=1; next }
    skip==1 {
        brace_count += gsub(/\{/, "{")
        brace_count -= gsub(/\}/, "}")
        if (brace_count <= 0) skip=0
        next
    }
    { print }
    ' "$DTS_FILE" > "${DTS_FILE}.tmp" && mv "${DTS_FILE}.tmp" "$DTS_FILE"

    # 2. 追加 eMMC 专属配置 (仅读取 MAC，让 EEPROM Fallback 到 NX30Pro 文件)
    cat >> "$DTS_FILE" <<EOF

&wifi {
	status = "okay";
	nvmem-cells = <&macaddr_factory_2a 0>;
	nvmem-cell-names = "mac-address";
};

&gmac0 {
	nvmem-cells = <&macaddr_factory_2a 0>;
	nvmem-cell-names = "mac-address";
};

&gmac1 {
	nvmem-cells = <&macaddr_factory_24 0>;
	nvmem-cell-names = "mac-address";
};

&mmc0 {
	bus-width = <8>;
	max-frequency = <50000000>;
	cap-mmc-highspeed;
	cap-mmc-hw-reset;
	vmmc-supply = <&reg_3p3v>;
	vqmmc-supply = <&reg_1p8v>;
	non-removable;
	status = "okay";
};

/ {
	factory {
		partname = "factory";
		nvmem-layout {
			compatible = "fixed-layout";
			#address-cells = <1>;
			#size-cells = <1>;

			macaddr_factory_24: macaddr@24 {
				reg = <0x24 0x6>;
			};

			macaddr_factory_2a: macaddr@2a {
				reg = <0x2a 0x6>;
			};
		};
	};
};
EOF
    echo "RAX3000M eMMC MAC patch applied successfully!"
else
    echo "Warning: mt7981b-cmcc-rax3000m.dts not found!"
fi
# =========================================================

# =========================================================
# 植入首次开机初始化脚本：自动设置中文、区分 2.4G 和 5G Wi-Fi 名字
# =========================================================
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-custom-setup
#!/bin/sh

# 1. 设置界面默认语言为中文
uci -q set luci.main.lang=zh_cn
uci commit luci

# 2. 动态分别获取并设置 2.4G 和 5G 的 Wi-Fi 名字
for iface in $(uci show wireless | grep "=wifi-device" | cut -d'.' -f2 | cut -d'=' -f1); do
    band=$(uci -q get wireless.${iface}.band)
    
    if [ "$band" = "2g" ]; then
        uci set wireless.default_${iface}.ssid="OpenWrt_2.4G"
    elif [ "$band" = "5g" ]; then
        uci set wireless.default_${iface}.ssid="OpenWrt_5G"
    else
        # 兜底保障
        if [ "$iface" = "radio0" ]; then
            uci set wireless.default_${iface}.ssid="OpenWrt_2.4G"
        elif [ "$iface" = "radio1" ]; then
            uci set wireless.default_${iface}.ssid="OpenWrt_5G"
        fi
    fi
done
uci commit wireless

# 3. 默认开启 Wi-Fi
uci set wireless.radio0.disabled=0
uci set wireless.radio1.disabled=0
uci commit wireless

# 执行完毕后自毁
rm -f /etc/uci-defaults/99-custom-setup
exit 0
EOF
# =========================================================
