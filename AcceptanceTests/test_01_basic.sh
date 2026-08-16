CURRENT_TEST="help shows usage and exits 0"
output=$(try_run --help)
code=$?
if echo "$output" | grep -q "ephemeral workspace manager" && [ "$code" -eq 0 ]; then
    pass
else
    fail "expected help text and exit 0, got exit $code: $output"
fi

CURRENT_TEST="version shows version string"
output=$(try_run --version)
if echo "$output" | grep -qE "try [0-9]+\.[0-9]+\.[0-9]+"; then
    pass
else
    fail "expected version string, got: $output"
fi

CURRENT_TEST="no command shows help and exits 2"
try_run >/dev/null 2>&1
code=$?
if [ "$code" -eq 2 ]; then
    pass
else
    fail "expected exit 2, got $code"
fi

CURRENT_TEST="--help wins even after other args"
output=$(try_run clone somearg --help)
if echo "$output" | grep -q "ephemeral workspace manager"; then
    pass
else
    fail "expected help text when --help appears after other args"
fi
