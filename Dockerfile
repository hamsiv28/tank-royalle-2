FROM node:alpine
RUN npm install -g peer
EXPOSE 10000
CMD ["sh", "-c", "peerjs --port ${PORT:-10000} --path /"]
