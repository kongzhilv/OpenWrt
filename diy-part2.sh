#!/bin/bash
# 描述: 编译前执行，用于修改系统默认配置和修复冲突

# 1. 修改默认后台 IP 为 192.168.2.1
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 2. 使用通配符，大范围物理删除 kenzok8/small 源中引发“死循环”报错的无用插件
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
# 直接删除原始 Makefile 中关于 download-ci-llvm 的配置行
sed -i '/download-ci-llvm/d' feeds/packages/lang/rust/Makefile
# 强制在 Makefile 写入配置的地方加上 download-ci-llvm = false
sed -i '/\[llvm\]/a \download-ci-llvm = false' feeds/packages/lang/rust/Makefile
