install:
	yarn

build: clean
	npx parcel build src/index.html

dev:
	npx parcel serve src/index.html

upgrade:
	yarn upgrade-interactive --latest

clean:
	rm -rf dist

reinstall:
	rm -rf node_modules
	rm -rf elm-stuff
	yarn

lint:
	npx elm-analyse
	npx elm-format --validate src/
