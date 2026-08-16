CURRENT_TEST="clone generates date-prefixed user-repo directory name"
output=$(try_run clone https://github.com/tobi/try --path "$TEST_TRIES")
today=$(date +%Y-%m-%d)
if echo "$output" | grep -q "$TEST_TRIES/$today-tobi-try"; then
    pass
else
    fail "expected dated clone directory name, got: $output"
fi

CURRENT_TEST="clone with custom name uses that name verbatim"
output=$(try_run clone https://github.com/tobi/try mycustomname --path "$TEST_TRIES")
if echo "$output" | grep -q "$TEST_TRIES/mycustomname"; then
    pass
else
    fail "expected custom clone name, got: $output"
fi

CURRENT_TEST="clone without a URI errors with usage message"
output=$(try_run clone --path "$TEST_TRIES" 2>&1)
if echo "$output" | grep -qi "git URI required"; then
    pass
else
    fail "expected usage error for missing URI, got: $output"
fi

CURRENT_TEST="unparsable URI errors clearly"
output=$(try_run clone "not a uri" --path "$TEST_TRIES" 2>&1)
if echo "$output" | grep -qi "Unable to parse git URI"; then
    pass
else
    fail "expected parse error, got: $output"
fi
