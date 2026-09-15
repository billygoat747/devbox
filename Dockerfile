FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install opencode; installer defaults to ~/.opencode/bin, so copy system-wide
RUN curl -fsSL https://opencode.ai/install | bash \
    && cp /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod 755 /usr/local/bin/opencode \
    && opencode --version

# Non-root developer user (Ubuntu 24.04 already reserves UID 1000)
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /home/dev/.config/opencode /workspace \
    && chown -R dev:dev /home/dev /workspace

COPY --chown=dev:dev opencode.json /home/dev/.config/opencode/opencode.json

USER dev
WORKDIR /workspace

ENV HOME=/home/dev \
    PATH="/usr/local/bin:${PATH}"

CMD ["opencode", "--auto"]
