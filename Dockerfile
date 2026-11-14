
# syntax=docker/dockerfile:1

FROM alpine:3.24.4

# ============================================================
# Version pinning
# ============================================================

# Talos
# renovate: datasource=github-releases depName=siderolabs/talos
ARG TALOSCTL_VERSION=v1.14.6

# Kubernetes
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.2

# Helm
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.2

# Omni
# renovate: datasource=github-releases depName=siderolabs/omni
ARG OMNICTL_VERSION=v1.13.3

# Kubernetes utilities
# renovate: datasource=github-releases depName=derailed/k9s
ARG K9S_VERSION=v0.51.0

# renovate: datasource=github-releases depName=ahmetb/kubectx
ARG KUBECTX_VERSION=v0.11.0

# renovate: datasource=github-releases depName=int128/kubelogin
ARG KUBELOGIN_VERSION=v1.36.4

# Infrastructure tools
# renovate: datasource=github-releases depName=postfinance/topf
ARG TOPF_VERSION=v0.6.2

# renovate: datasource=pypi depName=python-openstackclient
ARG OPENSTACKCLIENT_VERSION=10.5.0

# GitOps
# renovate: datasource=github-releases depName=helmfile/helmfile
ARG HELMFILE_VERSION=v1.8.4

# renovate: datasource=github-releases depName=databus23/helm-diff
ARG HELM_DIFF_VERSION=v3.15.15

# renovate: datasource=github-releases depName=fluxcd/flux2
ARG FLUX_VERSION=v2.10.0

# Networking
# shortcut: v1.17 removed dist/images/kubectl-ko (now Go code in cmd/), so
# stay on the v1.16 line until the install is reworked
# renovate: datasource=github-releases depName=kubeovn/kube-ovn
ARG KUBE_OVN_VERSION=v1.16.19

# renovate: datasource=github-releases depName=cilium/cilium-cli
ARG CILIUM_CLI_VERSION=v0.20.3

# Security
# renovate: datasource=github-releases depName=getsops/sops
ARG SOPS_VERSION=v3.13.3

# renovate: datasource=github-releases depName=FiloSottile/age
ARG AGE_VERSION=v1.3.2

# Developer tools
# renovate: datasource=github-releases depName=casey/just
ARG JUST_VERSION=1.59.0

# BuildKit target architecture
ARG TARGETARCH=amd64

# ============================================================
# Environment
# ============================================================

WORKDIR /root

ENV PATH="/usr/local/bin:${PATH}"

ENV IMAGE_SERVICE_ENDPOINT=unix:///host/run/containerd/containerd.sock
ENV CONTAINER_RUNTIME_ENDPOINT=unix:///host/run/containerd/containerd.sock

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# ============================================================
# Base packages
# ============================================================

RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        bash \
        bash-completion \
        curl \
        wget \
        tar \
        gzip \
        unzip \
        lvm2 \
        util-linux \
        jq \
        yq \
        drbd-utils \
        tcpdump \
        nano \
        cri-tools \
        bash \
        tshark \
        bind-tools \
        iproute2 \
        nmap \
        nmap-ncat \
        socat \
        iperf3 \
        mtr \
        e2fsprogs \
        xfsprogs \
        parted \
        nvme-cli \
        openssl \
        vim \
        tmux \
        lsof \
        strace \
        git \
        fzf \
        aws-cli \
        coreutils \
        python3 \
        py3-pip

# ============================================================
# Download and install CLI tools
# ============================================================

RUN set -eux; \
    \
    mkdir -p \
        /root/.local/share/helm/plugins \
        /tmp/tool-downloads; \
    \
    case "${TARGETARCH}" in \
        amd64) ;; \
        *) echo "Unsupported architecture for this image: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    echo "========================================"; \
    echo "Installing talosctl"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${TARGETARCH}" \
        -o /usr/local/bin/talosctl; \
    \
    echo "========================================"; \
    echo "Installing kubectl"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
        -o /usr/local/bin/kubectl; \
    \
    echo "========================================"; \
    echo "Installing omnictl"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/siderolabs/omni/releases/download/${OMNICTL_VERSION}/omnictl-linux-${TARGETARCH}" \
        -o /usr/local/bin/omnictl; \
    \
    echo "========================================"; \
    echo "Installing kubectx and kubens"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://raw.githubusercontent.com/ahmetb/kubectx/${KUBECTX_VERSION}/kubectx" \
        -o /usr/local/bin/kubectx; \
    curl -fSL --retry 3 \
        "https://raw.githubusercontent.com/ahmetb/kubectx/${KUBECTX_VERSION}/kubens" \
        -o /usr/local/bin/kubens; \
    \
    echo "========================================"; \
    echo "Installing Helm"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/helm.tar.gz; \
    tar -xzf /tmp/tool-downloads/helm.tar.gz \
        -C /tmp linux-${TARGETARCH}/helm; \
    mv /tmp/linux-${TARGETARCH}/helm /usr/local/bin/helm; \
    \
    echo "========================================"; \
    echo "Installing k9s"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/k9s.tar.gz; \
    tar -xzf /tmp/tool-downloads/k9s.tar.gz \
        -C /usr/local/bin k9s; \
    \
    echo "========================================"; \
    echo "Installing kubelogin"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/int128/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin_linux_${TARGETARCH}.zip" \
        -o /tmp/tool-downloads/kubelogin.zip; \
    unzip -o /tmp/tool-downloads/kubelogin.zip kubelogin \
        -d /tmp; \
    mv /tmp/kubelogin /usr/local/bin/kubectl-oidc_login; \
    \
    echo "========================================"; \
    echo "Installing topf"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/postfinance/topf/releases/download/${TOPF_VERSION}/topf_linux_${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/topf.tar.gz; \
    tar -xzf /tmp/tool-downloads/topf.tar.gz \
        -C /usr/local/bin topf; \
    \
    echo "========================================"; \
    echo "Installing helmfile"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/helmfile.tar.gz; \
    tar -xzf /tmp/tool-downloads/helmfile.tar.gz \
        -C /usr/local/bin helmfile; \
    \
    echo "========================================"; \
    echo "Installing Flux"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_linux_${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/flux.tar.gz; \
    tar -xzf /tmp/tool-downloads/flux.tar.gz \
        -C /usr/local/bin flux; \
    \
    echo "========================================"; \
    echo "Installing kubectl-ko"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://raw.githubusercontent.com/kubeovn/kube-ovn/${KUBE_OVN_VERSION}/dist/images/kubectl-ko" \
        -o /usr/local/bin/kubectl-ko; \
    \
    echo "========================================"; \
    echo "Installing Cilium CLI"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/cilium.tar.gz; \
    tar -xzf /tmp/tool-downloads/cilium.tar.gz \
        -C /usr/local/bin cilium; \
    \
    echo "========================================"; \
    echo "Installing SOPS"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${TARGETARCH}" \
        -o /usr/local/bin/sops; \
    \
    echo "========================================"; \
    echo "Installing Helm Diff"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/databus23/helm-diff/releases/download/${HELM_DIFF_VERSION}/diff-${HELM_DIFF_VERSION#v}-linux-${TARGETARCH}.tgz" \
        -o /tmp/tool-downloads/helm-diff.tgz; \
    tar -xzf /tmp/tool-downloads/helm-diff.tgz \
        -C /root/.local/share/helm/plugins; \
    \
    echo "========================================"; \
    echo "Installing age"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-${TARGETARCH}.tar.gz" \
        -o /tmp/tool-downloads/age.tar.gz; \
    tar -xzf /tmp/tool-downloads/age.tar.gz \
        -C /tmp age/age age/age-keygen; \
    mv /tmp/age/age /tmp/age/age-keygen /usr/local/bin/; \
    \
    echo "========================================"; \
    echo "Installing just"; \
    echo "========================================"; \
    curl -fSL --retry 3 \
        "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/tool-downloads/just.tar.gz; \
    tar -xzf /tmp/tool-downloads/just.tar.gz \
        -C /usr/local/bin just; \
    \
    echo "========================================"; \
    echo "Setting executable permissions"; \
    echo "========================================"; \
    chmod +x \
        /usr/local/bin/talosctl \
        /usr/local/bin/kubectl \
        /usr/local/bin/omnictl \
        /usr/local/bin/kubectx \
        /usr/local/bin/kubens \
        /usr/local/bin/helm \
        /usr/local/bin/k9s \
        /usr/local/bin/kubectl-oidc_login \
        /usr/local/bin/topf \
        /usr/local/bin/helmfile \
        /usr/local/bin/flux \
        /usr/local/bin/kubectl-ko \
        /usr/local/bin/cilium \
        /usr/local/bin/sops \
        /usr/local/bin/age \
        /usr/local/bin/age-keygen \
        /usr/local/bin/just; \
    \
    echo "========================================"; \
    echo "Verifying installed binaries"; \
    echo "========================================"; \
    for bin in \
        talosctl \
        kubectl \
        omnictl \
        kubectx \
        kubens \
        helm \
        k9s \
        kubectl-oidc_login \
        topf \
        helmfile \
        flux \
        kubectl-ko \
        cilium \
        sops \
        age \
        age-keygen \
        just; \
    do \
        test -s "/usr/local/bin/${bin}"; \
        test -x "/usr/local/bin/${bin}"; \
        echo "OK: ${bin}"; \
    done; \
    \
    rm -rf /tmp/tool-downloads /tmp/age /tmp/linux-${TARGETARCH}

# ============================================================
# OpenStack CLI
# ============================================================

RUN set -eux; \
    python3 -m pip install \
        --no-cache-dir \
        --break-system-packages \
        "python-openstackclient==${OPENSTACKCLIENT_VERSION}"; \
    openstack --version

# ============================================================
# crictl configuration
# ============================================================

RUN set -eux; \
    mkdir -p /var/log; \
    echo "runtime-endpoint: unix:///host/run/containerd/containerd.sock" \
        > /etc/crictl.yaml; \
    echo "image-endpoint: unix:///host/run/containerd/containerd.sock" \
        >> /etc/crictl.yaml; \
    ln -s /host/var/log/pods /var/log/pods; \
    ln -s /host/var/log/containers /var/log/containers

# ============================================================
# Bash configuration
# ============================================================

COPY bashrc /root/.bashrc

# ============================================================
# Final verification
# ============================================================

RUN set -eux; \
    echo "Architecture: ${TARGETARCH}"; \
    echo "Python:"; python3 --version; \
    echo "OpenStack:"; openstack --version; \
    echo "Talos:"; talosctl version --client; \
    echo "Kubernetes:"; kubectl version --client; \
    echo "Helm:"; helm version --short; \
    echo "Just:"; just --version; \
    echo "SOPS:"; sops --version; \
    echo "Age:"; age --version; \
    echo "Toolbox verification completed"

# ============================================================
# Runtime
# ============================================================

# Keep container alive in detached mode
CMD ["sleep", "infinity"]
