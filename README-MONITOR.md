# GitHub Actions Monitor Script

A real-time monitoring script for GitHub Actions workflows that provides continuous status updates with color-coded output and optional sound alerts.

## Features

- 🔄 **Continuous Monitoring** - Polls GitHub Actions at configurable intervals
- 🎨 **Color-Coded Status** - Visual indicators for success, failure, in-progress
- 🔔 **Sound Alerts** - Optional audio notifications on status changes (macOS)
- 📊 **Statistics** - Real-time count of successful, failed, and in-progress runs
- 🔍 **Auto-Detection** - Automatically detects repository from current directory
- 📝 **State Tracking** - Notifies when workflow status changes

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- `jq` for JSON processing
- Bash shell

## Installation

1. Make the script executable:
```bash
chmod +x gh-actions-monitor.sh
```

2. Verify GitHub CLI is authenticated:
```bash
gh auth status
```

## Usage

### Basic Usage

Run from any Git repository:
```bash
./gh-actions-monitor.sh
```

### Configuration Options

Configure via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `GH_MONITOR_REPO` | auto-detect | Repository to monitor (owner/repo) |
| `GH_MONITOR_INTERVAL` | 30 | Polling interval in seconds |
| `GH_MONITOR_SHOW_PROGRESS` | true | Show in-progress workflows |
| `GH_MONITOR_SOUND` | false | Enable sound alerts on status changes |
| `GH_MONITOR_MAX_RUNS` | 5 | Maximum number of runs to display |

### Examples

Monitor with 10-second intervals and sound alerts:
```bash
GH_MONITOR_INTERVAL=10 GH_MONITOR_SOUND=true ./gh-actions-monitor.sh
```

Monitor a specific repository:
```bash
GH_MONITOR_REPO=owner/repo ./gh-actions-monitor.sh
```

Show only the 3 most recent runs:
```bash
GH_MONITOR_MAX_RUNS=3 ./gh-actions-monitor.sh
```

### Running in Background

Run continuously with nohup:
```bash
nohup GH_MONITOR_INTERVAL=60 ./gh-actions-monitor.sh > monitor.log 2>&1 &
```

Or use screen/tmux:
```bash
screen -S gh-monitor
./gh-actions-monitor.sh
# Detach with Ctrl-A, D
```

## Output Format

The monitor displays:
- Workflow name and commit message
- Branch and trigger event
- Status with color coding:
  - ✓ SUCCESS (green)
  - ✗ FAILED (red)
  - ⚡ IN PROGRESS (yellow)
  - ⏳ QUEUED (blue)
  - ⊘ CANCELLED (purple)
- Duration of completed runs
- Direct link to workflow run
- Statistics summary

## Status Change Alerts

When a workflow status changes:
- Visual indicator: `[JUST SUCCEEDED]` or `[JUST FAILED]`
- Optional sound alert (macOS only)
- State tracking persists between polling cycles

## Troubleshooting

If you see "Error: Not authenticated with GitHub":
```bash
gh auth login
```

If repository auto-detection fails:
```bash
# Explicitly set the repository
export GH_MONITOR_REPO=owner/repo
./gh-actions-monitor.sh
```

## Stopping the Monitor

Press `Ctrl+C` to gracefully stop the monitor.

## License

This script is provided as-is for monitoring GitHub Actions workflows.