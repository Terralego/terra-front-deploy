#!/bin/bash
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)
NPM_INSTALL=${NPM_INSTALL-}
RUN_NGINX=${RUN_NGINX-}
SKIP_SETTINGS=${SKIP_SETTINGS-}
# AS $user
set -e
set -x
NO_START=${NO_START-}
# Run app
# for dev or SSR
if [ ! -e node_modules/.bin ];then
    NPM_INSTALL=1
fi
# Usage: file_env 'XYZ_DB_PASSWORD' 'example'. This code is taken from:
# https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh
if [[ -z "$SKIP_SETTINGS" ]];then
    cat > $STATICS_DEST/injection.js << EOF
window.REACT_APP_API_URL = "{{cops_terralego_back_url}}/api"
window.REACT_APP_BASE_URL = "{{cops_terralego_back_url}}"
window.REACT_APP_SOURCE_VECTOR_URL = "{{cops_terralego_vector_tiles_url}}"
EOF
fi
if [[ -z $RUN_NGINX ]] && [[ -n $NPM_INSTALL ]];then
    npm install
fi
if [[ -z "${NO_START}" ]];then
    if [[ -z $RUN_NGINX ]];then
        exec npm start $@
    else
        envsubst '$HOSTNAME' \
            < /etc/nginx/conf.d/vhost.conf.template \
            > /etc/nginx/conf.d/default.conf
        exec nginx -g 'daemon off;'
    fi
else
    while true;do echo "start skipped" >&2;sleep 65535;done
fi
