#! /bin/bash
#
# Helper functions to analyze JSON logs and output a summary of the results.

source "./scripts/pre-script-run.sh"

# Get all log files for a given item type
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files <item-type> [--prefix-chars <prefix-chars>] [<find-args>...]
get_log_files() {
	local positional_args=()
	local prefix_chars="*"
	while [[ "$#" -gt 0 ]]; do
		case $1 in
			--prefix-chars)
			prefix_chars="$2"
			shift 2
			;;
			*)
			positional_args+=("$1")
			shift 1
			;;
		esac
	done
	local item_type="${positional_args[0]}"
	local find_args=("${positional_args[@]:1}")

	# Get a list of paths to search in
	local prefixes=($(ls -1 "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type"))
	local paths=()
	for prefix in "${prefixes[@]}"; do
		if [[ "$prefix_chars" == "*" ]] || [[ "$prefix_chars" == *"$prefix"* ]]; then
			paths+=("$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/$prefix")
		fi
	done

	find "${paths[@]}" -mindepth 2 -maxdepth 2 -type f "${find_args[@]}"
}

# Get log files with errors
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files_with_errors <item-type> <limit>
get_log_files_with_errors() {
	local item_type="$1"
	local limit="$2"
	if [ -z "$limit" ]; then
		shift
		get_log_files "$item_type" -name "error.json" -size +3c "$@"
	else
		shift 2
		get_log_files "$item_type" -name "error.json" -size +3c "$@" | head -n "$limit"
	fi
}

# Get all errors of a given level from the JSON log file
#
# Usage:
#   get_errors_by_level <level> <log-file>
get_errors_by_level() {
	local level="$1"
	local log_file="$2"
	jq '[.[] | select(.level == "'"$level"'")]' "$log_file"
}

# Get the number of errors of a given level from the JSON log file
#
# Usage:
#   get_number_of_errors_by_level <level> <log-file>
get_number_of_errors_by_level() {
	echo "$(get_errors_by_level "$1" "$2" | jq 'length')"
}

# Get the first n logs to test.
# We first need to test logs that have not been
# tested for the longest time.
# The last tested time is stored in TIMESTAMP-last-tested.txt
# file located in log directories of each item.
#
# Usage:
#   get_first_n_logs_to_test <item-type> <batch-size> [--prefix-chars <prefix-chars>]
get_first_n_logs_to_test() {
	local positional_args=()
	local prefix_chars="*"
	while [[ "$#" -gt 0 ]]; do
		case $1 in
			--prefix-chars)
			prefix_chars="$2"
			shift 2
			;;
			*)
			positional_args+=("$1")
			shift 1
			;;
		esac
	done
	local item_type="${positional_args[0]}"
	local batch_size="${positional_args[1]}"

	local all_log_files=$(get_log_files "$item_type" --prefix-chars "$prefix_chars" -name "*last-tested.txt"|
		awk -F'/' '{print $NF " " substr($0, 1, length($0)-length($NF)-1)}' |
		sort |
		cut -d' ' -f2-)
	echo "$all_log_files" |
		head -n "$batch_size"
}
