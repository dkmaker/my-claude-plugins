#!/bin/bash
# Shared venv setup for the image plugin (used by both generate and manipulate skills)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
ERRORS=0

echo "=== Image Plugin - Shared Environment Setup ==="
echo ""

# 1. Check Python
echo -n "Python 3: "
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "OK $PYTHON_VERSION"
else
    echo "MISSING"
    echo "  Install Python 3.8+"
    ((ERRORS++))
fi

# 2. Check/create venv
echo -n "Virtual environment: "
if [ -d "$VENV_DIR" ]; then
    echo "OK exists"
else
    echo "creating..."
    python3 -m venv "$VENV_DIR"
    if [ -d "$VENV_DIR" ]; then
        echo "  OK created at $VENV_DIR"
    else
        echo "  FAILED to create venv"
        ((ERRORS++))
    fi
fi

# 3. Install all dependencies
echo -n "Dependencies: "
if "$VENV_DIR/bin/python" -c "from google import genai; from PIL import Image; import yaml; import numpy" 2>/dev/null; then
    echo "OK all installed"
else
    echo "installing..."
    "$VENV_DIR/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null
    if "$VENV_DIR/bin/python" -c "from PIL import Image" 2>/dev/null; then
        echo "  OK installed"
    else
        echo "  FAILED"
        echo "  Run: $VENV_DIR/bin/pip install -r $SCRIPT_DIR/requirements.txt"
        ((ERRORS++))
    fi
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "OK Ready!"
    exit 0
else
    echo "$ERRORS error(s) found. See output above."
    exit 1
fi
