.PHONY: clean test pass

node_modules: 
	npm install .

log.js: node_modules src/log.coffee
	./node_modules/.bin/coffee --output . --compile src/log.coffee

test/results:
	mkdir -p test/results

clean:
	rm -rf ./node_modules/
	rm -rf ./test/node_modules/
	rm -rf ./test/results/*

test: node_modules test/results log.js
	cd ./test && npm install .
	./test/run.sh

commit: test
	git commit -a
	git push origin master

pass/%:
	cp test/results/$(subst pass/,,$@) test/expected/$(subst pass/,,$@)
