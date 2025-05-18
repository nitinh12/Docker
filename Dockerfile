# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PIP_NO_CACHE_DIR=false
ENV PIP_CACHE_DIR=/root/.cache/pip

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system dependencies
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
        psmisc && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Python 3.13
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

# Clean up older Python
RUN apt-get update && \
    apt-get remove -y python3.12 python3.12-dev || true && \
    dpkg -l | grep -E 'python3\.[0-9]+' | grep -v 'python3\.13' | awk '{print $2}' | xargs -r apt-get purge -y || true && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Pip and symlinks
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --upgrade pip && \
    ln -sf /usr/bin/python3.13 /usr/bin/python && \
    ln -sf /usr/bin/python3.13 /usr/bin/python3

# Install JupyterLab and tools
RUN python -m pip install \
    jupyterlab==4.4.2 \
    ipywidgets \
    jupyter-archive

# Install PyTorch with CUDA 12.8 and preload torch (CPU-safe)
RUN python -m pip install \
    torch==2.7.0 \
    torchvision==0.22.0 \
    torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu128 && \
    python -c "import torch; torch.nn.functional.softmax(torch.randn(2, 2), dim=1)"

# Create visible workspace for mounted network disk
RUN mkdir -p /workspace && chmod -R 777 /workspace

# Welcome message
RUN echo -e '\n\033[1mCogniCore-AI\033[0m\n' > /etc/cogni_core.txt && \
    echo -e 'Subscribe to my YouTube channel for the latest automatic install scripts for RunPod:\n\033[1;34mhttps://www.youtube.com/@CogniCore-AI\033[0m\n' >> /etc/cogni_core.txt && \
    echo 'cat /etc/cogni_core.txt' >> /root/.bashrc

# Safe heredoc-based start.sh script
RUN bash -c 'cat > /start.sh <<EOF
#!/bin/bash
echo "Starting container..."
mkdir -p /workspace
chmod -R 777 /workspace
ln -sf /bin/bash /bin/sh

if ss -tuln | grep -q ":8888 "; then
  echo "Port 8888 is already in use, attempting to free it..."
  fuser -k 8888/tcp || true
fi

echo "Warming up CUDA..."
python -c "import torch; print(\\"CUDA available:\\", torch.cuda.is_available()); \
  torch.randn(1, device=\\"cuda\\") if torch.cuda.is_available() else print(\\"Running on CPU\\")"

echo "Starting JupyterLab..."
python3.13 -m jupyter lab \
  --ip=0.0.0.0 \
  --port=\${JUPYTER_PORT:-8888} \
  --no-browser \
  --allow-root \
  --FileContentsManager.delete_to_trash=False \
  --ServerApp.token="" \
  --ServerApp.allow_origin="*" \
  --ServerApp.preferred_dir=/workspace \
  --ServerApp.terminado_settings="{\\"shell_command\\": [\\"/bin/bash\\"]}" \
  &> /tmp/jupyter.log &

echo "JupyterLab started"
tail -f /tmp/jupyter.log
EOF' && chmod +x /start.sh

# Set working directory to root
WORKDIR /

EXPOSE 8888

ENTRYPOINT ["/start.sh"]
