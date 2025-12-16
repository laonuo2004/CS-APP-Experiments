# 优化流水线处理器的性能

## 1 简介

在本实验中，您将了解流水线 Y86-64 处理器的设计和实现，优化它和基准程序以最大限度地提高性能。您可以对基准程序进行任何语义保持转换，或者对流水线处理器进行增强，或者两者兼而有之。当你完成实验后，你会对影响程序性能的代码和硬件之间的交互产生强烈的兴趣。

实验分为三个部分，每个部分都有自己的上交成果。在 A 部分中，您将编写一些简单的 Y86-64 程序，并熟悉 Y86-64 工具。在 B 部分中，您将使用新的指令扩展 SEQ 模拟器。这两个部分将为您完成 C 部分，即实验的核心做好准备，在这里您将优化 Y86-64 基准程序和处理器设计。

## 2 组织工作

你将独立完成本实验。作业的任何澄清和修改都将发布在课程网页上。

## 3 讲义说明

特定说明：在此处插入一段，解释学生应如何下载 `archlab-handout.tar` 文件。

1. 首先复制文件 `archlab-handout.tar` 到您计划在其中执行工作的（受保护的）目录。
2. 然后给出命令：`tar xvf archlab-handout.tar`。这将导致以下文件解压缩到目录中：`README`、`Makefile`、`sim.tar`、`archlab.pdf` 和 `simguide.pdf`。
3. 接下来，给出命令 `tar xvf sim.tar`。这将创建目录 `sim`，其中包含 Y86-64 工具的个人副本。您将在该目录中完成所有工作。
4. 最后，切换到 `sim` 目录并构建 Y86-64 工具：

```bash
unix> cd sim
unix> make clean; make
```

## 4 A 部分

在本部分中，您将在目录 `sim/misc` 中工作。

您的任务是编写并模拟以下三个 Y86-64 程序。这些程序所需的行为由 `examples.c` 中的示例 C 函数定义。请确保在每个程序开头的注释中输入您的姓名和 ID。您可以先用程序 YAS 汇编这些程序，然后用指令集模拟器 YIS 运行它们，从而测试您的程序。

在所有 Y86-64 函数中，应该遵循 x86-64 惯例来传递函数参数、使用寄存器和使用栈。这包括保存和恢复您使用的任何被调用方保存的寄存器。

### `sum.ys`: 对链表元素进行迭代求和

编写 Y86-64 程序 `sum.ys` 对链表元素进行迭代求和。您的程序应该由一些代码组成，这些代码设置栈结构，调用函数，然后停机。在这种情况下，函数应该是 Y86-64 代码（`sum_list` 函数），功能等同于图 1 中 C `sum_list` 函数。使用以下三元素列表测试您的程序：

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

**图 1: C 语言版本 Y86-64 解决方案函数。请参阅 `sim/misc/examples.c`**

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

### `rsum.ys`：递归求和链表元素

编写一个 Y86-64 程序 `rsum.ys` 对链表元素进行递归求和。该代码应与 `sum.ys` 的代码类似，但它使用一个函数 `rsum_list` 递归地对一系列数字求和，如图 1 中的 C 语言函数 `rsum_list` 所示。使用与测试 `list.ys` 相同的三元素列表测试您的程序。

### `copy.ys`：将源块复制到目标块

编写一个程序（`copy.ys`），将一个若干字构成的数据块从内存的一部分复制到另一个（非重叠区）内存区域，计算所有复制字的校验和（Xor）。

您的程序应该由设置栈帧、调用函数 `copy_block` 然后停机的代码组成。该函数在功能上应等同于图 1 所示的 C `copy_block` 函数。使用以下三元素源块和目标块测试程序：

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

## 5 B 部分

在本部分中，您将在目录 `sim/seq` 中工作。

您在 B 部分的任务是扩展 SEQ 处理器以支持 `iaddq` 指令，如家庭作业问题 4.51 和 4.52 所述。要添加此指令，您将修改文件 `seq-full.hcl`，它实现了 CS:APP3e 教科书中描述的 SEQ 版本。此外，它还包含解决方案所需的一些常量的声明。

HCL 文件必须以注释头开始，其中包含以下信息：

- 您的姓名和 ID。
- `iaddq` 指令所需计算的描述。参考 CS:APP3e 教材中图 4.18 中的 `irmovq` 和 `OPq` 描述。

### 构建和测试您的解决方案

完成对 `seq-full.hcl` 文件的修改后，则需要基于此 HCL 文件构建 SEQ 模拟器（`ssim`）的新实例，然后对其进行测试：

- **构建新的模拟器。** 您可以使用 make 构建新的 SEQ 模拟器：

  ```bash
  unix> make VERSION=full
  ```

  这将构建一个使用 `seq-full.hcl` 中指定的控制逻辑的 `ssim` 版本。要保存键入，可以在 Makefile 中指定 `VERSION=full`。

- **在一个简单的 Y86-64 程序上测试您的解决方案。** 对于初始测试，我们推荐在 TTY 模式下运行简单的程序例如 `asumi.yo`（测试 `iaddq`），将结果与 ISA 模拟进行比较：

  ```bash
  unix> ./ssim -t ../y86-code/asumi.yo
  ```

  如果 ISA 测试失败，则应在 GUI 模式下单步执行模拟器来调试实现：

  ```bash
  unix> ./ssim -g ../y86-code/asumi.yo
  ```

- **使用基准程序重新测试解决方案。** 一旦模拟器能够正确执行小程序，您就可以用 `../y86-code` 中的 Y86-64 基准程序自动测试它：

  ```bash
  unix> (cd ../y86-code; make testssim)
  ```

  这将在基准程序上运行 `ssim`，并通过将生成的处理器状态与高级 ISA 模拟的状态进行比较来检查正确性。请注意，这些程序都没有测试添加的指令。您只是确保您的解决方案没有为原始指令注入错误。有关更多详细信息，请参阅文件 `../y86-code/README`。

- **执行回归测试。** 一旦您能够正确执行基准程序，那么您应该在 `../ptest` 中运行大量的回归测试。要测试除 `iaddq` 之外的所有内容，请执行以下操作：

  ```bash
  unix> (cd ../ptest; make SIM=../seq/ssim)
  ```

  要测试 `iaddq` 的实现，请执行以下操作：

  ```bash
  unix> (cd ../ptest; make SIM=../seq/ssim TFLAGS=-i)
  ```

有关 SEQ 模拟器的更多信息，请参阅讲义 CS:APP3e Y86-64 处理器模拟器指南（`simguide.pdf`）。

## 6 C 部分

在本部分中，您将在目录 `sim/pipe` 中工作。

图 2 中的 `ncopy` 函数将 `len` 个元素整数数组 `src` 复制到非重叠的 `dst`，返回 `src` 中包含的正整数的数量。图 3 显示了 `ncopy` 的基线 Y86-64 版本。文件 `pipe-full.hcl` 包含 PIPE 的 HCL 代码副本，以及常量值 `IIADDQ` 的声明。

**图 2：`ncopy` 函数的 C 语言版本。参见 `sim/pipe/ncopy.c`**

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

在 C 部分中，您的任务是修改 `ncopy.ys` 和 `pipe-full.hcl`，目标是使 `ncopy.ys` 尽可能快地运行。

您将提交两个文件：`pipe-full.hcl` 和 `ncopy.ys`。每个文件应以注释头开始，其中包含以下信息：
- 您的姓名和 ID。
- 代码的高级描述。在每种情况下，描述您修改代码的方式和原因。

### 编码规则

您可以根据以下限制自由进行任何修改：

- 您的 `ncopy.ys` 函数必须适用于任意数组大小。您可能会试图通过编写 64 个复制指令来硬连接 64 元素数组的解决方案，但这不是一个好主意，因为我们将根据解决方案在任意数组上的性能对其进行分级。

**图 3: `ncopy` 函数的基线 Y86-64 版本。请参见 `sim/pipe/ncopy.ys`。**

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

- 您的 `ncopy.ys` 函数必须与 YIS 一起正确运行。正确地说，我们的意思是它必须正确地复制 `src` 块并正确返回（在 `%rax` 中）其中正整数的数量。
- `ncopy` 文件的汇编版本长度不得超过 1000 字节。您可以使用提供的脚本 `check-len.pl` 来检查嵌入 `ncopy` 函数的任何程序的长度：

  ```bash
  unix> ./check-len.pl < ncopy.yo
  ```

- 您的 `pipe-full.hcl` 实现必须通过 `../y86-code` 和 `../ptest` 中的回归测试（不要使用 `-i` 标志，那是测试 `iaddq` 指令用的）。

除此之外，如果您认为 `iaddq` 指令有帮助，您可以自由实现它。您可以在保持语义不变的情况下对 `ncopy.ys` 函数进行任何转换，例如重新排序指令、用单个指令替换指令组、删除一些指令以及添加其他指令。您可能会发现阅读 CS:APP3e 第 5.8 节关于循环展开的内容很有用。

### 构建和运行解决方案

为了测试您的解决方案，您需要构建一个调用 `ncopy` 函数的驱动程序。我们为您提供了 `gen-driver.pl` 程序，它可以为任意大小的输入数组生成驱动程序。例如，键入

```bash
unix> make drivers
```

将构建以下两个有用的驱动程序：

- `sdriver.yo`：一个小的驱动程序，在 4 个元素的小数组上测试 `ncopy` 函数。如果您的解决方案是正确的，那么在复制 `src` 数组后停机，在寄存器 `%rax` 中返回值 2。
- `ldriver.yo`：一个大型驱动程序，在 63 个元素的大型数组上测试 `ncopy` 函数。如果您的解决方案是正确的，那么在复制 `src` 数组后停机，在寄存器 `%rax` 中返回值 31（`0x1f`）。

每次修改 `ncopy.ys` 程序，您可以通过键入以下命令重新构建驱动程序

```bash
unix> make drivers
```

每次修改 `pipe-full.hcl` 文件，您可以通过键入以下命令重新构建模拟器

```bash
unix> make psim VERSION=full
```

如果要重新构建模拟器和驱动程序，请键入

```bash
unix> make VERSION=full
```

要在小型 4 元素数组上以 GUI 模式测试解决方案，请键入

```bash
unix> ./psim -g sdriver.yo
```

要在更大的 63 元素数组上测试解决方案，请键入

```bash
unix> ./psim -g ldriver.yo
```

一旦你的模拟器在这两个块长度上正确运行你的 `ncopy.ys` 版本，您将需要执行以下附加测试：

- **在 ISA 模拟器上测试驱动程序文件。** 确保您的 `ncopy.ys` 函数与 YIS 一起正常工作：

  ```bash
  unix> make drivers
  unix> ../misc/yis sdriver.yo
  ```

- **使用 ISA 模拟器在一系列块长度上测试代码。** Perl 脚本 `correctness.pl` 生成的驱动程序文件的块长度从 0 到一定限界（默认值 65），再加上一些较大的大小。该脚本模拟不同大小块复制程序（默认情况下使用 YIS），并检查结果。该脚本生成一个报告，显示每个块长度的状态：

  ```bash
  unix> ./correctness.pl
  ```

  此脚本生成测试程序，其中结果计数随着每次运行而随机变化，因此它提供了比标准驱动程序更严格的测试。如果某个长度 K 的结果不正确，可以生成该长度的驱动程序文件，其中包含检查代码，并且结果随机变化：

  ```bash
  unix> ./gen-driver.pl -f ncopy.ys -n K -rc > driver.ys
  unix> make driver.yo
  unix> ../misc/yis driver.yo
  ```

  程序将以寄存器 `%rax` 具有以下值结束：
    - `0xaaaa`：所有测试均通过。
    - `0xbbbb`：计数不正确。
    - `0xcccc`：函数 `ncopy` 的长度超过 1000 字节。
    - `0xdddd`：某些源数据未复制到其目的地。
    - `0xeeee`：目的区域之前或之后的某个字已损坏。

- **在基准程序上测试流水线模拟器。** 一旦模拟器能够正确执行 `sdriver.yo` 和 `ldriver.yo`，您应该使用 `../y86-code` 中的 Y86-64 基准程序进行测试：

  ```bash
  unix> (cd ../y86-code; make testpsim)
  ```

  这将在基准程序上运行 `psim`，并将结果与 YIS 进行比较。

- **使用广泛的回归测试测试流水线模拟器。** 一旦您能够正确执行基准程序，就应该使用 `../ptest` 中的回归测试进行检查。例如，如果您的解决方案实现了 `iaddq` 指令，那么

  ```bash
  unix> (cd ../ptest; make SIM=../pipe/psim TFLAGS=-i)
  ```

- **使用流水线模拟器在一系列块长度上测试代码。** 最后，您可以在流水线模拟器上运行与之前使用 ISA 模拟器相同的代码测试

  ```bash
  unix> ./correctness.pl -p
  ```

## 7 评估

实验评估值 190 分：A 部分 30 分，B 部分 60 分，C 部分 100 分。

### A 部分
A 部分值 30 分，每个 Y86-64 解决方案程序得 10 分。将评估每个解决方案程序的正确性，包括栈和寄存器的正确处理，以及与 `examples.c` 中的示例 C 函数的功能等效性。

如果评分器在程序 `sum.ys` 和 `rsum.ys` 中没有发现任何错误，并且它们各自的 `sum_list` 和 `rsum_list` 函数在寄存器 `%rax` 中返回总和为 `0xcba`，则认为这些程序是正确的。

如果评分器在程序 `copy.ys` 中没有发现任何错误，并且复制块函数在寄存器 `%rax` 中返回总和为 `0xcba`，将三个 64 位值 `0x00a`、`0x0b` 和 `0xc` 复制到从地址 `dest` 开始的 24 个字节，并且不会损坏其他内存位置，则认为 `copy.ys` 是正确的。

### B 部分
这部分实验评估值 35 分：
- 您对 `iaddq` 指令所需计算的描述得 10 分。
- 通过 `y86-code` 中的基准回归测试得 10 分，以验证模拟器仍然正确执行基准测试套件。
- 通过 `iaddq` 的 `ptest` 回归测试得 15 分。

### C 部分
这部分实验评估值 100 分：如果你的代码 `ncopy.ys` 或者您修改的模拟器未能通过前面描述的任何测试，你将不会得到任何分数。

- `ncopy.ys` 和 `pipe-full.hcl` 头中的每个描述，以及这些实现的质量，各值 20 分。
- 性能值 60 分。要在这方面获得分数，您的解决方案必须是正确的，如前面所定义的。也就是说，`ncopy` 使用 YIS 正确运行，并且 `pipe-full.hcl` 通过了 `y86-code` 和 `ptest` 中的所有测试。

我们将以每个元素的周期数（CPE）为单位表示您的函数性能。也就是说，如果模拟代码需要 C 个周期来复制 N 个元素的块，那么 CPE 就是 C/N。PIPE 模拟器显示完成程序所需的总周期数。在标准 PIPE 模拟器上运行的 `ncopy` 函数的基线版本（带有大型 63 个元素数组）需要 897 个周期才能复制 63 个元素，相当于 CPE 为 $897/63 = 14.24$。

由于一些周期用于设置对 `ncopy` 的调用和在 `ncopy` 中设置循环，您会发现对于不同的块长度，您会得到不同的 CPE 值（通常 CPE 会随着 N 的增加而下降）。

因此，我们将通过计算从 1 到 64 个元素的块的平均 CPE 来评估您的函数性能。您可以使用 `pipe` 目录中的 Perl 脚本 `benchmark.pl` 运行一系列块长度的 `ncopy.ys` 模拟代码，并计算平均 CPE。只需运行命令

```bash
unix> ./benchmark.pl
```

看看会发生什么。例如，`ncopy` 函数的基线版本的 CPE 值介于 29.00 和 14.27 之间，平均值为 15.18。请注意，此 Perl 脚本并不检查答案的正确性。使用脚本 `correctness.pl` 检查程序正确性。

您应该能够取得低于 9.00 的平均 CPE，我们的最佳版本平均为 7.48。如果您的平均 CPE 为 $c$，那么您在这部分实验中的分数 $S$ 为：

$$
S = \begin{cases} 
0, & c > 10.5 \\
20 \cdot (10.5 - c), & 7.50 \leq c \leq 10.50 \\
60, & c < 7.50
\end{cases}
$$

默认情况下，`benchmark.pl` 和 `correctness.pl` 编译并测试 `ncopy.ys`。使用 `-f` 参数指定不同文件名。`-h` 标志给出了命令行参数的完整列表。

## 8 上交说明

特定说明：插入说明解释学生应如何提交实验的三个部分。这是我们在 CMU 使用的说明。

- 您将提交三套文件：
    - A 部分：`sum.ys`，`rsum.ys` 和 `copy.ys`。
    - B 部分：`seq-full.hcl`。
    - C 部分：`ncopy.ys` 和 `pipe-full.hcl`。

- 确保在每个 handin 文件顶部的注释中包含您的姓名和 ID。
- 要提交第 X 部分的文件，请转到 `archlab-handout` 目录并键入：
  ```bash
  unix> make handin-partX TEAM=teamname
  ```
  其中 X 是 a、b 或 c，teamname 是您的 ID。例如，要提交 Part A：
  ```bash
  unix> make handin-parta TEAM=teamname
  ```

- 在提交之后，如果发现错误并想提交修订后的副本，请键入
  ```bash
  unix make handin-partX TEAM=teamname VERSION=2
  ```
  每次提交时不断增加版本号。

- 您可以通过在 `CLASSDIR/archlab/handin-partX` 中查找来验证您的提交。您拥有此目录列表和插入权限，但没有读或写权限。

## 9 提示

- 根据设计，两个驱动程序 `sdriver.yo` 和 `ldriver.yo` 都足够小，可以在 GUI 模式下进行调试。我们发现在 GUI 模式下调试最容易，建议您使用它。
- 如果在 Unix 服务器上以 GUI 模式运行，请确保已初始化 DISPLAY 环境变量：
  ```bash
  unix> setenv DISPLAY myhost.edu:0
  ```
- 对于某些 X 服务器，当您在 GUI 模式下运行 `psim` 或 `ssim` 时，“程序代码”窗口开始以关闭图标的形式出现。只需单击图标即可展开窗口。
- 对于一些基于 Microsoft Windows 的 X 服务器，“内存内容”窗口不会自动调整大小。您需要手动调整窗口大小。
- 如果您要求 `psim` 和 `ssim` 模拟器执行一个不是有效 Y86-64 目标代码的文件，则它们会因段错误而终止。
