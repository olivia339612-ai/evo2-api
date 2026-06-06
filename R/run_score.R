# ============================================================
# 批量变异评分
# 用法: Rscript R/run_score.R
# ============================================================

cat("\n===== Evo2-40B 变异效应评分 =====\n\n")

source("R/npy.R")
source("R/forward.R")
source("R/score.R")
source("R/utils.R")

wt_file <- "input/wt.txt"
mt_file <- "input/mt.txt"

if (!file.exists(wt_file)) stop("找不到 ", wt_file)
if (!file.exists(mt_file)) stop("找不到 ", mt_file)

wt_seqs <- read_sequences(wt_file)
mt_seqs <- read_sequences(mt_file)

if (length(wt_seqs) != length(mt_seqs))
  stop("野生型和突变型序列数量不一致")

# ---- 参数 ----
SCORE_LAYER <- "blocks.49"
OUTPUT_FILE <- "output/variant_scores.csv"

# ---- 逐条评分 ----
all_scores <- list()

for (i in seq_along(wt_seqs)) {
  cat(sprintf("[%d/%d] %s\n", i, length(wt_seqs), names(wt_seqs)[i]))
  result <- tryCatch(
    evo2_score(wt_seqs[i], mt_seqs[i], score_layer = SCORE_LAYER),
    error = function(e) {
      cat(sprintf("  失败: %s\n", conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(result)) {
    result$per_variant$seq_name <- names(wt_seqs)[i]
    all_scores[[i]] <- result$per_variant
  }
}

# ---- 汇总输出 ----
score_table <- do.call(rbind, all_scores)
write.csv(score_table, OUTPUT_FILE, row.names = FALSE)

cat(sprintf("\n已保存 %d 条序列的评分 -> %s\n", length(all_scores), OUTPUT_FILE))
print(head(score_table))
