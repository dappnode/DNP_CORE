#!/bin/bash

# Set environment variables to avoid interactive prompts
export DEBIAN_FRONTEND=noninteractive
DOCKER_DOWNLOAD_ORIGINS="Docker:\${distro_codename}"
UNATTENDED_UPGRADES_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
LOG_FILE="/usr/src/dappnode/logs/upgrade_014.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a ${LOG_FILE}
}

add_docker_to_unattended_upgrades() {
    # Add docker to unattended-upgrades
    log "Add docker to unattended-upgrades"
    
    # Check that the UNATTENDED_upgrades_file exists if so, check that the file does not already contain the DOCKER_DOWNLOAD_ORIGINS, if not then modify it to include in the section Unattended-Upgrade::Allowed-Origins the docker download origins
    if ! grep -q "${DOCKER_DOWNLOAD_ORIGINS}" "${UNATTENDED_UPGRADES_FILE}"; then
        log "Add docker download origins to unattended-upgrades"
        sed -i "/Unattended-Upgrade::Allowed-Origins {/a \"${DOCKER_DOWNLOAD_ORIGINS}\";" "${UNATTENDED_UPGRADES_FILE}" 2>&1 | tee -a ${LOG_FILE}
    fi
}

log "Starting docker install migration from pkg to apt"

# Only update docker if unattended upgrades is enabled,
# otherwise the update might crash due to updating docker from docker.
if [ ! -f "${UNATTENDED_UPGRADES_FILE}" ]; then
  log "WARNING: Unattended upgrades is not enabled, skipping upgrade"
  exit 0
fi

# Check if docker is installed via apt
# The docker.list file is created by the docker installation script
if [ -f /etc/apt/sources.list.d/docker.list ]; then
  log "Docker is already installed via apt, skipping upgrade"
  add_docker_to_unattended_upgrades
  exit 0
fi

# Get docker version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')

# Check the OS
if [ -f /etc/os-release ]; then
  source /etc/os-release
  OS=$NAME
  VERSION=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
  OS=$(lsb_release -si)
  VERSION=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
  source /etc/lsb-release
  OS=$DISTRIB_ID
  VERSION=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
  OS=Debian
  VERSION=$(cat /etc/debian_version)
else
  OS=$(uname -s)
  VERSION=$(uname -r)
fi

if echo "$OS" | grep -Ei "(Debian)" >/dev/null 2>&1; then
  DOWNLOAD_GPG_URL="https://download.docker.com/linux/debian/gpg"
  DOWNLOAD_REPO_URL="https://download.docker.com/linux/debian"
elif echo "$OS" | grep -Ei "(Ubuntu)" >/dev/null 2>&1; then
  DOWNLOAD_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
  DOWNLOAD_REPO_URL="https://download.docker.com/linux/ubuntu"
elif echo "$OS" | grep -Ei "(Raspbian)" >/dev/null 2>&1; then
  DOWNLOAD_GPG_URL="https://download.docker.com/linux/raspbian/gpg"
  DOWNLOAD_REPO_URL="https://download.docker.com/linux/raspbian"
else
  log "OS $OS is not supported, skipping upgrade"
  exit 0
fi

# Print OS and version for the migration
log "OS: $OS ; Version: $VERSION ; Docker version: $DOCKER_VERSION"

# Remove legacy docker packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  log "Removing $pkg"
  apt-get remove $pkg 2>&1 | tee -a ${LOG_FILE}
done

# Set up the repository
log "Set up the repository"
# 1. Update the apt package index and install packages to allow apt to use a repository over HTTPS
log "Update the apt packages"
apt-get update 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to update"
  exit 1
fi
log "Install ca-certificates curl and gnupg"
apt-get install -y ca-certificates curl gnupg 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to install ca-certofocates curl and gnupg."
  exit 1
fi
# 2. Add Docker's official GPG key
log "Add Docker's official GPG key"
install -m 0755 -d /etc/apt/keyrings 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to create /etc/apt/keyrings directory."
  exit 1
fi
log "Download and install docker gpg key"
curl -fL "${DOWNLOAD_GPG_URL}" |
  gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to download and install docker gpg key."
  exit 1
fi
log "Change permissions for docker gpg key"
chmod a+r /etc/apt/keyrings/docker.gpg 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to change permissions for docker gpg key."
  exit 1
fi
# 3. Use the following command to set up the repository
log "Add docker repository"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOWNLOAD_REPO_URL} \
  $(source /etc/os-release && echo "$VERSION_CODENAME") stable" 2>&1 |
  tee /etc/apt/sources.list.d/docker.list >/dev/null
if [ $? -ne 0 ]; then
  log "Failed to add docker repository."
  exit 1
fi

# 1. Update the apt package index:
log "Update the apt packages again"
apt-get update 2>&1 | tee -a ${LOG_FILE}
if [ $? -ne 0 ]; then
  log "Failed to update"
  exit 1
fi
# IMPORTANT: This step MUST be skipped so unattended-upgrades will upgrade docker later on
# 2. Install Docker Engine, containerd, and Docker Compose.
#log "Install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
#apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y 2>&1 | tee -a ${LOG_FILE}
#if [ $? -ne 0 ]; then
#  log "Failed to install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin."
#  exit 1
#fi
# 3. Verify that the Docker Engine installation is successful by running the hello-world image.
#docker run --rm hello-world && docker rmi hello-world

# Add docker to unattended-upgrades
add_docker_to_unattended_upgrades

# Add docker-compose alias of docker compose to the dappnode profile if is not already there and if docker compose is installed
if [ -x "$(command -v docker-compose)" ]; then
  if ! grep -q "alias docker-compose='docker compose'" /usr/src/dappnode/DNCORE/.dappnode_profile; then
    log "Adding docker-compose alias to the dappnode profile"
    echo "alias docker-compose='docker compose'" >>/usr/src/dappnode/DNCORE/.dappnode_profile
    source /usr/src/dappnode/DNCORE/.dappnode_profile | tee -a ${LOG_FILE}
    if [ $? -ne 0 ]; then
      log "Failed to source dappnode profile."
      exit 1
    fi
    # TODO: consider removing old docker-compose binary
  fi
fi

# Remove legacy docker download path /usr/src/dappnode/bin/docker/ if exists
if [ -d /usr/src/dappnode/bin/docker/ ]; then
  log "Removing legacy docker download path /usr/src/dappnode/bin/docker/"
  rm -rf /usr/src/dappnode/bin/docker/
fi

exit 0
