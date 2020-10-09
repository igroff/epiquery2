SHELL=/bin/bash

export PATH := ./node_modules/.bin:$(PATH)
.PHONY: watch test pass lint clean start ci

watch: build
	TZ=UTC ./node_modules/.bin/supervisor -e "litcoffee,coffee" --exec /bin/bash -- ./bin/npm-starter

start: run-server

run-server: static/js/epiclient_v2.js static/js/epiclient_v3.js
	exec ./bin/npm-starter

ci: node_modules/
	difftest run ${TEST_NAME}

test: node_modules/
	docker-compose up --detach
	difftest run ${TEST_NAME}

pass/%:
	cp difftest/results/$(subst pass/,,$@) difftest/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs coffeelint --file ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs jshint

static/js/sockjstest.js: static/js/src/wstest.coffee
	browserify --transform coffeeify static/js/src/wstest.coffee > static/js/sockjstest.js

static/js/epiclient_v3.js: src/clients/EpiClient.coffee
	browserify --transform coffeeify --require ./src/clients/EpiClient.coffee:epi-client --outfile $@

static/js/hunting-websocket.js: src/clients/hunting-websocket.litcoffee
	browserify --transform coffeeify src/clients/hunting-websocket.litcoffee --outfile $@

build: static/js/epiclient_v3.js node_modules/

deploy/%:
	git push --force origin master:deploy$(@F)

node_modules/:
	npm install .

clean:
	rm -rf ./node_modules/
