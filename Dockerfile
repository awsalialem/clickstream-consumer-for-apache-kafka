FROM public.ecr.aws/docker/library/centos:latest

RUN cd /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum install -y wget tar openssh-server openssh-clients sysstat sudo which openssl hostname
RUN yum install -y java-17-openjdk java-17-openjdk-devel 
RUN yum install -y epel-release &&\
    yum install -y jq &&\
    yum install -y nmap-ncat git
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
    
# Verify Java installation
RUN java -version && javac -version

# First install required dependencies
RUN yum groupinstall -y "Development Tools" && \
    yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel make


ARG MAVEN_VERSION=3.9.10
# Maven
RUN curl -fsSL https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_VERSION=${MAVEN_VERSION}
ENV M2_HOME /usr/share/maven
ENV maven.home $M2_HOME
ENV M2 $M2_HOME/bin
ENV PATH $M2:$PATH
ENV SCALA_VERSION 2.13
ENV KAFKA_VERSION 3.7.0

# Prometheus Java agent
RUN wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.13.0/jmx_prometheus_javaagent-0.13.0.jar
RUN mv jmx_prometheus_javaagent-0.13.0.jar /opt

RUN git clone https://github.com/aws-samples/sasl-scram-secrets-manager-client-for-msk.git
WORKDIR sasl-scram-secrets-manager-client-for-msk
RUN mvn clean install -f pom.xml
WORKDIR ../

RUN mkdir clickstream-consumer-for-apache-kafka
WORKDIR clickstream-consumer-for-apache-kafka
COPY src/ ./src/
COPY pom.xml ./
RUN mvn clean install -f pom.xml
COPY start-kafka-consumer.sh consumer.properties kafka-producer-consumer.yml ./
RUN chmod 777 start-kafka-consumer.sh
# cleanup
RUN yum clean all;

EXPOSE 3801
ENTRYPOINT ./start-kafka-consumer.sh
