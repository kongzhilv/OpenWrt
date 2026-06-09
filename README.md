# OpenWrt for CMCC RAX3000M

这是一个面向 **中国移动 CMCC RAX3000M / MediaTek Filogic** 的 OpenWrt 自动构建仓库。

本仓库本身不是 OpenWrt 源码仓，而是一套用于 GitHub Actions 自动编译固件的配置、脚本和 `files/` overlay 文件。构建时会从官方 OpenWrt 仓库拉取源码，再注入本仓库中的 `.config`、`diy-*.sh` 脚本、第三方包补丁和 `files/` 覆盖文件，最终生成可刷写固件。

> ⚠️ 刷机有风险。操作前请确认设备型号、闪存布局、救砖方式和原厂固件恢复方法。本仓库主要用于个人自用构建，不保证适用于所有硬件版本。

## 目标设备

当前 `.config` 指定目标为：

```text
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
```

也就是说，本仓库默认构建 **CMCC RAX3000M** 的 OpenWrt 固件。请不要直接把该配置用于其它路由器型号。

## ROM、运行时 overlay 和仓库 files/ 的关系

OpenWrt 刷入后的只读固件层通常对应 `/rom`，刷机后运行中修改的文件、安装的软件包和热修内容会进入可写 overlay。系统实际看到的 `/` 是 ROM 与 overlay 合并后的结果。

本仓库中的：

```text
files/...
```

是 **构建时 overlay**，会在编译阶段被复制进 OpenWrt buildroot 的 `files/`，最终进入新固件 ROM。它不是路由器运行时的 overlay 分区。

因此：

```text
仓库 files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
-> 构建进新固件
-> 刷机后出现在 /rom/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
-> 系统通过 /usr/libexec/netdata/plugins.d/openwrt_clients.plugin 使用它
```

如果刷机时选择“不保留配置”，旧 overlay 中的 `/etc/config/eqosplus`、手工热修脚本和运行中 `tc/nft` 规则不会被保留。但如果仓库 `files/` 中嵌入了配置，它会成为新 ROM 自带内容。

本仓库明确禁止嵌入：

```text
files/etc/config/eqosplus
```

避免把真实家庭设备 MAC/IP 限速规则写入公开仓库或固件 ROM。

## 固件特性

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

构建脚本会把默认 LAN IP 从 `192.168.1.1` 修改为：

```text
192.168.2.1
```

首次刷机后访问：

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

> ⚠️ 当前脚本在无线加密未设置时会将 `encryption` 设为 `none`。首次登录后请立即设置无线密码，或者在刷机前自行修改 `files/etc/uci-defaults/01-enable-wifi`。

### 网络加速默认策略

本仓库会把 Turbo ACC、nft fullcone、BBR、offload 相关组件编进固件，但默认运行时关闭大部分加速项，方便排障和避免影响监控/限速。

`files/etc/uci-defaults/10-network-accel-defaults` 默认行为大致为：

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

## Netdata 客户端实时流量插件

本仓库使用 Netdata 作为实时监控方案，并额外提供自定义插件：

```text
files/usr/libexec/netdata/plugins.d/openwrt_clients.plugin
```

当前插件特性：

- 使用 `inet openwrt_clients` nftables 表；
- 使用 named counters 统计每个 LAN 客户端实时流量；
- 一台客户端一张图；
- 图表命名空间为 `openwrt_clients_zh`；
- 图表标题为中文；
- 维度细分为 IPv4 / IPv6：

```text
IPv4下载
IPv4上传
IPv6下载
IPv6上传
```

插件会从以下来源发现客户端：

```text
/tmp/dhcp.leases
ip -4 neigh show dev br-lan
ip -6 neigh show dev br-lan
```

IPv6 统计逻辑：

- 跳过 `fe80::` link-local；
- 跳过 `ff*` multicast；
- 跳过 FAILED 邻居；
- 尽量按 MAC 聚合同一设备的 IPv4/IPv6 地址；
- 同一 MAC 下多个 IPv6 地址会被归入同一客户端图表。

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

## EQOS Plus 调整

本仓库会拉取 `sirpdboy/luci-app-eqosplus`，并通过：

```text
scripts/patches/patch-eqosplus-mac-ipv6.sh
```

对 LuCI 页面和后端脚本进行补丁。

当前补丁目标：

- 保留原始 `IP/MAC` 可编辑字段；
- 同一个选择器中同时提供 IP 和 MAC 候选；
- 修正 `dhcp.leases` 解析；
- 修正 `ip neigh` 中 `lladdr` 的 MAC 解析，避免把 `STALE`、`REACHABLE` 等状态误识别为 MAC；
- 修复 `@device[10]` 及以后设备编号被 `grep -o '[0-9]'` 拆开的问题；
- 把每设备 leaf qdisc 从 `sfq` 改为 `fq_codel`；
- IFB 创建后设置 `txqueuelen 1000`；
- 尝试补充 IPv6 相关 tc filter；
- 不把真实限速规则嵌入固件 overlay。

### EQOS Plus 单位说明

当前 EQOS Plus 后端换算中，界面数值不是 Mbps，而近似等价于：

```text
实际 Mbps = EQOS 数值 * 8.192
```

例如 1000/100 Mbps 宽带，如果想把瓶颈控制在路由器侧，建议总值从以下开始测试：

```text
download = 110  ≈ 901 Mbps
upload   = 11   ≈ 90 Mbps
```

设备限速同理：

```text
5 ≈ 40.96 Mbps
10 ≈ 81.92 Mbps
```

## GitHub Actions 构建与 Release

工作流文件：

```text
.github/workflows/build-openwrt-fixed-overview.yml
```

主要环境变量：

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

构建流程概览：

1. 检查本仓库必须文件是否存在；
2. 清理 GitHub Actions runner 的磁盘空间；
3. 安装 OpenWrt 编译依赖；
4. 克隆官方 OpenWrt 源码；
5. 执行 `diy-part1.sh` 添加第三方包并 patch EQOS Plus；
6. 执行 feeds update/install；
7. 复制 `.config` 到 OpenWrt 源码目录；
8. 执行 `diy-part2.sh`；
9. 执行 `diy-part3-overlay.sh`；
10. 执行 `make defconfig`；
11. 执行 `make download -j8 V=s`；
12. 执行 `make -j4 V=s`；
13. 如果并行构建失败，回退执行 `make -j1 V=s`；
14. 收集固件文件、manifest、buildinfo、sha256sums 等；
15. 构建成功时创建 GitHub Release；
16. 上传 GitHub Actions artifact；
17. 上传诊断日志 artifact。

### 为什么某次 Actions 只有 artifact 没有 Release

如果 workflow 里没有 `Create GitHub Release` 步骤，即使构建成功，也只会上传 artifact，不会创建 Release。当前 workflow 已加入 Release 步骤：构建成功且 `UPLOAD_RELEASE=true` 时，会用 `gh release create` 把 `release-files/*` 发布到 GitHub Releases。

GitHub Actions 使用仓库的自动 `GITHUB_TOKEN` 进行 API 操作；本工作流已设置：

```yaml
permissions:
  contents: write
```

用于创建 Release 和上传 release assets。

## 如何使用 GitHub Actions 构建

1. 进入仓库的 **Actions** 页面；
2. 选择工作流：`Build OpenWrt Netdata EQOS`；
3. 点击 **Run workflow**；
4. 等待构建完成；
5. 在 workflow run 页面下载 artifact；
6. 构建成功后也会在 Releases 页面生成发行版。

artifact 名称大致为：

```text
OpenWrt_Firmware_Netdata_EQOS_<run_number>
OpenWrt_Netdata_EQOS_Diagnostics_<run_number>
```

Release tag 名称大致为：

```text
OpenWrt_Netdata_EQOS_YYYYMMDD_HHMMSS_<run_number>
```

## 本地构建参考

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

## 诊断与排错

### Netdata 没有客户端图表

检查：

```sh
uci show netdata_clients
ls -l /usr/libexec/netdata/plugins.d/openwrt_clients.plugin
/etc/init.d/netdata restart
logread | grep -i openwrt_clients
nft list table inet openwrt_clients
cat /tmp/dhcp.leases
ip -4 neigh show dev br-lan
ip -6 neigh show dev br-lan
```

常见原因：

- LAN 接口不是 `br-lan`；
- 没有 DHCP lease 或邻居表为空；
- Netdata 插件没有执行权限；
- nftables 表或 counter 没有成功创建；
- IPv6 设备只有 link-local 地址，插件会跳过 `fe80::`。

### EQOS Plus 设备规则不完整

检查：

```sh
uci show eqosplus
tc class show dev br-lan | grep 'class htb'
tc class show dev br-lan_ifb | grep 'class htb'
nft list table inet eqosplus 2>/dev/null | grep -E 'ether saddr|meta mark'
```

如果配置里有 `@device[10]` 以后设备，但运行中只生成到 `1:1090`，说明多位数设备编号补丁没有生效。当前仓库构建时会强制校验 `grep -oE '[0-9]+'`，防止这个问题回归。

### EQOS Plus 延迟/丢包检查

```sh
ping -c 20 -W 1 223.5.5.5
tc -s qdisc show dev br-lan_ifb
tc -s class show dev br-lan_ifb | grep -E 'class htb|dropped|overlimits|backlog' -A2
tc qdisc show dev br-lan | grep fq_codel
tc qdisc show dev br-lan_ifb | grep fq_codel
```

判断：

```text
br-lan_ifb dropped 不快速增加 = 上传方向队列基本稳定
backlog 长期为 0 或很低 = 队列未明显堆积
fq_codel 出现在设备 class 下 = 低延迟 leaf qdisc 生效
```

## 安全建议

- 首次启动后立即设置 root 密码；
- 首次启动后立即设置 Wi-Fi 加密；
- 不要把真实家庭网络限速规则、MAC、IP 写入公开仓库；
- 不要在公开仓库中提交私有 DDNS、Token、密码、证书；
- 如果要长期使用，建议固定第三方仓库 commit，减少供应链风险；
- 刷机前确认有串口、TFTP、恢复模式或其它救砖方式。

## 许可证

本仓库中的脚本和配置用于 OpenWrt 自动构建。OpenWrt 本体遵循其上游许可证；第三方包分别遵循其各自上游许可证。请在分发固件或二次修改时遵守 OpenWrt、LuCI、Netdata 以及所有第三方软件包的许可证要求。
