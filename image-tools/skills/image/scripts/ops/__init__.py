"""Operation modules for image-tools. Each module registers subcommands."""

import importlib
import pkgutil
import os


def register_all(subparsers):
    """Auto-discover and register all ops modules."""
    ops_dir = os.path.dirname(__file__)
    for finder, name, ispkg in pkgutil.iter_modules([ops_dir]):
        if name.startswith("_"):
            continue
        module = importlib.import_module(f"ops.{name}")
        if hasattr(module, "register"):
            module.register(subparsers)
