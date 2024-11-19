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
    --add) add="$2"; shift 2;;
    --message) message="$2"; shift 2;;
    --push) push=true; shift 1;;
    -h|--help)
      grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//' | tail -n +3
      exit 0
      ;;
    *) echo "Invalid option: $1" >&2; exit 1;;
  esac
done

if [ "$PLAYGROUND_TESTER_DISABLE_GIT" = true ]; then
  echo "Git commits are disabled."
  exit 0
fi

# pull and rebase
git pull --rebase --quiet

if [ -n "$message" ] && [ -n "$add" ]; then
    git add -A $add
    git commit --allow-empty -m "$message" --quiet
fi
if $push; then
    git push --quiet
fi
