#!/bin/bash

dirName=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

######################
######## INIT ########
######################

echo "Setup Dependencies..."

"$dirName"/init/init.sh

