#!/usr/bin/env sh
set -e

# shellcheck disable=SC1007
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"

# shellcheck source=src/shared.sh
. "$SELF_DIR/shared.sh"

# shellcheck source=src/database.sh
. "$SELF_DIR/database.sh"

# determines the running operating system id
# usage: detect_os
detect_os() {
	_os="$(to_lower "$(uname -s)")"
	case "$_os" in
		linux)	{ . /etc/os-release; printf "%s" "$ID";	} ;;
		*)		printf "%s" "$_os" ;;
	esac
}

# manages a package from the system package manager
# usage: manage_package <action> <package> [args...]
manage_package() {
	_action="$1"
	_package="$2"
	shift; shift

	_apt() {
		_action="$1"
		_package="$2"
		shift; shift

		_configure() {
			_package="$1"
			_repo_url="${2:-${ENV_GOOD_REPO_URL}}"
			shift; shift

			_list="/etc/apt/sources.list.d/${_package}.list"
			_gpg="/etc/apt/trusted.gpg.d/${_package}.gpg"

			if [ -n "$_repo_url" ]; then
				sudo sh -c "echo 'deb ${_repo_url}/ /' > ${_list}"
				curl -fsSL "${_repo_url}/Release.key" \
					| gpg --dearmor \
					| sudo tee "${_gpg}" > /dev/null
			fi
			sudo apt-get update "$@"
		}

		export DEBIAN_FRONTEND=noninteractive
		case "$_action" in
			configure)		_configure "$_package" "$@" ;;
			install|remove)	sudo apt-get "$_action" "$_package" -y "$@" ;;
			*)				fatal 1 "unsupported apt action: $_action" ;;
		esac
	}

	# TODO: support other operating systems?
	case "$(detect_os)" in
		debian|ubuntu)	_apt "$_action" "$_package" "$@" ;;
		*)				fatal 1 "unsupported operating system: $(detect_os)" ;;
	esac
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

# checks the system for critical packages and their versions
# usage: step_dependencies <node-minimum> <skopeo-minimum>
step_dependencies() {
	_node_minimum="$1"
	_skopeo_minimum="$2"

	for _non_posix in curl gpg sudo; do
		if ! check_package "$_non_posix"; then
			fatal 1 "missing required package: $_non_posix"
		fi
	done

	step_version "node" "$_node_minimum"
	step_version "npm" "0"
	step_version "skopeo" "$_skopeo_minimum"
}

# normalizes a comma separated list of OCI platform specifiers
# usage: step_platforms <platforms>
step_platforms() {
	_platforms="$1"

	_all=""; _cross="";	_native=""
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

	printf "platforms-self=%s\n" "$_self_platform"
	printf "needs-cross=%s\n" "$_needs_cross"

	_format() { printf "%s" "$(trim "$1")" | sort -u | xargs | tr " " ","; }
	printf "platforms-all=%s\n" "$(_format "$_all")"
	printf "platforms-cross=%s\n" "$(_format "$_cross")"
	printf "platforms-native=%s\n" "$(_format "$_native")"
}

# ensures skopeo is installed or prepared for installation
# usage: step_skopeo [repo-url] [use-cache]
step_skopeo() {
	_repo_url="$1"
	_use_cache="${2:-true}"

	IFS="=" read -r _ _present <<-END
		$(step_version "skopeo" "0" | grep "present")
	END

	# https://github.com/devcontainers/ci/issues/191#issuecomment-1416384710
	manage_package "configure" "skopeo" "$_repo_url"

	if [ "$_use_cache" = "true" ] && [ "$_present" = "true" ]; then
		# the cache action step will handle installing skopeo
		manage_package "remove" "skopeo"
	elif [ "$_use_cache" = "false" ]; then
		manage_package "install" "skopeo"
	fi
}

# determines if a package needs to be installed or updated
# usage: step_version <package> [minimum]
step_version() {
	_package="$1"
	_minimum="${2:-0}"

	case "$_package" in
		node|npm)	_version="$(check_package "$_package" "--version")" ;;
		skopeo)		_version="$(check_package "$_package" "--version")"
					_version="$(split " " "$_version" | tail -n 1)" ;;
		*)			fatal 1 "unsupported package: $_package" ;;
	esac

	# HACK: not real semver checking, but should be good enough
	_clean() { split "." "$1" | tr -cd '0-9.\n'; }
	_to_int() { for p in $(_clean "$1"); do printf "%03d" "$p"; done; }

	_present="false"; _updated="false"
	if [ "$(_to_int "$_version")" -ne "0" ]; then
		_present="true"
		if [ "$(_to_int "$_version")" -ge "$(_to_int "$_minimum")" ]; then
			_updated="true"
		fi
	fi

	# matches awalsh128/cache-apt-pkgs-action format
	printf "%s-version=%s=%s\n" "$_package" "$_package" "$_version"
	printf "%s-present=%s\n" "$_package" "$_present"
	printf "%s-updated=%s\n" "$_package" "$_updated"
}

STEP_NAME="$1"; shift
case "$STEP_NAME" in
	dependencies)	step_dependencies "${INPUT_NODE_MIN:-$1}" "${INPUT_SKOPEO_MIN:-$2}" ;;
	platforms)		step_platforms "${INPUT_PLATFORMS:-$1}" ;;
	skopeo)			step_skopeo "${INPUT_SKOPEO_URL:-$1}" "${INPUT_CACHE:-$2}" ;;
	version)		step_version "${INPUT_PACKAGE:-$1}" "${INPUT_PACKAGE_MIN:-$2}" ;;
	*)				fatal 1 "unsupported step: $STEP_NAME" ;;
esac
