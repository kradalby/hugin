install:
	yarn

build: clean
	npx parcel build src/index.html

dev:
	npx parcel serve src/index.html

upgrade:
	yarn upgrade-interactive --latest
	elm-json upgrade
	elm2nix convert > elm-srcs.nix
	elm2nix snapshot

clean:
	rm -rf dist

reinstall:
	rm -rf node_modules
	rm -rf elm-stuff
	yarn

lint:
	npx elm-analyse
	npx elm-format --validate src/
