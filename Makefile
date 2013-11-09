.PHONY: watch test pass

watch:
	DEBUG=true nodemon --ext .coffee server.coffee

test:
	./test/run.sh

pass/%:
	cp test/results/$(subst pass/,,$@) test/expected/$(subst pass/,,$@)
