ARG NODE_VERSION=10-alpine
ARG BASE=corpusops/node:$NODE_VERSION
FROM $BASE
WORKDIR /code
ADD src /code/src/
ADD package* /code/
ADD public /code/public/
RUN bash -c 'set -ex \
    && chown node:node -R /code \
    && cd /code' \
    && gosu node:node bash -c ' \
      npm install \
      && node npm run-script build
      && npm cache clean --force \
      && rsync -azv build/ public/' \
    && bash -c 'set -ex && cd /code \
      && while read f;do chmod 0755 $f;done < \
        <(find public -type d)
      && while read f;do chmod 0644 $f;done < \
        <(find public -type f)'
ADD local/terra-front-deploy/prod/init.sh /code/init/
ADD local/terra-front-deploy/prod/etc/    /etc/
ENTRYPOINT ["/code/init/init.sh"]
CMD ["node"]
