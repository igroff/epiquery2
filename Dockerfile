FROM node:5.5.0

RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

RUN apt-get update
RUN apt-get install make 
RUN apt-get install jq
RUN apt-get install bc
RUN apt-get install -y  python-dev 
RUN curl -O https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py
RUN pip install awscli

# Add Docker Client - Needed to send SIGINT to docker as part of tests
RUN apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
RUN apt-get update
RUN apt-get -y install docker-ce


RUN npm install -g igroff/difftest-runner
RUN npm install -g coffee-script

RUN mkdir /var/app
WORKDIR /var/app
ADD . /var/app
RUN mkdir /var/config

RUN make build

#ENTRYPOINT ["/bin/bash"]
#CMD ["./epistream-docker-secrets-entrypoint.sh"]
CMD ["./epistream.coffee"]