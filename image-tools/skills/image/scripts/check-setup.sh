#!/bin/bash
# Setup check for image-tools plugin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

echo "=== Image Tools Setup Check ==="
echo ""

# 1. Check Python 3
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
if [ -d "$SCRIPT_DIR/venv" ]; then
    echo "OK exists"
else
    echo "creating..."
    python3 -m venv "$SCRIPT_DIR/venv"
    if [ -d "$SCRIPT_DIR/venv" ]; then
        echo "  OK created"
    else
        echo "  FAILED to create venv"
        ((ERRORS++))
    fi
fi

# 3. Check/install Pillow
echo -n "Pillow: "
if "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image; print(Image.__version__)" 2>/dev/null; then
    echo " OK"
else
    echo "installing..."
    "$SCRIPT_DIR/venv/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null
    if "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image" 2>/dev/null; then
        echo "  OK installed"
    else
        echo "  FAILED"
        echo "  Run: $SCRIPT_DIR/venv/bin/pip install -r $SCRIPT_DIR/requirements.txt"
        ((ERRORS++))
    fi
fi

# 4. Check entrypoint
echo -n "image_tools.py: "
if [ -f "$SCRIPT_DIR/image_tools.py" ]; then
    echo "OK"
else
    echo "MISSING"
    ((ERRORS++))
fi

# 5. Make run.sh executable
if [ -f "$SCRIPT_DIR/run.sh" ] && [ ! -x "$SCRIPT_DIR/run.sh" ]; then
    chmod +x "$SCRIPT_DIR/run.sh"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo '{"status": "ok"}'
    exit 0
else
    echo "{\"status\": \"error\", \"message\": \"$ERRORS error(s) found. See output above.\"}"
    exit 1
fi
