#!/bin/bash
set -e
set -x

CORE=$1
SEED_URL=$2

if [ -z "$CORE" ]
then
    echo "CORE not set, exiting ..."
    exit -1
fi

if [ -z "$SEED_URL" ]
then
    echo "SEED_URL not set, exiting ..."
    exit -1
fi

CRAWLID_FILE=~/.lastcrawlid

if [ -f $CRAWLID_FILE ]; then
   . $CRAWLID_FILE
else
   touch $CRAWLID_FILE
fi

echo "creating core ${CORE}";
su - solr -c "${SOLR_BIN}/solr create_core -c $CORE -d basic_configs"
su - solr -c "cp ${CONF_HOME}/schema.xml ${SOLR_HOME}/${CORE}/conf/schema.xml"
su - solr -c "cp ${CONF_HOME}/solrconfig.xml ${SOLR_HOME}/${CORE}/conf/solrconfig.xml"
su - solr -c "rm ${SOLR_HOME}/${CORE}/conf/managed-schema"
echo "created core ${CORE}"

echo "setting nutch for core ${CORE}"

mkdir -p ${NUTCH_LOCAL_CONF}/${CORE} && cp ${NUTCH_LOCAL_CONF_TPL}/* ${NUTCH_LOCAL_CONF}/${CORE}
mkdir -p ${NUTCH_HOME}/urls/${CORE}
touch ${NUTCH_HOME}/urls/${CORE}/seeds.txt
echo "${SEED_URL}" >> ${NUTCH_HOME}/urls/${CORE}/seeds.txt

echo "adding to nutch cron tab ..."
# run each 6 hours
echo "0 */6 * * * root . /root/env.sh && /usr/bin/flock -xn /tmp/${CORE}.lockfile ${NUTCH_HOME}/crawler.sh ${CORE} ${LAST_CRAWL_ID} ${NUTCH_HOME}/urls/${CORE} $DEFAULT_DEPTH \"\" $DEFAULT_TOP ${NUTCH_LOCAL_CONF}/${CORE} >> /var/log/nutch_cron_${CORE}.log 2>&1
" >> /etc/cron.d/nutch-tab

LAST_CRAWL_ID=$((LAST_CRAWL_ID+1))
echo "LAST_CRAWL_ID=${LAST_CRAWL_ID}" > $CRAWLID_FILE

service solr restart

exit 0
