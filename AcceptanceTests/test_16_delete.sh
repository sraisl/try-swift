CURRENT_TEST="delete confirmation with YES emits rm -rf script"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "CTRL-D,ENTER" --and-confirm "YES")
if echo "$output" | grep -q "test -d '2026-08-15-alpha' && rm -rf '2026-08-15-alpha'"; then
    pass
else
    fail "expected rm -rf script for confirmed delete, got: $output"
fi

CURRENT_TEST="delete confirmation without literal YES cancels (no script emitted)"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "CTRL-D,ENTER" --and-confirm "no")
if ! echo "$output" | grep -q "rm -rf"; then
    pass
else
    fail "expected delete to be cancelled without YES, got: $output"
fi

CURRENT_TEST="delete script actually removes the directory when eval'd"
script=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "CTRL-D,ENTER" --and-confirm "YES")
(cd /tmp && eval "$script") >/dev/null 2>&1
if [ ! -d "$TEST_TRIES/2026-08-15-alpha" ]; then
    pass
else
    fail "expected directory to be removed after eval, still exists"
fi
