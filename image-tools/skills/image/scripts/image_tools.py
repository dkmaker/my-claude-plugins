#!/usr/bin/env python3
"""image-tools: Swiss army knife for image manipulation."""

import argparse
import sys
import os

# Add script directory to path so ops package is importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ops import register_all


def main():
    parser = argparse.ArgumentParser(
        prog="image_tools",
        description="Swiss army knife for image manipulation",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    subparsers = parser.add_subparsers(dest="command", help="Operation to perform")
    register_all(subparsers)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
