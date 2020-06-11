#!/bin/sh
read -r -e -p "version: " version
pod2man --name BASHMOUNT --release "bashmount $version" \
    --center  bashmount ./manpage.pod > bashmount.1
