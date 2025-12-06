#!/bin/bash
set -e  # 遇到错误立即退出

# 定义颜色输出（增强可读性）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 重置颜色

# 脚本标题
echo -e "${YELLOW}=============================================${NC}"
echo -e "${YELLOW}          Docker 一键卸载脚本 (Ubuntu)        ${NC}"
echo -e "${YELLOW}=============================================${NC}"
echo ""

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误：请使用 root 权限运行此脚本（sudo ./docker-uninstall.sh）${NC}"
    exit 1
fi

# 确认操作（避免误执行）
read -p "⚠️  此操作将彻底卸载 Docker 并删除所有容器/镜像/卷/配置，是否继续？(y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}ℹ️  卸载操作已取消${NC}"
    exit 0
fi

# 可选：备份 Docker 数据（/var/lib/docker）
read -p "📦 是否先备份 Docker 数据到 /tmp/docker-backup.tar.gz？(y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🔄 正在备份 Docker 数据...${NC}"
    tar -zcf /tmp/docker-backup.tar.gz /var/lib/docker || {
        echo -e "${RED}❌ 数据备份失败，但仍继续卸载流程${NC}"
    }
    echo -e "${GREEN}✅ 数据已备份至 /tmp/docker-backup.tar.gz${NC}"
fi

# 步骤1：停止 Docker 相关服务
echo -e "\n${YELLOW}🔄 停止 Docker/Containerd 服务...${NC}"
systemctl stop docker || true
systemctl stop docker.socket || true
systemctl stop containerd || true

# 步骤2：卸载 Docker 软件包
echo -e "${YELLOW}🔄 卸载 Docker 核心包...${NC}"
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
apt-get autoremove -y --purge docker-ce docker-ce-cli containerd.io || true

# 步骤3：删除残留文件和目录
echo -e "${YELLOW}🔄 清理 Docker 残留文件...${NC}"
rm -rf /var/lib/docker || true
rm -rf /var/lib/containerd || true
rm -rf /etc/docker || true
rm -rf /usr/bin/docker || true
rm -rf /usr/bin/docker-compose || true
rm -rf /usr/bin/docker-buildx || true
rm -rf /usr/bin/containerd || true
rm -rf /etc/apt/sources.list.d/docker.list || true

# 步骤4：验证卸载结果
echo -e "\n${YELLOW}🔍 验证卸载结果...${NC}"
if command -v docker &>/dev/null; then
    echo -e "${RED}❌ Docker 卸载失败！${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker 已彻底卸载完成！${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}           卸载流程全部完成                  ${NC}"
    echo -e "${GREEN}=============================================${NC}"
fi
