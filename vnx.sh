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

# 3. 交互式配置 VNC 端口和密码（增加严格校验）
echo -e "${YELLOW}[3/5] 开始配置 VNC 端口和密码...${NC}"

# 端口校验（限制 5901-5910）
while true; do
    read -p "请输入 VNC 端口（默认 5901，仅支持 5901-5910 之间）：" VNC_PORT
    VNC_PORT=${VNC_PORT:-5901}
    # 校验端口范围
    if [[ $VNC_PORT -ge 5901 && $VNC_PORT -le 5910 ]]; then
        break
    else
        echo -e "${RED}错误：端口必须在 5901-5910 之间，请重新输入！${NC}"
    fi
done
# 计算 display 号
DISPLAY_NUM=$((VNC_PORT - 5900))

# VNC 普通密码校验（6-8 位）
while true; do
    echo -e "\n请设置 VNC 连接密码（必须 6-8 位）："
    read -s -p "密码：" PASSWORD1
    echo
    read -s -p "确认密码：" PASSWORD2
    echo
    # 校验密码长度和一致性
    if [ ${#PASSWORD1} -lt 6 ] || [ ${#PASSWORD1} -gt 8 ]; then
        echo -e "${RED}错误：密码长度必须是 6-8 位！${NC}"
    elif [ "$PASSWORD1" != "$PASSWORD2" ]; then
        echo -e "${RED}错误：两次输入的密码不一致！${NC}"
    else
        break
    fi
done

# 只读密码校验（可选，同样 6-8 位）
while true; do
    read -p "是否设置只读密码（y/n，建议 n）：" READ_ONLY_CHOICE
    READ_ONLY_CHOICE=${READ_ONLY_CHOICE:-n}
    if [[ $READ_ONLY_CHOICE == "y" || $READ_ONLY_CHOICE == "Y" ]]; then
        read -s -p "只读密码：" RO_PASSWORD1
        echo
        read -s -p "确认只读密码：" RO_PASSWORD2
        echo
        if [ ${#RO_PASSWORD1} -lt 6 ] || [ ${#RO_PASSWORD1} -gt 8 ]; then
            echo -e "${RED}错误：只读密码长度必须是 6-8 位！${NC}"
        elif [ "$RO_PASSWORD1" != "$RO_PASSWORD2" ]; then
            echo -e "${RED}错误：两次输入的只读密码不一致！${NC}"
        else
            # 写入密码到 passwd 文件（避免交互崩溃）
            echo -e "$PASSWORD1\n$RO_PASSWORD1\nn" | su - ${SUDO_USER:-root} -c "vncpasswd -f > $VNC_DIR/passwd"
            break
        fi
    elif [[ $READ_ONLY_CHOICE == "n" || $READ_ONLY_CHOICE == "N" ]]; then
        # 仅设置普通密码
        echo -e "$PASSWORD1\n$PASSWORD1\nn" | su - ${SUDO_USER:-root} -c "vncpasswd -f > $VNC_DIR/passwd"
        break
    else
        echo -e "${RED}错误：请输入 y 或 n！${NC}"
    fi
done

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
echo -e "  普通密码 → 你刚才设置的密码"
echo -e "  只读密码 → $(if [ $READ_ONLY_CHOICE == "y" ]; then echo "已设置"; else echo "未设置"; fi)"
echo ""
echo -e "${YELLOW}常用命令：${NC}"
echo -e "  重启VNC → systemctl restart vncserver@$DISPLAY_NUM.service"
echo -e "  查看状态 → systemctl status vncserver@$DISPLAY_NUM.service"
echo -e "  停止VNC → systemctl stop vncserver@$DISPLAY_NUM.service"
echo -e "${GREEN}=====================================${NC}"
