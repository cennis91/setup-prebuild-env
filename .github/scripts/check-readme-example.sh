#!/usr/bin/env sh
set -e

# immediately exit with an exit code and message
# usage: fatal <exit-code> <message>
fatal() {
	printf "%s\n" "$2" 1>&2
	# shellcheck disable=SC2086
	exit $1
}

# reads the yaml job definition from a file
# usage: get_job_definition <file> <job-name> [indent]
get_job_definition() {
	_file="$1"
	_job_name="$2"
	_indent="${3:-2}"

	_interval() {
		# shellcheck disable=SC2046
		printf "$1"'%.0s' $(seq 1 "$2")
	}

	# mawk before 1.3.4 20200717 does not support regexp intervals
	awk -v start="^$(_interval ' ' "$_indent")${_job_name}:$" \
		-v end="^$(_interval '[ `]' "$_indent")[^ ]" \
		'$0 ~ start {f=1; print; next} $0 ~ end {f=0; next} f' \
		"$_file"
}

if [ -z "$1" ]; then
	fatal 1 "usage: $0 <README.md> <workflow.yml> <job-name>"
fi

README_FILE="$1"
WORKFLOW_FILE="$2"
JOB_NAME="$3"

# because it is tested, the workflow is the source of truth
ACTUAL="$(get_job_definition "$README_FILE" "$JOB_NAME")"
EXPECTED="$(get_job_definition "$WORKFLOW_FILE" "$JOB_NAME")"

if [ "$EXPECTED" != "$ACTUAL" ]; then
	tmp_dir="$(mktemp -d)"

	readme="${tmp_dir}/readme.txt"
	workflow="${tmp_dir}/workflow.txt"
	printf "%s\n" "$ACTUAL" > "$readme"
	printf "%s\n" "$EXPECTED" > "$workflow"

	printf "Example job '%s' does not match workflow:\n\n" "$JOB_NAME"
	git --no-pager diff --color=always "$readme" "$workflow"

	rm -f "$readme" "$workflow"

	exit 1
fi
