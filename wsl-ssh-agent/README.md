# WSL SSH Agent Bridge

A Claude Code plugin that bridges the Windows SSH agent to WSL, enabling SSH, SCP, and Git operations from WSL using keys managed on the Windows side.

## Features

- **Works with any Windows SSH agent**: 1Password, native Windows OpenSSH agent, or other implementations
- **Automatic setup**: Installs and configures everything on first run
- **Persistent configuration**: Works in all terminal sessions, not just Claude Code
- **Non-intrusive**: Stores binaries in your Windows user home (`~/.bin/`)
- **Silent operation**: Only notifies when action is needed

## What It Does

1. **Validates WSL environment**: Checks interop is enabled and Windows drives are mounted
2. **Installs npiperelay.exe**: Copies the relay binary to your Windows home directory
3. **Configures shell**: Adds bridge script to `~/.bashrc` for automatic activation
4. **Starts the bridge**: Creates a Unix socket that forwards to the Windows SSH agent

## Prerequisites

- **WSL2** with interop enabled (default)
- **socat**: Install with `sudo apt install socat`
- **Windows SSH agent** running (1Password with SSH agent enabled, or Windows OpenSSH Agent service)

## How It Works

The plugin uses [npiperelay](https://github.com/jstarks/npiperelay) to bridge between Windows named pipes and Unix sockets. When you run SSH, SCP, or Git commands in WSL, they communicate through a Unix socket that `socat` relays to the Windows SSH agent via `npiperelay.exe`.

```
WSL SSH/Git → Unix Socket → socat → npiperelay.exe → Windows Named Pipe → SSH Agent
```

## Files Created

- `$WIN_HOME/.bin/npiperelay.exe` - The relay binary (in your Windows user folder)
- `~/.ssh/agent-bridge.sh` - Bridge startup script
- `~/.bashrc` modification - Sources the bridge script

## Troubleshooting

### "Conflicting SSH_AUTH_SOCK detected"

You have an existing SSH agent configuration. Remove the old `SSH_AUTH_SOCK` export from your `~/.bashrc` or `~/.zshrc`.

### "WSL interop is disabled"

Enable interop in `/etc/wsl.conf`:
```ini
[interop]
enabled=true
```
Then run `wsl --shutdown` from PowerShell and restart WSL.

### "socat not installed"

Install socat:
```bash
sudo apt install socat
```

### Bridge not starting

Ensure the Windows SSH agent is running:
- **1Password**: Settings → Developer → Enable SSH agent
- **Windows OpenSSH**: Start the "OpenSSH Authentication Agent" service

## Credits

This plugin uses [npiperelay](https://github.com/jstarks/npiperelay) by John Googins Starks ([@jstarks](https://github.com/jstarks)). Thank you for creating this essential tool that makes WSL SSH agent bridging possible!

## License

MIT
