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

# Update main repository and submodules
git pull --rebase --quiet
git submodule update --init --recursive --quiet

if [ -n "$message" ] && [ -n "$add" ]; then
    # Add all changes (including new files) in the specified path
    git add -A $add

    # Check if any of the changes are in submodules
    if git status --porcelain | grep -q '^M.*\.\.'; then
        # If there are submodule changes, stage them but only in the specified path
        git add -u $add
    fi

    git commit --allow-empty -m "$message" --quiet
fi

if $push; then
    # Push changes in the main repository
    git push --quiet

    # Push changes in submodules if any
    git submodule foreach 'git push --quiet || :'
fi
