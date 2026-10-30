FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

ARG APT_MIRROR=
RUN if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|//archive.ubuntu.com|//$APT_MIRROR|; s|//security.ubuntu.com|//$APT_MIRROR|" /etc/apt/sources.list.d/ubuntu.sources; \
    fi \
    && apt-get update && apt-get install -y --no-install-recommends \
      tzdata locales ca-certificates curl git python3 python3-pip \
      python3-venv python3-yaml util-linux \
      inotify-tools file iproute2 dnsutils jq less nano openssh-client openssh-server \
    && ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo 'America/Los_Angeles' > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && touch -h -d '2024-03-09 10:00:00' /etc/localtime \
    && touch -d '2024-03-09 10:00:00' /etc/timezone \
    && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY sshd_sandbox_config /etc/ssh/sshd_sandbox_config
RUN chmod +x /entrypoint.sh && mkdir -p /run/sshd
WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
