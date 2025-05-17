FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV JUPYTER_PORT=8888
ENV SHELL=/bin/bash

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
        psmisc \
        openssh-server \
        nginx && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Python 3.13
RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-dev \
        python3.13-venv && \
    ln -s /usr/bin/python3.13 /usr/bin/python && \
    rm /usr/bin/python3 && \
    ln -s /usr/bin/python3.13 /usr/bin/python3 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python get-pip.py && \
    rm get-pip.py && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
        jupyterlab==4.4.2 \
        ipywidgets \
        jupyter-archive

# Install PyTorch (separate command)
RUN pip install --no-cache-dir \
    torch==2.7.0 \
    torchvision==0.22.0 \
    torchaudio==2.7.0 \
    --index-url https://download.pytorch.org/whl/cu128

# Only ensure path exists — RunPod will mount over it
RUN mkdir /workspace

# Optional welcome message
RUN echo -e '\n\033[1mCogniCore-AI\033[0m\n' > /etc/cogni_core.txt && \
    echo -e 'Subscribe to my YouTube channel:\n\033[1;34mhttps://www.youtube.com/@CogniCore-AI\033[0m\n' >> /etc/cogni_core.txt && \
    echo 'cat /etc/cogni_core.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor RunPod guides: https://docs.runpod.io/\n"' >> /root/.bashrc

# Start script
RUN printf '#!/bin/bash\n\
mkdir -p /workspace\n\
ln -sf /bin/bash /bin/sh\n\
echo "Launching JupyterLab..."\n\
python -m jupyter lab \\\n\
  --ip=0.0.0.0 \\\n\
  --port=${JUPYTER_PORT:-8888} \\\n\
  --no-browser \\\n\
  --allow-root \\\n\
  --ServerApp.token="" \\\n\
  --ServerApp.password="" \\\n\
  --ServerApp.allow_origin="*" \\\n\
  --ServerApp.root_dir=/ \\\n\
  --ServerApp.default_url="/lab/tree/workspace" \\\n\
  --ServerApp.terminado_settings="{\\"shell_command\\": [\\"/bin/bash\\"]}" \\\n\
  &> /tmp/jupyter.log &\n\
tail -f /tmp/jupyter.log\n' > /start.sh && chmod +x /start.sh

# Match RunPod setup: don't set /workspace as WORKDIR
WORKDIR /

EXPOSE 8888

ENTRYPOINT ["/start.sh"]
