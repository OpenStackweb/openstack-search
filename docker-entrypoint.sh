#!/bin/bash
set -e
set -x

service mongodb start

service solr start

service cron start

# run crawler first time

. /root/env.sh && $NUTCH_HOME/crawler.sh www-openstack 1 $NUTCH_HOME/urls/www $DEFAULT_DEPTH https://www.openstack.org $DEFAULT_TOP
. /root/env.sh && $NUTCH_HOME/crawler.sh docs-openstack 2 $NUTCH_HOME/urls/docs $DEFAULT_DEPTH https://docs.openstack $DEFAULT_TOP
. /root/env.sh && $NUTCH_HOME/crawler.sh superuser-openstack 3 $NUTCH_HOME/urls/superuser $DEFAULT_DEPTH "" $DEFAULT_TOP

exec "$@";
