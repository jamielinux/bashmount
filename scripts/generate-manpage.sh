#!/bin/sh
read -r -e -p "version: " version
cat ./manpage.pod \
  | pod2man --name BASHMOUNT --release "bashmount $version" --center bashmount \
  > bashmount.1
