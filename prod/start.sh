#!/bin/bash
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)
NPM_INSTALL=${NPM_INSTALL-}
# AS $user
set -e
set -x
NO_START=${NO_START-}
# Run app
# for dev
if [ ! -e node_modules/.bin ];then
    NPM_INSTALL=1
fi
if [[ -n $NPM_INSTALL ]];then
    npm install
fi
if [[ -z "${NO_START}" ]];then
    exec npm start $@
else
    while true;do echo "start skipped" >&2;sleep 65535;done
fi
