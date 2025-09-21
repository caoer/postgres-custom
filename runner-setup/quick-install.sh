#!/bin/bash

# Quick GitHub Actions Runner Installation Script
# One-liner installation helper

set -e

# Default GitHub raw content URL
SCRIPT_URL="https://raw.githubusercontent.com/caoer/postgres-custom/main/runner-setup/install-runner.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to get runner token via gh CLI
get_runner_token() {
    local owner=$1
    local repo=$2
    
    if ! command -v gh &> /dev/null; then
        print_message "$RED" "Error: GitHub CLI (gh) is not installed"
        echo "Please install gh first: https://cli.github.com/"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_message "$RED" "Error: Not authenticated with GitHub CLI"
        echo "Please run: gh auth login"
        exit 1
    fi
    
    # Get registration token
    local token=$(gh api "repos/${owner}/${repo}/actions/runners/registration-token" --method POST --jq '.token' 2>/dev/null)
    
    if [ -z "$token" ]; then
        print_message "$RED" "Error: Failed to get runner registration token"
        echo "Make sure you have admin access to ${owner}/${repo}"
        exit 1
    fi
    
    echo "$token"
}

# Parse arguments
GITHUB_OWNER=""
GITHUB_REPO=""
RUNNER_TOKEN=""
RUNNER_NAME=""
AUTO_TOKEN=false

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
        --auto-token)
            AUTO_TOKEN=true
            shift
            ;;
        -h|--help)
            echo "Quick GitHub Actions Runner Installation"
            echo ""
            echo "Usage: $0 -o OWNER -r REPO [-t TOKEN | --auto-token] [-n NAME]"
            echo ""
            echo "Options:"
            echo "  -o, --org OWNER     GitHub repository owner (required)"
            echo "  -r, --repo REPO     GitHub repository name (required)"
            echo "  -t, --token TOKEN   Runner registration token"
            echo "  --auto-token        Automatically get token using gh CLI"
            echo "  -n, --name NAME     Runner name (default: hostname)"
            echo ""
            echo "Examples:"
            echo "  # With manual token:"
            echo "  $0 -o caoer -r postgres-custom -t YOUR_TOKEN"
            echo ""
            echo "  # With automatic token (requires gh CLI):"
            echo "  $0 -o caoer -r postgres-custom --auto-token"
            echo ""
            echo "  # One-liner with curl:"
            echo "  curl -sL https://raw.githubusercontent.com/caoer/postgres-custom/main/runner-setup/quick-install.sh | sudo bash -s -- -o caoer -r postgres-custom --auto-token"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    print_message "$RED" "Error: Missing required parameters"
    echo "Usage: $0 -o OWNER -r REPO [-t TOKEN | --auto-token] [-n NAME]"
    exit 1
fi

# Get token if not provided
if [ -z "$RUNNER_TOKEN" ]; then
    if [ "$AUTO_TOKEN" = true ]; then
        print_message "$YELLOW" "Getting runner registration token..."
        RUNNER_TOKEN=$(get_runner_token "$GITHUB_OWNER" "$GITHUB_REPO")
        print_message "$GREEN" "Token obtained successfully"
    else
        print_message "$RED" "Error: No token provided. Use -t TOKEN or --auto-token"
        exit 1
    fi
fi

# Download and run the main installation script
print_message "$YELLOW" "Downloading installation script..."
curl -sL -o /tmp/install-runner.sh "$SCRIPT_URL"
chmod +x /tmp/install-runner.sh

# Build arguments for main script
ARGS="-o $GITHUB_OWNER -r $GITHUB_REPO -t $RUNNER_TOKEN"
if [ -n "$RUNNER_NAME" ]; then
    ARGS="$ARGS -n $RUNNER_NAME"
fi

print_message "$YELLOW" "Running installation script..."
/tmp/install-runner.sh $ARGS

# Cleanup
rm -f /tmp/install-runner.sh

print_message "$GREEN" "Installation complete!"