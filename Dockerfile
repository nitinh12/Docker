# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Set shell for build commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        build-essential \
        curl \
        wget \
        git \
        libgl1 \
        locales \
        iproute2 \
        psmisc \
    && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA and install Python 3.13
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-setuptools \
        python3-wheel \
        libexpat1-dev \
        zlib1g-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove other Python versions (except Python 3.13) to avoid conflicts
RUN apt-get update && \
    apt-get remove -y python3.12 python3.12-dev || true && \
    dpkg -l | grep -E 'python3\.[0-9]+' | grep -v 'python3\.13' | awk '{print $2}' | xargs -r apt-get purge -y || true && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install pip for Python 3.13 and set up symbolic links
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --upgrade pip && \
    ln -sf /usr/bin/python3.13 /usr/bin/python && \
    ln -sf /usr/bin/python3.13 /usr/bin/python3 && \
    python --version && \
    python3 --version

# Install JupyterLab and additional utilities
RUN python -m pip install --no-cache-dir \
    jupyterlab==4.4.2 \
    ipywidgets \
    jupyter-archive

# Install PyTorch 2.7.0 with CUDA 12.8
RUN python -m pip install --no-cache-dir \
    torch==2.7.0 \
    torchvision==0.22.0 \
    torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu128

# Create the workspace directory
RUN mkdir -p /workspace && chmod -R 777 /workspace

# Plain bold welcome message
RUN echo -e '\n\033[1mCogniCore-AI\033[0m\n' > /etc/cogni_core.txt && \
    echo -e 'Subscribe to my YouTube channel for the latest automatic install scripts for RunPod:\n\033[1;34mhttps://www.youtube.com/@CogniCore-AI\033[0m\n' >> /etc/cogni_core.txt && \
    echo 'cat /etc/cogni_core.txt' >> /root/.bashrc

# Create the startup script inline
COPY <<EOF /start.sh
#!/bin/bash
echo "Starting container..."

# Ensure /workspace exists
mkdir -p /workspace
chmod -R 777 /workspace

# Ensure shell works in terminals
ln -sf /bin/bash /bin/sh

# Free port 8888 if already in use
if ss -tuln | grep -q ":8888 "; then
    echo "Port 8888 is already in use, attempting to free it..."
    fuser -k 8888/tcp || true
fi

# ✅ Start JupyterLab properly
echo "Starting JupyterLab..."
python -m jupyter lab \
  --ip=0.0.0.0 \
  --port=\${JUPYTER_PORT:-8888} \
  --no-browser \
  --allow-root \
  --ServerApp.token="" \
  --ServerApp.password="" \
  --ServerApp.allow_origin="*" \
  --ServerApp.root_dir=/workspace \
  --ServerApp.terminado_settings='{"shell_command": ["/bin/bash"]}' \
  &> /tmp/jupyter.log &

echo "JupyterLab started"
tail -f /tmp/jupyter.log
EOF

# Ensure the script is executable
RUN chmod +x /start.sh && \
    ls -l /start.sh && \
    cat /start.sh

# Set working directory
WORKDIR /workspace

# Expose JupyterLab port
EXPOSE 8888

# Use the startup script as entrypoint
ENTRYPOINT ["/start.sh"]
