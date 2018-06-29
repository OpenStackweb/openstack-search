#!/bin/bash
set -e
set -x

service mongodb start

service solr start

service cron start

# run crawler first time

. /root/env.sh && $NUTCH_HOME/crawler.sh www-openstack 1 $NUTCH_HOME/urls/www 10 https://www.openstack.org 50
. /root/env.sh && $NUTCH_HOME/crawler.sh docs-openstack 2 $NUTCH_HOME/urls/docs 10 https://docs.openstack 50
. /root/env.sh && $NUTCH_HOME/crawler.sh superuser-openstack 3 $NUTCH_HOME/urls/superuser 10 http://superuser.openstack.org 50

exec "$@";
