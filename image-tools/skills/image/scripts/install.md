# Image Tools Installation

## Requirements

- Python 3.8+
- pip (comes with Python)

## Manual Setup

1. Install Python 3 if missing:
   - Ubuntu/Debian: `sudo apt install python3 python3-venv`
   - macOS: `brew install python3`
   - Arch: `sudo pacman -S python`

2. Create virtual environment:
   ```bash
   SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/image/scripts"
   python3 -m venv "$SCRIPT_DIR/venv"
   ```

3. Install Pillow:
   ```bash
   "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
   ```

4. Verify:
   ```bash
   "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image; print(Image.__version__)"
   ```
