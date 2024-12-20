#! /bin/bash

# Navigate to the data submodule
cd data || exit 1

REPO_URL="origin"
#"https://github.com/bgrgicak/Playground-compatibility-reports.git"
if [ -n "$GH_TOKEN" ] && [ -n "$GH_USER" ]; then
    echo "Logging in with GH_TOKEN"
    echo "$GH_TOKEN" | gh auth login --with-token
fi

# Test git push with --dry-run (with any pending changes)
push_output=$(git push "$REPO_URL" --dry-run main 2>&1)
push_status=$?

echo "Push output: $push_output"
echo "Push status: $push_status"

# Test git push with --dry-run (should show up-to-date)
no_change_output=$(git push --dry-run "$REPO_URL" main 2>&1)
no_change_status=$?

echo "No change output: $no_change_output"
echo "No change status: $no_change_status"

# Assert results
if [ $push_status -eq 0 ] && \
   [ $no_change_status -eq 0 ]; then
    echo "✅ Git push dry-run tests passed"
    exit 0
else
    echo "❌ Git push dry-run tests failed"
    echo "Push output (with changes): $push_output"
    echo "Push output (no changes): $no_change_output"
    exit 1
fi

