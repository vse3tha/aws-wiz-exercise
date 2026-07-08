FROM node:26-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY server.js ./

# Exercise evidence file. Validate with:
# kubectl -n wizexercise exec <pod> -- cat /app/wizexercise.txt
RUN printf "Vamshidhar’s Seetha\n" > /app/wizexercise.txt \
    && adduser -D nodeapp \
    && chown -R nodeapp:nodeapp /app

USER nodeapp
EXPOSE 3000
CMD ["node", "server.js"]
