# ============================================================
# 输入 / 输出工具
# ============================================================

read_sequences <- function(path) {
  raw <- readLines(path, warn = FALSE)
  raw <- raw[raw != ""]

  if (grepl("^>", raw[1])) {
    cat("检测到 FASTA 格式\n")
    header_idx <- grep("^>", raw)
    seq_start  <- header_idx + 1
    seq_end    <- c(header_idx[-1] - 1, length(raw))
    seqs <- mapply(function(s, e) paste(raw[s:e], collapse = ""),
                   seq_start, seq_end)
    names(seqs) <- gsub("^>\\s*", "", raw[header_idx])
    cat(sprintf("  找到 %d 条序列\n", length(seqs)))
    return(seqs)
  } else if (any(grepl("[,;\t]", raw))) {
    cat("检测到表格格式，取第一列\n")
    df <- read.table(path, header = TRUE, sep = "", comment.char = "")
    seqs <- df[[1]]
    names(seqs) <- if (ncol(df) > 1) df[[2]] else paste0("seq_", seq_along(seqs))
    return(seqs)
  } else {
    cat("每行一条序列\n")
    seqs <- raw
    names(seqs) <- paste0("seq_", seq_along(seqs))
    cat(sprintf("  找到 %d 条序列\n", length(seqs)))
    return(seqs)
  }
}

write_fasta <- function(seqs, path) {
  con <- file(path, "w")
  for (nm in names(seqs)) {
    writeLines(paste0(">", nm), con)
    writeLines(seqs[[nm]], con)
  }
  close(con)
  cat(sprintf("已保存 %d 条序列 -> %s\n", length(seqs), path))
}

write_json_results <- function(results, path) {
  good <- results[!sapply(results, is.null)]
  out <- lapply(good, function(r) list(
    prompt        = r$prompt,
    full_sequence = r$full_sequence,
    continuation  = r$continuation,
    n_new         = r$n_new,
    probs         = r$probs
  ))
  jsonlite::write_json(out, path, pretty = TRUE, auto_unbox = TRUE, digits = 10)
  cat(sprintf("已保存 %d 条结果的置信度 -> %s\n", length(out), path))
}

cat_seq <- function(seq, width = 60) {
  cat(gsub(paste0("(.{", width, "})"), "\\1\n", seq), "\n")
}
