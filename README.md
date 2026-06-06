```markdown
# evo2-api

用 NVIDIA Evo2-40B 在 R 中批量生成 DNA 序列、提取 embedding、零样本变异效应预测。

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
NVIDIA_API_KEY="nvapi-你的密钥"
```

3. 重启 RStudio

## 使用

把序列文件放进 `input/` 文件夹，然后：

```r
source("R/main.R")
run()
```

程序自动检测 `input/` 下的文件并执行对应任务。

## input 文件格式

| 任务 | 文件 | 格式 |
|------|------|------|
| 生成序列 | `sequences.txt` | 每行一条 DNA，或 FASTA |
| 变异评分 | `wt.txt` + `mt.txt` | FASTA，一一对应，长度 ≥ 128 bp |

`sequences.txt` 示例：
```
ATGCGATCGATCG
TTTTAAAACCCCGGG
```

## 输出

| 文件 | 内容 |
|------|------|
| `output/generated_sequences.fasta` | 生成的完整序列 |
| `output/generated_sequences.json` | 每个位置置信度 |
| `output/variant_scores.csv` | 变异评分（cos_sim 越偏离 1 越有害） |

## 参数调整

打开 `R/main.R`，文件顶部：

```r
N_TOKENS     <- 400      # 每次生成多少 bp
TEMPERATURE  <- 1.0      # 0.1 保守  /  2.0 随机
TOP_K        <- 4        # 1 贪婪  /  4 不限制
TOP_P        <- 1.0      # 0.9 去尾  /  1.0 不限制
RANDOM_SEED  <- NULL     # 设数字可复现
SCORE_LAYER  <- "blocks.49"  # 评分用的模型层
```

改数字，保存，重新 `source("R/main.R"); run()`。