FROM alpine:3.22

RUN apk add --no-cache \
    git \
    curl \
    bash \
    ca-certificates  # <-- HTTPS (k8s.io) için GEREKLİ

# KUBECTL
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# ARGOCD 
RUN curl -SL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && chmod +x /usr/local/bin/argocd

CMD ["sleep", "infinity"]