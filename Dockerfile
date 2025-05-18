# Use the correct NVIDIA CUDA base image with Ubuntu 24.04
FROM nvidia/cuda:12.8.1-cudnn-devel-Ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system dependencies and Python 3.13
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
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-setuptools \
        python3-wheel \
        libexpat1-dev \
        zlib1g-dev && \
    apt-get remove -y python3.12 python3.12-dev || true && \
    dpkg -l | grep -E 'python3\.[0-9]+' | grep -v 'python3\.13' | awk '{print $2}' | xargs -r apt-get purge -y || true && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js for JupyterLab build support
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
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

# Pre-download large files (reverted to original placeholder)
RUN mkdir -p /opt/models && \
    echo "Downloading large files during build..." && \
    echo "Large files downloaded and extracted"

# Create visible workspace for mounted network disk
RUN mkdir -p /workspace && chmod -R 777 /workspace

# Copy the ASCII art file for the welcome message
COPY cognicore.txt /etc/cognicore.txt

# Update .bashrc to display the ASCII art on terminal startup
RUN echo 'cat /etc/cognicore.txt' >> /root/.bashrc

# Updated start.sh to skip downloads if files exist (reverted authentication fix)
RUN printf '#!/bin/bash\n\
echo "Starting container..."\n\
mkdir -p /workspace\n\
chmod -R 777 /workspace\n\
ln -sf /bin/bash /bin/sh\n\
echo "Checking contents of /workspace..."\n\
ls -la /workspace >> /tmp/jupyter.log 2>&1\n\
# Check for pre-downloaded files and skip download if they exist\n\
if [ -d "/opt/models" ] && [ "$(ls -A /opt/models)" ]; then\n\
  echo "Pre-downloaded files found in /opt/models, skipping download..." >> /tmp/jupyter.log\n\
else\n\
  echo "No pre-downloaded files found in /opt/models, you may need to download them manually..." >> /tmp/jupyter.log\n\
fi\n\
if ss -tuln | grep -q ":8888 "; then\n\
  echo "Port 8888 is already in use, attempting to free it..."\n\
  fuser -k 8888/tcp || true\n\
fi\n\
echo "Starting JupyterLab..."\n\
python3.13 -m jupyter lab \\\n\
  --ip=0.0.0.0 \\\n\
  --port=${JUPYTER_PORT:-8888} \\\n\
  --no-browser \\\n\
  --allow-root \\\n\
  --FileContentsManager.delete_to_trash=False \\\n\
  --ServerApp.token="" \\\n\
  --ServerApp.allow_origin="*" \\\n\
  --ServerApp.preferred_dir=/workspace \\\n\
  --ServerApp.terminado_settings="{\\"shell_command\\": [\\"/bin/bash\\"]}" \\\n\
  &>> /tmp/jupyter.log &\n\
echo "JupyterLab started"\n\
tail -f /tmp/jupyter.log\n' > /start.sh && chmod +x /start.sh

# Set working directory to root to avoid forcing terminal to /workspace
WORKDIR /

EXPOSE 8888

ENTRYPOINT ["/start.sh"]
