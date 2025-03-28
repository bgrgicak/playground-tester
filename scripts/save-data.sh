#! /bin/bash
#
# Save changes made in the data submodule to git
#
# Usage: save_data --add <path> --message <message> --push
#
# Options:
#   --add <path>       Path to the source files/directories to commit. Required for committing.
#   --message <message> Commit message. Required for committing.
#   --push             Push changes to git. Optional.

save_data() {
  local add=""
  local message=""
  local push=false
  local dry_run=""
  local remote="origin"
  local branch="main"
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --add) add="$2"; shift 2;;
      --message) message="$2"; shift 2;;
      --push) push=true; shift 1;;
      --dry-run) dry_run="--dry-run"; shift 1;;
      *) echo "Invalid option: $1" >&2; exit 1;;
    esac
  done

  if [ "$PLAYGROUND_TESTER_DISABLE_GIT" = true ]; then
    echo "Git commits are disabled."
    exit 0
  fi

  # If path starts with PLAYGROUND_TESTER_DATA_PATH remove it to ensure the
  # path is relative to the data submodule
  if [[ "$add" == "$PLAYGROUND_TESTER_DATA_PATH"* ]]; then
    add="${add#$PLAYGROUND_TESTER_DATA_PATH/}"
  fi

  cd data || { echo "Submodule directory 'data' not found."; exit 1; }

  echo "[DEBUG]: Starting git checkout $branch"
  # Checkout $branch.
  # Only run the checkout if we're not already on the target branch,
  # as checkout may take a few seconds in a repository of this size.
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "$branch" ]; then
    if ! git checkout "$branch" > /dev/null 2>&1; then
      echo "Failed to checkout branch $branch"
      exit 1
    fi
  fi
  echo "[DEBUG]: Done git checkout"

  if [ -n "$message" ] && [ -n "$add" ]; then
    echo "[DEBUG]: Starting git add -A $add $dry_run"
    git add -A $add $dry_run
    echo "[DEBUG]: Done git add"

    echo "[DEBUG]: Starting git commit --allow-empty -m "$message" --quiet $dry_run"
    git commit --allow-empty --no-status --untracked-files=no -m "$message" --quiet $dry_run
    echo "[DEBUG]: Done git commit"
  fi

  if $push; then
    # Fetch remote changes
    echo "[DEBUG]: Starting git fetch $remote $branch"
    if ! git fetch "$remote" "$branch" > /dev/null 2>&1; then
      echo "Failed to fetch from remote"
      exit 1
    fi
    echo "[DEBUG]: Done git fetch"

    # Try to merge remote changes, allow unrelated histories and automatically accept remote version for conflicts
    echo "[DEBUG]: Starting git merge --allow-unrelated-histories -X theirs $remote/$branch"
    merge_output=$(git merge --allow-unrelated-histories -X theirs "$remote/$branch" 2>&1)
    if [ $? -ne 0 ]; then
      echo "Failed to merge with remote:"
      echo "$merge_output"
      exit 1
    fi
    echo "[DEBUG]: Done git merge"

    echo "[DEBUG]: Starting git push $remote $branch --recurse-submodules=on-demand --quiet $dry_run"
    git push "$remote" "$branch" --recurse-submodules=on-demand --quiet $dry_run
    echo "[DEBUG]: Done git push"
  fi

  cd ..
}
