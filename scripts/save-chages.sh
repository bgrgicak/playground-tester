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

src=""
message=""
push=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --src) src="$2"; shift 2;;
    --message) message="$2"; shift 2;;
    --push) push=true; shift 1;;
    -h|--help)
      grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//'
      exit 0
      ;;
    *) echo "Invalid option: $1" >&2; exit 1;;
  esac
done

if [ -z "$src" ]; then
  echo "Error: --src argument is required" >&2
  exit 1
fi

if [ -n "$message" ]; then
    git add "$src"
    git commit -m "$message"
fi
if $push; then
    git push
fi
