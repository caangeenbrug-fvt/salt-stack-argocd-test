FROM saltstack/salt:3004-alpine3.14
USER root
RUN apk add --no-cache git
COPY cloud-master/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
VOLUME ["/gitops"]
ENTRYPOINT ["/entrypoint.sh"]
