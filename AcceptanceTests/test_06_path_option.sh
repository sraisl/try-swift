CURRENT_TEST="--path before command is honored"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "ENTER")
if echo "$output" | grep -q "$TEST_TRIES/2026-08-15-alpha"; then
    pass
else
    fail "expected path to resolve under $TEST_TRIES, got: $output"
fi

CURRENT_TEST="--path after command is also honored (anywhere in argv)"
output=$(try_script exec cd alpha --path "$TEST_TRIES" --and-keys "ENTER")
if echo "$output" | grep -q "$TEST_TRIES/2026-08-15-alpha"; then
    pass
else
    fail "expected path flag to work after command, got: $output"
fi

CURRENT_TEST="--path=value equals form works"
output=$(try_script "exec" "cd" "alpha" "--path=$TEST_TRIES" "--and-keys" "ENTER")
if echo "$output" | grep -q "$TEST_TRIES/2026-08-15-alpha"; then
    pass
else
    fail "expected --path=value form to work, got: $output"
fi
