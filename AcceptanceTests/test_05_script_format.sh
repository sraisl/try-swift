CURRENT_TEST="script output has warning comment first line"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "ENTER")
first_line=$(echo "$output" | head -1)
if echo "$first_line" | grep -q "didn.t launch try from an alias"; then
    pass
else
    fail "expected warning comment as first line, got: $first_line"
fi

CURRENT_TEST="multi-command script uses && continuation"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "ENTER")
if echo "$output" | grep -q " && \\\\$"; then
    pass
else
    fail "expected && \\\\ continuation in script, got: $output"
fi

CURRENT_TEST="cd script contains touch, echo, and cd for the selected path"
output=$(try_script --path "$TEST_TRIES" exec cd alpha --and-keys "ENTER")
if echo "$output" | grep -q "touch '$TEST_TRIES/2026-08-15-alpha'" \
    && echo "$output" | grep -q "cd '$TEST_TRIES/2026-08-15-alpha'"; then
    pass
else
    fail "expected touch/cd commands for selected path, got: $output"
fi
