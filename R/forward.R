# ============================================================
# Evo2-40B 前向传播
# 提取 logits 或中间层 embedding
# ============================================================

evo2_forward <- function(sequence,
                         output_layers = c("blocks.0"),
                         api_key       = Sys.getenv("NVIDIA_API_KEY"),
                         save_npz      = FALSE,
                         npz_prefix    = "forward") {
  
  if (api_key == "") stop("NVIDIA_API_KEY 未设置")
  sequence <- toupper(gsub("[\\s\\n]+", "", sequence))
  if (!grepl("^[ATCG]+$", sequence)) stop("序列只能包含 A/T/C/G")
  if (nchar(sequence) < 128) stop("序列长度至少 128 bp，当前 ", nchar(sequence), " bp")
  
  cat(sprintf("  前向传播... (%d bp, %d 层)\n",
              nchar(sequence), length(output_layers)))
  
  resp <- httr2::request(
    "https://health.api.nvidia.com/v1/biology/arc/evo2-40b/forward"
  ) |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_body_json(list(
      sequence      = sequence,
      output_layers = as.list(output_layers)
    )) |>
    httr2::req_timeout(600) |>
    httr2::req_retry(max_tries = 2) |>
    httr2::req_perform()
  
  result  <- httr2::resp_body_json(resp)
  raw_npz <- NULL
  layers  <- list()
  
  if (!is.null(result$data)) {
    raw_npz <- jsonlite::base64_dec(result$data)
    layers  <- parse_npz(raw_npz)
  }
  
  if (save_npz && !is.null(raw_npz)) {
    dir.create("output", showWarnings = FALSE)
    npz_path <- file.path("output",
                          paste0(npz_prefix, "_", format(Sys.Date(), "%Y%m%d"), ".npz"))
    writeBin(raw_npz, npz_path)
    cat(sprintf("  NPZ 已保存 -> %s\n", npz_path))
  }
  
  cat(sprintf("  耗时 %d ms\n", result$elapsed_ms))
  
  invisible(list(
    sequence   = sequence,
    layers     = layers,
    raw_npz    = raw_npz,
    elapsed_ms = result$elapsed_ms
  ))
}
