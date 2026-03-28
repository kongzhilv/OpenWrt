#!/bin/bash
# 描述: 编译前执行，用于添加第三方软件源

# 添加 kenzok8 维护的国内精选插件源 (包含几乎所有主流代理和增强插件)
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >>feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small' >>feeds.conf.default
