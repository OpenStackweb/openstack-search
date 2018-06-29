# Docker for Openstack Search Service

# build

docker build -t openstack-search .

# run

docker run --name openstack-search1 -p 32769:8983 -it -d openstack-search

# connect

docker exec -it openstack-search1 /bin/bash

by default creates 3 cores

# default solr cores

* www site
* docs site
* super users


# create new core on existing container instance

docker exec -it openstack-search1 create-nutch-core.sh new-core-name "http://test.com" CRAWL_ID
