SHELL=/bin/bash
.PHONY: watch test pass lint clean

difftest/templates:
	cd difftest/ && git clone https://github.com/igroff/epiquery-templates.git \
		templates/

test: difftest/templates
	./node_modules/.bin/difftest run ${TEST_NAME}

pass/%:
	cp difftest/results/$(subst pass/,,$@) difftest/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint

clean:
	rm -rf ./node_modules/
