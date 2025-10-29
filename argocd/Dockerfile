FROM python:3.11-alpine
RUN apk add --no-cache git
RUN pip install --no-cache-dir pyyaml
COPY argocd/application.yaml /config/application.yaml
COPY argocd/entrypoint.py /entrypoint.py
ENV APPLICATION_PATH=/config/application.yaml \
    ARGO_WORKDIR=/gitops/worktree \
    ARGO_STATE_DIR=/gitops/state \
    RECONCILE_SECONDS=10
VOLUME ["/gitops"]
ENTRYPOINT ["python", "/entrypoint.py"]
