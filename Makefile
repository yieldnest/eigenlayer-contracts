
.PHONY: deps
deps:
	brew install libusb
	curl -L https://foundry.paradigm.xyz | bash
	foundry up

.PHONY: compile
compile:
	forge b

.PHONY: bindings
bindings: compile
	./scripts/compileBindings.sh
