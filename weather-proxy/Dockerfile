# No dependencies to install: the proxy uses only Node's standard library, so
# the image is the runtime plus the sources.
FROM node:22-alpine

WORKDIR /app
# Copy the directory rather than naming each file — .gcloudignore and
# .dockerignore already keep the tests out, and an explicit list silently ships
# a broken image the moment a new module is added.
COPY . .

USER node
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.js"]
