

install:
	yarn

build: clean
	env NODE_ENV=production npx webpack

build-debug:
	npx webpack

dev:
	npx webpack serve --hot --port 8000

upgrade:
	yarn upgrade --latest

clean:
	rm -rf dist

reinstall:
	rm -rf node_modules
	rm -rf elm-stuff
	yarn

lint:
	npx elm-analyse
	npx elm-format --validate src/
