FROM node:5.5.0

# adding our node_modules bin to the path so we can reference installed packages
# without installing them globally
ENV PATH="/var/app/node_modules/.bin:${PATH}"

WORKDIR /var/app
COPY package.json /var/app
RUN npm install
COPY . /var/app

CMD ["./epistream.coffee"]
