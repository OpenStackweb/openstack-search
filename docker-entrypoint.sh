#!/bin/bash
set -e
set -x

service mongodb start

service solr start

service cron start

# run crawler first time

. /root/env.sh && $NUTCH_HOME/crawler.sh www-openstack 1 $NUTCH_HOME/urls/www

exec "$@";
