# ============================================================
# Python 加速安装（可选）
# 用法: source("R/setup_fast.R")
# ============================================================

install.packages("reticulate")
reticulate::install_miniconda(path = file.path(getwd(), "miniconda"))
reticulate::conda_create(envname = "./python_env", packages = "numpy")

cat("加速安装完成。NPZ 解析从 30 秒 → <1 秒\n")
cat("重新 source('R/main.R'); run() 即可\n")
