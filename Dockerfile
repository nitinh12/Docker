# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

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
RUN python -m pip install --no-cache-dir \
    jupyterlab==4.4.2 \
    ipywidgets \
    jupyter-archive

# Install PyTorch with CUDA 12.8
RUN python -m pip install --no-cache-dir \
    torch==2.7.0 \
    torchvision==0.22.0 \
    torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu128

# Create workspace
RUN mkdir -p /workspace && chmod -R 777 /workspace

# Welcome message
RUN echo -e '\n\033[1mCogniCore-AI\033[0m\n' > /etc/cogni_core.txt && \
    echo -e 'Subscribe to my YouTube channel for the latest automatic install scripts for RunPod:\n\033[1;34mhttps://www.youtube.com/@CogniCore-AI\033[0m\n' >> /etc/cogni_core.txt && \
    echo 'cat /etc/cogni_core.txt' >> /root/.bashrc

# ✅ Correct embedded startup script
RUN printf '#!/bin/bash\n\
echo "Starting container..."\n\
mkdir -p /workspace\n\
chmod -R 777 /workspace\n\
ln -sf /bin/bash /bin/sh\n\
if ss -tuln | grep -q ":8888 "; then\n\
  echo "Port 8888 is already in use, attempting to free it..."\n\
  fuser -k 8888/tcp || true\n\
fi\n\
echo "Starting JupyterLab..."\n\
python -m jupyter lab \\\n\
  --ip=0.0.0.0 \\\n\
  --port=${JUPYTER_PORT:-8888} \\\n\
  --no-browser \\\n\
  --allow-root \\\n\
  --ServerApp.token="" \\\n\
  --ServerApp.password="" \\\n\
  --ServerApp.allow_origin="*" \\\n\
  --ServerApp.root_dir=/workspace \\\n\
  --ServerApp.terminado_settings="{\\"shell_command\\": [\\"/bin/bash\\"]}" \\\n\
  &> /tmp/jupyter.log &\n\
echo "JupyterLab started"\n\
tail -f /tmp/jupyter.log\n' > /start.sh && chmod +x /start.sh

# Working directory
WORKDIR /workspace

# Expose port
EXPOSE 8888

# Entrypoint
ENTRYPOINT ["/start.sh"]
