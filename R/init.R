# ============================================================
# 一键加载 evo2-api 全部功能
# ============================================================

source("R/npy.R")
source("R/utils.R")
source("R/generate.R")
source("R/forward.R")
source("R/score.R")

cat("\n  Evo2-40B 已就绪\n")
cat("  生成序列: evo2_generate('ACGT...', n_tokens=200)\n")
cat("  变异评分: evo2_score('ACGT...', 'ACGA...')\n")
cat("  一键运行: run()\n\n")
