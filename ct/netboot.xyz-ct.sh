#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: [YourUserName]
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL]

# App Default Values
# Name of the app (e.g. Google, Adventurelog, Apache-Guacamole"
APP="netboot.xyz"
# Tags for Proxmox VE, maximum 2 pcs., no spaces allowed, separated by a semicolon ; (e.g. database | adblock;dhcp)
var_tags="${var_tags:-pxe;boot}"
# Number of cores (1-X) (e.g. 4) - default are 2
var_cpu="${var_cpu:-2}"
# Amount of used RAM in MB (e.g. 2048 or 4096)
var_ram="${var_ram:-2048}"
# Amount of used disk space in GB (e.g. 4 or 10)
var_disk="${var_disk:-25}"
# Default OS (e.g. debian, ubuntu, alpine)
var_os="${var_os:-alpine}"
# Default OS version (e.g. 12 for debian, 24.04 for ubuntu, 3.20 for alpine)
var_version="${var_version:-3.20}"
# 1 = unprivileged container, 0 = privileged container
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if installation is present | -f for file, -d for folder
  if [[ ! -f /opt/netboot.xyz/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Get current version
  CURRENT_VERSION=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep netbootxyz/netboot.xyz | head -1 | cut -d':' -f2)
  
  # Get latest version from Docker Hub
  RELEASE=$(curl -fsSL "https://registry.hub.docker.com/v2/repositories/netbootxyz/netboot.xyz/tags/" | jq -r '.results[0].name' 2>/dev/null || echo "latest")

  if [[ "${RELEASE}" != "${CURRENT_VERSION}" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    # Stopping Services
    msg_info "Stopping $APP"
    cd /opt/netboot.xyz
    docker-compose down
    msg_ok "Stopped $APP"

    # Creating Backup
    msg_info "Creating Backup"
    tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /opt/netboot.xyz/config /opt/netboot.xyz/assets
    msg_ok "Backup Created"

    # Execute Update
    msg_info "Updating $APP to v${RELEASE}"
    docker-compose pull
    docker-compose up -d
    msg_ok "Updated $APP to v${RELEASE}"

    # Starting Services
    msg_info "Starting $APP"
    systemctl start [SERVICE_NAME]
    msg_ok "Started $APP"

    # Cleaning up
    msg_info "Cleaning Up"
    docker image prune -f
    msg_ok "Cleanup Completed"

    # Last Action
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access the web interface using:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
echo -e "${INFO}${YW} TFTP server is available on:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}tftp://${IP}:69${CL}"
echo -e "${INFO}${YW} Configuration directory:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}/opt/netboot.xyz/config${CL}"
