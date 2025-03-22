FROM python:3.12-slim

ENV PIP_NO_CACHE_DIR=true

RUN pip install feast \
    && rm -rf ~/.cache/pip

ENV WORKDIR=/workspace/training-infra/feast

WORKDIR ${WORKDIR}

# TODO: copy existing files from feast/ directory
#COPY ../../feast/ ${WORKDIR}/

CMD echo "project: feast_project\n\
registry: data/registry.db\n\
provider: local\n\
online_store:\n\
  # TODO: connect to online redis instance, instead of using local file\n\
  # type: redis\n\
  # connection_string: redis://redis-${ENVIRONMENT}.redis.svc.cluster.local:6379/0\n\
  type: sqlite\n\
  path: data/online_store.db\n\
entity_key_serialization_version: 2\n\
auth:\n\
  type: no_auth" > ${WORKDIR}/feature_store.yaml && \
    cd ${WORKDIR} && \
    feast apply
