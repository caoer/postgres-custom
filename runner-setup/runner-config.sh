#!/bin/bash

# GitHub Actions Runner Configuration File
# Edit this file to customize your runner installation

# GitHub Repository Settings
export GITHUB_OWNER="caoer"
export GITHUB_REPO="postgres-custom"

# Runner Configuration
export RUNNER_NAME="vphosting-16g"           # Name of the runner (default: hostname)
export RUNNER_LABELS="self-hosted,Linux,X64"  # Comma-separated labels
export RUNNER_USER="runner"                   # System user to run the runner
export RUNNER_VERSION="2.321.0"               # GitHub Actions Runner version

# Advanced Settings (usually don't need to change)
export RUNNER_HOME="/home/${RUNNER_USER}"
export RUNNER_DIR="${RUNNER_HOME}/actions-runner"
export RUNNER_WORK_DIR="${RUNNER_DIR}/_work"

# Service Configuration
export SERVICE_NAME="actions.runner.${GITHUB_OWNER}-${GITHUB_REPO}.${RUNNER_NAME}"
export SERVICE_DESCRIPTION="GitHub Actions Runner for ${GITHUB_OWNER}/${GITHUB_REPO}"

# Installation Behavior
export REPLACE_EXISTING=true    # Replace existing runner with same name
export START_IMMEDIATELY=true   # Start the runner service after installation
export INSTALL_AS_SERVICE=true  # Install as systemd service

# Security Settings
export ALLOW_RUNASROOT=false    # Allow runner to run as root (not recommended)
export DISABLE_UPDATE=false     # Disable automatic runner updates

# Network Settings (for proxy environments)
export HTTP_PROXY=""
export HTTPS_PROXY=""
export NO_PROXY=""

# Logging
export ENABLE_DEBUG_LOGGING=false
export LOG_DIR="${RUNNER_DIR}/_diag"

# Function to load custom configuration
load_custom_config() {
    local custom_config="$1"
    if [ -f "$custom_config" ]; then
        echo "Loading custom configuration from: $custom_config"
        source "$custom_config"
    fi
}

# Export all variables for use in other scripts
export -f load_custom_config