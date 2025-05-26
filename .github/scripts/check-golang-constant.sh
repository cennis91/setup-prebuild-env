#!/usr/bin/env sh
set -e

# shellcheck disable=SC1007
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"

# shellcheck source=src/database.sh
. "$SELF_DIR/../../src/database.sh"

# immediately exit with an exit code and message
# usage: fatal <exit-code> <message>
fatal() {
	printf "%s\n" "$2" 1>&2
	# shellcheck disable=SC2086
	exit $1
}

# downloads a raw source file from a golang mirror
# usage: get_source <path> [mirror-url]
get_source() {
	_path="${1:-internal/syslist/syslist.go}"
	_mirror="${2:-https://go.dev/src}"
	curl -sSL "${_mirror}/${_path}?m=text"
}

# reads keys from a golang map based on value
# usage: read_keys <content> <var-name> <value-regex>
read_keys() {
	_map="$(printf "%s" "$1" | awk "/^var $2 =/{f=1; next}/^}$/{f=0} f")"
	printf "%s" "$_map" | grep -E "$3,?$" | cut -d'"' -f2 | sort -u | xargs
}

if [ -z "$1" ]; then
	fatal 1 "usage: $0 <constant>"
fi

CONSTANT="$1"
VAR_NAME=""
VALUE_REGEX=""

case "$CONSTANT" in
	KNOWN_ARCH)	VAR_NAME="KnownArch"; VALUE_REGEX="true" ;;
	KNOWN_OS)	VAR_NAME="KnownOS"; VALUE_REGEX="true" ;;
	*)			fatal 1 "unknown constant: $CONSTANT" ;;
esac

SYSLIST_GO="$(get_source "internal/syslist/syslist.go" "$2")"

ACTUAL="$(eval printf '%s' "\"\$$CONSTANT\"")"
EXPECTED="$(read_keys "$SYSLIST_GO" "$VAR_NAME" "$VALUE_REGEX")"

if [ "$ACTUAL" != "$EXPECTED" ]; then
	printf 'Constant "%s" has changed, please update:\n' "$CONSTANT"
	printf '%s="%s"\n' "$CONSTANT" "$EXPECTED"

	exit 1
fi
