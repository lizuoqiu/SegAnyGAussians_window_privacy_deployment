FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive \
    CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    CONDA_PLUGINS_AUTO_ACCEPT_TOS=yes

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates wget curl bzip2 \
    build-essential cmake ninja-build \
    libgl1 libglib2.0-0 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Miniforge（稳定链接）
RUN curl -fsS --retry 5 --retry-delay 2 --retry-connrefused \
    -o /tmp/miniconda.sh "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    conda config --set channel_priority flexible


RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN git config --global url."https://github.com/".insteadOf "git@github.com:"

ARG REPO_URL="https://github.com/lizuoqiu/SegAnyGAussians_window_privacy.git"
ARG REPO_REF="v2"

WORKDIR /workspace

# 拉你的 fork + submodules
RUN git clone --recurse-submodules ${REPO_URL} src && \
    cd src && \
    git checkout ${REPO_REF} && \
    git submodule update --init --recursive

# 用“构建仓库里的 environment.yml”覆盖掉 src 里的（这样你不用改 fork）
COPY environment.yml /workspace/src/environment.yml

WORKDIR /workspace/src

RUN conda env create -f environment.yml && conda clean -a -y

# 保险起见：再锁一次你要的 safetensors
RUN conda run -n gaussian_splatting pip install --no-cache-dir safetensors==0.4.2

ENV CONDA_DEFAULT_ENV=gaussian_splatting
ENV PATH=/opt/conda/envs/gaussian_splatting/bin:$PATH

# 构建期自检
RUN python -c "import torch, safetensors; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'safetensors', safetensors.__version__)"

# SSH 基本配置：仅允许 key 登录
RUN mkdir -p /var/run/sshd && \
    printf "PermitRootLogin prohibit-password\nPasswordAuthentication no\nPubkeyAuthentication yes\n" \
      > /etc/ssh/sshd_config.d/runpod.conf

EXPOSE 22

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]