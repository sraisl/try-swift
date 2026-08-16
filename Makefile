.PHONY: build test test-acceptance install clean

PREFIX ?= /usr/local

build:
	swift build -c release

test:
	swift test

test-acceptance: build
	bash AcceptanceTests/runner.sh .build/release/try

install: build
	install -d "$(PREFIX)/bin"
	install ".build/release/try" "$(PREFIX)/bin/try"

clean:
	rm -rf .build
