#!/bin/sh
# Installs a dittofleet CLI from its latest release:
#
#   curl -fsSL https://raw.githubusercontent.com/dittofleet/.github/main/install.sh | sh -s <name>
#
# It goes in ~/.local/bin, or <NAME>_INSTALL_DIR (navi: NAVI_INSTALL_DIR,
# port-pool: PORT_POOL_INSTALL_DIR). Then the CLI's own `postinstall`
# command does its first-time setup.
set -eu

NAME="${1:-}"
case "$NAME" in
  "" | *[!a-z0-9-]*) echo "usage: sh -s <name>, e.g. sh -s navi" >&2; exit 1 ;;
esac
VAR="$(printf %s "$NAME" | tr 'a-z-' 'A-Z_')_INSTALL_DIR"
eval "DEST=\${$VAR:-\$HOME/.local/bin}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$(uname -m)" in
  arm64 | aarch64) ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
  *) ARCH=$(uname -m) ;;
esac
URL="https://github.com/dittofleet/$NAME/releases/latest/download/$NAME-$OS-$ARCH"

mkdir -p "$DEST"
# Staged next to the binary, so the install is a rename: a running copy
# keeps its old file, and an interruption cannot leave a truncated one.
TMP=$(mktemp "$DEST/.$NAME.XXXXXX")
trap 'rm -f "$TMP"' EXIT

echo "Downloading $URL..." >&2
curl -fsSL "$URL" -o "$TMP" || {
  echo "Could not download $NAME for $OS-$ARCH. Not every CLI is built for every system." >&2
  exit 1
}
chmod 755 "$TMP"
mv "$TMP" "$DEST/$NAME"
echo "Installed $NAME to $DEST/$NAME" >&2

case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "Note: $DEST is not in \$PATH. Add it to your shell profile to use $NAME." >&2 ;;
esac

# Under `curl | sh` stdin is this script, so setup gets the terminal
# instead, when there is one, for its questions.
if (: </dev/tty) 2>/dev/null; then
  "$DEST/$NAME" postinstall </dev/tty
else
  "$DEST/$NAME" postinstall </dev/null
fi
