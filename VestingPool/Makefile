tvcs = VestingService.tvc VestingPool.tvc
all: $(tvcs)

$(tvcs): %.tvc: %.sol
	everdev sol compile $^

clean:
	rm -f *.tvc *.abi.json
	rm -rf .solc_imports

rebuild: clean all