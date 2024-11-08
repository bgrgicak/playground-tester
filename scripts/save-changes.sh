#! /bin/bash
#
# Save changes to git
#
# Usage: ./scripts/save-changes.sh --src <path> --message <message> --push
#
# Options:
#   --add <path>       Path to the source files/directories to commit. Required for committing.
#   --message <message> Commit message. Required for committing.
#   --push             Push changes to git. Optional.

add=""
message=""
push=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --add) src="$2"; shift 2;;
    --message) message="$2"; shift 2;;
    --push) push=true; shift 1;;
    -h|--help)
      grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//' | tail -n +3
      exit 0
      ;;
    *) echo "Invalid option: $1" >&2; exit 1;;
  esac
done

if [ -n "$message" ] && [ -n "$add" ]; then
    git add "$add"
    git commit -m "$message"
fi
if $push; then
    git push
fi
