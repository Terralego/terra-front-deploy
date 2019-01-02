#!/bin/bash
CONF_PREFIX=FRONT_
get_conf_vars() {
    echo $( env | egrep "${CONF_PREFIX}[^=]+=.*" \
    | sed -e "s/\(${CONF_PREFIX}[^=]\+\)=.*/$\1;/g";); }
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)
NPM_INSTALL=${NPM_INSTALL-}
export FOREGO_PROCFILE="${FOREGO_PROCFILE:-"/etc/procfiles/nginx_logrotate.Procfile"}"
RUN_NGINX=${RUN_NGINX-}
SKIP_SETTINGS=${SKIP_SETTINGS-}
# AS $user
set -ex
NO_START=${NO_START-}
# Run app
# for dev or SSR
if [ ! -e node_modules/.bin ];then NPM_INSTALL=1;fi
# Usage: file_env 'XYZ_DB_PASSWORD' 'example'. This code is taken from:
# https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh
if [[ -z "$SKIP_SETTINGS" ]];then
    cat > $STATICS_DEST/injection.js << EOF
window.REACT_APP_API_URL = "$FRONT_BACK_URL/api"
window.REACT_APP_BASE_URL = "$FRONT_BACK_URL"
window.REACT_APP_SOURCE_VECTOR_URL = "$FRONT_TILES_URL"
EOF
fi
if [[ -z $RUN_NGINX ]] && [[ -n $NPM_INSTALL ]];then
    npm install
fi
if [[ -z "${NO_START}" ]];then
    if [[ -z $RUN_NGINX ]]
    then exec npm start $@
    else exec /bin/forego.sh
    fi
else while true;do echo "start skipped" >&2;sleep 65535;done;fi
