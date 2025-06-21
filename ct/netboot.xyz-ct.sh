#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/MrNRod/ProxmoxVE/MrNRod-Scripts/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MrNRod
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://netboot.xyz/

APP="netboot.xyz"
var_tags="${var_tags:-pxe;boot}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-25}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/netboot.xyz/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  LATEST_PUSH=$(curl -fsSL "https://registry.hub.docker.com/v2/repositories/netbootxyz/netbootxyz/tags/" | jq -r '.results[] | select(.name=="latest") | .last_pushed' 2>/dev/null)
  CURRENT_IMAGE_DATE=$(docker inspect netbootxyz/netbootxyz:latest --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
  LATEST_PUSH_DATE=$(echo "$LATEST_PUSH" | cut -d'T' -f1)

  if [[ "$LATEST_PUSH_DATE" != "$CURRENT_IMAGE_DATE" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    msg_info "Stopping $APP"
    cd /opt/netboot.xyz
    docker-compose down
    msg_ok "Stopped $APP"

    msg_info "Creating Backup"
    tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /opt/netboot.xyz/config /opt/netboot.xyz/assets
    msg_ok "Backup Created"

    msg_info "Updating $APP (pushed: $LATEST_PUSH_DATE)"
    docker-compose pull
    docker-compose up -d
    msg_ok "Updated $APP"

    msg_info "Cleaning Up"
    docker image prune -f
    msg_ok "Cleanup Completed"

    echo "$LATEST_PUSH_DATE" > /opt/${APP}_version.txt
    msg_ok "Update Successful"
  else
    msg_ok "No update required. Image is current (pushed: $LATEST_PUSH_DATE)"
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
echo -e "${INFO}${YW} Boot assets available at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
echo -e "${INFO}${YW} Configuration directory:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}/opt/netboot.xyz/config${CL}"
