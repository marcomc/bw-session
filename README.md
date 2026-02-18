# bw-session

`bw-session` is a helper script for Bitwarden CLI session management.

It solves a common workflow problem: getting a valid `BW_SESSION` quickly, reusing it when still valid, and refreshing it only when needed.

## What This Project Achieves

- Reuses a valid `BW_SESSION` instead of rotating on every run.
- Supports explicit rotation via `--refresh-session`.
- Can emit shell-specific assignment output for `bash`, `zsh`, or `fish`.
- Can run `bw ...` commands with a valid session automatically.
- Reads Bitwarden API credentials and master password from macOS Keychain so credentials are not stored in plaintext dotfiles.

Use this project when you use `bw` frequently from terminal automation and want predictable, low-friction auth/session behavior.

## Requirements

- macOS (uses the built-in `security` command for Keychain access)
- `bw` (Bitwarden CLI)
- `jq`
- A Bitwarden account with API key credentials

Check dependencies:

```bash
command -v bw
command -v jq
command -v security
```

## Preparation (One-Time Setup)

### 1. Create Bitwarden API key

1. Sign in to the Bitwarden Web Vault at <https://vault.bitwarden.com>.
2. Open your profile menu (top right) and choose `Account settings`.
3. Go to the `Security` section, then open the `Keys` page.
4. In the `API Key` section, click `View API key` (or `Generate API key` if one does not exist yet).
5. Complete the identity verification prompt if Bitwarden asks for your master password or 2FA.
6. Copy and save both values shown:

- `client_id`
- `client_secret`

### 2. Save required secrets in macOS Keychain

`bw-session.sh` expects these Keychain service names:

- `BW_CLIENTID`
- `BW_CLIENTSECRET`
- `BW_MASTER_PASSWORD`

Use secure prompts (example in `bash`/`zsh`):

```bash
read -rs BWSEC; printf '\n'; security add-generic-password -a "$USER" -s BW_CLIENTID -w "$BWSEC" -U; unset BWSEC
read -rs BWSEC; printf '\n'; security add-generic-password -a "$USER" -s BW_CLIENTSECRET -w "$BWSEC" -U; unset BWSEC
read -rs BWSEC; printf '\n'; security add-generic-password -a "$USER" -s BW_MASTER_PASSWORD -w "$BWSEC" -U; unset BWSEC
```

Use secure prompts (example in `fish`):

```fish
read -s BWSEC; echo; security add-generic-password -a "$USER" -s BW_CLIENTID -w "$BWSEC" -U; set -e BWSEC
read -s BWSEC; echo; security add-generic-password -a "$USER" -s BW_CLIENTSECRET -w "$BWSEC" -U; set -e BWSEC
read -s BWSEC; echo; security add-generic-password -a "$USER" -s BW_MASTER_PASSWORD -w "$BWSEC" -U; set -e BWSEC
```

## Usage

### Print shell assignment (default mode)

```bash
./bw-session.sh
```

Examples:

```bash
./bw-session.sh --bash
./bw-session.sh --zsh
./bw-session.sh --fish
```

### Print script version

```bash
./bw-session.sh --version
```

### Export in current shell

`bash`/`zsh`:

```bash
eval "$(./bw-session.sh)"
```

`fish`:

```fish
eval (./bw-session.sh --fish)
```

### Rotate session explicitly

```bash
./bw-session.sh --refresh-session
```

### Run Bitwarden commands through helper

```bash
./bw-session.sh list items
./bw-session.sh get item <item-id>
./bw-session.sh --refresh-session list items
```

## Security Notes

- Do not commit real credentials, session tokens, or exported environment values.
- Do not paste `BW_SESSION` values into issue trackers or chat.
- Keep Keychain as the secret source of truth for local machine use.
- Consider rotating Bitwarden API key if you suspect exposure.

## Project Files

- `bw-session.sh`: main script
- `README.md`: setup and usage documentation
