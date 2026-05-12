# BBR

一个完全符合 POSIX `sh` 的一键脚本：`enable-bbr.sh`。

## 目标

在以下系统（及其衍生发行版）自动启用 BBR：

- Debian / Ubuntu
- Alpine
- RHEL / AlmaLinux / Rocky
- FreeBSD

## 用法

```sh
sudo sh ./enable-bbr.sh
# 或
#doas sh ./enable-bbr.sh
```

脚本行为：

- Linux:
  - 尝试加载 `sch_fq` 和 `tcp_bbr` 模块（若内建则自动忽略加载失败）
  - 立即设置：
    - `net.core.default_qdisc=fq`
    - `net.ipv4.tcp_congestion_control=bbr`
  - 持久化到 `/etc/sysctl.d/99-bbr.conf`（若不存在该目录则写入 `/etc/sysctl.conf`）

- FreeBSD:
  - 加载 `tcp_rack`、`tcp_bbr`
  - 立即设置：
    - `net.inet.tcp.functions_default=bbr`
  - 持久化：
    - `/boot/loader.conf` 中加入 `tcp_rack_load="YES"`、`tcp_bbr_load="YES"`
    - `/etc/sysctl.conf` 中加入以上 TCP 参数

## 说明

- 脚本若非 root 运行，会自动尝试通过 `sudo` 或 `doas` 提权重启自身。
- 若系统不支持 BBR 或内核未提供相关模块，`sysctl` 设置会失败并返回错误。
