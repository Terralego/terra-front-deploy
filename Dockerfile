ARG NODE_BASE_NODE_VERSION=10-alpine
ARG NODE_BASE_NODE_IMAGE=corpusops/node
FROM $NODE_BASE_NODE_IMAGE:$NODE_BASE_NODE_VERSION
ENV IMAGE_MODE=node
WORKDIR /code
ADD src /code/src/
ADD package* /code/
ADD public /code/public/
RUN bash -c 'set -ex \
    && chown node:node -R /code \
    && cd /code' \
    && gosu node:node bash -c 'set -ex \
      && npm install \
      && npm run-script build \
      && npm cache clean --force \
      && while read f;do cp -rf "$f" public;done < \
           <(find build -maxdepth 1 -mindepth 1) \
      && rm -rf build' \
    && bash -c 'set -ex && cd /code \
      && while read f;do chmod 0755 "$f";done < \
        <(find public -type d) \
      && while read f;do chmod 0644 "$f";done < \
        <(find public -type f)'
ADD prod/env.dist.json /code/prod/
ADD local/terra-front-deploy/prod/init.sh /code/init/
ADD local/terra-front-deploy/prod/etc/    /etc/
ENTRYPOINT ["/code/init/init.sh"]
CMD []
