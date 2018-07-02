#!/bin/bash

set -e;

CORE=$1
CRAWL_ID=$2
SEEDS=$3
ITERATIONS=$4
DOMAIN=$5
TOP=$6

echo "CORE ${CORE} CRAWL_ID ${CRAWL_ID} SEEDS ${SEEDS} DEPTH ${ITERATIONS} DOMAIN ${DOMAIN} TOP ${TOP}";

#############################################
# MODIFY THE PARAMETERS BELOW TO YOUR NEEDS #
#############################################

# set the number of slaves nodes
numSlaves=1

# and the total number of available tasks
# sets Hadoop parameter "mapred.reduce.tasks"
numTasks=`expr $numSlaves \* 2`

# number of urls to fetch in one iteration
# 250K per task?
sizeFetchlist=`expr $numSlaves \* 50000`

# time limit for fetching
timeLimitFetch=180
skipRecordsOptions="-D mapred.skip.attempts.to.start.skipping=2 -D mapred.skip.map.max.skip.records=1"
commonOptions="-D mapred.reduce.tasks=$numTasks -D mapred.child.java.opts=-Xmx1000m -D mapred.reduce.tasks.speculative.execution=false -D mapred.map.tasks.speculative.execution=false -D mapred.compress.map.output=true"
if [ -z "$DOMAIN" ]
then
    echo "DOMAIN not set, skipping sitemap retrieval..."
else
    echo "trying to get site map for $DOMAIN..."
    curl $DOMAIN/sitemap.xml | grep -e loc | sed 's|<loc>\(.*\)<\/loc>$|\1|g' > $SEEDS/sitemap.txt
fi
echo "crawling for core $CORE crawl_id $CRAWL_ID seed $SEEDS";
$NUTCH_HOME/runtime/local/bin/nutch inject $SEEDS -crawlId $CRAWL_ID

for i in $(seq ${ITERATIONS}); do
      echo "Iteration $i"

      batchId=`date +%s`-$RANDOM
      echo "doing generate"
      $NUTCH_HOME/runtime/local/bin/nutch generate $commonOptions -topN $TOP -noNorm -noFilter -crawlId $CRAWL_ID -batchId $batchId
      echo "doing fetch"
      $NUTCH_HOME/runtime/local/bin/nutch fetch $commonOptions -D fetcher.timelimit.mins=$timeLimitFetch $batchId -crawlId $CRAWL_ID -threads 50
      echo "doing parse"
      $NUTCH_HOME/runtime/local/bin/nutch parse $commonOptions $skipRecordsOptions $batchId -crawlId $CRAWL_ID
      echo "doing updatedb"
      $NUTCH_HOME/runtime/local/bin/nutch updatedb $commonOptions $batchId -crawlId $CRAWL_ID
      echo "doing solrindex"
      $NUTCH_HOME/runtime/local/bin/nutch solrindex http://localhost:$SOLR_PORT/solr/$CORE -all -crawlId $CRAWL_ID
      echo "doing solrdedup"
      $NUTCH_HOME/runtime/local/bin/nutch solrdedup http://localhost:$SOLR_PORT/solr/$CORE
done

echo 'Done with all iterations'

exit 0;