#!/bin/bash
set -e  # 遇到错误立即退出

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo "错误：请使用 root 用户运行此脚本（sudo -i 切换后执行）"
    exit 1
fi

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Ubuntu XFCE + VNC 一键安装脚本${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# 1. 更新系统并安装依赖
echo -e "${YELLOW}[1/5] 正在更新系统并安装基础依赖...${NC}"
apt update -y && apt upgrade -y
apt install -y xfce4 xfce4-goodies tightvncserver xfonts-base dbus-x11

# 2. 配置 VNC 基础环境
echo -e "${YELLOW}[2/5] 正在配置 VNC 基础环境...${NC}"
# 创建 VNC 配置目录（针对当前执行用户，非 root 需调整）
USER_HOME=$(eval echo ~$SUDO_USER)
if [ -z "$SUDO_USER" ]; then
    USER_HOME=/root
fi
VNC_DIR="$USER_HOME/.vnc"
mkdir -p "$VNC_DIR"

# 3. 交互式配置 VNC 端口和密码
echo -e "${YELLOW}[3/5] 开始配置 VNC 端口和密码...${NC}"
# 输入端口（默认 5901，对应 display :1）
read -p "请输入 VNC 端口（默认 5901，建议使用 5901-5910 之间）：" VNC_PORT
VNC_PORT=${VNC_PORT:-5901}
# 计算 display 号（5901 -> :1，5902 -> :2...）
DISPLAY_NUM=$((VNC_PORT - 5900))

# 设置 VNC 密码
echo -e "\n请设置 VNC 连接密码（仅支持 6-8 位）："
su - ${SUDO_USER:-root} -c "vncpasswd $VNC_DIR/passwd"

# 4. 生成 XFCE 启动配置文件
echo -e "${YELLOW}[4/5] 正在生成 XFCE 启动配置...${NC}"
cat > "$VNC_DIR/xstartup" << EOF
#!/bin/bash
xrdb $USER_HOME/.Xresources
startxfce4 &
EOF

# 设置配置文件权限
chmod +x "$VNC_DIR/xstartup"
chown -R ${SUDO_USER:-root}:${SUDO_USER:-root} "$VNC_DIR"

# 5. 创建 VNC 服务文件（开机自启）
echo -e "${YELLOW}[5/5] 正在创建系统服务并设置开机自启...${NC}"
SERVICE_FILE="/etc/systemd/system/vncserver@$DISPLAY_NUM.service"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VNC Server for XFCE on display $DISPLAY_NUM
After=network.target

[Service]
Type=forking
User=${SUDO_USER:-root}
PAMName=login
WorkingDirectory=$USER_HOME
ExecStart=/usr/bin/vncserver :$DISPLAY_NUM -geometry 1920x1080 -depth 24 -dpi 96
ExecStop=/usr/bin/vncserver -kill :$DISPLAY_NUM
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 重新加载服务配置并启动
systemctl daemon-reload
systemctl enable vncserver@$DISPLAY_NUM.service
systemctl start vncserver@$DISPLAY_NUM.service

# 开放防火墙端口（如果启用了 ufw）
if command -v ufw &> /dev/null; then
    ufw allow $VNC_PORT/tcp
    ufw reload
fi

# 输出完成信息
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}安装配置完成！${NC}"
echo -e "${GREEN}VNC 连接信息：${NC}"
echo -e "  服务器IP:端口 → $(hostname -I | awk '{print $1}'):$VNC_PORT"
echo -e "  分辨率 → 1920x1080"
echo -e "  密码 → 你刚才设置的密码"
echo ""
echo -e "${YELLOW}常用命令：${NC}"
echo -e "  重启VNC → systemctl restart vncserver@$DISPLAY_NUM.service"
echo -e "  查看状态 → systemctl status vncserver@$DISPLAY_NUM.service"
echo -e "  停止VNC → systemctl stop vncserver@$DISPLAY_NUM.service"
echo -e "${GREEN}=====================================${NC}"
