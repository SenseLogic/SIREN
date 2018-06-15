#!/bin/sh
set -x
dmd -m64 siren.d
rm *.o
