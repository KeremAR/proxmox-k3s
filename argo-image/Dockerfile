FROM alpine:latest


RUN apk add --no-cache \
    git \
    curl \
    bash

RUN curl -SL -o ./argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && chmod +x ./argocd


CMD ["sleep", "infinity"]