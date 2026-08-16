CURRENT_TEST="fuzzy search filters to matching entries"
output=$(try_run --path "$TEST_TRIES" exec cd redis --and-exit)
# Matched chars are ANSI-highlighted individually, so "redis-server" won't
# appear as one literal substring - check for the surrounding text instead.
if echo "$output" | grep -q "2026-08-10-" && echo "$output" | grep -q -- "-server"; then
    pass
else
    fail "expected redis-server entry to match query 'redis', got: $output"
fi

CURRENT_TEST="fuzzy search excludes non-matching entries from render"
output=$(try_run --path "$TEST_TRIES" exec cd zzz-nomatch --and-exit)
if ! echo "$output" | grep -q "alpha"; then
    pass
else
    fail "expected alpha to be excluded for non-matching query, got: $output"
fi

CURRENT_TEST="empty query shows all entries"
output=$(try_run --path "$TEST_TRIES" exec cd "" --and-exit)
if echo "$output" | grep -q "alpha" && echo "$output" | grep -q "beta" && echo "$output" | grep -q "redis-server"; then
    pass
else
    fail "expected all entries visible for empty query, got: $output"
fi
