# ============================================================
# 纯 R 实现 .npy / .npz 解析
# 自动检测 numpy，有则加速，无则纯 R
# ============================================================

parse_npz <- function(raw_vec) {
  result <- tryCatch(parse_npz_fast(raw_vec), error = function(e) NULL)
  if (!is.null(result)) return(result)
  
  tmp_zip <- tempfile(fileext = ".zip")
  tmp_dir <- tempfile()
  writeBin(raw_vec, tmp_zip)
  dir.create(tmp_dir)
  utils::unzip(tmp_zip, exdir = tmp_dir)
  
  files <- list.files(tmp_dir, pattern = "\\.npy$", full.names = TRUE)
  result <- list()
  for (f in files) {
    nm <- gsub("\\.npy$", "", basename(f))
    raw_npy <- readBin(f, what = "raw", n = file.info(f)$size)
    result[[nm]] <- parse_npy(raw_npy)
  }
  result
}

parse_npz_fast <- function(raw_vec) {
  if (!requireNamespace("reticulate", quietly = TRUE)) stop("reticulate not available")
  if (!reticulate::py_module_available("numpy")) stop("numpy not available")
  
  np <- reticulate::import("numpy", convert = FALSE)
  tmp <- tempfile(fileext = ".npz")
  writeBin(raw_vec, tmp)
  data <- np$load(tmp)
  
  file_names <- reticulate::py_to_r(data$files)
  
  result <- list()
  for (nm in file_names) {
    key <- gsub("\\.npy$", "", nm)
    arr <- np$squeeze(data[[nm]], as.integer(0L))
    result[[key]] <- reticulate::py_to_r(arr)
  }
  result
}





parse_npy <- function(raw_vec) {
  magic <- raw_vec[1:6]
  if (!all(magic == as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59)))) {
    stop("not a valid .npy file")
  }
  
  major <- as.integer(raw_vec[7])
  minor <- as.integer(raw_vec[8])
  
  header_len <- as.integer(raw_vec[9]) + as.integer(raw_vec[10]) * 256L
  
  header_start <- 11
  header_raw   <- raw_vec[header_start:(header_start + header_len - 1)]
  header_str   <- rawToChar(header_raw[header_raw != as.raw(0x0a)])
  
  dtype <- regmatches(header_str,
                      regexec("'descr':\\s*'([^']+)'", header_str))[[1]][2]
  
  shape_str <- regmatches(header_str,
                          regexec("'shape':\\s*\\(([^)]*)\\)", header_str))[[1]][2]
  shape <- as.integer(strsplit(gsub("\\s+", "", shape_str), ",")[[1]])
  if (length(shape) == 1) {
    shape <- c(shape, 1L)
  } else if (length(shape) == 3 && shape[1] == 1) {
    shape <- shape[2:3]
  }
  
  dt_map <- list(
    "<f2" = list(bytes = 2, signed = TRUE,  type = "float16"),
    ">f2" = list(bytes = 2, signed = TRUE,  type = "float16_be"),
    "<f4" = list(bytes = 4, signed = TRUE,  type = "numeric"),
    ">f4" = list(bytes = 4, signed = TRUE,  type = "numeric_be"),
    "<f8" = list(bytes = 8, signed = TRUE,  type = "numeric"),
    ">f8" = list(bytes = 8, signed = TRUE,  type = "numeric_be"),
    "<i4" = list(bytes = 4, signed = TRUE,  type = "integer"),
    "<i8" = list(bytes = 8, signed = TRUE,  type = "integer")
  )
  dt <- dt_map[[dtype]]
  if (is.null(dt)) stop("unsupported dtype: ", dtype)
  
  aligned     <- ((10L + header_len + 15L) %/% 16L) * 16L
  data_offset <- aligned + 1L
  data_raw    <- raw_vec[data_offset:length(raw_vec)]
  total_elems <- prod(shape)
  
  endian <- if (grepl("^<", dtype)) "little" else "big"
  
  if (grepl("float16", dt$type)) {
    vals <- read_float16(data_raw, endian == "little")
  } else {
    vals <- readBin(data_raw, what = dt$type,
                    n = total_elems, size = dt$bytes,
                    signed = dt$signed, endian = endian)
  }
  
  matrix(vals, nrow = shape[1], ncol = shape[2], byrow = TRUE)
}

read_float16 <- function(raw_vec, little_endian = TRUE) {
  n <- length(raw_vec) / 2
  result <- numeric(n)
  for (i in seq_len(n)) {
    idx <- (i - 1) * 2 + 1
    b1 <- as.integer(raw_vec[idx])
    b2 <- as.integer(raw_vec[idx + 1])
    bits <- if (little_endian) b1 + b2 * 256L else b2 + b1 * 256L
    sign  <- if (bitwAnd(bits, 0x8000) > 0) -1 else 1
    expo  <- bitwAnd(bitwShiftR(bits, 10), 0x1F)
    mant  <- bitwAnd(bits, 0x03FF)
    if (expo == 0) {
      result[i] <- sign * 2^(-14) * (mant / 1024)
    } else if (expo == 31) {
      result[i] <- if (mant == 0) sign * Inf else NaN
    } else {
      result[i] <- sign * 2^(expo - 15) * (1 + mant / 1024)
    }
  }
  result
}
