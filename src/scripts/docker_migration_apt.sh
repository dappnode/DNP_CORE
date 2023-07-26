#!/bin/bash

# Upgrade from 0.2.76 to 0.2.77

# Switch docker installtion method to use apt official repository
# OS supported: Ubuntu, Debian, Raspbian
# TODO: check if its needed to execute the script docker installed through pkg or apt
# TODO: rollback docker? /var/lib/docker
# TODO: research if previous removal is needed
# TODO: implement `systemctl restart docker` if docker was installed but not started

# log function with argument string to print to the log file /usr/src/dappnode/logs/upgrade_013.log. print with date in beautifull format
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a /usr/src/dappnode/logs/upgrade_013.log
}

# Set environment variables to avoid interactive prompts
export DEBIAN_FRONTEND=noninteractive

log "Starting docker migration to apt repository"

# TODO: Check if docker is installed via package manager

# Get docker version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')

# array of legacy docker versions installed in dappnode

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

# TODO: research Backup docker data
#log "Backup docker data"
#cp -r /var/lib/docker /var/lib/docker.bak

# TODO: research Remove old docker installation
# TODO: consider checking in cache policy that the packages to be installed from the repository exist
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  apt-get remove $pkg
done

# Set up the repository
log "Set up the repository"
# 1. Update the apt package index and install packages to allow apt to use a repository over HTTPS
apt-get update | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to update"
  exit 1
fi
apt-get install -y ca-certificates curl gnupg | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to install ca-certofocates curl and gnupg."
  exit 1
fi
# 2. Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to create /etc/apt/keyrings directory."
  exit 1
fi
curl -fsSL "${DOWNLOAD_GPG_URL}" |
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to download and install docker gpg key."
  exit 1
fi
chmod a+r /etc/apt/keyrings/docker.gpg | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to change permissions for docker gpg key."
  exit 1
fi
# 3. Use the following command to set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOWNLOAD_REPO_URL} \
  $(source /etc/os-release && echo "$VERSION_CODENAME") stable" |
  tee /etc/apt/sources.list.d/docker.list >/dev/null
if [ $? -ne 0 ]; then
  log "Failed to add docker repository."
  exit 1
fi

# Install Docker Engine
log "Install Docker Engine"
# 1. Update the apt package index:
apt-get update | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to update"
  exit 1
fi
# 2. Install Docker Engine, containerd, and Docker Compose.
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y | tee -a /usr/src/dappnode/logs/upgrade_013.log
if [ $? -ne 0 ]; then
  log "Failed to install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin."
  exit 1
fi
# 3. Verify that the Docker Engine installation is successful by running the hello-world image.
#docker run --rm hello-world && docker rmi hello-world

# Add docker-compose alias of docker compose to the dappnode profile if is not already there and if docker compose is installed
if [ -x "$(command -v docker-compose)" ]; then
  if ! grep -q "alias docker-compose='docker compose'" /usr/src/dappnode/DNCORE/.dappnode_profile; then
    log "Adding docker-compose alias to the dappnode profile"
    echo "alias docker-compose='docker compose'" >>/usr/src/dappnode/DNCORE/.dappnode_profile
    source /usr/src/dappnode/DNCORE/.dappnode_profile | tee -a /usr/src/dappnode/logs/upgrade_013.log
    if [ $? -ne 0 ]; then
      log "Failed to source dappnode profile."
      exit 1
    fi
    # TODO: consider removing old docker-compose binary
  fi
fi
