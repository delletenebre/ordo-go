FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY server.mjs ./
COPY public ./public
USER node
EXPOSE 8787
CMD ["node", "server.mjs"]
