FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Lean system stack: Python, Node, plus SDKMAN! prereqs (curl/git/zip/unzip).
# build-essential stays for pip/npm native builds. Single layer, no recommends.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# opencode system-wide; drop the installer leftovers to keep the layer small
RUN curl -fsSL https://opencode.ai/install | bash \
    && cp /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod 755 /usr/local/bin/opencode \
    && rm -rf /root/.opencode \
    && opencode --version

# Non-root developer user
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /home/dev/.config/opencode /workspace \
    && chown -R dev:dev /home/dev /workspace

COPY --chown=dev:dev opencode.json /home/dev/.config/opencode/opencode.json

USER dev
WORKDIR /workspace

ENV HOME=/home/dev \
    SDKMAN_DIR=/home/dev/.sdkman

# SDKMAN! with NO pre-installed JDKs — install on demand to keep the image small:
#   sdk list java
#   sdk install java 21-tem && sdk default java 21-tem
# Non-interactive answers, no self-update, for reproducibility.
RUN curl -s "https://get.sdkman.io" | bash \
    && sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/; s/^sdkman_selfupdate_enable=.*/sdkman_selfupdate_enable=false/' "$SDKMAN_DIR/etc/config" \
    && bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk version"

CMD ["opencode", "--auto"]
