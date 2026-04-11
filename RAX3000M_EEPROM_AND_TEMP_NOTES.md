# RAX3000M eMMC 分支说明

这个分支已经新增：

- `files/usr/share/rax3000m/mt7981_eeprom_mt7976_dbdc.bin.b64`
- `files/etc/uci-defaults/99-rax3000m-eeprom-fallback`

用途：首次开机时把 EEPROM fallback 写入 `/lib/firmware/mediatek/mt7981_eeprom_mt7976_dbdc.bin`。

## 仍建议补上的两处修改

### 1. `.config` 增加

```text
CONFIG_PACKAGE_luci-app-temp-status=y
```

### 2. `diy-part2.sh` 在 Argon 主题安装后增加

```bash
echo ">>> 安装温度状态插件"
rm -rf package/luci-app-temp-status 2>/dev/null || true
git clone --depth=1 https://github.com/gSpotx2f/luci-app-temp-status.git package/luci-app-temp-status
```

## 说明

当前 workflow 已经会自动把仓库根目录的 `files/` 导入到 `openwrt/files`，因此 EEPROM 相关新增文件会直接进入最终镜像。
