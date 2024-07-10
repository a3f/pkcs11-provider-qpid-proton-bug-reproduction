#!/bin/sh

set -e

export PKCS11_PROVIDER=$(find $PWD/build/out -wholename */ossl-modules/pkcs11.so)
export PKCS11_PROVIDER_MODULE="/usr/lib/softhsm/libsofthsm2.so"

if [ ! -r "$PKCS11_PROVIDER" ]; then
	echo "PKCS11_PROVIDER $PKCS11_PROVIDER not found"
	exit 1
fi

if [ ! -r "$PKCS11_PROVIDER_MODULE" ]; then
	echo "PKCS11_PROVIDER_MODUKE $PKCS11_PROVIDER_MODULE not found"
	exit 1
fi

export SOFTHSM2_CONF=$PWD/softhsm2.conf
export OPENSSL_CONF=$PWD/openssl-pkcs11.cnf

export PKCS11_MODULE_LOAD_BEHAVIOR=late

echo
echo "Running test without PKCS#11"
echo "============================"
cd build/out/share/proton/tests
./connect_config_test

echo
echo "Loading Keys into SoftHSM"
echo "========================="
cd testdata/certs

mkdir -p /tmp/softhsm-tokens-pkcs11-provider-qpid-proton-bug-reproduction

softhsm2-util --delete-token --token test 2>/dev/null || true
softhsm2-util --init-token --free --label test --pin tclientpw --so-pin tclientpw

alias pkcs11-tool="pkcs11-tool --module=$PKCS11_PROVIDER_MODULE --token-label test --pin tclientpw"

pkcs11-tool -l --label tclient --delete-object --type privkey 2>/dev/null || true

pkcs11-tool -l --label tclient --id 4444 \
	--write-object client-private-key-no-password.pem --type privkey --usage-sign

cd ../..

obj="pkcs11:token=test;id=%44%44;object=tclient"
# crashes for me when it's loaded early...
openssl storeutl -provider pkcs11 -keys -out pkcs11-key.pem "$obj"

echo
echo "Running test _with_ PKCS#11"
echo "==========================="
export PKCS11_MODULE_LOAD_BEHAVIOR=${LOAD_BEHAVIOR:-late}
export TEST_KEY=pkcs11-key.pem
# cat $TEST_KEY
if ./connect_config_test; then
	echo "==========================="
	echo SUCCESS!
	echo "==========================="
else
	echo "==========================="
	echo FAILURE! Now try again with LOAD_BEHAVIOR=early
	echo "==========================="
fi
