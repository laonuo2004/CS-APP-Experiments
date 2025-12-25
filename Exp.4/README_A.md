## 简介

**独立完成本实验！**

CacheLab 将帮助你理解 cache 对 C 语言程序性能的影响。实验分为两部分：Part A 需要你写一个小程序（200-300 行），用以模拟 cache 的行为。

---

## 实验步骤

用 git 获取实验初始文件：

1. 在虚拟桌面左边窗口的上方点击“GitLab”。
2. “点击复制”按钮，复制 git 仓库地址。
3. 关闭上述界面，在左边窗口的上方点击“更多”，选择“剪切板”。
4. 在剪切板中 ctrl+v 贴入 git 仓库地址。
5. 关闭上述界面，在命令行界面中输入下述命令，你要把 http 地址替换成你的仓库地址：

```bash
git clone http://172.16.2.166/2020302111371/expProject2026-674.git csapp-cachelab
```

得到的 *csapp-cachelab* 目录下有一些文件，你需要修改的是两个：*csim.c*（part A）和 *trans.c*（part B）。编译这些文件，可以输入：

```bash
linux > make clean
linux > make
```

---

## 实验描述

本实验的 Part A 要实现一个 cache 模拟器。

### 访问序列（Reference Trace）文件

traces 子目录中包括一组访问 trace 文件，我们会用它们来验证你写的 cache 模拟器的正确性。这些 trace 文件是用 *valgrind* 生成的，例如，在命令行输入：

```bash
linux> valgrind --log-fd=1 --tool=lackey -v --trace-mem=yes ls -l
```

它会执行 `ls -l`，并按照该程序对内存访问的顺序记录下这些访问，输出在标准输出上。

*Valgrind* 的输出形如：

```text
	I 0400d7d4,8
	M 0421c7f0,4
	L 04f6b868,8
	S 7ff0005c8,8
```

每行代表一个或两个内存访问，格式为：

```text
[space]operation address, size
```

*operation* 字段表示内存访问的类型：“*I*”表示加载指令，“*L*”表示加载数据，“*S*”表示存储数据，而“*M*”表示修改数据（i.e. 一个数据加载，紧接着一个数据存储）。“*I*”前面不能有空格，“*M*”、“*L*”和“*S*”前面则有一个空格。地址字段是一个 64 位十六进制内存地址。*size*字段指明这次操作要访问的字节数。

---

### 写一个 cache 模拟器

在 Part A，你要在 *csim.c* 文件中写一个 cache 模拟器，以 *valgrind* 内存 trace 作为输入，模拟这个 trace 在 cache 上的 hit/miss 行为，输出 hit、miss 和替换页（eviction）的总数。

我们提供了一个参考的 cache 模拟器，是二进制可执行文件，名叫 *csim-ref*。它可以在一个 valgrind trace 文件上模拟任意大小和相联度的 cache 的行为。在选择要替换哪个 cache 行时，它采用 LRU（least-recently used）替换策略。

*csim-ref* 模拟器的命令行参数说明如下：

- -h: Optional help flag that prints usage info
- -v: Optional verbose flag that displays trace info
- -s `<s`>: Number of set index bits ($S = 2^s$ is the number of sets)
- -E `<E`>: Associativity (number of lines per set)
- -b `<b`>: Number of block bits ($B = 2^b$ is the block size)
- -t `<tracefile`>: Name of the valgrind trace to replay

这里命令行参数的释意与教材中的一致。例如：

```bash
linux> ./csim-ref -s 4 -E 1 -b 4 -t traces/yi.trace
hits:4 misses:5 evictions:3
```

如果用 verbose 模式运行同一例子会得到：

```bash
 linux> ./csim-ref -v -s 4 -E 1 -b 4 -t traces/yi.trace L 10,1 miss
	M 20,1 miss hit
	L 22,1 hit
	S 18,1 hit
	L 110,1 miss eviction
	L 210,1 miss eviction
	M 12,1 miss eviction hit hits:4 misses:5 evictions:3
```

在 Part A 中你的任务就是补充完善 *csim.c* 文件，使得它的输入参数和输出都与参考模拟器一模一样。

---

### Part A 的编程规则

- 在 *csim.c* 开头的注释中写上你的姓名和学号。
- *csim.c* 的编译必须没有 warnings，否则不能评测给分。
- 你的模拟器必须对任意 $s$、$E$ 和 $b$ 都能正确工作，也就是说你需要用 *malloc* 函数来为你的模拟器数据结构分配存储空间。关于 *malloc* 函数的使用可以在命令行用 `man malloc` 命令获取。
- 本实验中，我们只关注数据 cache 的性能，所以模拟器要忽略所有指令 cache 访问（以“*I*”开头的那些行）。记住 *valgrind* 把“*I*”放在第一列（前面没有空格），“*M*”、“*L*”和“*S*”在第二列（前面有一个空格）。这可能对你解析 trace 有帮助。
- 想获得正确的评分，一定要在主函数结尾，调用函数 *printSummary* 来打印 hit、miss 和 eviction 的数量：`printSummary(hit_count, miss_count, eviction_count);`。
- 对于本实验，可以假设内存访问都是正确对齐了的，也就是一次内存访问不会超过块的边界，因而可以在 *valgrind* trace 中忽略请求的大小。

---

## 评测

本实验的满分为 100 分：
Part A：自动评测，满分 45 分
Part B：自动评测，满分 45 分
代码风格+实验报告：教师评分，满分 10 分

---

### Part A 评测

本部分评测，我们会用不同的 cache 参数和 trace 来运行你的 cache 模拟器。一共有 8 个测试用例，第 1 个 3 分，后 7 个每个 6 分，总共 45 分。

```bash
linux> ./csim -s 1 -E 1 -b 1 -t traces/yi2.trace
linux> ./csim -s 4 -E 2 -b 4 -t traces/yi.trace
linux> ./csim -s 2 -E 1 -b 4 -t traces/dave.trace
linux> ./csim -s 2 -E 1 -b 3 -t traces/trans.trace
linux> ./csim -s 2 -E 2 -b 3 -t traces/trans.trace
linux> ./csim -s 2 -E 4 -b 3 -t traces/trans.trace
linux> ./csim -s 5 -E 1 -b 5 -t traces/trans.trace
linux> ./csim -s 5 -E 1 -b 5 -t traces/long.trace
```

你可以用参考模拟器 *csim-ref* 来获得每个测试用例的正确结果。debug 的时候，用 *-v* 选项可以得到每次 hit 和 miss 的详细记录。

对于每个测试用例，cache hit、miss 和 eviction 次数分别是该用例分值的 1/3（1 分或者 2 分）。

---

### 代码风格评分

代码风格占 10 分，由教师评分，会检查你的代码中是否有不符合要求的数组声明和/或过多的变量声明。

---

## 实验内容

我们提供了一个自动评测的程序，*test-csim*，能测试你的 cache 模拟器对参考 trace 的正确性。先编译再运行测试：

```bash
linux> make
linux> ./test-csim
                        Your simulator     Reference simulator
Points (s,E,b)    Hits  Misses  Evicts    Hits  Misses  Evicts
     3 (1,1,1)       9       8       6       9       8       6  traces/yi2.trace
     3 (4,2,4)       4       5       2       4       5       2  traces/yi.trace
     3 (2,1,4)       2       3       1       2       3       1  traces/dave.trace
     3 (2,1,3)     167      71      67     167      71      67  traces/trans.trace
     3 (2,2,3)     201      37      29     201      37      29  traces/trans.trace
     3 (2,4,3)     212      26      10     212      26      10  traces/trans.trace
     3 (5,1,5)     231       7       0     231       7       0  traces/trans.trace
     6 (5,1,5)  265189   21775   21743  265189   21775   21743  traces/long.trace
    27
```

对于每个测试，给出了你的得分，cache 参数，输入的 trace 文件，以及对比了你的模拟器与参考模拟器的测试结果。

对于 Part A，我们给你一些提示：

- 现在较小的 trace 上做调试，比如 `traces/dave.trace`
- 参考模拟器有个参数 *-v*，有详细的输出，给出了每次内存访问时发生的 hit、miss 和 eviction。你的 *csim.c* 代码中不用实现这一功能，但是我们强烈建议你这么做。它能够帮助你直接比较你的模拟器和参考模拟器在 trace 文件上的行为。
- 我们建议你用 getopt 函数分析你的命令行参数。要添加如下头文件：

```c
#include <getopt.h>
#include <stdlib.h>
#include <unistd.h>
```

运行 `man 3 getopt` 查阅详细信息。

- 每个数据加载（*L*）或者存储（*S*）最多引起一次 cache miss。数据修改（*M*）是一个加载，后面跟着一个对同一地址的存储。因此，一次 *M* 操作可能导致两次 cache hit 或者一次 miss 和一次 hit，可能还有一次 eviction。

---

## 在线评测

本实验采用在线评测方式。

将你实现的 *csim.c* 拷贝到桌面上，然后点击终端界面上的“提交评测”，会得到并提交你的实验评分。