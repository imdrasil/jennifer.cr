FROM crystallang/crystal:1.8

RUN apt-get update -qq \
  && apt-get install -y \
    libpq-dev \
    libmysqlclient-dev \
    libreadline-dev \
    curl \
    vim

WORKDIR /app

COPY shard.yml shard.lock shard.override.yml /app

RUN shards

CMD ["bash"]
