#!/usr/bin/env sh
set -e

# shellcheck disable=SC1007
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"

# shellcheck source=src/database.sh
. "$SELF_DIR/database.sh"

# determine the running operating system id
# usage: detect_os
detect_os() {
	_os="$(to_lower "$(uname -s)")"

	_detect_linux() {
		. /etc/os-release
		printf "%s" "$ID"
	}

	case "$_os" in
		linux)	_detect_linux ;;
		*)		printf "%s" "$_os" ;;
	esac
}

# immediately exit with an exit code and message
# usage: fatal <exit-code> <message>
fatal() {
	printf "%s\n" "$2" 1>&2
	# shellcheck disable=SC2086
	exit $1
}

# normalizes an OCI platform specifier like containerd
# usage: normalize_platform <platform>
normalize_platform() {
	_platform="$1"
	_platform="$(trim "$_platform")"

	IFS="/" read -r _os _arch _variant <<-END
		$_platform
	END

	_os="$(normalize_os "$_os")"
	IFS=" " read -r _arch _variant <<-END
		$(normalize_arch "$_arch" "$_variant")
	END

	is_known_os "$_os" || fatal 1 "unknown operating system: $_os"
	is_known_arch "$_arch" || fatal 1 "unknown architecture: $_arch"

	_platform="$_os/$_arch"
	[ -n "$_variant" ] && _platform="$_platform/$_variant"

	printf "%s" "$_platform"
}

# installs (or prepares to install) skopeo from the package manager
# usage: skopeo_install [repo-url] [install]
skopeo_install() {
	_repo_url="$1"
	_use_cache="${2:-true}"

	_apt_install() {
		_repo_url="${1:-${GOOD_APT_REPO_URL}}"
		_use_cache="$2"

		# https://github.com/devcontainers/ci/issues/191#issuecomment-1416384710
		if [ -n "$_repo_url" ]; then
			_skopeo_list="/etc/apt/sources.list.d/skopeo.list"
			_skopeo_gpg="/etc/apt/trusted.gpg.d/skopeo.gpg"

			sudo sh -c "echo 'deb ${_repo_url}/ /' > ${_skopeo_list}"
			curl -fsSL "${_repo_url}/Release.key" \
				| gpg --dearmor \
				| sudo tee "${_skopeo_gpg}" > /dev/null
		fi

		export DEBIAN_FRONTEND=noninteractive
		sudo apt-get update
		if [ "$_use_cache" = "false" ]; then
			sudo apt-get install -y skopeo
		fi
	}

	# TODO: support other operating systems
	_os="$(detect_os)"
	case "$_os" in
		debian|ubuntu)	_apt_install "$_repo_url" "$_use_cache" ;;
		*)				fatal 1 "unsupported operating system: $_os" ;;
	esac
}

# splits a string into multiline by a separator
# usage: split <separator> <string>
# shellcheck disable=2086
split() {
	set -f;	_ifs=$IFS; IFS=$1
	set -- $2; printf '%s\n' "$@"
	IFS=$_ifs; set +f
}

# normalizes a comma separated list of OCI platform specifiers
# usage: step_platforms <platforms>
step_platforms() {
	_platforms="$1"

	_all=""
	_cross=""
	_native=""
	_needs_cross="false"

	# detect the native platform
	_self_platform="$(normalize_platform "")"
	[ -z "$_platforms" ] && _platforms="$_self_platform"

	_append() { printf "%s\n%s" "$1" "$2"; }
	for _platform in $(split "," "$_platforms"); do
		_platform="$(normalize_platform "$_platform")"

		_all="$(_append "$_all" "$_platform")"
		if [ "$_platform" = "$_self_platform" ]; then
			_native="$(_append "$_native" "$_platform")"
		else
			_cross="$(_append "$_cross" "$_platform")"
			_needs_cross="true"
		fi
	done

	printf "PLATFORMS_SELF=%s\n" "$_self_platform"
	printf "NEEDS_CROSS=%s\n" "$_needs_cross"

	_format() { printf "%s" "$(trim "$1")" | sort -u | xargs | tr " " ","; }
	printf "PLATFORMS_ALL=%s\n" "$(_format "$_all")"
	printf "PLATFORMS_CROSS=%s\n" "$(_format "$_cross")"
	printf "PLATFORMS_NATIVE=%s\n" "$(_format "$_native")"
}

# determines if skopeo needs to be installed or updated
# usage: step_skopeo <minimum> [repo-url] [use-cache] [retry]
step_skopeo() {
	_minimum="$1"
	_repo_url="$2"
	_use_cache="${3:-true}"
	_retry="${4:-1}"

	_needs_skopeo="true"
	_version="0"

	_skopeo_version() { split " " "$(skopeo --version)" | tail -n 1; }
	_to_int() { trim "$1" | sed 's/\.//g'; }

	if command -v skopeo >/dev/null 2>&1; then
		_version="$(_skopeo_version)"
	fi

	if [ "$(_to_int "$_version")" -ge "$(_to_int "$_minimum")" ]; then
		_needs_skopeo="false"
	else
		if [ "$_retry" -eq 1 ]; then
			skopeo_install "$_repo_url" "$_use_cache"
			step_skopeo "$_minimum" "$_repo_url" "$_use_cache" "0"
			return
		fi
	fi

	# matches awalsh128/cache-apt-pkgs-action
	printf "version=%s=%s\n" "skopeo" "$_version"
	printf "needs-skopeo=%s\n" "$_needs_skopeo"
}

# trims whitespace from the start and end of a string
# usage: trim <string>
trim() {
	_trim=${1#"${1%%[![:space:]]*}"}
	_trim=${_trim%"${_trim##*[![:space:]]}"}
	printf '%s\n' "$_trim"
}

STEP_NAME="$1"; shift
case "$STEP_NAME" in
	platforms)		step_platforms "${INPUT_PLATFORMS:-$1}" ;;
	skopeo-check)	step_skopeo "${INPUT_SKOPEO_MINIMUM:-$1}" "${INPUT_SKOPEO_URL:-$2}" "${INPUT_CACHE:-$3}" ;;
	skopeo-version)	step_skopeo "${INPUT_SKOPEO_MINIMUM:-$1}" "" "" "0" ;;
	*)				fatal 1 "unknown step: $STEP_NAME" ;;
esac
