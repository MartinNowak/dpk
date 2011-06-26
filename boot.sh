#!/bin/sh
dmd -ofdpk_boot src/dpk/*.d
echo "RUNNING TESTS"
rm dpk_boot.o
./dpk_boot test
