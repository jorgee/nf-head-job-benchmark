FROM amazoncorretto:17.0.3
RUN yum install -y procps-ng

ENV NXF_HOME=/.nextflow

COPY nextflow /usr/local/bin/nextflow

RUN mkdir /.nextflow \
 && touch /.nextflow/dockerized \
 && chmod 755 /usr/local/bin/nextflow \
 && nextflow info
