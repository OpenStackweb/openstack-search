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

RUN wget http://www-eu.apache.org/dist/nutch/2.3.1/apache-nutch-${NUTCH_VERSION}-src.tar.gz && \
    tar xvfz apache-nutch-${NUTCH_VERSION}-src.tar.gz
ENV NUTCH_HOME /apache-nutch-${NUTCH_VERSION}
COPY conf/nutch/nutch-site.xml $NUTCH_HOME/conf/nutch-site.xml
COPY conf/nutch/gora.properties $NUTCH_HOME/conf/gora.properties
COPY conf/nutch/ivy/ivy.xml $NUTCH_HOME/ivy/ivy.xml
RUN mkdir -p $NUTCH_HOME/urls/www
COPY conf/nutch/seeds/www.txt $NUTCH_HOME/urls/www/seeds.txt
COPY conf/nutch/crawler.sh $NUTCH_HOME/crawler.sh
RUN chmod 777 $NUTCH_HOME/crawler.sh
RUN cd $NUTCH_HOME && ant runtime

# mongo config from mongodb.conf
RUN mkdir -p /data/db /data/configdb \
	&& chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb

# solr

ARG SOLR_VERSION=6.5.1
ENV SOLR_PORT=8983
RUN  wget http://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz && \
     tar xzf /solr-${SOLR_VERSION}.tgz && \
     cp /solr-${SOLR_VERSION}/bin/install_solr_service.sh /install_solr_service.sh && \	
     chmod 777 /install_solr_service.sh && \
     ./install_solr_service.sh /solr-${SOLR_VERSION}.tgz

USER solr

ENV SOLR_HOME=/var/solr/data
ENV SOLR_BIN=/opt/solr/bin

RUN ${SOLR_BIN}/solr start && \	
    ${SOLR_BIN}/solr create_core -c www-openstack -d basic_configs && \
    ${SOLR_BIN}/solr stop

# copy default core configurations

COPY conf/solr/www-openstack/schema.xml ${SOLR_HOME}/www-openstack/conf/schema.xml
COPY conf/solr/www-openstack/solrconfig.xml ${SOLR_HOME}/www-openstack/conf/solrconfig.xml
RUN rm ${SOLR_HOME}/www-openstack/conf/managed-schema

VOLUME ${SOLR_HOME}/www-openstack

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
RUN chmod 777 /usr/local/bin/docker-entrypoint.sh \
    && ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bin/bash"]

EXPOSE 8983


