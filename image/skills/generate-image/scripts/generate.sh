#!/bin/bash
# Wrapper script to run image_gen.py with the shared virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../../../scripts/venv"
"$VENV_DIR/bin/python" "$SCRIPT_DIR/image_gen.py" "$@"
