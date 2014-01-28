SHELL=/bin/bash
.PHONY: watch test pass lint clean

watch:
	DEBUG=true supervisor --ignore "./test"  -e ".coffee|.js" --exec bash ./ar-start

test/templates:
	cd test/ && git clone https://github.com/intimonkey/epiquery-templates.git \
		templates/

test: lint test/templates
	./test/run.sh ${TEST_NAME}

pass/%:
	cp test/results/$(subst pass/,,$@) test/expected/$(subst pass/,,$@)

show/%:
	cat test/results/$(subst show/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint 
	find ./static -name '*.js' | xargs ./node_modules/.bin/jshint 

static/js/sockjstest.js: static/js/src/wstest.coffee
	browserify -t coffeeify static/js/src/wstest.coffee > static/js/sockjstest.js

debug: static/js/sockjstest.js
	DEBUG=true PORT=8080 exec ./ar-start

clean:
	rm -rf ./node_modules/
