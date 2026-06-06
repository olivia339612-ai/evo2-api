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
  
  aligned    <- ((10L + header_len + 15L) %/% 16L) * 16L
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
