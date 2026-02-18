# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-02-18

### Added

- Initial release of `bw-session`, a Bitwarden CLI session helper for macOS.
- Reuse of valid `BW_SESSION` tokens to avoid unnecessary unlock/login cycles.
- `--refresh-session` option to explicitly rotate and refresh the active session.
- Shell output modes for `bash`, `zsh`, and `fish` (`--bash`, `--zsh`, `--fish`).
- Automatic shell detection for assignment output when no shell mode is forced.
- Source-aware behavior to export `BW_SESSION` in the current shell when sourced.
- Command passthrough to run `bw` commands with a validated session automatically.
- Safe passthrough for direct Bitwarden auth/config commands and explicit `--session` usage.
- Keychain-based secret retrieval using `BW_CLIENTID`, `BW_CLIENTSECRET`, and `BW_MASTER_PASSWORD`.
- User guidance output for exporting sessions in current and other shell types.
- `--help` usage output.
- `--version` option to print the script version.
