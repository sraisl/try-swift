CURRENT_TEST="PR URL clone fetches and checks out detached HEAD"
output=$(try_run clone https://github.com/tobi/try/pull/123 --path "$TEST_TRIES")
today=$(date +%Y-%m-%d)
if echo "$output" | grep -q "$TEST_TRIES/$today-tobi-try" \
    && echo "$output" | grep -q "fetch origin 'pull/123/head'" \
    && echo "$output" | grep -q "checkout --detach FETCH_HEAD"; then
    pass
else
    fail "expected PR clone script with fetch+checkout, got: $output"
fi

CURRENT_TEST="PR URL via default cd shorthand also triggers PR clone"
output=$(try_run exec cd https://github.com/tobi/try/pull/5 --path "$TEST_TRIES")
if echo "$output" | grep -q "pull/5/head"; then
    pass
else
    fail "expected PR shorthand to trigger clone, got: $output"
fi
