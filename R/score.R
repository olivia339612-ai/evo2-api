# ============================================================
# 零样本变异效应预测 (Zero-shot VEP)
# ============================================================

evo2_score <- 
  function(wt_seq, mt_seq,
                       variant_pos   = NULL,
                       score_layer   = "blocks.49",
                       api_key       = Sys.getenv("NVIDIA_API_KEY")) {
  
  if (nchar(wt_seq) != nchar(mt_seq))
    stop("野生型和突变型序列长度必须相同")
    
  if (nchar(wt_seq) < 128) stop("序列长度至少 128 bp，当前 ", nchar(wt_seq), " bp")
    
  if (is.null(variant_pos)) {
    wt_chars <- strsplit(wt_seq, "")[[1]]
    mt_chars <- strsplit(mt_seq, "")[[1]]
    variant_pos <- which(wt_chars != mt_chars)
    if (length(variant_pos) == 0) stop("未检测到变异位点")
  }
  
  cat(sprintf("  序列: %d bp | 变异位点: %s\n",
              nchar(wt_seq),
              paste(variant_pos[1:min(5, length(variant_pos))], collapse = ",")))
  
  cat("  处理野生型...\n")
  wt_fwd <- evo2_forward(wt_seq, output_layers = c(score_layer), api_key = api_key)
  
  cat("  处理突变型...\n")
  mt_fwd <- evo2_forward(mt_seq, output_layers = c(score_layer), api_key = api_key)
  
  wt_hidden <- wt_fwd$layers[[paste0(score_layer, ".output")]]
  mt_hidden <- mt_fwd$layers[[paste0(score_layer, ".output")]]
  
  if (is.null(wt_hidden) || is.null(mt_hidden))
    stop("无法提取 ", score_layer, " 的输出")
  
  # 用最后一个 block 的输出做余弦距离评估变异影响
  seq_len_dim <- nchar(wt_seq)
  
  wt_chars <- strsplit(wt_seq, "")[[1]]
  mt_chars <- strsplit(mt_seq, "")[[1]]
  
  scores <- data.frame(
    pos     = integer(),
    ref     = character(),
    alt     = character(),
    cos_sim = numeric(),
    stringsAsFactors = FALSE
  )
  
  for (p in variant_pos) {
    if (p > nrow(wt_hidden)) next
    
    wt_vec <- wt_hidden[p, ]
    mt_vec <- mt_hidden[p, ]
    cos_sim <- sum(wt_vec * mt_vec) / (sqrt(sum(wt_vec^2)) * sqrt(sum(mt_vec^2)))
    
    scores <- rbind(scores, data.frame(
      pos     = p,
      ref     = wt_chars[p],
      alt     = mt_chars[p],
      cos_sim = cos_sim,
      stringsAsFactors = FALSE
    ))
  }
  
  cat(sprintf("  平均余弦相似度: %.6f (%s)\n",
              mean(scores$cos_sim),
              ifelse(mean(scores$cos_sim) < 0.999, "可能有害", "可能良性")))
  
  invisible(list(
    wt_sequence       = wt_seq,
    mt_sequence       = mt_seq,
    variant_positions  = variant_pos,
    per_variant       = scores,
    mean_cos_sim      = mean(scores$cos_sim)
  ))
}


evo2_score_batch <- function(wt_list, mt_list, ...) {
  if (is.character(wt_list) && length(wt_list) == 1 && file.exists(wt_list)) {
    source("R/utils.R")
    wt_list <- read_sequences(wt_list)
    mt_list <- read_sequences(mt_list)
  }
  if (length(wt_list) != length(mt_list))
    stop("野生型和突变型序列数量不一致")
  
  results <- vector("list", length(wt_list))
  for (i in seq_along(wt_list)) {
    cat(sprintf("[%d/%d] %s\n", i, length(wt_list), names(wt_list)[i]))
    results[[i]] <- tryCatch(
      evo2_score(wt_list[i], mt_list[i], ...),
      error = function(e) { cat(sprintf("  失败: %s\n", conditionMessage(e))); NULL }
    )
  }
  
  good <- !sapply(results, is.null)
  if (sum(good) == 0) stop("全部失败")
  
  score_table <- do.call(rbind, lapply(results[good], `[[`, "per_variant"))
  cat(sprintf("\n汇总: 成功 %d/%d | 平均余弦相似度: %.6f\n",
              sum(good), length(wt_list), mean(score_table$cos_sim)))
  invisible(list(table = score_table, details = results))
}
