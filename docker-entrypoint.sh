#!/bin/bash
set -e
set -x

service mongodb start

service solr start

service cron start

exec "$@";
