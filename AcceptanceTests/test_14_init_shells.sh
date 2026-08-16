CURRENT_TEST="init emits a bash/zsh compatible try() function"
output=$(try_run init "$TEST_TRIES")
if echo "$output" | grep -q "try() {" && echo "$output" | grep -q 'eval "\$out"'; then
    pass
else
    fail "expected bash/zsh try() wrapper, got: $output"
fi

CURRENT_TEST="init snippet references the binary path with exec subcommand"
output=$(try_run init "$TEST_TRIES")
if echo "$output" | grep -q " exec --path "; then
    pass
else
    fail "expected 'exec --path' invocation in snippet, got: $output"
fi

CURRENT_TEST="init with explicit path bakes it into the snippet"
output=$(try_run init "$TEST_TRIES")
if echo "$output" | grep -q -- "--path '$TEST_TRIES'"; then
    pass
else
    fail "expected explicit path baked into snippet, got: $output"
fi
