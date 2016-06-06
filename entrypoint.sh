#!/bin/bash

set +e

HOSTNAME=`hostname`

if [ "${1:0:1}" = '-' ]; then
  set -- mysqld "$@"
fi

# if the command passed is 'mysqld' via CMD, then begin processing.
if [ "$1" = 'mysqld' ]; then
  # read DATADIR from the MySQL config
  DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

  # only check if system tables not created from mysql_install_db and permissions
  # set with initial SQL script before proceeding to build SQL script
  if [ ! -d "$DATADIR/mysql" ]; then

    echo 'Running mysql_install_db ...'
    mysql_install_db --datadir="/var/lib/mysql"
    chown -R mysql:mysql /var/lib/mysql
    echo 'Finished mysql_install_db'

    # this script will be run once when MySQL first starts to set up
    # prior to creating system tables and will ensure proper user permissions
    tempSqlFile='/tmp/mysql-first-time.sql'
    cat > "$tempSqlFile" <<-EOSQL
DELETE FROM mysql.user;
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE USER '${WSREP_SST_USER}'@'localhost' IDENTIFIED BY '${WSREP_SST_PASSWORD}';
GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${WSREP_SST_USER}'@'localhost';
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS test;
CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so';
CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so';
CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so';
EOSQL

    sed -i -e "s/\(wsrep_sst_auth\=\).*/\1 $WSREP_SST_USER:$WSREP_SST_PASSWORD/" /etc/mysql/conf.d/cluster.cnf
    set -- "$@" --init-file="$tempSqlFile"
  fi
fi

# get info from kuberctl

TIME=$[ ( $RANDOM  % 10 ) + 1 ]
echo "sleep ${TIME}"
sleep $TIME
/kubectl create configmap percona-cluster --from-literal=wsrepclusterbootstraped=0
exitcode=$?
if [ $exitcode == 0 ]; then
    echo "Created"
    SERVER_ID=1
    WSREP_CLUSTER_ADDRESS="gcomm://"
    /kubectl get configmap -o json | sed "s/\(\"wsrepclusterbootstraped\"\).*$/\1: \"1\"/" | /kubectl replace -f -
    set -- "$@" --wsrep-new-cluster
else
    echo "Failed"
    SERVER_ID=${RANDOM}
    SERVICE=`/kubectl describe service/pxc-cluster | grep 4567 | grep -i endpoints | awk '{print $2}'`
    WSREP_CLUSTER_ADDRESS="gcomm://"
    WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS}${SERVICE}"
fi

WSREP_NODE_ADDRESS=`ip addr show | grep -E '^[ ]*inet' | grep -m1 global | awk '{ print $2 }' | sed -e 's/\/.*//'`
if [ -n "$WSREP_NODE_ADDRESS" ]; then
    sed -i -e "s/\(wsrep_node_address\=\).*$/\1$WSREP_NODE_ADDRESS/" /etc/mysql/conf.d/cluster.cnf
fi

sed -i -e "s/^server\-id\s*\=\s.*$/server-id = ${SERVER_ID}/" /etc/mysql/my.cnf
sed -i -e "s|\(wsrep_cluster_address\=\).*|\1${WSREP_CLUSTER_ADDRESS}|" /etc/mysql/conf.d/cluster.cnf
sed -i -e "s/\(wsrep_node_name\=\).*/\1${HOSTNAME}/" /etc/mysql/conf.d/cluster.cnf

cat /etc/mysql/conf.d/cluster.cnf

echo "sever-id: $SERVER_ID"
echo "wsrep_cluster_address: $WSREP_CLUSTER_ADDRESS"

# finally, start mysql
exec "$@"
