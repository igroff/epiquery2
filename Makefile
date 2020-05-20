SHELL=/bin/bash
.PHONY: watch test pass lint clean start

watch: build
	TZ=UTC ./node_modules/.bin/supervisor -e "litcoffee,coffee" --exec /bin/bash -- ./bin/npm-starter

start: run-server

run-server: static/js/epiclient_v2.js static/js/epiclient_v3.js
	exec ./bin/npm-starter

difftest/templates:
	cd difftest/ && git clone https://github.com/igroff/epiquery-templates.git \
		templates/

test: node_modules/ difftest/templates
	docker-compose up -d
	PATH=./node_modules/.bin:${PATH} ./node_modules/.bin/difftest run ${TEST_NAME}

pass/%:
	cp difftest/results/$(subst pass/,,$@) difftest/expected/$(subst pass/,,$@)

lint:
	find ./src -name '*.coffee' | xargs ./node_modules/.bin/coffeelint -f ./etc/coffeelint.conf
	find ./src -name '*.js' | xargs ./node_modules/.bin/jshint 

static/js/sockjstest.js: static/js/src/wstest.coffee
	./node_modules/.bin/browserify -t coffeeify static/js/src/wstest.coffee > static/js/sockjstest.js

static/js/epiclient_v3.js: src/clients/EpiClient.coffee
	./node_modules/.bin/browserify -t coffeeify -r ./src/clients/EpiClient.coffee:epi-client --outfile $@

static/js/hunting-websocket.js: src/clients/hunting-websocket.litcoffee
	./node_modules/.bin/browserify -t coffeeify src/clients/hunting-websocket.litcoffee --outfile $@

build: static/js/epiclient_v3.js node_modules/

deploy/%:
	git push --force origin master:deploy$(@F)

node_modules/:
	npm install .

clean:
	rm -rf ./node_modules/
