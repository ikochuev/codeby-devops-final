FROM fluent/fluentd:v1.16.3-debian-1.0
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN gem install elasticsearch --no-document --version 8.19.0
RUN gem install fluent-plugin-elasticsearch --no-document --version 5.4.3
USER fluent
COPY conf/fluentd.conf /fluentd/etc/
