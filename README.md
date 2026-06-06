# evo2-api

用 [NVIDIA Evo2-40B](https://build.nvidia.com/arc/evo2-40b) 在 R 中批量生成 DNA 序列、提取 embedding、零样本变异效应预测。

## 前置要求

- **R** ≥ 4.0
- **RStudio**（推荐）或任意 R 终端
- **renv** 包（用于依赖管理）
- [NVIDIA API Key](https://build.nvidia.com/arc/evo2-40b)（免费注册获取）

## 项目结构

```
evo2-api/
├── R/
│   ├── main.R          # 入口，参数配置 + run()
│   ├── init.R          # 模块加载
│   ├── generate.R      # 序列生成（调用 NVIDIA API）
│   ├── score.R         # 零样本变异评分
│   ├── forward.R       # embedding 提取
│   ├── npy.R           # NumPy .npy 文件解析
│   └── utils.R         # FASTA 读写等工具
├── input/              # 放输入文件
├── output/             # 结果输出（自动创建）
├── renv.lock           # renv 依赖锁文件
├── .Renviron           # API Key（需自行创建）
└── README.md
```

## 安装

```bash
git clone https://github.com/olivia339612-ai/evo2-api.git
cd evo2-api
```

打开 RStudio，切到项目目录，运行：

```r
renv::restore()
```

如果报 `package 'renv' not found`：

```r
install.packages("renv")
renv::restore()
```

## 配置 API Key

1. 打开 https://build.nvidia.com/arc/evo2-40b 注册获取 Key
2. 在项目根目录创建 `.Renviron` 文件，内容一行：

```
NVIDIA_API_KEY="nvapi-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

3. 重启 RStudio

> **注意**：`.Renviron` 已在 `.gitignore` 中，不会被提交到 git。

## 使用

把序列文件放进 `input/` 文件夹，开启梯子然后：

```r
Sys.setenv(http_proxy = "http://127.0.0.1:7890")
Sys.setenv(https_proxy = "http://127.0.0.1:7890")
source("R/main.R")
run()
```

程序自动检测 `input/` 下的文件并执行对应任务。

### 单独使用

环境初始化后也可以直接调用函数：

```r
source("R/init.R")

# 生成序列
result <- evo2_generate("ACGTACGT", n_tokens = 200, temperature = 1.0)

# 变异评分
scores <- evo2_score("ACGTACGT...", "ACGAACGT...", score_layer = "blocks.49")
```

## Input 文件格式

| 任务 | 文件 | 格式 | 说明 |
|------|------|------|------|
| 生成序列 | `input/sequences.txt` | 每行一条 DNA，或 FASTA | 以输入序列为 prompt，续写生成 |
| 变异评分 | `input/wt.txt` + `input/mt.txt` | FASTA，一一对应 | 序列长度 ≥ 128 bp |

`sequences.txt` 示例：

```
ATGCGATCGATCG
TTTTAAAACCCCGGG
```

`wt.txt` / `mt.txt` 示例（FASTA 格式）：

```
>seq1
ATGCGATCGATCGATCGATCG...（≥ 128 bp）
>seq2
GCTAGCTAGCTAGCTAGCTA...
```

## 输出

| 文件 | 内容 |
|------|------|
| `output/generated_sequences.fasta` | 生成的完整序列（prompt + 续写） |
| `output/generated_sequences.json` | 每个位置的概率置信度 |
| `output/variant_scores.csv` | 变异评分（`cos_sim` 越偏离 1 越有害） |

## 参数调整

打开 `R/main.R`，修改文件顶部的参数区：

```r
# ── 序列生成参数 ──
N_TOKENS     <- 400      # 每次生成多少 bp
TEMPERATURE  <- 1.0      # 0.1 保守 / 2.0 随机
TOP_K        <- 4        # 1 贪婪 / 4 不限制
TOP_P        <- 1.0      # 0.9 去尾 / 1.0 不限制
RANDOM_SEED  <- NULL     # 设数字可复现

# ── 变异评分参数 ──
SCORE_LAYER  <- "blocks.49"  # 评分用的模型层
```

改数字，保存，重新 `source("R/main.R"); run()`。

### 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `N_TOKENS` | `400` | 每次续写生成的核苷酸数量（bp） |
| `TEMPERATURE` | `1.0` | 温度，越高越随机。范围 0 ~ +∞ |
| `TOP_K` | `4` | 只从概率最高的 K 个碱基中采样。DNA 只有 4 个字母，设 4 = 不限制 |
| `TOP_P` | `1.0` | Nucleus Sampling 阈值。0.9 = 去掉概率尾部 10% |
| `RANDOM_SEED` | `NULL` | 随机种子。设整数（如 `42`）可复现结果 |
| `SCORE_LAYER` | `"blocks.49"` | 评分所用模型层。"blocks.0" 浅层，"blocks.49" 最深 |

## 常见问题

### API Key 认证失败

确保 `.Renviron` 文件在项目根目录，且格式正确（无多余空格）：

```
NVIDIA_API_KEY="nvapi-..."
```

然后**重启 RStudio**，运行 `Sys.getenv("NVIDIA_API_KEY")` 验证是否生效。

### 序列长度不够

变异评分要求输入序列 ≥ 128 bp。更短的序列会导致 API 返回错误。

### 网络问题

API 调用需要访问 `https://api.nvcf.nvidia.com`。如果公司网络有限制，请配置代理或切换网络。

## License

MIT
