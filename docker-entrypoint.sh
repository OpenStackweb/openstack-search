#!/bin/bash
set -e
set -x

service mongodb start

service solr start

service cron start

# run crawler first time

. /root/env.sh && $NUTCH_HOME/crawler.sh www-openstack 1 $NUTCH_HOME/urls/www $DEFAULT_DEPTH https://www.openstack.org $DEFAULT_TOP $NUTCH_LOCAL_CONF/www >> /var/log/nutch_cron_www.log
. /root/env.sh && $NUTCH_HOME/crawler.sh docs-openstack 2 $NUTCH_HOME/urls/docs 250 https://docs.openstack 10000  $NUTCH_LOCAL_CONF/docs >> /var/log/nutch_cron_docs.log
. /root/env.sh && $NUTCH_HOME/crawler.sh superuser-openstack 3 $NUTCH_HOME/urls/superuser $DEFAULT_DEPTH "" $DEFAULT_TOP $NUTCH_LOCAL_CONF/superuser >> /var/log/nutch_cron_superuser.log
. /root/env.sh && $NUTCH_HOME/crawler.sh blog 4 $NUTCH_HOME/urls/blog 50 "" 10000 $NUTCH_LOCAL_CONF/blog >> /var/log/nutch_cron_blog.log

exec "$@";
