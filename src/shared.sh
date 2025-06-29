#!/usr/bin/env sh
set -e

# checks the presence and/or version of a package
# usage: check_package <package> [args...]
check_package() {
	_package="$1"; shift

	if command -v "$_package" > /dev/null 2>&1; then
		[ $# -gt 0 ] && "$_package" "$@" || return 0
	else
		[ $# -gt 0 ] && printf "0" || return 1
	fi
}

# immediately exits with an exit code and message
# usage: fatal <exit-code> <message>
fatal() {
	printf "%s\n" "$2" 1>&2
	# shellcheck disable=SC2086
	exit $1
}

# splits a string into multiline by a separator
# usage: split <separator> <string>
# https://github.com/dylanaraps/pure-sh-bible
# shellcheck disable=2086
split() {
	set -f;	_ifs=$IFS; IFS=$1
	set -- $2; printf '%s\n' "$@"
	IFS=$_ifs; set +f
}

# trims whitespace from the start and end of a string
# usage: trim <string>
# https://github.com/dylanaraps/pure-sh-bible
trim() {
	_trim=${1#"${1%%[![:space:]]*}"}
	_trim=${_trim%"${_trim##*[![:space:]]}"}
	printf '%s\n' "$_trim"
}
