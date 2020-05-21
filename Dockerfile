FROM node:12.16.3-alpine3.10

# adding our node_modules bin to the path so we can reference installed packages
# without installing them globally
ENV PATH="/var/app/node_modules/.bin:${PATH}"
WORKDIR /var/app
COPY package*.json ./
RUN apk add --no-cache --virtual build-dependencies \
    git \
  && npm install \
  && apk del build-dependencies
COPY . .

CMD ["./epistream.coffee"]
