.PHONY: watch test pass

watch:
	DEBUG=true nodemon --ext .coffee server.coffee

test/templates:
	cd test/ && git clone https://github.com/intimonkey/epiquery-templates.git \
		templates/

test: test/templates
	./test/run.sh

pass/%:
	cp test/results/$(subst pass/,,$@) test/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
