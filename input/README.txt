================================================================
  input/ 文件夹使用说明
================================================================

本文件夹用于存放待处理的序列文件。程序会自动检测并执行对应任务。


【任务一】批量生成序列
----------------------------------------------------------------

  文件名：sequences.txt
  说明：  每行为一条 DNA 序列作为 prompt，模型会续写生成新序列。

  格式示例（每行一条）：

    ATGCGATCGATCG
    TTTTAAAACCCCGGG
    GATTACAGATTACA

  也支持 FASTA 格式：

    >启动子A
    ATGCGATCGATCG
    >增强子B
    TTTTAAAACCCCGGG

  输出文件：
    output/generated_sequences.fasta   （生成的完整序列）
    output/generated_sequences.json    （含每个位置置信度）


【任务二】批量变异评分
----------------------------------------------------------------

  文件名：wt.txt  和  mt.txt
  说明：  wt.txt = 野生型序列
          mt.txt = 突变型序列
          两条文件里的序列必须一一对应（同数量、同顺序）。

  格式示例：

    --- wt.txt ---              --- mt.txt ---
    >BRCA1_wt                   >BRCA1_mt
    ATGCGATCGATCGATCG...        ATGCGATCGATCGATCG...
    >TP53_wt                    >TP53_mt
    TTTAAAACCCGGGTTT...         TTTAAAACCCGGGTTT...

  注意：
    - 每条序列长度必须 >= 128 bp
    - 同一对序列长度必须相同（只有一个或多个碱基不同）
    - 程序自动检测变异位点，无需手动标注

  输出文件：
    output/variant_scores.csv   （每行一个变异位点的评分）


【同时使用两个任务】
----------------------------------------------------------------

  可以同时在 input/ 下放 sequences.txt 和 wt.txt + mt.txt，
  运行一次会依次执行两个任务。
================================================================
