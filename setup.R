# ============================================================
# evo2-api 项目初始化
# 用法: Rscript setup.R
# ============================================================

cat("\n正在配置 evo2-api 项目...\n\n")

# 1. renv 环境隔离
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}
renv::init(bare = TRUE, restart = FALSE)
install.packages(c("httr2", "jsonlite"))
renv::snapshot(prompt = FALSE)

# 2. API Key
cat("\nNVIDIA API Key:\n")
cat("  (去 https://build.nvidia.com/arc/evo2-40b 注册获取)\n")
cat("  留空跳过，稍后可手动编辑 .Renviron\n\n")
cat("  粘贴 Key: ")
key <- readline()
if (nchar(key) > 0) {
  cat(sprintf('NVIDIA_API_KEY="%s"\n', key),
      file = ".Renviron", append = TRUE)
  cat("已保存到 .Renviron\n")
}

# 3. 测试连接
cat("\n测试 API 连接...\n")
Sys.setenv(NVIDIA_API_KEY = key)
source("R/generate.R")
tryCatch({
  r <- evo2_generate("ACGT", n_tokens = 8)
  cat("连接成功！生成序列:", r$full_sequence, "\n")
}, error = function(e) {
  cat("测试失败:", conditionMessage(e), "\n")
})

cat("\n初始化完成！\n")
cat("  - 生成序列: Rscript R/run.R\n")
cat("  - 变异评分: source('R/score.R'); evo2_score('ACGT','ACGA')\n")
