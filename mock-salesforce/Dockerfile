FROM node:5.5.0

ENV production

RUN npm install -g drakov

ADD . /var/app
WORKDIR /var/app

CMD ["drakov", "-f", "./*.md", "-p", "80", "--public", "--watch" ]
