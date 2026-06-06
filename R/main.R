# ============================================================
#  evo2-api  一键运行
# ============================================================
#  用法:  source("R/main.R")
#         run()
#
#  文件放入 input/ 后运行即可，结果在 output/
# ============================================================

# ╔══════════════════════════════════════════════════════════╗
# ║                   参   数   区                           ║
# ║              改这里控制所有行为                           ║
# ╚══════════════════════════════════════════════════════════╝

# ── 序列生成参数 ─────────────────────────────────────────────

# 每次生成多少个核苷酸（bp）
#   小值（50-200）：快速测试
#   中值（400-800）：常规使用
#   大值（1000+） ：长序列设计，耗时长
N_TOKENS     <- 400

# 温度 —— 控制随机性
#   0.1 = 非常保守，几乎总选最高概率碱基
#   1.0 = 默认平衡
#   2.0 = 非常随机，可能出现低概率碱基
#   范围：0 到正无穷
TEMPERATURE  <- 1.0

# Top-K 采样 —— 只从概率最高的 K 个碱基中抽取
#   DNA 只有 4 个字母（A/T/C/G），设 4 = 不限制
#   设 1 = 永远选概率最高的（贪婪解码）
#   设 2 = 只从前 2 个候选里选
TOP_K        <- 4

# Top-P（Nucleus Sampling）—— 累积概率达到 P 就截断
#   1.0 = 不限制
#   0.9 = 只从累积概率前 90% 的碱基中采样（去尾）
#   0.5 = 更激进地去掉低概率选项
#   范围：0 到 1
TOP_P        <- 1.0

# 随机种子 —— 生成结果是否可复现
#   NULL = 每次运行结果不同
#   任意整数（如 42）= 相同输入产生相同输出
RANDOM_SEED  <- NULL

# ── 变异评分参数 ─────────────────────────────────────────────

# 用于评分的 Evo2 模型层
#   "blocks.0"   = 浅层，早期特征
#   "blocks.28"  = 中层
#   "blocks.49"  = 最深可用层（推荐，语义信息最丰富）
#   加后缀可细化：如 "blocks.28.mlp"、"blocks.28.mlp.l3"
SCORE_LAYER  <- "blocks.49"

# ╔══════════════════════════════════════════════════════════╗
# ║             参数区结束，以下无需改动                       ║
# ╚══════════════════════════════════════════════════════════╝


run <- function() {
  source("R/init.R")
  
  has_generate <- file.exists("input/sequences.txt")
  has_score    <- file.exists("input/wt.txt") && file.exists("input/mt.txt")
  
  if (!has_generate && !has_score) {
    stop("input/ 下没有可识别的文件。请放入：\n",
         "  sequences.txt  → 批量生成序列\n",
         "  wt.txt + mt.txt → 批量变异评分")
  }
  
  # ── 序列生成 ──
  if (has_generate) {
    cat("\n")
    cat("══════════ 序列生成 ══════════\n")
    cat(sprintf("  n_tokens:    %d\n", N_TOKENS))
    cat(sprintf("  temperature: %.1f\n", TEMPERATURE))
    cat(sprintf("  top_k:       %d\n", TOP_K))
    cat(sprintf("  top_p:       %.1f\n", TOP_P))
    cat(sprintf("  seed:        %s\n",
                if (is.null(RANDOM_SEED)) "随机" else RANDOM_SEED))
    cat("──────────────────────────────\n\n")
    
    seqs <- read_sequences("input/sequences.txt")
    results <- vector("list", length(seqs))
    
    for (i in seq_along(seqs)) {
      cat(sprintf("[%d/%d] %s\n", i, length(seqs), names(seqs)[i]))
      results[[i]] <- tryCatch(
        evo2_generate(seqs[i],
                      n_tokens    = N_TOKENS,
                      temperature = TEMPERATURE,
                      top_k       = TOP_K,
                      top_p       = TOP_P,
                      random_seed = RANDOM_SEED,
                      return_probs = TRUE),
        error = function(e) { cat(sprintf("  失败: %s\n", conditionMessage(e))); NULL }
      )
      cat("\n")
    }
    
    good <- !sapply(results, is.null)
    if (sum(good) > 0) {
      full_seqs <- sapply(results[good], `[[`, "full_sequence")
      names(full_seqs) <- paste0(names(seqs)[good], "_evo2")
      write_fasta(full_seqs, "output/generated_sequences.fasta")
      write_json_results(results, "output/generated_sequences.json")
    }
    cat(sprintf("生成完成: %d/%d 成功\n\n", sum(good), length(seqs)))
  }
  
  # ── 变异评分 ──
  if (has_score) {
    cat("\n")
    cat("══════════ 变异评分 ══════════\n")
    cat(sprintf("  评分层: %s\n", SCORE_LAYER))
    cat("──────────────────────────────\n\n")
    
    wt_seqs <- read_sequences("input/wt.txt")
    mt_seqs <- read_sequences("input/mt.txt")
    
    if (length(wt_seqs) != length(mt_seqs))
      stop("wt.txt 和 mt.txt 序列数量不一致")
    
    all_scores <- list()
    for (i in seq_along(wt_seqs)) {
      cat(sprintf("[%d/%d] %s\n", i, length(wt_seqs), names(wt_seqs)[i]))
      result <- tryCatch(
        evo2_score(wt_seqs[i], mt_seqs[i], score_layer = SCORE_LAYER),
        error = function(e) { cat(sprintf("  失败: %s\n", conditionMessage(e))); NULL }
      )
      if (!is.null(result)) {
        result$per_variant$seq_name <- names(wt_seqs)[i]
        all_scores[[i]] <- result$per_variant
      }
    }
    
    good <- !sapply(all_scores, is.null)
    if (sum(good) > 0) {
      score_table <- do.call(rbind, all_scores[good])
      write.csv(score_table, "output/variant_scores.csv", row.names = FALSE)
      cat(sprintf("\n评分完成: %d/%d 成功\n", sum(good), length(wt_seqs)))
      print(score_table)
    }
  }
  
  cat("\n全部完成。结果在 output/ 下。\n")
}
