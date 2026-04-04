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

# 7. 【核心新增】强行注入 EEPROM，修复官方源码 RAX3000M 没有 WiFi 的致命 BUG
# 创建自定义系统级的固件存放目录
mkdir -p package/base-files/files/lib/firmware/mediatek
# 从知名仓库拉取完美提取的 MT7981 双频 EEPROM 校准文件，直接塞进系统深层
curl -sLo package/base-files/files/lib/firmware/mediatek/mt7981_eeprom_mt7976_dual.bin https://raw.githubusercontent.com/coolsnowwolf/lede/master/package/lean/mt/mt76/files/lib/firmware/mediatek/mt7981_eeprom_mt7976_dual.bin
# 复制一份作为备用名，防止官方底层内核寻找旧版命名
cp package/base-files/files/lib/firmware/mediatek/mt7981_eeprom_mt7976_dual.bin package/base-files/files/lib/firmware/mediatek/mt7981_eeprom_mt7976.bin
