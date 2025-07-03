#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update && apt -y full-upgrade

# 安装核心组件
apt install -y kali-linux-full xfce4 xfce4-goodies tightvncserver dbus-x11 \
  fonts-noto-cjk fonts-wqy-zenhei locales firefox-esr zsh git curl python3-pip \
  proxychains4 socat keepassxc

# 设置中文
locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8

# 创建 kali 用户
useradd -m -s /usr/bin/zsh kali
echo "kali:kali" | chpasswd
usermod -aG sudo kali

# 配置 VNC
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

# 安装 noVNC
git clone https://github.com/novnc/noVNC.git /opt/noVNC
git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify
cat <<EOF > /opt/noVNC/launch.sh
#!/bin/bash
vncserver -kill :1 > /dev/null 2>&1
vncserver :1 -geometry 1280x800 -depth 24
/opt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 6080
EOF
chmod +x /opt/noVNC/launch.sh

# 配置 systemd 服务
cat <<EOF > /etc/systemd/system/novnc.service
[Unit]
Description=noVNC Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/noVNC/launch.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable novnc
systemctl start novnc

# 配置 oh-my-zsh
sudo -u kali sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo -u kali sed -i 's/plugins=(git)/plugins=(git sudo proxychains4)/' /home/kali/.zshrc
sudo -u kali sed -i 's/ZSH_THEME=.*/ZSH_THEME="agnoster"/' /home/kali/.zshrc

# alias
cat <<EOF >> /home/kali/.zshrc
alias ff="firefox"
alias proxyfire="proxychains4 firefox"
alias socat-shell="socat TCP-LISTEN:4444,reuseaddr,fork EXEC:/bin/bash"
alias msf="msfconsole"
EOF

chown kali:kali /home/kali/.zshrc
