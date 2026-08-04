install:
	yarn

# --no-autoinstall: parcel otherwise writes newly-discovered polyfills straight
# into package.json/yarn.lock mid-build, which desyncs the flake's
# fetchYarnDeps hash. The nix build is offline and never autoinstalls, so a
# missing dep should fail here too rather than be papered over.
build: clean
	npx parcel build --no-autoinstall src/index.html
	cp -r src/images dist/images

dev:
	npx parcel serve --no-autoinstall src/index.html

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
	prek run --all-files
