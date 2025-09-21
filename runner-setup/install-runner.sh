#!/bin/bash

# GitHub Actions Self-Hosted Runner Installation Script
# This script automates the setup of a GitHub Actions runner on a Linux server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
RUNNER_VERSION="2.321.0"
RUNNER_USER="runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -o, --org OWNER        GitHub repository owner (required)"
    echo "  -r, --repo REPO        GitHub repository name (required)"
    echo "  -t, --token TOKEN      GitHub runner registration token (required)"
    echo "  -n, --name NAME        Runner name (default: hostname)"
    echo "  -l, --labels LABELS    Runner labels (default: self-hosted,Linux,X64)"
    echo "  -u, --user USER        Runner user (default: runner)"
    echo "  -v, --version VERSION  Runner version (default: 2.321.0)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -o caoer -r postgres-custom -t YOUR_TOKEN -n vphosting-16g"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--org)
            GITHUB_OWNER="$2"
            shift 2
            ;;
        -r|--repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -t|--token)
            RUNNER_TOKEN="$2"
            shift 2
            ;;
        -n|--name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        -l|--labels)
            RUNNER_LABELS="$2"
            shift 2
            ;;
        -u|--user)
            RUNNER_USER="$2"
            RUNNER_HOME="/home/${RUNNER_USER}"
            RUNNER_DIR="${RUNNER_HOME}/actions-runner"
            shift 2
            ;;
        -v|--version)
            RUNNER_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Set defaults if not provided
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,Linux,X64"}

# Validate required parameters
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ] || [ -z "$RUNNER_TOKEN" ]; then
    print_message "$RED" "Error: Missing required parameters"
    print_usage
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "$RED" "Error: This script must be run as root"
    exit 1
fi

print_message "$GREEN" "=========================================="
print_message "$GREEN" "GitHub Actions Runner Installation Script"
print_message "$GREEN" "=========================================="
echo ""
print_message "$YELLOW" "Configuration:"
echo "  Repository: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "  Runner Name: ${RUNNER_NAME}"
echo "  Runner Labels: ${RUNNER_LABELS}"
echo "  Runner User: ${RUNNER_USER}"
echo "  Runner Version: ${RUNNER_VERSION}"
echo ""

# Step 1: Create runner user
print_message "$YELLOW" "Step 1: Creating runner user..."
if id "$RUNNER_USER" &>/dev/null; then
    print_message "$GREEN" "  User ${RUNNER_USER} already exists"
else
    useradd -m -s /bin/bash "$RUNNER_USER"
    print_message "$GREEN" "  User ${RUNNER_USER} created"
fi

# Step 2: Install dependencies
print_message "$YELLOW" "Step 2: Installing dependencies..."
apt-get update -qq
apt-get install -qq -y curl tar gzip sudo > /dev/null 2>&1
print_message "$GREEN" "  Dependencies installed"

# Step 3: Download and extract runner
print_message "$YELLOW" "Step 3: Downloading GitHub Actions Runner v${RUNNER_VERSION}..."
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" ]; then
    curl -sL -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    print_message "$GREEN" "  Runner downloaded"
else
    print_message "$GREEN" "  Runner already downloaded"
fi

print_message "$YELLOW" "Step 4: Extracting runner..."
tar xzf "./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"
print_message "$GREEN" "  Runner extracted"

# Step 5: Configure runner
print_message "$YELLOW" "Step 5: Configuring runner..."
REPO_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"

# Remove any existing runner with same name
su - "$RUNNER_USER" -c "cd $RUNNER_DIR && ./config.sh remove --token $RUNNER_TOKEN 2>/dev/null || true"

# Configure the runner
su - "$RUNNER_USER" -c "cd $RUNNER_DIR && ./config.sh \
    --url $REPO_URL \
    --token $RUNNER_TOKEN \
    --name $RUNNER_NAME \
    --labels $RUNNER_LABELS \
    --unattended \
    --replace"

print_message "$GREEN" "  Runner configured"

# Step 6: Install and start service
print_message "$YELLOW" "Step 6: Installing runner as service..."
cd "$RUNNER_DIR"
./svc.sh install "$RUNNER_USER"
print_message "$GREEN" "  Service installed"

print_message "$YELLOW" "Step 7: Starting runner service..."
./svc.sh start
sleep 2
print_message "$GREEN" "  Service started"

# Step 8: Check status
print_message "$YELLOW" "Step 8: Checking runner status..."
if ./svc.sh status | grep -q "active (running)"; then
    print_message "$GREEN" "  Runner is active and running!"
else
    print_message "$RED" "  Warning: Runner may not be running properly"
    ./svc.sh status
fi

# Print summary
echo ""
print_message "$GREEN" "=========================================="
print_message "$GREEN" "Installation Complete!"
print_message "$GREEN" "=========================================="
echo ""
echo "Runner Details:"
echo "  Name: ${RUNNER_NAME}"
echo "  User: ${RUNNER_USER}"
echo "  Directory: ${RUNNER_DIR}"
echo "  Service: actions.runner.${GITHUB_OWNER}-${GITHUB_REPO}.${RUNNER_NAME}"
echo ""
echo "Useful commands:"
echo "  Check status:  cd ${RUNNER_DIR} && sudo ./svc.sh status"
echo "  Stop runner:   cd ${RUNNER_DIR} && sudo ./svc.sh stop"
echo "  Start runner:  cd ${RUNNER_DIR} && sudo ./svc.sh start"
echo "  View logs:     journalctl -u actions.runner.${GITHUB_OWNER}-${GITHUB_REPO}.${RUNNER_NAME} -f"
echo ""
print_message "$GREEN" "Runner is ready to accept jobs!"