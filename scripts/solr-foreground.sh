#!/bin/bash

set -e
set -x

if [[ -v SOLR_PORT ]] && ! grep -E -q '^[0-9]+$' <<<"${SOLR_PORT}"; then
  echo "Invalid SOLR_PORT=$SOLR_PORT environment variable specified"
  exit 1
fi

echo "Starting Solr $SOLR_VERSION"

$SOLR_BIN/solr start -f -force