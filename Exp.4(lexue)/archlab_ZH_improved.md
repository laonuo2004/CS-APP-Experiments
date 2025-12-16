# 优化流水线处理器的性能

## 1 简介

在这个实验中，你将学习流水线 Y86-64 处理器的设计与实现，并对其以及基准程序进行优化以最大化性能。你可以对基准程序进行任何**保持语义的变换** (semantics preserving transformation)，也可以改进流水线处理器，或者两者兼而有之。当你完成这个实验时，你将对代码与硬件之间如何交互并影响程序性能有一个深刻的理解。

实验分为三个部分，每个部分都有相应的提交 (handin) 要求。在 A 部分，你将编写一些简单的 Y86-64 程序并熟悉 Y86-64 工具链。在 B 部分，你将通过添加一条新指令来扩展 SEQ 模拟器。这两部分是为 C 部分做准备，C 部分是本实验的核心，你将在此部分优化 Y86-64 基准程序和处理器设计。

> [!NOTE]
> **译者注：** 本文档旨在提供比机翻更通顺的中文阅读体验。对于一些专业术语，我会尽量保留英文原词或在括号中标注，以便对照。

## 2 实验须知

你将独立完成这个实验。关于作业的任何说明和修订都将发布在课程网页上。

## 3 实验材料说明

*站点特定：在此处插入一段说明，解释学生应如何下载 archlab-handout.tar 文件。*

1.  首先，将文件 `archlab-handout.tar` 复制到你打算进行工作的（受保护的）目录中。
2.  然后执行命令：`tar xvf archlab-handout.tar`。这将把以下文件解压到当前目录：`README`、`Makefile`、`sim.tar`、`archlab.pdf` 和 `simguide.pdf`。
3.  接下来，执行命令 `tar xvf sim.tar`。这将创建 `sim` 目录，其中包含你个人副本的 Y86-64 工具。你所有的工作都将在这个目录中进行。
4.  最后，进入 `sim` 目录并构建 Y86-64 工具：

```bash
unix> cd sim
unix> make clean; make
```

> [!TIP]
> **环境配置提示：** 确保你的实验环境已经安装了构建所需的依赖库（如 flex, bison, tcl/tk 等），否则 `make` 可能会失败。

## 4 Part A (A 部分)

这部分你将在 `sim/misc` 目录下工作。

你的任务是编写并模拟以下三个 Y86-64 程序。这些程序所需的行为由 `examples.c` 中的示例 C 函数定义。请务必在每个程序的开头用注释写上你的姓名和 ID。你可以先用汇编器 YAS 汇编你的程序，然后用指令集模拟器 YIS 运行它们来进行测试。

在你所有的 Y86-64 函数中，应该遵循 x86-64 的函数参数传递、寄存器使用和栈使用规范。这包括保存和恢复你使用的任何**被调用者保存** (callee-save) 寄存器。

> [!IMPORTANT]
> **关于调用规范：** 这是一个常见的扣分点。Y86-64 遵循类似 x86-64 的 System V AMD64 ABI 规范。例如，参数通常通过 `%rdi`, `%rsi`, `%rdx` 等传递，返回值在 `%rax` 中。如果你的函数修改了 `%rbx`, `%rbp`, `%r12`-%`r15` 等寄存器，必须先 push 保存，返回前 pop 恢复。

### `sum.ys`: 迭代求链表元素之和

编写一个 Y86-64 程序 `sum.ys`，迭代计算链表元素的和。你的程序应该包含设置栈结构的代码，调用一个函数，然后停机。在这个例子中，该函数 (`sum_list`) 应该是 `sim/misc/examples.c` 中 C 语言 `sum_list` 函数（见图 1）的 Y86-64 等价实现。使用以下三元素链表测试你的程序：

```assembly
# Sample linked list
.align 8
ele1:
    .quad 0x00a
    .quad ele2
ele2:
    .quad 0x0b0
    .quad ele3
ele3:
    .quad 0xc00
    .quad 0
```

**图 1: Y86-64 解决方案函数的 C 语言版本。见 `sim/misc/examples.c`**

```c
/* linked list element */
typedef struct ELE {
    long val;
    struct ELE *next;
} *list_ptr;

/* sum_list - Sum the elements of a linked list */
long sum_list(list_ptr ls)
{
    long val = 0;
    while (ls) {
        val += ls->val;
        ls = ls->next;
    }
    return val;
}

/* rsum_list - Recursive version of sum_list */
long rsum_list(list_ptr ls)
{
    if (!ls)
        return 0;
    else {
        long val = ls->val;
        long rest = rsum_list(ls->next);
        return val + rest;
    }
}

/* copy_block - Copy src to dest and return xor checksum of src */
long copy_block(long *src, long *dest, long len)
{
    long result = 0;
    while (len > 0) {
        long val = *src++;
        *dest++ = val;
        result ^= val;
        len--;
    }
    return result;
}
```

### `rsum.ys`: 递归求链表元素之和

编写一个 Y86-64 程序 `rsum.ys`，递归计算链表元素的和。这段代码应该与 `sum.ys` 类似，不同之处在于它应该使用一个函数 `rsum_list` 来递归地对数字列表求和，如图 1 中的 C 函数 `rsum_list` 所示。使用与测试 `list.ys`（注：原文应为 `sum.ys`）相同的三元素链表来测试你的程序。

### `copy.ys`: 将源块复制到目标块

编写一个程序 (`copy.ys`)，将一块字 (words) 从内存的一个区域复制到内存的另一个（不重叠的）区域，并计算所有复制字的校验和（Xor 异或和）。

你的程序应该包含建立栈帧的代码，调用函数 `copy_block`，然后停机。该函数在功能上应等同于图 1 所示的 C 函数 `copy_block`。使用以下三元素源块和目标块测试你的程序：

```assembly
.align 8
# Source block
src:
    .quad 0x00a
    .quad 0x0b0
    .quad 0xc00
# Destination block
dest:
    .quad 0x111
    .quad 0x222
    .quad 0x333
```

## 5 Part B (B 部分)

这部分你将在 `sim/seq` 目录下工作。

你在 B 部分的任务是扩展 SEQ 处理器以支持 `iaddq` 指令，该指令在家庭作业问题 4.51 和 4.52 中有描述。要添加这些指令，你需要修改 `seq-full.hcl` 文件，该文件实现了 CS:APP3e 教材中描述的 SEQ 版本。此外，它还包含了一些你在解决方案中需要用到的常量声明。

你的 HCL 文件必须以包含以下信息的头注释开始：

*   你的姓名和 ID。
*   `iaddq` 指令所需计算的描述。请参照 CS:APP3e 课本图 4.18 中对 `irmovq` 和 `OPq` 的描述作为指南。

> [!TIP]
> **`iaddq` 指令各阶段行为参考：**
> | 阶段      | `iaddq V, rB`                     |
> | :-------- | :-------------------------------- |
> | Fetch     | `icode:ifun ← M1[PC]`             |
> |           | `rA:rB ← M1[PC+1]`                |
> |           | `valC ← M8[PC+2]`                 |
> |           | `valP ← PC + 10`                  |
> | Decode    | `valB ← R[rB]`                    |
> | Execute   | `valE ← valB + valC`              |
> |           | Set CC                            |
> | Memory    | (无操作)                          |
> | Write back| `R[rB] ← valE`                    |
> | PC update | `PC ← valP`                       |

### 构建和测试你的解决方案

修改完 `seq-full.hcl` 文件后，你需要基于此 HCL 文件构建 SEQ 模拟器 (`ssim`) 的新实例，然后对其进行测试：

*   **构建新的模拟器。** 你可以使用 make 来构建新的 SEQ 模拟器：

    ```bash
    unix> make VERSION=full
    ```

    这将构建一个使用你在 `seq-full.hcl` 中指定的控制逻辑的 `ssim` 版本。为了省事，你可以在 Makefile 中赋值 `VERSION=full`。

*   **在一个简单的 Y86-64 程序上测试你的解决方案。** 对于初步测试，我们建议在 TTY 模式下运行简单的程序，例如 `asumi.yo`（测试 `iaddq`），并将结果与 ISA 模拟进行比较：

    ```bash
    unix> ./ssim -t ../y86-code/asumi.yo
    ```

    如果 ISA 测试失败，你应该在 GUI 模式下通过单步执行模拟器来调试你的实现：

    ```bash
    unix> ./ssim -g ../y86-code/asumi.yo
    ```

*   **使用基准程序重新测试你的解决方案。** 一旦你的模拟器能够正确执行小程序，你就可以在 `../y86-code` 中的 Y86-64 基准程序上自动测试它：

    ```bash
    unix> (cd ../y86-code; make testssim)
    ```

    这将在基准程序上运行 `ssim`，并通过比较生成的处理器状态与高级 ISA 模拟的状态来检查正确性。注意，这些程序都没有测试新添加的指令。你只是在确保你的解决方案没有引入原有指令的错误。详情请见 `../y86-code/README` 文件。

*   **执行回归测试。** 一旦你能正确执行基准程序，你就应该运行 `../ptest` 中广泛的回归测试集。要测试除 `iaddq` 之外的所有内容并退出：

    ```bash
    unix> (cd ../ptest; make SIM=../seq/ssim)
    ```

    要测试你的 `iaddq` 实现：

    ```bash
    unix> (cd ../ptest; make SIM=../seq/ssim TFLAGS=-i)
    ```

有关 SEQ 模拟器的更多信息，请参阅讲义 CS:APP3e Guide to Y86-64 Processor Simulators (`simguide.pdf`)。

## 6 Part C (C 部分)

这部分你将在 `sim/pipe` 目录下工作。

图 2 中的 `ncopy` 函数将一个 `len` 元素的整数数组 `src` 复制到一个不重叠的 `dst`，并返回 `src` 中包含的正整数的数量。图 3 显示了 `ncopy` 的基准 Y86-64 版本。文件 `pipe-full.hcl` 包含 PIPE 的 HCL 代码副本，以及常量值 `IIADDQ` 的声明。

**图 2: ncopy 函数的 C 语言版本。见 `sim/pipe/ncopy.c`**

```c
/*
 * ncopy - copy src to dst, returning number of positive ints
 * contained in src array.
 */
word_t ncopy(word_t *src, word_t *dst, word_t len)
{
    word_t count = 0;
    word_t val;

    while (len > 0) {
        val = *src++;
        *dst++ = val;
        if (val > 0)
            count++;
        len--;
    }
    return count;
}
```

你在 C 部分的任务是修改 `ncopy.ys` 和 `pipe-full.hcl`，目标是使 `ncopy.ys` 运行得尽可能快。

你将提交两个文件：`pipe-full.hcl` 和 `ncopy.ys`。每个文件都应以包含以下信息的头注释开头：
*   你的姓名和 ID。
*   你的代码的高级描述。在每种情况下，描述你是如何以及为什么要修改你的代码的。

### 编码规则

你可以自由地做任何你想要的修改，但在以下约束条件下：

*   你的 `ncopy.ys` 函数必须适用于**任意数组大小**。你可能会想简单地编写 64 个复制指令来针对 64 元素数组硬编码你的解决方案，但这将是一个坏主意，因为我们将根据你的解决方案在任意大小数组上的性能来评分。

**图 3: ncopy 函数的基准 Y86-64 版本。见 `sim/pipe/ncopy.ys`。**

```assembly
##################################################################
# ncopy.ys - Copy a src block of len words to dst.
# Return the number of positive words (>0) contained in src.
#
# Include your name and ID here.
#
# Describe how and why you modified the baseline code.
#
##################################################################
# Do not modify this portion
# Function prologue.
# %rdi = src, %rsi = dst, %rdx = len
ncopy:

##################################################################
# You can modify this portion
# Loop header
    xorq %rax,%rax      # count = 0;
    andq %rdx,%rdx      # len <= 0?
    jle Done            # if so, goto Done:

Loop: mrmovq (%rdi), %r10 # read val from src...
    rmmovq %r10, (%rsi)   # ...and store it to dst
    andq %r10, %r10       # val <= 0?
    jle Npos              # if so, goto Npos:
    irmovq $1, %r10
    addq %r10, %rax       # count++
Npos: irmovq $1, %r10
    subq %r10, %rdx       # len--
    irmovq $8, %r10
    addq %r10, %rdi       # src++
    addq %r10, %rsi       # dst++
    andq %rdx,%rdx        # len > 0?
    jg Loop               # if so, goto Loop:
##################################################################
# Do not modify the following section of code
# Function epilogue.
Done:
    ret
##################################################################
# Keep the following label at the end of your function
End:
```

*   你的 `ncopy.ys` 函数必须在 YIS 下正确运行。所谓“正确”，是指它必须正确复制 `src` 块并在 `%rax` 中返回正确的正整数数量。
*   你的 `ncopy` 文件的汇编版本长度不得超过 1000 字节。你可以使用提供的脚本 `check-len.pl` 检查任何嵌入了 `ncopy` 函数的程序的长度：

    ```bash
    unix> ./check-len.pl < ncopy.yo
    ```

*   你的 `pipe-full.hcl` 实现必须通过 `../y86-code` 和 `../ptest` 中的回归测试（不带测试 `iaddq` 的 `-i` 标志）。

除此之外，如果你认为有帮助，你可以自由实现 `iaddq` 指令。你可以对 `ncopy.ys` 函数进行任何**保持语义的变换**，例如重新排序指令、用单个指令替换指令组、删除某些指令以及添加其他指令。你可能会发现阅读 CS:APP3e 第 5.8 节中关于**循环展开** (loop unrolling) 的内容很有用。

> [!TIP]
> **优化思路：** 这是一个极其开放的优化任务。常见的优化手段包括：
> 1.  实现 `iaddq` 指令（这能减少很多 `irmovq` + `addq` 组合）。
> 2.  **循环展开 (Loop Unrolling)**：一次处理多个元素（如 4路、8路甚至 16路展开），以减少循环开销。
> 3.  处理剩余元素：循环展开后，需要用 Switch-case 跳转表或其他方式高效处理剩余的不足一次展开步长的元素。
> 4.  **加载/使用冒险 (Load-use hazard)** 消除：在流水线中，读取内存后立即使用该值会产生气泡。尝试重新排列指令，在读取内存和使用数据之间插入不相关的指令。

### 构建和运行你的解决方案

为了测试你的解决方案，你需要构建一个驱动程序来调用你的 `ncopy` 函数。我们为你提供了 `gen-driver.pl` 程序，用于为任意大小的输入数组生成驱动程序。例如，输入

```bash
unix> make drivers
```

将构建以下两个有用的驱动程序：

*   `sdriver.yo`: 一个小型驱动程序，测试 `ncopy` 函数在 4 个元素的小数组上的表现。如果你的解决方案正确，该程序在复制 `src` 数组后将停机，并在寄存器 `%rax` 中返回值 2。
*   `ldriver.yo`: 一个大型驱动程序，测试 `ncopy` 函数在 63 个元素的大数组上的表现。如果你的解决方案正确，该程序在复制 `src` 数组后将停机，并在寄存器 `%rax` 中返回值 31 (`0x1f`)。

每次修改 `ncopy.ys` 程序时，你都可以通过输入以下命令重新构建驱动程序：

```bash
unix> make drivers
```

每次修改 `pipe-full.hcl` 文件时，你都可以通过输入以下命令重新构建模拟器：

```bash
unix> make psim VERSION=full
```

如果你想同时重新构建模拟器和驱动程序，请输入：

```bash
unix> make VERSION=full
```

要在 GUI 模式下在 4 元素小数组上测试你的解决方案，请输入：

```bash
unix> ./psim -g sdriver.yo
```

要在 63 元素大数组上测试你的解决方案，请输入：

```bash
unix> ./psim -g ldriver.yo
```

一旦你的模拟器在这些长度的块上正确运行你的 `ncopy.ys` 版本，你将需要执行以下额外的测试：

*   **在 ISA 模拟器上测试你的驱动文件。** 确保你的 `ncopy.ys` 函数在 YIS 下正常工作：

    ```bash
    unix> make drivers
    unix> ../misc/yis sdriver.yo
    ```

*   **使用 ISA 模拟器在一定范围的块长度上测试你的代码。** Perl 脚本 `correctness.pl` 生成块长度从 0 到某个限制（默认为 65）以及一些更大尺寸的驱动文件。它模拟它们（默认使用 YIS），并检查结果。它会生成一份报告，显示每个块长度的状态：

    ```bash
    unix> ./correctness.pl
    ```

    该脚本生成的测试程序结果计数会在运行之间随机变化，因此它比标准驱动程序提供了更严格的测试。如果你在某个长度 K 上得到不正确的结果，你可以为该长度生成一个包含检查代码且结果随机变化的驱动文件：

    ```bash
    unix> ./gen-driver.pl -f ncopy.ys -n K -rc > driver.ys
    unix> make driver.yo
    unix> ../misc/yis driver.yo
    ```

    该程序结束时，寄存器 `%rax` 将具有以下值：
    *   `0xaaaa`: 所有测试通过。
    *   `0xbbbb`: 计数不正确。
    *   `0xcccc`: 函数 `ncopy` 长度超过 1000 字节。
    *   `0xdddd`: 部分源数据未复制到其目标位置。
    *   `0xeeee`: 目标区域之前或之后的一个字被破坏。

*   **在基准程序上测试你的流水线模拟器。** 一旦你的模拟器能够正确执行 `sdriver.yo` 和 `ldriver.yo`，你应该根据 `../y86-code` 中的 Y86-64 基准程序对其进行测试：

    ```bash
    unix> (cd ../y86-code; make testpsim)
    ```

    这将在基准程序上运行 `psim` 并将结果与 YIS 进行比较。

*   **使用广泛的回归测试测试你的流水线模拟器。** 一旦你能正确执行基准程序，你就应该使用 `../ptest` 中的回归测试来检查它。例如，如果你的解决方案实现了 `iaddq` 指令，那么：

    ```bash
    unix> (cd ../ptest; make SIM=../pipe/psim TFLAGS=-i)
    ```

*   **使用流水线模拟器在一定范围的块长度上测试你的代码。** 最后，你可以在流水线模拟器上运行你之前在 ISA 模拟器上做的相同的代码测试：

    ```bash
    unix> ./correctness.pl -p
    ```

## 7 评分标准 (Evaluation)

本实验总分 190 分：A 部分 30 分，B 部分 60 分，C 部分 100 分。

### A 部分
A 部分值 30 分，每个 Y86-64 解决方案程序 10 分。每个解决方案程序将根据正确性进行评估，包括对栈和寄存器的正确处理，以及与 `examples.c` 中示例 C 函数的功能等价性。

如果评分员没有发现 `sum.ys` 和 `rsum.ys` 中的任何错误，并且它们各自的 `sum_list` 和 `rsum_list` 函数在寄存器 `%rax` 中返回和 `0xcba`，则认为它们是正确的。

如果评分员没有发现 `copy.ys` 中的任何错误，并且 `copy_block` 函数在寄存器 `%rax` 中返回校验和 `0xcba`，将三个 64 位值 `0x00a`、`0x0b0` 和 `0xc00` 复制到以地址 `dest` 开始的 24 字节中，并且不破坏其他内存位置，则认为该程序是正确的。

> [!WARNING]
> **译者注（原文勘误）：** 原文此处写的是 `0x00a`, `0x0b`, 和 `0xc`。根据上下文的链表/数据块定义 (`ele1`, `ele2`, `ele3` 或 `src` 块)，正确的值应为 `0x00a`, `0x0b0`, `0xc00`。

### B 部分
这部分实验值 35 分：

> [!NOTE]
> **译者注（原文数值不一致）：** 原文第 7 节开头写的是 B 部分 60 分，但此处的分项加起来只有 35 分 (10+10+15)。实际评分请以你老师/助教的说明为准。
*   10 分：你对 `iaddq` 指令所需计算的描述。
*   10 分：通过 `y86-code` 中的基准回归测试，以验证你的模拟器仍然正确执行基准套件。
*   15 分：通过 `ptest` 中针对 `iaddq` 的回归测试。

### C 部分
这部分实验值 100 分：如果你用于 `ncopy.ys` 的代码或你修改后的模拟器未通过前面描述的任何测试，你将不会获得任何分数。

*   20 分（各）：`ncopy.ys` 和 `pipe-full.hcl` 头部中的描述以及这些实现的质量。
*   60 分：性能。要在此处获得分数，你的解决方案必须是正确的，如前所定义。也就是，`ncopy` 在 YIS 下运行正确，且 `pipe-full.hcl` 通过 `y86-code` 和 `ptest` 中的所有测试。

我们将以**每元素周期数 (CPE)** 为单位表示你的函数的性能。也就是说，如果模拟代码需要 C 个周期来复制 N 个元素的块，那么 CPE 就是 C/N。PIPE 模拟器显示完成程序所需的总周期数。在标准 PIPE 模拟器上运行的 `ncopy` 函数的基准版本，对于一个 63 元素的大数组，需要 897 个周期来复制 63 个元素，CPE 为 $897/63 = 14.24$。

由于一些周期用于设置对 `ncopy` 的调用以及 `ncopy` 内的循环设置，你会发现对于不同的块长度，你会得到不同的 CPE 值（通常随着 N 的增加，CPE 会下降）。

因此，我们将通过计算 1 到 64 个元素范围内块的**平均 CPE** 来评估你的函数的性能。你可以使用 `pipe` 目录中的 Perl 脚本 `benchmark.pl` 在一系列块长度上运行你的 `ncopy.ys` 代码模拟并计算平均 CPE。只需运行命令：

```bash
unix> ./benchmark.pl
```

看看会发生什么。例如，`ncopy` 函数的基准版本 CPE 值在 29.00 到 14.27 之间，平均值为 15.18。请注意，此 Perl 脚本**不检查**答案的正确性。请使用脚本 `correctness.pl` 来检查正确性。

你应该能够实现小于 9.00 的平均 CPE。我们最好的版本平均为 7.48。如果你的平均 CPE 为 $c$，那么你这部分的得分 $S$ 将是：

$$ 
S = \begin{cases} 
0, & c > 10.5 \\
20 \cdot (10.5 - c), & 7.50 \leq c \leq 10.50 \\
60, & c < 7.50
\end{cases}
$$

默认情况下，`benchmark.pl` 和 `correctness.pl` 编译并测试 `ncopy.ys`。使用 `-f` 参数指定不同的文件名。`-h` 标志给出了命令行参数的完整列表。

## 8 提交说明 (Handin Instructions)

*站点特定：在此处插入描述，解释学生应如何提交实验的三个部分。这是我们在 CMU 使用的描述。*

*   你将提交三组文件：
    *   Part A: `sum.ys`, `rsum.ys`, 和 `copy.ys`.
    *   Part B: `seq-full.hcl`.
    *   Part C: `ncopy.ys` 和 `pipe-full.hcl`.

*   确保你在每个提交文件的顶部注释中都包含了你的姓名和 ID。
*   要提交 X 部分的文件，请转到你的 `archlab-handout` 目录并输入：
    ```bash
    unix> make handin-partX TEAM=teamname
    ```
    其中 X 是 a, b, 或 c，teamname 是你的 ID。例如，要提交 A 部分：
    ```bash
    unix> make handin-parta TEAM=teamname
    ```

*   提交后，如果你发现错误并想提交修订版，请输入
    ```bash
    unix make handin-partX TEAM=teamname VERSION=2
    ```
    每次提交时增加版本号。

*   你可以查看 `CLASSDIR/archlab/handin-partX` 来验证你的提交。你在此目录中拥有列出和插入权限，但没有读取或写入权限。

## 9 提示 (Hints)

*   按照设计，`sdriver.yo` 和 `ldriver.yo` 都足够小，可以在 GUI 模式下调试。我们发现用 GUI 模式调试最容易，并建议你使用它。
*   如果你在 Unix 服务器上以 GUI 模式运行，请确保你已经初始化了 DISPLAY 环境变量：
    ```bash
    unix> setenv DISPLAY myhost.edu:0
    ```
*   对于某些 X 服务器，“Program Code”窗口在 GUI 模式下运行 `psim` 或 `ssim` 时一开始是一个关闭的图标。只需点击该图标即可展开窗口。
*   对于某些基于 Windows 的 X 服务器，“Memory Contents”窗口不会自动调整大小。你需要手动调整窗口大小。
*   如果你要求 `psim` 和 `ssim` 模拟器执行无效的 Y86-64 目标文件，它们会以段错误终止。
