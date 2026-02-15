# Superpowers Fork

This is a vendored fork of [obra/superpowers](https://github.com/obra/superpowers) v4.3.0
maintained in the my-claude-plugins marketplace for local customization and control.

## Original Author

**Jesse Vincent** (@obra)
- Repository: https://github.com/obra/superpowers
- Sponsorship: https://github.com/sponsors/obra
- Blog: https://blog.fsck.com/2025/10/09/superpowers/

## Why Forked

This fork was created to:
- Allow customization of skills and workflows specific to our needs
- Control update timing and versioning
- Integrate seamlessly with the my-claude-plugins ecosystem
- Maintain stability while upstream evolves

## Original README

See [README.md](README.md) for the complete original documentation.

## Syncing Upstream Updates

To check for and merge updates from upstream:

```bash
# Check for new releases
curl -s https://api.github.com/repos/obra/superpowers/releases/latest | jq -r '.tag_name'

# Manual update process:
# 1. Download latest release from https://github.com/obra/superpowers
# 2. Review RELEASE-NOTES.md for breaking changes
# 3. Merge changes carefully, preserving local customizations
# 4. Update version in plugin.json and marketplace.json
# 5. Test thoroughly before committing
```

## Local Customizations

Document any local modifications here:

- **Removed non-Claude Code files**: Stripped out Codex/OpenCode specific components (docs/, commands/, lib/, run-hook.cmd, .codex/, .opencode/)
- **Removed build artifacts**: .gitignore, .gitattributes, .claude-plugin/marketplace.json (obsolete in vendored fork)
- **Claude Code only**: This fork contains only Claude Code relevant components (skills/, agents/, hooks/)

## License

MIT License - maintained from original.

Copyright (c) Jesse Vincent

See [LICENSE](LICENSE) for full license text.

## Support

For issues with the original superpowers functionality, please refer to:
- Original issues: https://github.com/obra/superpowers/issues
- Original marketplace: https://github.com/obra/superpowers-marketplace

For issues specific to this fork or integration with my-claude-plugins:
- File issues in the my-claude-plugins repository
