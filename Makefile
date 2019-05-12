

install:
	yarn

build:
	env NODE_ENV=production npx webpack -p

dev:
	npx webpack-dev-server --hot --colors --port 8000

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
