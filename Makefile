SHELL=/bin/bash
.PHONY: watch test pass lint clean start

watch:
	supervisor -e ".litcoffee|.coffee|.js" --exec make -- run-server

start: run-server

run-server: static/js/epiclient_v2.js static/js/epiclient_v3.js
	exec ./bin/npm-starter

difftest/templates:
	cd difftest/ && git clone https://github.com/igroff/epiquery-templates.git \
		templates/
test: build difftest/templates
	docker-compose up --force-recreate -d
	./bin/wait-for-epi
	docker-compose exec epiquery difftest run ${TEST_NAME}
	

test/codeship: build difftest/templates
	jet steps --tag codeship

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

push/%:
	git push origin master:$(@F)

node_modules/:
	npm install .

clean:
	rm -rf ./node_modules/
	docker-compose build --no-cache
