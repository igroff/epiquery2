SHELL=/bin/bash
.PHONY: watch test pass lint

watch:
	DEBUG=true nodemon --ext .coffee --exec bash nodemon_helper

test/templates:
	cd test/ && git clone https://github.com/intimonkey/epiquery-templates.git \
		templates/

test: lint test/templates
	./test/run.sh ${TEST_NAME}

pass/%:
	cp test/results/$(subst pass/,,$@) test/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint 
	find ./static -name '*.js' | xargs ./node_modules/.bin/jshint 

