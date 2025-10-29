FROM saltstack/salt:3004-alpine3.14
USER root
RUN if command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*; \
    elif command -v yum >/dev/null 2>&1; then \
      yum install -y git && yum clean all; \
    elif command -v zypper >/dev/null 2>&1; then \
      zypper refresh && zypper install -y git; \
    else \
      echo "Unsupported package manager" >&2 && exit 1; \
    fi
COPY worker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
VOLUME ["/gitops"]
ENTRYPOINT ["/entrypoint.sh"]
