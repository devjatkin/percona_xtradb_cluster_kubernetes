FROM ubuntu:xenial

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A

RUN echo "deb http://repo.percona.com/apt xenial main" > /etc/apt/sources.list.d/percona.list
RUN echo "deb-src http://repo.percona.com/apt xenial main" >> /etc/apt/sources.list.d/percona.list

RUN apt-get update
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get install -y percona-xtradb-cluster-56 curl

# clean up
RUN rm -rf /var/lib/apt/lists/* \
RUN rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql && chown -R mysql:mysql /var/lib/mysql

RUN curl -o kubectl curl -O https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl
RUN chmod +x kubectl

VOLUME /var/lib/mysql

COPY my.cnf /etc/mysql/my.cnf
COPY cluster.cnf /etc/mysql/conf.d/cluster.cnf

# mysql
EXPOSE 3306
# state-snapshot-transfer
EXPOSE 4444
# replication-traffic
EXPOSE 4567
# incremental-state-transfer
EXPOSE 4568

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["mysqld"]
#CMD ["/bin/bash"]
