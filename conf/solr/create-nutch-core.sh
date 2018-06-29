#!/bin/bash
set -e
set -x

CORE=$1
BASE_URL=$2
CRAWL_ID=$3

if [ -z "$CORE" ]
then
    echo "CORE not set, exiting ..."
    exit -1
fi

if [ -z "$BASE_URL" ]
then
    echo "BASE_URL not set, exiting ..."
    exit -1
fi

if [ -z "$CRAWL_ID" ]
then
    echo "CRAWL_ID not set, exiting ..."
    exit -1
fi

echo "creating core ${CORE}";
su - solr -c "${SOLR_BIN}/solr create_core -c $CORE -d basic_configs"
su - solr -c "cp ${CONF_HOME}/schema.xml ${SOLR_HOME}/${CORE}/conf/schema.xml"
su - solr -c "cp ${CONF_HOME}/solrconfig.xml ${SOLR_HOME}/${CORE}/conf/solrconfig.xml"
su - solr -c "rm ${SOLR_HOME}/${CORE}/conf/managed-schema"
echo "created core ${CORE}"

echo "setting nutch for core ${CORE}"

mkdir -p ${NUTCH_HOME}/urls/${CORE}
touch ${NUTCH_HOME}/urls/${CORE}/seeds.txt
echo "$BASE_URL" >> ${NUTCH_HOME}/urls/${CORE}/seeds.txt

echo "adding to nutch cron tab..."
echo "*/20 * * * * root . /root/env.sh && ${NUTCH_HOME}/crawler.sh ${CORE} ${CRAWL_ID} ${NUTCH_HOME}/urls/${CORE} 10 \"\" 50 >> /var/log/nutch_cron_${CORE}.log 2>&1
" >> /etc/cron.d/nutch-tab

service solr restart

exit 0
