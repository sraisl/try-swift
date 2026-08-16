CURRENT_TEST="rename dialog emits mv script with new name"
output=$(try_script --path "$TEST_TRIES" exec cd beta --and-keys "CTRL-R,CTRL-U,TYPE=2026-08-14-renamed,ENTER")
if echo "$output" | grep -q "mv '2026-08-14-beta' '2026-08-14-renamed'"; then
    pass
else
    fail "expected mv script for rename, got: $output"
fi

CURRENT_TEST="rename script actually renames the directory when eval'd"
script=$(try_script --path "$TEST_TRIES" exec cd beta --and-keys "CTRL-R,CTRL-U,TYPE=2026-08-14-renamed,ENTER")
(cd /tmp && eval "$script") >/dev/null 2>&1
if [ ! -d "$TEST_TRIES/2026-08-14-beta" ] && [ -d "$TEST_TRIES/2026-08-14-renamed" ]; then
    pass
else
    fail "expected directory renamed on disk after eval"
fi
