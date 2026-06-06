# ============================================================
# Evo2-40B DNA 序列生成
# ============================================================

evo2_generate <- function(prompt,
                          n_tokens      = 400,
                          temperature   = 1.0,
                          top_k         = 4,
                          top_p         = 1.0,
                          random_seed   = NULL,
                          return_probs  = FALSE,
                          return_logits = FALSE,
                          return_timing = FALSE,
                          api_key       = Sys.getenv("NVIDIA_API_KEY")) {

  if (api_key == "") stop("NVIDIA_API_KEY 未设置")
  prompt <- toupper(gsub("[\\s\\n]+", "", prompt))
  if (!grepl("^[ATCG]+$", prompt)) stop("序列只能包含 A/T/C/G")

  cat(sprintf("  发送中... (%d bp prompt)\n", nchar(prompt)))

  body <- list(
    sequence                 = prompt,
    num_tokens               = n_tokens,
    temperature              = temperature,
    top_k                    = top_k,
    top_p                    = top_p,
    enable_sampled_probs     = return_probs,
    enable_logits            = return_logits,
    enable_elapsed_ms_per_token = return_timing
  )
  if (!is.null(random_seed)) body$random_seed <- random_seed

  resp <- httr2::request(
    "https://health.api.nvidia.com/v1/biology/arc/evo2-40b/generate"
  ) |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_body_json(body) |>
    httr2::req_timeout(300) |>
    httr2::req_retry(max_tries = 2) |>
    httr2::req_perform()

  result   <- httr2::resp_body_json(resp)
  full_seq <- paste0(prompt, result$sequence)

  cat(sprintf("  生成 %d 个新核苷酸 | 耗时 %d ms\n",
              nchar(result$sequence), result$elapsed_ms))

  invisible(list(
    prompt        = prompt,
    continuation  = result$sequence,
    full_sequence = full_seq,
    probs         = result$sampled_probs,
    logits        = result$logits,
    timing        = result$elapsed_ms_per_token,
    n_new         = nchar(result$sequence),
    elapsed_ms    = result$elapsed_ms
  ))
}
