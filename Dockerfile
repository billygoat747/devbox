FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libssl-dev \
    nodejs \
    npm \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Go from the official tarball (pinned via ARG for easy bumps).
# dpkg arch names (amd64/arm64) match Go's naming.
ARG GO_VERSION=1.26.0
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tgz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz \
    && /usr/local/go/bin/go version

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
    PATH="/home/dev/.cargo/bin:/usr/local/go/bin:/usr/local/bin:${PATH}"

# Install Rust via rustup as the dev user (stable, minimal profile).
# build-essential/pkg-config/libssl-dev above provide the C toolchain
# most crates need for linking.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable \
    && ~/.cargo/bin/rustc --version \
    && ~/.cargo/bin/cargo --version

CMD ["opencode", "--auto"]
