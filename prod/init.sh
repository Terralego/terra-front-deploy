#!/bin/bash
# docker-compose run nginx
# docker-compose run node
# docker-compose run run $img bash
# docker-compose run run $img npminstall
if [[ "${NO_START-}" ]];then
    while true;do echo "start skipped" >&2;sleep 65535;done
    exit 0
fi
# load locales & default env
for i in /etc/environment /etc/default/locale;do if [ -e $i ];then . $i;fi;done
# AS root
set -e
NODE_SDEBUG=${NODE_SDEBUG-${SDEBUG-}}
if [[ -n "${NODE_SDEBUG}" ]];then set -x;fi
SCRIPTSDIR="$(dirname $(readlink -f "$0"))"
cd "$SCRIPTSDIR/.."
TOPDIR=$(pwd)
# one of: nginx|node
IMAGE_MODE="${IMAGE_MODE-}"
FINDPERMS_PERMS_DIRS_CANDIDATES="${FINDPERMS_PERMS_DIRS_CANDIDATES:-"public"}"
FINDPERMS_OWNERSHIP_DIRS_CANDIDATES="${FINDPERMS_OWNERSHIP_DIRS_CANDIDATES:-"public node_modules"}"
export APP_TYPE="${APP_TYPE:-node}"
export ENV_JSON="${ENV_JSON-$TOPDIR/public/env.json}"
export USER_DIRS=". build"
if [[ "$IMAGE_MODE" = "nginx" ]];then
    export APP_USER="${APP_USER:-nginx}"
    export USER_DIRS=""
    NO_FIXPERMS="${NGINX_NO_FIX_PERMS-${NO_FIXPERMS:-1}}"
else
    export APP_USER="${APP_USER:-$APP_TYPE}"
fi
export APP_GROUP="$APP_USER"
SHELL_USER=${SHELL_USER:-${APP_USER}}
if [[ $IMAGE_MODE = "node" ]];then
    for i in $TOPDIR/node_modules/.bin;do
        if [ -e "$i" ];then export PATH=$i:$PATH;fi
    done
fi
NPM_INSTALL=${NPM_INSTALL-}
NO_INSTALL="${NO_INSTALL-}"
NO_SETTINGS="${NO_SETTINGS-}"
NO_FIXPERMS="${NO_FIXPERMS-}"
FINDPERMS_DIRS=""
for i in $FINDPERMS_DIRS_CANDIDATES;do
    if [ -e "$i" ];then
    FINDPERMS_DIRS="$FINDPERMS_DIRS $i"
    fi
done

_shell() {
    local pre=""
    local user="$APP_USER"
    if [[ -n $1 ]];then user=$1;shift;fi
    local bargs="$@"
    local NO_VIRTUALENV=${NO_VIRTUALENV-}
    local NO_NVM=${NO_VIRTUALENV-}
    local NVMRC=${NVMRC:-.nvmrc}
    local NVM_PATH=${NVM_PATH:-..}
    local NVM_PATHS=${NVMS_PATH:-${NVM_PATH}}
    local VENV_NAME=${VENV_NAME:-venv}
    local VENV_PATHS=${VENV_PATHS:-./$VENV_NAME ../$VENV_NAME}
    local DOCKER_SHELL=${DOCKER_SHELL-}
    local pre="DOCKER_SHELL=\"$DOCKER_SHELL\";touch \$HOME/.control_bash_rc;
    if [ \"x\$DOCKER_SHELL\" = \"x\" ];then
        if ( bash --version >/dev/null 2>&1 );then \
            DOCKER_SHELL=\"bash\"; else DOCKER_SHELL=\"sh\";fi;
    fi"
    if [[ -z "$NO_NVM" ]];then
        if [[ -n "$pre" ]];then pre=" && $pre";fi
        pre="for i in $NVM_PATHS;do \
        if [ -e \$i/$NVMRC ] && ( nvm --help > /dev/null );then \
            printf \"\ncd \$i && nvm install \
            && nvm use && cd - && break\n\">>\$HOME/.control_bash_rc; \
        fi;done $pre"
    fi
    if [[ -z "$NO_VIRTUALENV" ]];then
        if [[ -n "$pre" ]];then pre=" && $pre";fi
        pre="for i in $VENV_PATHS;do \
        if [ -e \$i/bin/activate ];then \
            printf \"\n. \$i/bin/activate\n\">>\$HOME/.control_bash_rc && break;\
        fi;done $pre"
    fi
    if [[ -z "$bargs" ]];then
        bargs="$pre && if ( echo \"\$DOCKER_SHELL\" | grep -q bash );then \
            exec bash --init-file \$HOME/.control_bash_rc -i;\
            else . \$HOME/.control_bash_rc && exec sh -i;fi"
    else
        bargs="$pre && . \$HOME/.control_bash_rc && \$DOCKER_SHELL -c \"$bargs\""
    fi
    export TERM="$TERM"; export COLUMNS="$COLUMNS"; export LINES="$LINES"
    exec gosu $user sh $( if [[ -z "$bargs" ]];then echo "-i";fi ) -c "$bargs"
}

fixperms() {
    if [[ -z $NO_FIXPERMS ]];then
        while read f;do chmod 0755 "$f";done < \
            <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type d \
              -not \( -perm 0755 \) |sort)
        while read f;do chmod 0644 "$f";done < \
            <(find $FINDPERMS_PERMS_DIRS_CANDIDATES -type f \
              -not \( -perm 0644 \) |sort)
        while read f;do chown $APP_USER:$APP_USER "$f";done < \
            <(find $FINDPERMS_OWNERSHIP_DIRS_CANDIDATES \
              \( -type d -or -type f \) \
              -and -not \( -user $APP_USER -and -group $APP_GROUP \) |sort)
    fi
}

#### main
# handle package*json stuff (mounting as file wont work with npm)
while read i;do
    ln -sfv "$i" "/code/$(basename $i)"
done < \
    <( find /hostdir -maxdepth 1 -type f \
       \( -name package.json -or -name package-lock.json \) \
       2>/dev/null||/bin/true)
for i in $USER_DIRS;do
    if [ ! -e "$i" ];then mkdir -p "$i";fi
    if ( getent passwd $APP_USER >/dev/null 2>&1);then
        chown $APP_USER:$APP_GROUP "$i"
    fi
done
chown -Rf root:root /etc/sudoers*
fixperms
if [[ -z $NO_SETTINGS ]];then
    touch $ENV_JSON
    chown $APP_USER $ENV_JSON
    chmod 644  $ENV_JSON
    cat prod/env.dist.json | gosu $APP_USER sh -c \
        "CONF_PREFIX='FRONT__' confenvsubst.sh>$ENV_JSON"
fi
if [[ -z $NO_INSTALL ]] && [[ "$IMAGE_MODE" = "node" ]];then
    if [ ! -e node_modules/.bin ];then NPM_INSTALL=1;fi
    if [[ -n $NPM_INSTALL ]];then
        npm install && fixperms
    fi
fi
if [[ -z $@ ]];then
    if [[ "$IMAGE_MODE" = "nginx" ]];then
        # Run nginx
        CONF_PREFIX='FRONT__' confenvsubst.sh /etc/nginx/conf.d/default.conf.template
        export SUPERVISORD_CONFIGS=${SUPERVISORD_CONFIGS:-/etc/supervisor.d/cron /etc/supervisor.d/nginx}
    elif [[ "$IMAGE_MODE" = "node" ]];then
        # Run app (eg: for dev or SSR)
        export SUPERVISORD_NPM_ARGS="${@-}"
        export SUPERVISORD_CONFIGS=${SUPERVISORD_CONFIGS:-/etc/supervisor.d/cron /etc/supervisor.d/npm}
    fi
    exec /bin/supervisord.sh
else
    _shell $SHELL_USER "$@"
fi
