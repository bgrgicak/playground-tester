#! /bin/bash
#
# Save changes to git
# If the path is in the logs submodule, it will commit the changes to the submodule.
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

# check if path is in a submodule
if [[ "$add" == logs* ]]; then
  # Navigate to the logs submodule directory
  cd logs || exit 1

  # remove logs/ from the path
  add="${add#logs/}"

  if [ -n "$add" ] && [ -n "$message" ]; then
    # Add the specified files/directories
    git add "$add"

    # Check if there are changes to commit
    if ! git diff --staged --quiet; then
      # Commit the changes
      git commit --allow-empty -m "$message" --quiet

      # Push if requested
      if [ "$push" = true ]; then
        git push --quiet
      fi
    fi
  fi
else
  git pull --rebase --quiet

  if [ -n "$message" ] && [ -n "$add" ]; then
      git add -A $add
      git commit --allow-empty -m "$message" --quiet
  fi
  if $push; then
      git push --quiet
  fi
fi
