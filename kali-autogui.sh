#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[0/8] 更新系统..."
apt update && apt -y full-upgrade

echo "[1/8] 安装核心组件..."
apt install -y kali-linux-full xfce4 xfce4-goodies tightvncserver dbus-x11 \
  fonts-noto-cjk fonts-wqy-zenhei locales firefox-esr zsh git curl python3-pip \
  proxychains4 socat keepassxc

echo "[2/8] 配置中文语言..."
locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8

echo "[3/8] 创建 kali 用户..."
id -u kali &>/dev/null || useradd -m -s /usr/bin/zsh kali
echo "kali:kali" | chpasswd
usermod -aG sudo kali

echo "[4/8] 配置 VNC..."
sudo -u kali mkdir -p /home/kali/.vnc
echo "kali" | sudo -u kali vncpasswd -f > /home/kali/.vnc/passwd
chmod 600 /home/kali/.vnc/passwd

cat <<EOF > /home/kali/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x /home/kali/.vnc/xstartup
chown -R kali:kali /home/kali/.vnc

echo "[5/8] 启动 VNC 桌面..."
sudo -u kali vncserver :1 -geometry 1280x800 -depth 24

echo "[6/8] 安装 noVNC..."
git clone https://github.com/novnc/noVNC.git /opt/noVNC
git clone https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify

cat <<EOF > /opt/noVNC/launch.sh
#!/bin/bash
vncserver -kill :1 > /dev/null 2>&1
vncserver :1 -geometry 1280x800 -depth 24
/opt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 6080
EOF
chmod +x /opt/noVNC/launch.sh

echo "[7/8] 配置 systemd 启动 noVNC..."
cat <<EOF > /etc/systemd/system/novnc.service
[Unit]
Description=noVNC Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/noVNC/launch.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reexec
systemctl enable novnc
systemctl start novnc

echo "[8/8] 设置 zsh 和 alias..."
sudo -u kali sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo -u kali sed -i 's/plugins=(git)/plugins=(git sudo proxychains4)/' /home/kali/.zshrc
sudo -u kali sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/' /home/kali/.zshrc
cat <<EOF >> /home/kali/.zshrc

alias ff="firefox"
alias proxyfire="proxychains4 firefox"
alias socat-shell="socat TCP-LISTEN:4444,reuseaddr,fork EXEC:/bin/bash"
alias msf="msfconsole"
EOF
chown kali:kali /home/kali/.zshrc

echo "✅ 部署完成：GUI+VNC+noVNC+中文+渗透工具已安装。"
echo "🔐 用户: kali / kali"
echo "🖥 VNC    : <外部.IP>:5901"
echo "🌐 浏览器: http://<外部.IP>:6080/vnc.html"
