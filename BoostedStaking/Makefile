tvcs = ExtraClient.tvc Concierge.tvc ExtraAccount.tvc
all: $(tvcs)

$(tvcs): %.tvc: %.sol
	tondev sol compile $^

clean:
	rm -f *.tvc *.abi.json
	rm -rf .solc_imports

rebuild: clean all
