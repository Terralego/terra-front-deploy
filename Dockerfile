ARG NODE_VERSION=10-alpine
ARG BASE=node:$NODE_VERSION
FROM $BASE
ARG TZ=Europe/Paris
ARG BUILD_DEV=y
# See https://github.com/nodejs/docker-node/issues/380
ARG GPG_KEYS=B42F6819007F00F88E364FD4036A9C25BF357DD4
ARG GPG_KEYS_SERVERS="hkp://p80.pool.sks-keyservers.net:80 hkp://ipv4.pool.sks-keyservers.net hkp://pgp.mit.edu:80"

WORKDIR /code
# setup project timezone, dependencies, user & workdir, gosu
ADD alpine.txt .
RUN sh -c 'set -ex \
    && apk update \
    && apk add -y $(grep -vE "^\s*#" ./alpine.txt  | tr "\n" " ") \
    && rm -rf /var/cache/apk/*' && bash -c 'set -ex\
    && : "project user & workdir" \
    && : ::: \
    && : install gosu \
    && : ::: \
    && mkdir /tmp/gosu && cd /tmp/gosu \
    && : :: gosu: search latest artefacts and SHA files \
    && arch=$( uname -m|sed -re "s/x86_64/amd64/g" ) \
    && : one keyserver may fail, try on multiple servers \
    && for k in $GPG_KEYS;do \
        touch /k_$k \
        && for s in $GPG_KEYS_SERVERS;do \
          if ( gpg -q --batch --keyserver $s --recv-keys $k );then \
            rm -f /k_$k && break;else echo "Keyserver failed: $s" >&2;fi;done \
        && if [ -e /k_$k ];then exit 1;fi \
       done \
    && urls="$( curl -s "https://api.github.com/repos/tianon/gosu/releases/latest" \
               | grep browser_download_url | cut -d "\"" -f 4\
               | egrep -i "sha|$arch"; )" \
    && : :: gosu: download artefacts \
    && while read u;do curl -sLO $u;done <<< "$urls" \
    && : :: gosu: integrity check \
    && for i in SHA256SUMS gosu-$arch;do gpg -q --batch --verify $i.asc $i &> /dev/null;done \
    && grep gosu-$arch SHA256SUMS | sha256sum -c - >/dev/null \
    && : :: gosu: filesystem install \
    && mv -f gosu-$arch /usr/bin/gosu \
    && chmod +x /usr/bin/gosu && cd / && rm -rf /tmp/gosu \
    && : ::: \
    && : "install https://github.com/jwilder/dockerize" \
    && : ::: \
    && mkdir /tmp/dockerize && cd /tmp/dockerize \
    && : :: dockerize: search latest artefacts and SHA files \
    && arch=$( uname -m|sed -re "s/x86_64/amd64/g" ) \
    && urls="$(curl -s \
        "https://api.github.com/repos/jwilder/dockerize/releases/latest" \
        | grep browser_download_url | cut -d "\"" -f 4\
        | ( if [ -e /etc/alpine-release ];then grep alpine;else grep -v alpine;fi; ) \
        | egrep -i "($(uname -s).*$arch|sha)" )" \
    && : :: dockerize: download and unpack artefacts \
    && while read u;do curl -sLO $u && tar -xf $(basename $u);done <<< "$urls" \
    && mv -f dockerize /usr/bin/dockerize \
    && chmod +x /usr/bin/dockerize && cd / && rm -rf /tmp/dockerize'

ADD crontab /etc/cron.d/node
ADD package* /code/
ADD local/terra-front-deploy/prod/cron.sh \
    local/terra-front-deploy/prod/start.sh \
    local/terra-front-deploy/prod/init.sh \
    /code/init/

CMD
# Install deps
RUN bash -c 'set -ex \
    && chmod 0644 /etc/cron.d/node \
    && chown node:node -R /code \
    && cd /code \
    && gosu node:node bash -c " \
    npm install && npm cache clean --force \
    "'
# image will drop privileges itself using gosu
# Expose ports (for orchestrators and dynamic reverse proxies)
ADD public /code/public/
ADD src /code/src/
EXPOSE 3000
# Start the app
CMD "/code/init/init.sh"
