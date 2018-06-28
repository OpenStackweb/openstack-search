#!/bin/bash

set -e;

CORE=$1
CRAWL_ID=$2
SEEDS=$3
ITERATIONS=$4
DOMAIN=$5
TOP=$6

#echo "trying to get site map for $DOMAIN..."
#curl $DOMAIN/sitemap.xml | grep -e loc | sed 's|<loc>\(.*\)<\/loc>$|\1|g' > $SEEDS/sitemap.txt

echo "crawling for core $CORE crawl_id $CRAWL_ID seed $SEEDS";

for i in $(seq ${ITERATIONS}); do
      echo "Iteration $i"
      $NUTCH_HOME/runtime/local/bin/nutch inject $SEEDS -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch generate -topN $TOP -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch fetch -all -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch parse -all -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch updatedb -all -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch solrindex http://localhost:$SOLR_PORT/solr/$CORE -all -crawlId $CRAWL_ID
      $NUTCH_HOME/runtime/local/bin/nutch solrdedup http://localhost:$SOLR_PORT/solr/$CORE 
done

echo 'Done with all iterations'

curl "http://localhost:$SOLR_PORT/solr/$CORE/update?optimize=true"
