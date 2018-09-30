#!/bin/bash
set -e
set -x

service mongodb start

service cron start

exec "$@";
