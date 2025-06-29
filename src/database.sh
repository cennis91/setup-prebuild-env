#!/usr/bin/env sh
# Reimplementation of containerd/platforms/database.go in POSIX sh
# https://github.com/containerd/platforms/blob/main/platforms.go
set -e

KNOWN_ARCH="386 amd64 amd64p32 arm arm64 arm64be armbe loong64 mips mips64 mips64le mips64p32 mips64p32le mipsle ppc ppc64 ppc64le riscv riscv64 s390 s390x sparc sparc64 wasm"
KNOWN_OS="aix android darwin dragonfly freebsd hurd illumos ios js linux nacl netbsd openbsd plan9 solaris wasip1 windows zos"

# converts a string to lowercase
# usage: to_lower <string>
to_lower() {
	printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

# is_known_os returns true if we know about the operating system.
# usage: is_known_os <os>
is_known_os() {
	case "$KNOWN_OS" in
		*"$1"*)	return 0 ;;
		*)		return 1 ;;
	esac
}

# is_arm_arch returns true if the architecture is ARM.
# usage: is_arm_arch <arch>
is_arm_arch() {
	case "$1" in
		arm|arm64)	return 0 ;;
		*)			return 1 ;;
	esac
}

# is_known_arch returns true if we know about the architecture.
# usage: is_known_arch <arch>
is_known_arch() {
	case "$KNOWN_ARCH" in
		*"$1"*)	return 0 ;;
		*)		return 1 ;;
	esac
}

# normalize_os normalizes the operating system.
# usage: normalize_os <os>
normalize_os() {
	_os="$(to_lower "$1")"

	case "$_os" in
		"")		printf "%s" "$(normalize_os "$(uname -s)")" ;;
		macos)	printf "darwin" ;;
		*)		printf "%s" "$_os" ;;
	esac
}

# normalize_arch normalizes the architecture.
# usage: normalize_arch <arch> [variant]
normalize_arch() {
	_arch="$(to_lower "$1")"
	_variant="$(to_lower "$2")"

	_amd64() {
		case "$1" in
			v1)	printf "v1" ;;
			*)	printf "%s" "$1" ;;
		esac
	}

	_arm64() {
		case "$1" in
			8|v8|v8.0)	printf "" ;;
			9|v9|v9.0)	printf "v9" ;;
			*)			printf "%s" "$1" ;;
		esac
	}

	_arm() {
		case "$1" in
			""|7)	printf "v7" ;;
			5|6|8)	printf "v%s" "$1" ;;
			*)		printf "%s" "$1" ;;
		esac
	}

	case "$_arch" in
		"")			_arch="$(normalize_arch "$(uname -m)")"; _variant="" ;;
		i386)		_arch="386"; _variant="" ;;
		x86[_-]64)	_arch="amd64"; _variant="$(_amd64 "$_variant")" ;;
		amd64)		_variant="$(_amd64 "$_variant")" ;;
		aarch64)	_arch="arm64"; _variant="$(_arm64 "$_variant")" ;;
		arm64)		_variant="$(_arm64 "$_variant")" ;;
		armhf)		_arch="arm"; _variant="v7" ;;
		armel)		_arch="arm"; _variant="v6" ;;
		arm)		_variant="$(_arm "$_variant")" ;;
	esac

	printf "%s %s" "$_arch" "$_variant"
}
