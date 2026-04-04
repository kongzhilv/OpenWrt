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

# 6. 强制修改系统默认语言为简体中文
sed -i 's/auto/zh_Hans/g' feeds/luci/modules/luci-base/root/etc/config/luci

# 6. 修复 eMMC 版本 EEPROM 读取失败，注入高功率 NX30 Pro 的 EEPROM 文件
mkdir -p package/base-files/files/lib/firmware/mediatek

# 注意：这里使用的是 raw.githubusercontent.com 的真实物理文件下载链接
# 并且下载后强制重命名为驱动所需要的 mt7981_eeprom_mt7976_dbdc.bin
curl -sLo package/base-files/files/lib/firmware/mediatek/mt7981_eeprom_mt7976_dbdc.bin \
    "https://raw.githubusercontent.com/KawaiiHachimi/Actions-rax3000m-emmc/main/eeprom/nx30pro_eeprom.bin"
