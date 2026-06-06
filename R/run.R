# ============================================================
# evo2-api -- 一键运行
# 用法: Rscript R/run.R
# ============================================================

cat("\n===== Evo2-40B 序列生成 =====\n\n")

source("R/npy.R")
source("R/generate.R")
source("R/forward.R")
source("R/utils.R")

input_file <- "input/sequences.txt"
if (!file.exists(input_file)) {
  cat("找不到 input/sequences.txt\n")
  cat("  请在 input/ 文件夹下放入序列文件\n")
  quit(status = 1)
}

seqs <- read_sequences(input_file)
cat("\n")

# ---- 参数 ----
N_TOKENS      <- 400
TEMPERATURE   <- 1.0
TOP_K         <- 4
TOP_P         <- 1.0
RANDOM_SEED   <- NULL
RETURN_PROBS  <- TRUE
RETURN_LOGITS <- FALSE
RETURN_TIMING <- FALSE
OUTPUT_FILE   <- "output/generated_sequences.fasta"
OUTPUT_JSON   <- "output/generated_sequences.json"

# ---- 逐条生成 ----
results <- vector("list", length(seqs))

for (i in seq_along(seqs)) {
  cat(sprintf("[%d/%d] %s\n", i, length(seqs), names(seqs)[i]))
  results[[i]] <- tryCatch(
    evo2_generate(seqs[i],
      n_tokens      = N_TOKENS,
      temperature   = TEMPERATURE,
      top_k         = TOP_K,
      top_p         = TOP_P,
      random_seed   = RANDOM_SEED,
      return_probs  = RETURN_PROBS,
      return_logits = RETURN_LOGITS,
      return_timing = RETURN_TIMING),
    error = function(e) {
      cat(sprintf("  失败: %s\n", conditionMessage(e)))
      NULL
    }
  )
  cat("\n")
}

good <- !sapply(results, is.null)
if (sum(good) == 0) stop("没有成功生成的序列，请检查 API Key 和网络")

full_seqs <- sapply(results[good], `[[`, "full_sequence")
names(full_seqs) <- paste0(names(seqs)[good], "_evo2")

write_fasta(full_seqs, OUTPUT_FILE)
write_json_results(results, OUTPUT_JSON)

cat("\n汇总:\n")
cat(sprintf("  成功: %d / %d\n", sum(good), length(seqs)))
cat(sprintf("  FASTA: %s\n", OUTPUT_FILE))
cat(sprintf("  JSON:  %s\n", OUTPUT_JSON))
