#! /bin/bash

# Navigate to the data submodule
cd data || exit 1

# Test git push with --dry-run (with any pending changes)
push_output=$(git push --dry-run origin main 2>&1)
push_status=$?

# Test git push with --dry-run (should show up-to-date)
no_change_output=$(git push --dry-run origin main 2>&1)
no_change_status=$?

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

