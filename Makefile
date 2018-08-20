#
#
#

all: clean install build

build: ;@echo "-- Building project"
# elm-make src/App.elm --output=./dist/app.js
	npm run build

prod: ;@echo "-- Building production and deploying"
	npm run prod
	ssh seel "rm -rf /usr/local/www/hugin.kradalby.no/*"
	scp -r dist/* seel:/usr/local/www/hugin.kradalby.no/. 


dev: ;@echo "-- Staring dev server"
# elm reactor ./src
	npm run dev

clean: ;@echo "-- Cleaning up dist files"
	rm -rf dist/

install: ;@echo "-- Installing dependencies"
	elm package install -y
	npm i --silent
	./node_modules/.bin/bower install


deinstall: ;@echo "-- Removing dependencies"
	rm -rf elm-stuff/
	rm -rf node_modules/

watch: ;@echo "-- watching files"
	npm run watch
