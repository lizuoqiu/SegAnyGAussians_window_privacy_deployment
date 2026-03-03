#!/usr/bin/env bash
set -e

# ========= SSH（RunPod 会注入你的公钥到 authorized_keys） =========
mkdir -p /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
ssh-keygen -A
/usr/sbin/sshd

# ========= 持久化代码：clone 到 /workspace/src =========
REPO_URL="${REPO_URL:-https://github.com/lizuoqiu/SegAnyGAussians_window_privacy.git}"
REPO_REF="${REPO_REF:-v2}"

mkdir -p /workspace
cd /workspace

if [ ! -d "src/.git" ]; then
  echo "[start] Cloning repo into /workspace/src ..."
  rm -rf src
  git clone --recurse-submodules "$REPO_URL" src || { echo "[start] git clone failed"; sleep infinity; }
  cd src
  git checkout "$REPO_REF"
  git submodule update --init --recursive
else
  echo "[start] Repo already exists at /workspace/src (skip clone)."
  cd src
fi

# =========（可选）在 A100 上编译/安装 CUDA 扩展（只跑一次）=========
# 如果你已经把 submodules 的 CUDA 扩展从 environment.yml 移除，
# 可以在这里检测并安装一次，然后以后重启不再重复编译：
if [ ! -f "/workspace/src/.cuda_ext_installed" ]; then
  echo "[start] Installing CUDA extensions (A100 sm80) ..."
  export TORCH_CUDA_ARCH_LIST="8.0+PTX"
  export FORCE_CUDA=1
  export MAX_JOBS="${MAX_JOBS:-8}"

  # 注意：这里假设这些目录在 repo 里存在
  conda run -n gaussian_splatting pip install -v submodules/diff-gaussian-rasterization
  conda run -n gaussian_splatting pip install -v submodules/diff-gaussian-rasterization_contrastive_f
  conda run -n gaussian_splatting pip install -v submodules/diff-gaussian-rasterization-depth
  conda run -n gaussian_splatting pip install -v submodules/simple-knn

  touch /workspace/src/.cuda_ext_installed
else
  echo "[start] CUDA extensions already installed (skip)."
fi

# ========= JupyterLab =========
JUPYTER_BIN="/opt/conda/envs/gaussian_splatting/bin/jupyter"
PORT="${JUPYTER_PORT:-8888}"
TOKEN="${JUPYTER_TOKEN:-runpod}"

"$JUPYTER_BIN" lab \
  --ip=0.0.0.0 \
  --port="$PORT" \
  --no-browser \
  --allow-root \
  --ServerApp.root_dir="/workspace" \
  --ServerApp.token="$TOKEN" \
  --ServerApp.password="" \
  > /var/log/jupyter.log 2>&1 &

echo "[start] JupyterLab running on port ${PORT} (token: ${TOKEN})."

# ========= 保活 =========
exec sleep infinity