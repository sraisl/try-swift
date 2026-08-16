CURRENT_TEST="worktree dir command emits mkdir and runtime git check"
output=$(try_run worktree dir experiment --path "$TEST_TRIES")
today=$(date +%Y-%m-%d)
if echo "$output" | grep -q "mkdir -p '$TEST_TRIES/$today-experiment'" \
    && echo "$output" | grep -q "git rev-parse --is-inside-work-tree"; then
    pass
else
    fail "expected worktree mkdir + runtime git check, got: $output"
fi

CURRENT_TEST="try . in a real git repo creates a real worktree"
REPO_DIR=$(mktemp -d)
(cd "$REPO_DIR" && git init -q && git commit -q --allow-empty -m init)
script=$(cd "$REPO_DIR" && try_script --path "$TEST_TRIES" exec cd . myworktree)
eval "$script" >/dev/null 2>&1
today=$(date +%Y-%m-%d)
if (cd "$REPO_DIR" && git worktree list | grep -q "$today-myworktree"); then
    pass
else
    fail "expected a real git worktree to be created, worktree list: $(cd "$REPO_DIR" && git worktree list)"
fi
rm -rf "$REPO_DIR"

CURRENT_TEST="try . outside a git repo falls back to plain mkdir"
NON_REPO_DIR=$(mktemp -d)
script=$(cd "$NON_REPO_DIR" && try_script --path "$TEST_TRIES" exec cd . plaindir)
today=$(date +%Y-%m-%d)
if echo "$script" | grep -q "mkdir -p '$TEST_TRIES/$today-plaindir'" && ! echo "$script" | grep -q "worktree add"; then
    pass
else
    fail "expected plain mkdir for non-repo cwd, got: $script"
fi
rm -rf "$NON_REPO_DIR"
