FROM alpine:3.24

# renovate: datasource=github-releases depName=siderolabs/talos
ARG TALOSCTL_VERSION=v1.14.5
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.1
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.1
# renovate: datasource=github-releases depName=siderolabs/omni
ARG OMNICTL_VERSION=v1.12.4
# renovate: datasource=github-releases depName=derailed/k9s
ARG K9S_VERSION=v0.51.0
# renovate: datasource=github-releases depName=ahmetb/kubectx
ARG KUBECTX_VERSION=v0.11.0
# renovate: datasource=github-releases depName=int128/kubelogin
ARG KUBELOGIN_VERSION=v1.36.4
# renovate: datasource=github-releases depName=postfinance/topf
ARG TOPF_VERSION=v0.6.2
# renovate: datasource=pypi depName=python-openstackclient
ARG OPENSTACKCLIENT_VERSION=10.5.0
# renovate: datasource=github-releases depName=helmfile/helmfile
ARG HELMFILE_VERSION=v1.8.2
# renovate: datasource=github-releases depName=databus23/helm-diff
ARG HELM_DIFF_VERSION=v3.15.15
# renovate: datasource=github-releases depName=fluxcd/flux2
ARG FLUX_VERSION=v2.10.0
# renovate: datasource=github-releases depName=kubeovn/kube-ovn
ARG KUBE_OVN_VERSION=v1.16.15
# renovate: datasource=github-releases depName=cilium/cilium-cli
ARG CILIUM_CLI_VERSION=v0.20.1

# Provided by buildkit, the default keeps classic `docker build` working
ARG TARGETARCH=amd64

WORKDIR /root

RUN apk add --no-cache \
    bash-completion curl wget lvm2 util-linux jq yq drbd-utils tcpdump nano cri-tools bash tshark \
    bind-tools iproute2 nmap nmap-ncat socat iperf3 mtr \
    e2fsprogs xfsprogs parted nvme-cli \
    openssl vim tmux lsof strace git fzf unzip aws-cli coreutils python3 py3-pip

RUN curl -fsSL "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${TARGETARCH}" -o /usr/local/bin/talosctl \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && curl -fsSL "https://github.com/siderolabs/omni/releases/download/${OMNICTL_VERSION}/omnictl-linux-${TARGETARCH}" -o /usr/local/bin/omnictl \
    && curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/${KUBECTX_VERSION}/kubectx" -o /usr/local/bin/kubectx \
    && curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/${KUBECTX_VERSION}/kubens" -o /usr/local/bin/kubens \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz -C /tmp \
    && mv "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin k9s \
    && curl -fsSL "https://github.com/int128/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin_linux_${TARGETARCH}.zip" -o /tmp/kubelogin.zip \
    && unzip -o /tmp/kubelogin.zip kubelogin -d /tmp \
    && mv /tmp/kubelogin /usr/local/bin/kubectl-oidc_login \
    && curl -fsSL "https://github.com/postfinance/topf/releases/download/${TOPF_VERSION}/topf_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin topf \
    && curl -fsSL "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin helmfile \
    && curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_linux_${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin flux \
    && curl -fsSL "https://raw.githubusercontent.com/kubeovn/kube-ovn/${KUBE_OVN_VERSION}/dist/images/kubectl-ko" -o /usr/local/bin/kubectl-ko \
    && curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${TARGETARCH}.tar.gz" | tar xz -C /usr/local/bin cilium \
    && mkdir -p /root/.local/share/helm/plugins \
    && curl -fsSL "https://github.com/databus23/helm-diff/releases/download/${HELM_DIFF_VERSION}/diff-${HELM_DIFF_VERSION#v}-linux-${TARGETARCH}.tgz" | tar xz -C /root/.local/share/helm/plugins \
    && chmod +x /usr/local/bin/talosctl /usr/local/bin/kubectl /usr/local/bin/omnictl \
        /usr/local/bin/kubectx /usr/local/bin/kubens /usr/local/bin/helm \
        /usr/local/bin/k9s /usr/local/bin/kubectl-oidc_login /usr/local/bin/topf \
        /usr/local/bin/helmfile /usr/local/bin/flux /usr/local/bin/kubectl-ko /usr/local/bin/cilium \
    && rm -rf /tmp/kubelogin.zip "/tmp/linux-${TARGETARCH}"

# No apk package exists for openstackclient (not even in edge); pin the pip install so renovate tracks it
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    "python-openstackclient==${OPENSTACKCLIENT_VERSION}"

# Fix for crictl logs and configuration warnings
RUN echo "runtime-endpoint: unix:///host/run/containerd/containerd.sock" > /etc/crictl.yaml && \
    echo "image-endpoint: unix:///host/run/containerd/containerd.sock" >> /etc/crictl.yaml && \
    mkdir -p /var/log && \
    ln -s /host/var/log/pods /var/log/pods && \
    ln -s /host/var/log/containers /var/log/containers

COPY bashrc /root/.bashrc

ENV IMAGE_SERVICE_ENDPOINT=unix:///host/run/containerd/containerd.sock
ENV CONTAINER_RUNTIME_ENDPOINT=unix:///host/run/containerd/containerd.sock

ENTRYPOINT [ "/bin/bash" ]
