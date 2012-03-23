#!/bin/sh
dmd ${DFLAGS} -ofdpk_boot src/dpk/*.d
rm -f dpk_boot.o
./dpk_boot test
echo ./dpk_boot help
./dpk_boot help
