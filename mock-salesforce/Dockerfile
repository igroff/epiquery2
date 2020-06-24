FROM node:5.5.0

ENV NODE_ENV production

RUN npm install -g drakov

ADD . /var/app
WORKDIR /var/app

CMD ["drakov", "-f", "./*.md", "-p", "80", "--public", "--watch" ]
