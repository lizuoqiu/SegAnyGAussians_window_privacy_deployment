#!/usr/bin/env bash
set -e

# RunPod 会在 Pod 启动时把你账户里的公钥注入到 ~/.ssh/authorized_keys（若已提前上传）
mkdir -p /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true

# 生成 host keys（第一次启动需要）
ssh-keygen -A

# 启动 sshd（后台），并让容器一直存活
/usr/sbin/sshd
exec sleep infinity