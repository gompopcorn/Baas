FROM ubuntu:18.04
LABEL "prjName"="baasImage"

WORKDIR /home/app

# prevent from input dialogs
ARG DEBIAN_FRONTEND=noninteractive


# install hlf prerequisites
RUN apt-get update && apt-get upgrade
RUN apt-get install -y build-essential git-all make curl wget zip unzip g++ libtool libltdl-dev jq

# # install jdk
# RUN apt-get install default-jre openjdk-11-jre-headless openjdk-8-jre-headless default-jre

# # install gradle
# wget https://services.gradle.org/distributions/gradle-5.0-bin.zip -P /tmp
# unzip -d /opt/gradle /tmp/gradle-*.zip
# echo -e "\n\n\nexport GRADLE_HOME=/opt/gradle/gradle-5.0" >> /etc/profile.d/gradle.sh
# echo "export PATH=${GRADLE_HOME}/bin:${PATH}" >> /etc/profile.d/gradle.sh
# chmod +x /etc/profile.d/gradle.sh
# source /etc/profile.d/gradle.sh

# install nodejs
RUN curl -sL https://deb.nodesource.com/setup_12.x  | bash -
RUN apt-get -y install nodejs
RUN node --version

# install go
RUN cd /usr/local
RUN wget https://go.dev/dl/go1.17.6.linux-amd64.tar.gz
RUN rm -rf /usr/local/go && tar -C /usr/local -xvzf go1.17.6.linux-amd64.tar.gz

# RUN echo -e "\n\n\nexport GOROOT=/usr/local/go" >> ~/.profile
ENV GOROOT=/usr/local/go
ENV GOPATH=/usr/local/bin
ENV PATH=$PATH:$GOROOT/bin:/usr/local/go/src/github.com/hyperledger/fabric-samples/bin
RUN export PATH GOPATH GOROOT

RUN apt-get update && apt-get upgrade

RUN cd /usr/local/go/src  &&  mkdir github.com  &&  mkdir github.com/hyperledger  &&  cd github.com/hyperledger
RUN curl -sSL https://bit.ly/2ysbOFE | bash -s
RUN ls


RUN go versionclwa
RUN node --version
RUN make -version
RUN git --version
# RUN java -version
# RUN gradle -v