# No dependencies to install: the proxy uses only Node's standard library, so
# the image is the runtime plus three files.
FROM node:22-alpine

WORKDIR /app
COPY package.json server.js token.js ./

USER node
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.js"]
