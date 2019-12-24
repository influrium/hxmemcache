LIB_NAME=hxmemcache
LIB_FILE=$(LIB_NAME).zip

upload:
	haxelib submit $(LIB_FILE)

lib: $(LIB_FILE) clean

$(LIB_FILE): haxelib.json src/*/*
	-mkdir temp
	cp haxelib.json temp/
	cp LICENSE temp/
	cp README.md temp/
	cp -R src temp/
	cd temp; zip -X -r $(LIB_FILE) .; mv $(LIB_FILE) ../

clean:
	-rm -rf temp
