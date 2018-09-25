FROM ubuntu:18.04

RUN apt-get update && \
  apt-get -y install git wget gnupg apt-utils mongodb software-properties-common tar zip curl lsof nano
RUN add-apt-repository ppa:webupd8team/java && apt-get update
RUN echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
RUN apt-get install -y oracle-java8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle/jre/
RUN apt-get -y install ant

# nutch

ARG NUTCH_VERSION=2.3.1

RUN wget http://www-eu.apache.org/dist/nutch/${NUTCH_VERSION}/apache-nutch-${NUTCH_VERSION}-src.tar.gz && \
    tar xvfz apache-nutch-${NUTCH_VERSION}-src.tar.gz

ENV NUTCH_HOME /apache-nutch-${NUTCH_VERSION}
ENV NUTCH_LOCAL ${NUTCH_HOME}/runtime/local
ENV NUTCH_LOCAL_CONF ${NUTCH_LOCAL}/conf
ENV NUTCH_LOCAL_CONF_TPL ${NUTCH_LOCAL}/conf-template

COPY conf/nutch/nutch-site.xml $NUTCH_HOME/conf/nutch-site.xml
COPY conf/nutch/conf/gora.properties $NUTCH_HOME/conf/gora.properties
COPY conf/nutch/conf/nutch-default.xml $NUTCH_HOME/conf/nutch-default.xml
COPY conf/nutch/ivy/ivy.xml $NUTCH_HOME/ivy/ivy.xml

COPY conf/nutch/crawler.sh $NUTCH_HOME/crawler.sh
RUN chmod 777 $NUTCH_HOME/crawler.sh
RUN cd $NUTCH_HOME && ant runtime

RUN mkdir -p $NUTCH_LOCAL_CONF_TPL
RUN cp $NUTCH_LOCAL_CONF/* $NUTCH_LOCAL_CONF_TPL

RUN mkdir -p $NUTCH_HOME/urls/www
COPY conf/nutch/seeds/www.txt $NUTCH_HOME/urls/www/seeds.txt
RUN mkdir -p $NUTCH_LOCAL_CONF/www && cp $NUTCH_LOCAL_CONF_TPL/* $NUTCH_LOCAL_CONF/www

RUN mkdir -p $NUTCH_HOME/urls/blog
COPY conf/nutch/seeds/blog.txt $NUTCH_HOME/urls/blog/seeds.txt
RUN mkdir -p $NUTCH_LOCAL_CONF/blog && cp $NUTCH_LOCAL_CONF_TPL/* $NUTCH_LOCAL_CONF/blog
COPY conf/nutch/conf/blog/regex-urlfilter.txt $NUTCH_LOCAL_CONF/blog/regex-urlfilter.txt

RUN mkdir -p $NUTCH_HOME/urls/docs
COPY conf/nutch/seeds/docs.txt $NUTCH_HOME/urls/docs/seeds.txt
RUN mkdir -p $NUTCH_LOCAL_CONF/docs && cp $NUTCH_LOCAL_CONF_TPL/* $NUTCH_LOCAL_CONF/docs

RUN mkdir -p $NUTCH_HOME/urls/superuser
COPY conf/nutch/seeds/superuser.txt $NUTCH_HOME/urls/superuser/seeds.txt
RUN mkdir -p $NUTCH_LOCAL_CONF/superuser && cp $NUTCH_LOCAL_CONF_TPL/* $NUTCH_LOCAL_CONF/superuser

# mongo config from mongodb.conf

RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

# solr

ARG SOLR_VERSION=6.5.1
ENV SOLR_PORT=8983
ENV SOLR_HOME=/var/solr/data
ENV SOLR_BIN=/opt/solr/bin
ENV SOLR_JAVA_MEM="-Xms2g -Xmx2g"

RUN  wget http://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz && \
     tar xzf /solr-${SOLR_VERSION}.tgz && \
     cp /solr-${SOLR_VERSION}/bin/install_solr_service.sh /install_solr_service.sh && \	
     chmod 777 /install_solr_service.sh && \
     ./install_solr_service.sh /solr-${SOLR_VERSION}.tgz

# copy default core configurations

ENV CONF_HOME=/var/solr-default-core-config
RUN mkdir -p ${CONF_HOME}
COPY conf/solr/default-core-config/schema.xml ${CONF_HOME}/schema.xml
COPY conf/solr/default-core-config/solrconfig.xml ${CONF_HOME}/solrconfig.xml
RUN chown solr:solr -R ${CONF_HOME}

USER solr

RUN ${SOLR_BIN}/solr start && \	
    ${SOLR_BIN}/solr create_core -c www-openstack -d basic_configs && \
    ${SOLR_BIN}/solr create_core -c blog -d basic_configs && \
    ${SOLR_BIN}/solr create_core -c docs-openstack -d basic_configs && \
    ${SOLR_BIN}/solr create_core -c superuser-openstack -d basic_configs && \
    ${SOLR_BIN}/solr stop

ENV LAST_CRAWL_ID=5
ENV DEFAULT_TOP=1000
ENV DEFAULT_DEPTH=60

# www
COPY conf/solr/default-core-config/schema.xml ${SOLR_HOME}/www-openstack/conf/schema.xml
COPY conf/solr/default-core-config/solrconfig.xml ${SOLR_HOME}/www-openstack/conf/solrconfig.xml
RUN rm ${SOLR_HOME}/www-openstack/conf/managed-schema

#blog
COPY conf/solr/default-core-config/schema.xml ${SOLR_HOME}/blog/conf/schema.xml
COPY conf/solr/default-core-config/solrconfig.xml ${SOLR_HOME}/blog/conf/solrconfig.xml
RUN rm ${SOLR_HOME}/blog/conf/managed-schema

# docs
COPY conf/solr/default-core-config/schema.xml ${SOLR_HOME}/docs-openstack/conf/schema.xml
COPY conf/solr/default-core-config/solrconfig.xml ${SOLR_HOME}/docs-openstack/conf/solrconfig.xml
RUN rm ${SOLR_HOME}/docs-openstack/conf/managed-schema

# super user
COPY conf/solr/default-core-config/schema.xml ${SOLR_HOME}/superuser-openstack/conf/schema.xml
COPY conf/solr/default-core-config/solrconfig.xml ${SOLR_HOME}/superuser-openstack/conf/solrconfig.xml
RUN rm ${SOLR_HOME}/superuser-openstack/conf/managed-schema

VOLUME ${SOLR_HOME}

USER root

# create cron tab

# Add crontab file in the cron directory
COPY crontab/nutch-tab /etc/cron.d/nutch-tab
 
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/nutch-tab
 
# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# create env file for cron
RUN printenv | sed 's/^\([a-zA-Z0-9_]*\)=\(.*\)$/export \1="\2"/g' > /root/env.sh

# entry point
COPY docker-entrypoint.sh /usr/local/bin/
COPY conf/solr/create-nutch-core.sh /usr/local/bin

RUN chmod 777 /usr/local/bin/docker-entrypoint.sh \
    && ln -s /usr/local/bin/docker-entrypoint.sh /

RUN chmod 777 /usr/local/bin/create-nutch-core.sh \
    && ln -s /usr/local/bin/create-nutch-core.sh /

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bin/bash"]

EXPOSE 8983


