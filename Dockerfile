from node:5.5.0

RUN apt-get update
RUN apt-get install make 
RUN apt-get install jq
RUN apt-get install bc

RUN npm install -g difftest-runner
RUN npm install -g coffee-script

RUN mkdir /var/app
WORKDIR /var/app
ADD . /var/app


RUN make build

#ENTRYPOINT ["/bin/bash"]
CMD ["./epistream.coffee"]
