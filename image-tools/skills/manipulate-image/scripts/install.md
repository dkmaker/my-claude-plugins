# Image Tools Installation

## Requirements

- Python 3.8+
- pip (comes with Python)

## Manual Setup

1. Install Python 3 if missing:
   - Ubuntu/Debian: `sudo apt install python3 python3-venv`
   - macOS: `brew install python3`
   - Arch: `sudo pacman -S python`

2. Run the shared environment setup:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-venv.sh"
   ```

3. Verify:
   ```bash
   VENV="${CLAUDE_PLUGIN_ROOT}/scripts/venv"
   "$VENV/bin/python" -c "from PIL import Image; print(Image.__version__)"
   ```
