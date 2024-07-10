D=$(PWD)/build/out

all: test
test: provider proton
	./runtest.sh

provider:
	git submodule update --init pkcs11-provider
	meson setup build/pkcs11-provider pkcs11-provider
	meson compile -C build/pkcs11-provider
	DESTDIR=$D meson install -C build/pkcs11-provider

proton:
	git submodule update --init qpid-proton
	(cd qpid-proton; git am ../0001-HACK-PROTON-2594-cpp-connect_config_test-adapt-for-t.patch)
	cmake -S qpid-proton -B build/qpid-proton -DCMAKE_INSTALL_PREFIX=$D -DENABLE_WARNING_ERROR=OF
	cmake --build build/qpid-proton -j$$(nproc)
	cmake --install build/qpid-proton

.PHONY: provider proton distclean
distclean:
	rm -rf build/pkcs11-provider
	rm -rf build/qpid-proton
	rm -rf build/out
	git clean -x -f
	git submodule update --init
