# OpenWrt for CMCC RAX3000M

这是一个面向 **中国移动 CMCC RAX3000M / MediaTek Filogic** 的 OpenWrt 自动构建仓库。

本仓库本身不是 OpenWrt 源码仓，而是一套用于 GitHub Actions 自动编译固件的配置、脚本和 overlay 文件。构建时会从官方 OpenWrt 仓库拉取源码，再注入本仓库中的 `.config`、`diy-*.sh` 脚本和 `files/` 覆盖文件，最终生成可刷写的固件文件。

> ⚠️ 刷机有风险，操作前请确认设备型号、闪存布局、救砖方式和原厂固件恢复方法。本仓库主要用于个人自用构建，不保证适用于所有硬件版本。

## 目标设备

当前 `.config` 指定的目标为：

```text
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
```

也就是说，本仓库默认构建的是 **CMCC RAX3000M** 的 OpenWrt 固件。

请不要直接把该配置用于其它路由器型号。即使同为 MediaTek Filogic 平台，不同设备的 DTS、分区、无线校准数据、闪存布局和固件格式也可能不同。

## 固件特性

当前构建主要集成以下内容：

### Web 管理与基础功能

- LuCI Web 管理界面
- 简体中文语言包
- Argon 主题
- `rpcd-mod-file`
- OpenSSH SFTP Server
- ttyd Web 终端
- 常用命令行工具：`bash`、`curl`、`wget-ssl`、`nano`、`vim`、`htop`、`tree`、`lsof`、`coreutils` 等

### 网络与调试工具

- `ip-full`
- `tcpdump`
- `iperf3`
- `mtr-json`
- `bind-dig`
- `arp-scan`
- `procps-ng-*`

### 无线相关

- `kmod-mt76`
- `kmod-mt7915e`
- `iw`
- `iwinfo`
- `wireless-regdb`
- `wpad-basic-mbedtls`

### USB 网卡相关

当前主要保留 USB 网络设备支持，例如：

- `kmod-usb-core`
- `kmod-usb2`
- `kmod-usb3`
- `kmod-usb-net`
- `kmod-usb-net-cdc-ether`
- `kmod-usb-net-rndis`
- `kmod-usb-net-cdc-ncm`
- `kmod-usb-net-cdc-eem`
- `kmod-usb-net-cdc-subset`

注意：本仓库默认没有启用 USB 存储、exFAT、NTFS、Btrfs、Docker、OpenClash、Passwall 等体积较大或容易引入冲突的组件。

### 已集成应用

- OpenList
- Lucky
- Turbo ACC
- EQOS Plus
- DiskMan
- Netdata
- 自定义 Netdata OpenWrt 客户端实时流量插件

## 默认配置

### 默认 LAN IP

构建脚本会把默认 LAN IP 从 OpenWrt 常见的：

```text
192.168.1.1
```

修改为：

```text
192.168.2.1
```

首次刷机后，请优先访问：

```text
http://192.168.2.1
```

### 默认 Wi-Fi

首次启动时，`files/etc/uci-defaults/01-enable-wifi` 会尝试自动启用 Wi-Fi，并按频段拆分 SSID：

```text
OpenWrt_2G
OpenWrt_5G
```

默认区域为 `CN`。

默认信道和带宽大致为：

- 2.4 GHz：信道 1，HE40
- 5 GHz：信道 36，HE80

> ⚠️ 当前脚本在无线加密未设置时会将 `encryption` 设为 `none`。也就是说，首次启动后 Wi-Fi 可能是开放网络。请在首次登录后立即设置无线密码，或者在刷机前自行修改 `files/etc/uci-defaults/01-enable-wifi`。

### 网络加速默认策略

本仓库会把 Turbo ACC、nft fullcone、BBR、offload 相关组件编进固件，但默认运行时不会开启大部分加速项。

`files/etc/uci-defaults/10-network-accel-defaults` 默认行为：

```sh
firewall.@defaults[0].flow_offloading='0'
firewall.@defaults[0].flow_offloading_hw='0'
turboacc.config.sw_flow='0'
turboacc.config.hw_flow='0'
turboacc.config.sfe_flow='0'
turboacc.config.fullcone_nat='1'
turboacc.config.fullcone6='0'
turboacc.config.hw_wed='0'
turboacc.config.bbr_cca='1'
```

设计目的：

- 保留相关功能，方便后续手动开启；
- 默认关闭可能影响稳定性或排障的加速项；
- 默认启用 FullCone NAT IPv4 和 BBR CCA。

### Netdata 客户端实时流量

本仓库使用 Netdata 作为实时监控方案，并额外提供一个自定义插件：

```text
files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
```

该插件通过 nftables named counters 统计 LAN 客户端 IPv4 实时上下行速率。

默认配置文件：

```text
files/etc/config/netdata_clients
```

默认内容：

```text
config netdata_clients 'main'
    option enabled '1'
    option lan_dev 'br-lan'
    option update_every '3'
    option rescan_every '60'
    option max_clients '64'
```

含义：

- `enabled`：是否启用插件；
- `lan_dev`：LAN 桥接口，默认 `br-lan`；
- `update_every`：刷新间隔，支持 `1`、`3`、`5`、`10` 秒；
- `rescan_every`：重新扫描在线客户端的间隔，最低 30 秒；
- `max_clients`：最多显示客户端数量，默认 64，插件内部最多限制到 128。

注意事项：

- 当前插件主要统计 IPv4 客户端；
- 客户端来源主要是 `/tmp/dhcp.leases` 和 `ip -4 neigh show dev br-lan`；
- 如果你的 LAN 不是 `br-lan`，需要修改 `netdata_clients.main.lan_dev`；
- 刷新间隔越小，CPU 开销越高。

### EQOS Plus 调整

本仓库会拉取 `sirpdboy/luci-app-eqosplus`，并通过：

```text
scripts/patches/patch-eqosplus-mac-ipv6.sh
```

对 LuCI 页面做轻量调整。

当前补丁目标：

- 保留原始 `IP/MAC` 可编辑字段；
- 同一个选择器中同时提供 IP 和 MAC 候选；
- 修正 `dhcp.leases` 解析；
- 修正 `ip neigh` 中 `lladdr` 的 MAC 解析，避免把 `STALE`、`REACHABLE` 等状态误识别为 MAC；
- 不把真实限速规则嵌入固件 overlay。

## 仓库结构

```text
.
├── .config
├── diy-part1.sh
├── diy-part2.sh
├── diy-part3-overlay.sh
├── files/
│   ├── etc/
│   │   ├── config/
│   │   │   └── netdata_clients
│   │   └── uci-defaults/
│   │       ├── 01-enable-wifi
│   │       ├── 02-set-argon-theme
│   │       ├── 10-network-accel-defaults
│   │       ├── 20-enable-netdata
│   │       ├── 21-app-service-defaults
│   │       ├── 30-netdata-zh
│   │       └── 40-enable-netdata-openwrt-clients
│   └── usr/
│       └── libexec/
│           └── netdata/
│               └── plugins.d/
│                   └── openwrt_clients.plugin
├── scripts/
│   └── patches/
│       └── patch-eqosplus-mac-ipv6.sh
└── .github/
    └── workflows/
        └── build-openwrt-fixed-overview.yml
```

## 构建流程说明

GitHub Actions 工作流文件位于：

```text
.github/workflows/build-openwrt-fixed-overview.yml
```

当前主要环境变量：

```yaml
REPO_URL: https://github.com/openwrt/openwrt
REPO_BRANCH: v25.12.1
CONFIG_FILE: .config
DIY_P1_SH: diy-part1.sh
DIY_P2_SH: diy-part2.sh
DIY_P3_SH: diy-part3-overlay.sh
UPLOAD_FIRMWARE: "true"
UPLOAD_RELEASE: "true"
TZ: Asia/Shanghai
```

构建步骤概览：

1. 检查本仓库必须文件是否存在；
2. 清理 GitHub Actions runner 的磁盘空间；
3. 安装 OpenWrt 编译依赖；
4. 克隆官方 OpenWrt 源码；
5. 执行 `diy-part1.sh` 添加第三方包；
6. 执行 `./scripts/feeds update -a`；
7. 执行 `./scripts/feeds install -a`；
8. 复制 `.config` 到 OpenWrt 源码目录；
9. 执行 `diy-part2.sh`；
10. 执行 `diy-part3-overlay.sh`；
11. 执行 `make defconfig`；
12. 执行 `make download -j8 V=s`；
13. 执行 `make -j4 V=s`；
14. 如果并行构建失败，回退执行 `make -j1 V=s`；
15. 收集固件文件、manifest、buildinfo、sha256sums 等；
16. 上传 GitHub Actions artifact；
17. 构建成功时发布 GitHub Release。

## 如何使用 GitHub Actions 构建

1. Fork 或克隆本仓库。
2. 进入仓库的 **Actions** 页面。
3. 选择工作流：`Build OpenWrt Netdata EQOS`。
4. 点击 **Run workflow**。
5. 等待构建完成。
6. 在 workflow run 页面下载 artifact：

```text
OpenWrt_Firmware_Netdata_EQOS_<run_number>
```

同时也会上传诊断日志：

```text
OpenWrt_Netdata_EQOS_Diagnostics_<run_number>
```

如果构建成功且 `UPLOAD_RELEASE` 为 `true`，会自动发布 Release，tag 名大致为：

```text
OpenWrt_Netdata_EQOS_YYYYMMDD_HHMMSS
```

## 本地构建参考

本仓库主要面向 GitHub Actions，但也可以参考以下步骤在 Linux 环境中本地构建。

> 本地构建需要较大的磁盘空间和较长时间。请确保文件系统大小写敏感。

```sh
git clone https://github.com/kongzhilv/OpenWrt.git build-config
cd build-config

git clone -b v25.12.1 --depth 1 https://github.com/openwrt/openwrt openwrt

chmod +x diy-part1.sh diy-part2.sh diy-part3-overlay.sh

cd openwrt
../diy-part1.sh

./scripts/feeds update -a
./scripts/feeds install -a

cp -f ../.config .config
../diy-part2.sh
../diy-part3-overlay.sh

make defconfig
make download -j8 V=s
make -j$(nproc) V=s
```

构建产物通常位于：

```text
openwrt/bin/targets/
```

## 重要注意事项

### 1. 不要混刷设备

本仓库目标是 `cmcc_rax3000m`。请确认你的设备型号、硬件版本和刷机方式完全匹配。

### 2. 首次启动后立刻设置密码

建议首次登录后立即完成：

- 设置 root 密码；
- 设置 Wi-Fi 加密方式和密码；
- 检查 LAN/WAN 口是否符合你的接线方式；
- 检查 Netdata、EQOS Plus、Turbo ACC 是否按预期运行。

### 3. 默认 Wi-Fi 可能开放

`01-enable-wifi` 会自动启用无线，并在没有现有加密设置时使用 `encryption=none`。如果你不希望默认开放 Wi-Fi，请在构建前修改该脚本。

### 4. 第三方包没有固定 commit

当前脚本会在构建时从多个上游仓库拉取最新代码，例如：

- `jerrykuku/luci-theme-argon`
- `sirpdboy/luci-app-lucky`
- `chenmozhijin/turboacc`
- `sirpdboy/luci-app-eqosplus`
- `OpenListTeam/OpenList-OpenWRT`
- `lisaac/luci-app-diskman`

这意味着构建结果可能会受到上游变动影响。若需要可复现构建，建议把这些第三方源固定到具体 commit 或 tag。

### 5. Release 固件仍需自行验证

即使 GitHub Actions 构建成功，也不代表固件一定适合你的设备。刷机前建议检查：

- 固件文件名是否对应目标设备；
- manifest 中是否包含预期包；
- sha256sums 是否匹配；
- 是否有足够的救砖手段；
- 是否需要从 factory 固件或 sysupgrade 固件进入。

## 可按需修改的地方

### 修改默认 LAN IP

修改：

```text
diy-part2.sh
```

找到：

```sh
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate || true
```

把 `192.168.2.1` 改成你需要的地址。

### 修改默认 Wi-Fi 名称

修改：

```text
files/etc/uci-defaults/01-enable-wifi
```

找到：

```sh
OpenWrt_2G
OpenWrt_5G
```

替换为你自己的 SSID。

### 修改 Netdata 客户端监控参数

修改：

```text
files/etc/config/netdata_clients
```

常用配置：

```text
option lan_dev 'br-lan'
option update_every '3'
option rescan_every '60'
option max_clients '64'
```

如果你的 LAN 接口不是 `br-lan`，请修改 `lan_dev`。

### 是否默认开启网络加速

修改：

```text
files/etc/uci-defaults/10-network-accel-defaults
```

例如想默认开启软件 flow offloading，可以把：

```sh
uci -q set firewall.@defaults[0].flow_offloading='0'
```

改为：

```sh
uci -q set firewall.@defaults[0].flow_offloading='1'
```

请注意，开启硬件加速、WED、SFE 等功能可能影响某些监控、限速或排障结果。

## 诊断与排错

### 构建失败

优先下载诊断 artifact：

```text
OpenWrt_Netdata_EQOS_Diagnostics_<run_number>
```

重点查看：

```text
logs/04_diy_part1.log
logs/05_feeds_update.log
logs/06_feeds_install.log
logs/07a_diy_part2.log
logs/07b_diy_part3_overlay.log
logs/07c_defconfig.log
logs/08_download.log
logs/09_compile_j4.log
logs/09_compile_j1.log
```

如果 `-j4` 失败但 `-j1` 有更明确错误，以 `09_compile_j1.log` 为准。

### Netdata 没有客户端图表

可检查：

```sh
uci show netdata_clients
ls -l /usr/lib/netdata/plugins.d/openwrt_clients.plugin
logread | grep -i openwrt_clients
nft list table inet openwrt_clients
cat /tmp/dhcp.leases
ip -4 neigh show dev br-lan
```

常见原因：

- LAN 接口不是 `br-lan`；
- 没有 DHCP lease；
- 客户端只走 IPv6；
- Netdata 插件没有执行权限；
- nftables 表或 counter 没有成功创建。

### EQOS Plus 设备选择异常

检查补丁是否成功执行：

```text
logs/07a_diy_part2.log
```

如果上游 `luci-app-eqosplus` 页面结构变化，`patch-eqosplus-mac-ipv6.sh` 可能无法匹配并中止构建。这通常需要重新适配补丁。

## 安全建议

- 首次启动后立即设置 root 密码；
- 首次启动后立即设置 Wi-Fi 加密；
- 不要把真实家庭网络限速规则、MAC、IP 写入公开仓库；
- 不要在公开仓库中提交私有 DDNS、Token、密码、证书；
- 如果要长期使用，建议固定第三方仓库 commit，减少供应链风险；
- 刷机前确认有串口、TFTP、恢复模式或其它救砖方式。

## 许可证

本仓库中的脚本和配置用于 OpenWrt 自动构建。OpenWrt 本体遵循其上游许可证；第三方包分别遵循其各自上游许可证。

请在分发固件或二次修改时遵守 OpenWrt、LuCI 以及所有第三方软件包的许可证要求。
