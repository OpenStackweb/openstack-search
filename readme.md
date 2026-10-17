# Docker for Openstack Search Service

# Offline crawler control-flow checks

Run `python3 -m unittest discover -s tests -v` and
`bash -n conf/nutch/crawler.sh`. The tests run the actual crawler shell script
against temporary Nutch/curl stubs. They cover normal batches, Nutch's empty
fetch-list status (1), unexpected generate failures and failures in each later
pipeline stage. They do not fetch pages or modify an index, and do not establish
deployed crawler freshness, robots handling or stale-result deletion behavior.

# build

````
docker build -t openstack-search .
````

# run

* create local bridge

````
docker network create -d bridge --subnet 192.168.0.0/24 --gateway 192.168.0.1 docker-bridge
````

* run container

````
docker run --name openstack-search1 \
-v mongo-data-db:/data/db \
-v mongo-data-config-db:/data/configdb \
-v solr-data:/var/solr/data \
--net=docker-bridge \
-p 32769:8983 -d -m 8GB --oom-kill-disable \
--restart=always openstack-search
````

# connect

````
docker exec -it openstack-search1 /bin/bash
````

* check process using supervisord

````
supervisorctl
````

by default creates 4 cores

# default solr cores

* www site
* docs site
* super users
* blog

# create new core on existing container instance

````
docker exec -it openstack-search1 create-nutch-core.sh $NEW_CORE_NAME $BASE_SEED_URL
````

# Nutch

* https://wiki.apache.org/nutch/NutchTutorial
* https://wiki.apache.org/nutch/FAQ#How_can_I_force_fetcher_to_use_custom_nutch-config.3F
* https://wiki.apache.org/nutch/IndexMetatags

# Useful commands

* kill all running containers with 

````
  docker kill $(docker ps -q)
````
* delete all stopped containers with

```` 
  docker rm $(docker ps -a -q)
````
* delete all images with

```` 
  docker rmi $(docker images -q)
````  
