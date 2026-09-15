FROM node:24-alpine
WORKDIR /app/relay
COPY relay/package*.json ./
RUN npm ci --omit=dev
COPY relay/server.mjs ./
COPY relay/public ./public
COPY assets/boons /app/assets/boons
COPY assets/avatars /app/assets/avatars
COPY assets/icons/web /app/assets/icons/web
USER node
EXPOSE 8787
CMD ["node", "server.mjs"]
