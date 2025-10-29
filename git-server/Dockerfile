FROM alpine:3.19
RUN apk add --no-cache git
COPY salt-states-repo /seed
COPY git-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 9418
ENTRYPOINT ["/entrypoint.sh"]
