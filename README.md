---

```
evo2-api 使用指南
最后更新：2026-06-06
```

## 1. 安装

```r
renv::restore()
```

如果报错 `package 'renv' not found`：

```r
install.packages("renv")
renv::restore()
```

## 2. 配置 API Key

去 [build.nvidia.com/arc/evo2-40b](https://build.nvidia.com/arc/evo2-40b) 注册获取 Key。

在项目根目录创建 `.Renviron`，内容一行：

```
NVIDIA_API_KEY="nvapi-你的密钥"
```

重启 RStudio。

## 3. 放入序列文件

文件放 `input/` 文件夹。

| 你要做什么 | 需要放的文件 |
|-----------|------------|
| 生成新序列 | `sequences.txt` |
| 变异评分 | `wt.txt` + `mt.txt` |

### `sequences.txt` 格式

```
ATGCGATCGATCG
TTTTAAAACCCCGGG
```

每行一条 DNA 序列。也支持 FASTA：
```
>启动子A
ATGCGATCGATCG
```

### `wt.txt` + `mt.txt` 格式

FASTA 格式，两条文件一一对应。序列长度必须 ≥ 128 bp，且同对长度相同。

## 4. 运行

```r
source("R/main.R")
run()
```

## 5. 结果

| 任务 | 输出文件 |
|------|---------|
| 生成序列 | `output/generated_sequences.fasta` |
| 置信度 | `output/generated_sequences.json` |
| 变异评分 | `output/variant_scores.csv` |

## 6. 参数调整

打开 `R/main.R`，文件顶部：

```r
N_TOKENS     <- 400      # 每次生成多少 bp
TEMPERATURE  <- 1.0      # 0.1=保守  2.0=随机
TOP_K        <- 4        # 1=贪婪 4=不限制
TOP_P        <- 1.0      # 0.9=去尾  1.0=不限制
RANDOM_SEED  <- NULL     # 设数字可复现
SCORE_LAYER  <- "blocks.49"  # 评分用的模型层
```

改数字，保存，重新 `source("R/main.R"); run()`。