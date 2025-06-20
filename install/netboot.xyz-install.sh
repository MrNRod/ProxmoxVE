#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: [YourUserName]
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL]

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  ca-certificates \
  gnupg \
  lsb-release
msg_ok "Installed Dependencies"

# Installing Docker
msg_info "Installing Docker"
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
msg_ok "Installed Docker"

msg_info "Installing Docker Compose (standalone)"
COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Setting up netboot.xyz"
mkdir -p /opt/netboot.xyz/{config,assets}
cd /opt/netboot.xyz

# Create docker-compose.yml
cat <<EOF > /opt/netboot.xyz/docker-compose.yml
version: "3.8"
services:
  netbootxyz:
    image: netbootxyz/netbootxyz:latest
    container_name: netbootxyz
    environment:
      - MENU_VERSION=1.9.9
      - NGINX_PORT=80
      - WEB_APP_PORT=3000
    volumes:
      - ./config:/config
      - ./assets:/assets
    ports:
      - "3000:3000"
      - "69:69/udp"
      - "80:80"
    restart: unless-stopped
EOF

# Create initial configuration
mkdir -p /opt/netboot.xyz/config/menus
cat <<EOF > /opt/netboot.xyz/config/netboot.xyz.yml
---
# netboot.xyz configuration
boot_domain: "https://boot.netboot.xyz"
boot_version: "1.9.9"
generate_menus: true
web_ui_port: 3000
nginx_port: 80
tftp_port: 69
custom_generate_menus: false
custom_templates_dir: "/config/custom"
bootloader_http_timeout: 30
bootloader_tftp_timeout: 5
generate_signatures: false
EOF

msg_ok "Created netboot.xyz configuration"

msg_info "Starting netboot.xyz"
docker-compose up -d
msg_ok "Started netboot.xyz"

msg_info "Creating update script"
cat <<'EOF' > /usr/local/bin/update-netboot.xyz
#!/bin/bash
cd /opt/netboot.xyz
echo "Stopping netboot.xyz..."
docker-compose down
echo "Pulling latest image..."
docker-compose pull
echo "Starting netboot.xyz..."
docker-compose up -d
echo "Cleaning up old images..."
docker image prune -f
echo "Update complete!"
EOF

chmod +x /usr/local/bin/update-netboot.xyz
msg_ok "Created update script"

msg_info "Setting up systemd service"
cat <<EOF > /etc/systemd/system/netboot.xyz.service
[Unit]
Description=netboot.xyz
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/netboot.xyz
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable netboot.xyz.service
msg_ok "Created systemd service"

msg_info "Waiting for netboot.xyz to start"
sleep 30

# Check if service is running
if docker ps | grep -q netbootxyz; then
    msg_ok "netboot.xyz is running"
else
    msg_error "netboot.xyz failed to start"
fi

# Save version info
RELEASE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep netbootxyz/netbootxyz | head -1 | cut -d':' -f2)
echo "${RELEASE}" > /opt/netboot.xyz_version.txt

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
