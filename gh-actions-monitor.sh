#!/bin/bash

# GitHub Actions Monitoring Script
# Continuously monitors GitHub Actions workflow runs and reports status changes

# Configuration
REPO="${GH_MONITOR_REPO:-}"  # Repository to monitor (owner/repo format)
POLL_INTERVAL="${GH_MONITOR_INTERVAL:-30}"  # Polling interval in seconds
SHOW_IN_PROGRESS="${GH_MONITOR_SHOW_PROGRESS:-true}"  # Show in-progress runs
SOUND_ALERTS="${GH_MONITOR_SOUND:-false}"  # Enable sound alerts
MAX_RUNS="${GH_MONITOR_MAX_RUNS:-5}"  # Maximum number of runs to display

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# State tracking (using files for compatibility)
STATE_DIR="/tmp/gh-monitor-$$"
mkdir -p "$STATE_DIR"
FIRST_RUN=true

# Statistics
SUCCESS_COUNT=0
FAILURE_COUNT=0
IN_PROGRESS_COUNT=0

# Function to print colored status
print_status() {
    local status=$1
    case $status in
        "completed")
            echo -e "${GREEN}✓ COMPLETED${NC}"
            ;;
        "in_progress")
            echo -e "${YELLOW}⚡ IN PROGRESS${NC}"
            ;;
        "queued")
            echo -e "${BLUE}⏳ QUEUED${NC}"
            ;;
        "failure")
            echo -e "${RED}✗ FAILED${NC}"
            ;;
        "cancelled")
            echo -e "${PURPLE}⊘ CANCELLED${NC}"
            ;;
        "success")
            echo -e "${GREEN}✓ SUCCESS${NC}"
            ;;
        *)
            echo -e "${NC}$status${NC}"
            ;;
    esac
}

# Function to play sound alert
play_alert() {
    local alert_type=$1
    if [ "$SOUND_ALERTS" = "true" ]; then
        case $alert_type in
            "success")
                # Play success sound (macOS)
                [ "$(uname)" = "Darwin" ] && afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
                ;;
            "failure")
                # Play failure sound (macOS)
                [ "$(uname)" = "Darwin" ] && afplay /System/Library/Sounds/Basso.aiff 2>/dev/null &
                ;;
        esac
    fi
}

# Function to format duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Function to get current repository
get_current_repo() {
    if [ -z "$REPO" ]; then
        # Try to get repo from current directory
        if git rev-parse --git-dir > /dev/null 2>&1; then
            local origin_url=$(git config --get remote.origin.url 2>/dev/null)
            if [ -n "$origin_url" ]; then
                # Extract owner/repo from GitHub URL and remove .git suffix
                REPO=$(echo "$origin_url" | sed -E 's|^.*github\.com[/:]([^/]+/[^/]+?)(\.git)?$|\1|' | sed 's/\.git$//')
            fi
        fi
    fi

    if [ -z "$REPO" ]; then
        echo -e "${RED}Error: No repository specified${NC}"
        echo "Set GH_MONITOR_REPO environment variable or run from a Git repository"
        exit 1
    fi
}

# Function to fetch and display workflow runs
monitor_runs() {
    local run_list=$(gh run list --repo "$REPO" --limit "$MAX_RUNS" --json status,conclusion,name,displayTitle,workflowName,startedAt,updatedAt,databaseId,headBranch,event 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error fetching workflow runs${NC}"
        return 1
    fi

    # Clear screen for better visibility
    if [ "$FIRST_RUN" != "true" ]; then
        clear
    fi

    # Print header
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}GitHub Actions Monitor - ${REPO}${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S') | Refresh: ${POLL_INTERVAL}s${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}\n"

    # Reset counters for this iteration
    SUCCESS_COUNT=0
    FAILURE_COUNT=0
    IN_PROGRESS_COUNT=0

    # Process each run
    echo "$run_list" | jq -r '.[] | @json' | while read -r run_json; do
        local run_id=$(echo "$run_json" | jq -r '.databaseId')
        local status=$(echo "$run_json" | jq -r '.status')
        local conclusion=$(echo "$run_json" | jq -r '.conclusion // "pending"')
        local name=$(echo "$run_json" | jq -r '.workflowName')
        local title=$(echo "$run_json" | jq -r '.displayTitle')
        local branch=$(echo "$run_json" | jq -r '.headBranch')
        local event=$(echo "$run_json" | jq -r '.event')
        local started=$(echo "$run_json" | jq -r '.startedAt')

        # Skip in-progress runs if configured
        if [ "$SHOW_IN_PROGRESS" = "false" ] && [ "$status" = "in_progress" ]; then
            continue
        fi

        # Track state changes using files
        local state_file="$STATE_DIR/run_${run_id}"
        local previous_state=""
        if [ -f "$state_file" ]; then
            previous_state=$(cat "$state_file")
        fi
        local current_state="${status}_${conclusion}"
        local state_changed=false

        if [ -n "$previous_state" ] && [ "$previous_state" != "$current_state" ]; then
            state_changed=true
        fi

        echo "$current_state" > "$state_file"

        # Calculate duration
        local duration=""
        if [ "$started" != "null" ]; then
            local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%s" 2>/dev/null || date -d "$started" "+%s" 2>/dev/null)
            local now_epoch=$(date "+%s")
            if [ -n "$start_epoch" ]; then
                local elapsed=$((now_epoch - start_epoch))
                duration=" ($(format_duration $elapsed))"
            fi
        fi

        # Count statuses (write to temp files to avoid subshell issue)
        case "$status" in
            "completed")
                if [ "$conclusion" = "success" ]; then
                    echo "1" >> "$STATE_DIR/success_count"
                elif [ "$conclusion" = "failure" ]; then
                    echo "1" >> "$STATE_DIR/failure_count"
                fi
                ;;
            "in_progress")
                echo "1" >> "$STATE_DIR/progress_count"
                ;;
        esac

        # Display run information
        echo -e "${BOLD}▶ ${name}${NC}"
        echo -e "  📝 ${title}"
        echo -e "  🌿 Branch: ${branch} | 🎯 Event: ${event}"
        echo -n "  📊 Status: "

        if [ "$status" = "completed" ]; then
            print_status "$conclusion"
            echo -n "$duration"

            # Alert on state change
            if [ "$state_changed" = "true" ] && [ "$FIRST_RUN" != "true" ]; then
                if [ "$conclusion" = "success" ]; then
                    echo -e " ${GREEN}[JUST SUCCEEDED]${NC}"
                    play_alert "success"
                elif [ "$conclusion" = "failure" ]; then
                    echo -e " ${RED}[JUST FAILED]${NC}"
                    play_alert "failure"
                else
                    echo ""
                fi
            else
                echo ""
            fi
        else
            print_status "$status"
            echo -n "$duration"
            if [ "$state_changed" = "true" ] && [ "$FIRST_RUN" != "true" ]; then
                echo -e " ${YELLOW}[STATUS CHANGED]${NC}"
            else
                echo ""
            fi
        fi

        echo -e "  🔗 ${CYAN}https://github.com/${REPO}/actions/runs/${run_id}${NC}"
        echo ""
    done

    # Update global statistics from temp files
    SUCCESS_COUNT=$(wc -l < "$STATE_DIR/success_count" 2>/dev/null | tr -d ' ' || echo 0)
    FAILURE_COUNT=$(wc -l < "$STATE_DIR/failure_count" 2>/dev/null | tr -d ' ' || echo 0)
    IN_PROGRESS_COUNT=$(wc -l < "$STATE_DIR/progress_count" 2>/dev/null | tr -d ' ' || echo 0)

    # Clear count files for next iteration
    rm -f "$STATE_DIR/success_count" "$STATE_DIR/failure_count" "$STATE_DIR/progress_count"

    # Print statistics
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Statistics:${NC}"
    echo -e "  ${GREEN}✓ Success: ${SUCCESS_COUNT}${NC} | ${RED}✗ Failed: ${FAILURE_COUNT}${NC} | ${YELLOW}⚡ In Progress: ${IN_PROGRESS_COUNT}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"

    FIRST_RUN=false
}

# Function to handle cleanup
cleanup() {
    echo -e "\n${CYAN}Stopping GitHub Actions Monitor...${NC}"
    # Clean up state directory
    [ -d "$STATE_DIR" ] && rm -rf "$STATE_DIR"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub${NC}"
        echo "Run: gh auth login"
        exit 1
    fi

    # Get repository
    get_current_repo

    echo -e "${CYAN}Starting GitHub Actions Monitor for ${BOLD}${REPO}${NC}"
    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  • Polling interval: ${POLL_INTERVAL} seconds"
    echo -e "  • Show in-progress: ${SHOW_IN_PROGRESS}"
    echo -e "  • Sound alerts: ${SOUND_ALERTS}"
    echo -e "  • Max runs shown: ${MAX_RUNS}"
    echo -e "${CYAN}Press Ctrl+C to stop${NC}\n"

    # Main monitoring loop
    while true; do
        monitor_runs
        sleep "$POLL_INTERVAL"
    done
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "GitHub Actions Monitoring Script"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Environment Variables:"
    echo "  GH_MONITOR_REPO      - Repository to monitor (owner/repo)"
    echo "  GH_MONITOR_INTERVAL  - Polling interval in seconds (default: 30)"
    echo "  GH_MONITOR_SHOW_PROGRESS - Show in-progress runs (default: true)"
    echo "  GH_MONITOR_SOUND     - Enable sound alerts (default: false)"
    echo "  GH_MONITOR_MAX_RUNS  - Maximum number of runs to display (default: 5)"
    echo ""
    echo "Examples:"
    echo "  # Monitor current repository"
    echo "  $0"
    echo ""
    echo "  # Monitor specific repository with options"
    echo "  GH_MONITOR_REPO=owner/repo GH_MONITOR_INTERVAL=10 $0"
    echo ""
    echo "  # Enable sound alerts"
    echo "  GH_MONITOR_SOUND=true $0"
    exit 0
fi

# Run the main function
main