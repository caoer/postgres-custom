# GitHub Actions Self-Hosted Runner Setup

This directory contains scripts to easily set up GitHub Actions self-hosted runners on Linux servers.

## Quick Start (One-Liner)

### Option 1: With automatic token generation (requires `gh` CLI)
```bash
curl -sL https://raw.githubusercontent.com/caoer/postgres-custom/main/runner-setup/quick-install.sh | \
  sudo bash -s -- -o caoer -r postgres-custom --auto-token -n my-runner
```

### Option 2: With manual token
First, get a runner registration token from GitHub:
```bash
# Using gh CLI:
gh api repos/caoer/postgres-custom/actions/runners/registration-token --method POST --jq '.token'

# Or get it from GitHub UI:
# Go to Settings > Actions > Runners > New self-hosted runner
```

Then run:
```bash
curl -sL https://raw.githubusercontent.com/caoer/postgres-custom/main/runner-setup/quick-install.sh | \
  sudo bash -s -- -o caoer -r postgres-custom -t YOUR_TOKEN -n my-runner
```

### Option 3: With sudo access (for internal use)
For internal deployments where the runner needs administrative privileges:
```bash
curl -sL https://raw.githubusercontent.com/caoer/postgres-custom/main/runner-setup/quick-install.sh | \
  sudo bash -s -- -o caoer -r postgres-custom --auto-token -n my-runner -s
```
**⚠️ Warning:** Enabling sudo access grants the runner user passwordless administrative privileges. Only use this for trusted internal deployments.

## Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/caoer/postgres-custom.git
cd postgres-custom/runner-setup
```

2. Get a runner registration token:
```bash
gh api repos/caoer/postgres-custom/actions/runners/registration-token --method POST --jq '.token'
```

3. Run the installation script:
```bash
sudo ./install-runner.sh -o caoer -r postgres-custom -t YOUR_TOKEN -n my-runner
```

## Files in this Directory

- **`install-runner.sh`** - Main installation script with all setup logic
- **`quick-install.sh`** - Helper script for one-liner installation
- **`runner-config.sh`** - Configuration file template for customization
- **`README.md`** - This documentation file

## Script Options

### install-runner.sh Options

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --org OWNER` | GitHub repository owner | Required |
| `-r, --repo REPO` | GitHub repository name | Required |
| `-t, --token TOKEN` | Runner registration token | Required |
| `-n, --name NAME` | Runner name | hostname |
| `-l, --labels LABELS` | Runner labels | self-hosted,Linux,X64 |
| `-u, --user USER` | System user for runner | runner |
| `-v, --version VERSION` | Runner version | 2.321.0 |
| `-s, --sudo` | Enable sudo access for runner user | false |
| `-h, --help` | Show help message | - |

### quick-install.sh Options

| Option | Description |
|--------|-------------|
| `-o, --org OWNER` | GitHub repository owner |
| `-r, --repo REPO` | GitHub repository name |
| `-t, --token TOKEN` | Runner registration token |
| `--auto-token` | Automatically get token using gh CLI |
| `-n, --name NAME` | Runner name |
| `-s, --sudo` | Enable sudo access for runner user |
| `-h, --help` | Show help message |

## Requirements

- **Operating System**: Linux (Debian/Ubuntu recommended)
- **Privileges**: Root access (for creating users and systemd services)
- **Dependencies**: curl, tar, gzip (automatically installed)
- **GitHub CLI** (optional): For automatic token generation

## What the Script Does

1. **Creates a dedicated user** for running the GitHub Actions runner
2. **Optionally grants sudo access** to the runner user (when -s flag is used)
3. **Downloads** the specified version of GitHub Actions runner
4. **Configures** the runner with your repository
5. **Installs** it as a systemd service
6. **Starts** the service automatically
7. **Verifies** the installation

## Managing the Runner

After installation, you can manage the runner using these commands:

### Check Status
```bash
sudo systemctl status actions.runner.caoer-postgres-custom.my-runner
```

### Stop Runner
```bash
cd /home/runner/actions-runner
sudo ./svc.sh stop
```

### Start Runner
```bash
cd /home/runner/actions-runner
sudo ./svc.sh start
```

### View Logs
```bash
journalctl -u actions.runner.caoer-postgres-custom.my-runner -f
```

### Uninstall Runner
```bash
cd /home/runner/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall
sudo -u runner ./config.sh remove --token YOUR_TOKEN
```

## Using the Runner in Workflows

To use your self-hosted runner in GitHub Actions workflows, specify it in the `runs-on` field:

```yaml
name: My Workflow
on: [push]

jobs:
  build:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v4
      - name: Run build
        run: |
          echo "Running on self-hosted runner"
```

## Troubleshooting

### Runner not starting
- Check the service status: `sudo systemctl status actions.runner.*`
- View logs: `journalctl -u actions.runner.* -n 50`
- Ensure the token hasn't expired (tokens expire after 1 hour)

### Permission issues
- Make sure you're running the installation script as root
- Check that the runner user has proper permissions

### Network issues
- Ensure the server can reach github.com
- Check firewall settings
- If using a proxy, set the proxy environment variables in runner-config.sh

## Security Considerations

- **Never run the runner as root** in production
- **Use dedicated runners** for sensitive repositories
- **Regularly update** the runner software
- **Monitor runner activity** through GitHub's UI
- **Limit network access** where possible
- **Sudo access warning**: The `-s` flag grants passwordless sudo access to the runner user. This is convenient for internal use but should **never** be used for:
  - Public repositories
  - Untrusted code
  - Production environments with sensitive data
  - Multi-tenant environments

## Advanced Configuration

For advanced configuration, edit `runner-config.sh` before running the installation:

```bash
# Copy and edit the configuration
cp runner-config.sh my-config.sh
nano my-config.sh

# Source it before installation
source my-config.sh
./install-runner.sh -o $GITHUB_OWNER -r $GITHUB_REPO -t YOUR_TOKEN
```

## Support

For issues or questions:
- Check the [GitHub Actions documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- Open an issue in this repository
- Check runner logs for detailed error messages