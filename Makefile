SHELL=/bin/bash
.PHONY: watch test pass lint clean

watch:
	DEBUG=true supervisor --ignore "./test"  -e ".coffee|.js" --exec bash ./ar-start

test/templates:
	cd test/ && git clone https://github.com/intimonkey/epiquery-templates.git \
		templates/

test: build lint test/templates
	difftest run ${TEST_NAME}

pass/%:
	cp difftest/results/$(subst pass/,,$@) difftest/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint 

static/js/sockjstest.js: static/js/src/wstest.coffee
	browserify -t coffeeify static/js/src/wstest.coffee > static/js/sockjstest.js

static/js/epiclient.js: src/clients/browserclient.coffee src/clients/EpiClient.coffee
	browserify -t coffeeify src/clients/browserclient.coffee --outfile $@

debug: static/js/sockjstest.js
	DEBUG=true PORT=8080 exec ./ar-start

build: static/js/epiclient.js

clean:
	rm -rf ./node_modules/
