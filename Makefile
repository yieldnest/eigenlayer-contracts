
.PHONY: deps
deps:
	brew install libusb
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

.PHONY: compile
compile:
	forge b

.PHONY: bindings
bindings: compile
	./scripts/compileBindings.sh
