SHELL=/bin/bash
.PHONY: watch test pass lint clean

watch: static/js/epiclient_v2.js
	DEBUG=true supervisor --ignore "./test"  -e ".litcoffee|.coffee|.js" --exec bash ./ar-start

difftest/templates:
	cd difftest/ && git clone https://github.com/igroff/epiquery-templates.git \
		templates/

test: build lint difftest/templates
	difftest run ${TEST_NAME}

pass/%:
	cp difftest/results/$(subst pass/,,$@) difftest/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint 

static/js/sockjstest.js: static/js/src/wstest.coffee
	browserify -t coffeeify static/js/src/wstest.coffee > static/js/sockjstest.js

static/js/epiclient_v2.js: src/clients/hunting-websocket.litcoffee src/clients/reconnecting-websocket.litcoffee src/clients/browserclient.coffee src/clients/reconnecting-websocket.js src/clients/EpiClient.coffee
	browserify -t coffeeify src/clients/browserclient.coffee --outfile $@

static/js/hunting-websocket.js: src/clients/hunting-websocket.litcoffee
	browserify -t coffeeify src/clients/hunting-websocket.litcoffee --outfile $@

debug: static/js/sockjstest.js
	DEBUG=true PORT=8080 exec ./ar-start

build: static/js/epiclient_v2.js

clean:
	rm -rf ./node_modules/
