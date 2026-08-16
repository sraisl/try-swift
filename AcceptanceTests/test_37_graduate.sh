PROJECTS_DIR=$(mktemp -d)

CURRENT_TEST="graduate emits mv + symlink script"
output=$(TRY_PROJECTS="$PROJECTS_DIR" try_script --path "$TEST_TRIES" exec cd beta --and-keys "CTRL-G,ENTER")
if echo "$output" | grep -q "mv '$TEST_TRIES/2026-08-14-beta' '$PROJECTS_DIR/beta'" \
    && echo "$output" | grep -q "ln -s '$PROJECTS_DIR/beta' '$TEST_TRIES/2026-08-14-beta'"; then
    pass
else
    fail "expected mv + ln -s graduate script, got: $output"
fi

CURRENT_TEST="graduate script actually moves and symlinks when eval'd"
script=$(TRY_PROJECTS="$PROJECTS_DIR" try_script --path "$TEST_TRIES" exec cd beta --and-keys "CTRL-G,ENTER")
(cd /tmp && eval "$script") >/dev/null 2>&1
if [ -d "$PROJECTS_DIR/beta" ] && [ -L "$TEST_TRIES/2026-08-14-beta" ]; then
    pass
else
    fail "expected real directory at destination and symlink left behind"
fi

rm -rf "$PROJECTS_DIR"
