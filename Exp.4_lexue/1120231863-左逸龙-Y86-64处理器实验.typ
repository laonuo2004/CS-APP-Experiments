#import "@preview/cetz:0.3.1"
#set page(
  margin: (top: 2.54cm, bottom: 2.54cm, left: 3.17cm, right: 3.17cm),
  footer: context [
    #set align(center)
    #counter(page).display()
  ],
)
#set text(font: ("Times New Roman", "Source Han Serif SC"), size: 12pt)
#set par(first-line-indent: (amount: 2em, all: true))

// 缩进函数：输入缩进距离 (em) ，返回带缩进的块
#let indent-block(amount, content) = {
  block(inset: (left: amount))[
    #content
  ]
}

// 设置标题样式
#set heading(numbering: (..nums) => {
  let level = nums.pos().len()
  if level == 1 {
    // 一级标题：1, 2, 3...
    numbering("1 ", ..nums)
  } else if level == 2 {
    // 二级标题：1.1, 1.2, 1.3...
    let parent = nums.pos().first()
    let current = nums.pos().last()
    numbering("1.", parent)
    numbering("1 ", current)
  } else if level == 3 {
    // 三级标题：1.1.1, 1.1.2, 1.1.3...
    let first = nums.pos().first()
    let second = nums.pos().at(1)
    let third = nums.pos().last()
    numbering("1.", first)
    numbering("1.", second)
    numbering("1", third)
  }
})

// 设置标题字体大小和粗体
#show heading.where(level: 1): it => {
  set text(size: 18pt, weight: "bold")
  it
  v(1em)
}

#show heading.where(level: 2): it => {
  set text(size: 16pt, weight: "bold")
  it
  v(1em)
}

#show heading.where(level: 3): it => {
  set text(size: 14pt, weight: "bold")
  it
  v(1em)
}

#set enum(numbering: "(i)")

// 设置代码块样式：带背景框、边框和行号
#show raw.where(block: true): it => {
  block(
    width: 100%,
    fill: luma(245),
    inset: 10pt,
    radius: 4pt,
    stroke: (paint: luma(220), thickness: 1pt),
  )[
    #set par(justify: false)
    #set text(size: 9pt)
    #it
  ]
}

// 为代码块添加行号 (只在多行代码块中显示) 
#show raw.line: it => {
  // 只有当代码块有多行时才显示行号
  if it.count > 1 {
    box(width: 2em, {
      text(fill: luma(120), str(it.number))
      h(0.5em)
    })
    it.body
  } else {
    // 单行代码或行内代码不显示行号
    it.body
  }
}

// 设置行内代码样式：带浅色背景
#show raw.where(block: false): box.with(
  fill: luma(245),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 2pt,
)

#align(center)[
  #text(size: 20pt)[第4章实验 - 优化Y86-64流水线处理器性能]

  #text(size: 14pt)[1120231863 #h(1em) 左逸龙 #h(1em) 07112303]
]

#v(2em)

= 实验环境

本实验在 Windows 10 操作系统下通过 WSL2 完成，具体环境如下：

#indent-block(2em)[
  - *操作系统*：Windows 10 (Build 19045) + WSL2
  - *Linux 发行版*：Ubuntu 24.04.1 LTS
  - *内核版本*：6.6.87.2-microsoft-standard-WSL2
]

= Part A：Y86-64 汇编程序设计

== 任务概述

Part A 要求编写三个 Y86-64 汇编程序，分别实现链表迭代求和、链表递归求和、块复制与异或校验功能。以下分别介绍这三个程序的实现以及测试结果。

== `sum.ys`：链表迭代求和

`sum_list` 函数采用迭代方式遍历链表，累加每个节点的值并返回总和。链表节点结构为 `{val, next}`，每个字段占 8 字节。核心实现如下：

```asm
sum_list:
    pushq %rbx              # 保存被调用者保存寄存器
    xorq %rax, %rax         # 初始化返回值 sum = 0
    jmp test                # 跳转到循环条件判断

loop:
    mrmovq (%rdi), %rbx     # 读取当前节点的 val
    addq %rbx, %rax         # sum += val
    mrmovq 8(%rdi), %rdi    # rdi = rdi->next

test:
    andq %rdi, %rdi         # 测试 rdi 是否为 NULL
    jne loop                # 非空则继续循环

done:
    popq %rbx               # 恢复被调用者保存寄存器
    ret
```

程序运行结果如下图所示，返回值 `%rax = 0xcba` (即 $10 + 176 + 3072 = 3258$) 与预期一致。

#align(center)[
  #image("images/report_1.png")
]

== `rsum.ys`：链表递归求和

`rsum_list` 函数采用递归方式实现链表求和。递归的基例是空指针返回 0，递归步骤是当前节点值加上剩余链表的和。

核心实现如下：

```asm
rsum_list:
    andq %rdi, %rdi         # 测试 rdi 是否为 NULL
    je base_case            # 空指针跳转到基例
    pushq %rbx              # 保存 %rbx
    pushq %r12              # 保存 %r12
    mrmovq (%rdi), %rbx     # 保存当前节点的 val
    mrmovq 8(%rdi), %r12    # 获取 next 指针
    rrmovq %r12, %rdi       # 设置递归调用参数
    call rsum_list          # 递归调用
    addq %rbx, %rax         # sum = val + rsum_list(next)
    popq %r12               # 恢复寄存器
    popq %rbx
    ret

base_case:
    xorq %rax, %rax         # 返回 0
    ret
```

注意这里递归的实现需要使用额外的被调用者保存寄存器 (`%rbx` 和 `%r12`) 保存当前节点的值和 next 指针，以确保递归返回后能正确累加。运行结果如下图所示，返回值同样为 `0xcba`，与预期一致。

#align(center)[
  #image("images/report_2.png")
]

== `copy.ys`：块复制与异或校验

`copy_block` 函数将源数组复制到目标数组，同时计算所有元素的异或校验和。

核心实现如下：

```asm
copy_block:
    pushq %rbx              # 保存被调用者保存寄存器
    xorq %rax, %rax         # 初始化 result = 0
    irmovq $8, %r8          # 常量 8 (指针步进) 
    irmovq $1, %r9          # 常量 1 (计数器递减) 
    jmp test

loop:
    mrmovq (%rdi), %rbx     # 读取 src[i]
    rmmovq %rbx, (%rsi)     # 写入 dst[i]
    xorq %rbx, %rax         # result ^= src[i]
    addq %r8, %rdi          # src++
    addq %r8, %rsi          # dst++
    subq %r9, %rdx          # len--

test:
    andq %rdx, %rdx         # 测试 len > 0
    jg loop                 # 正数则继续循环

done:
    popq %rbx
    ret
```

由于 Y86-64 缺少立即数加法指令 (Part B 将添加 `iaddq`) ，因此这里需要使用寄存器 `%r8` 和 `%r9` 存储常量 8 和 1。运行结果如下图所示，异或校验和 `0x00a ^ 0x0b0 ^ 0xc00 = 0xcba` 验证正确，与预期一致。

#align(center)[
  #image("images/report_3.png")
]

= Part B：扩展 SEQ 处理器支持 `iaddq` 指令

== 任务概述

Part B 要求修改 `seq-full.hcl`，使 SEQ 处理器支持 `iaddq V, rB` 指令。该指令将立即数 V 加到寄存器 rB，并更新条件码。

== `iaddq` 指令分析

- *指令格式*

`iaddq` 指令的编码格式如下图所示，共占 10 字节：

#align(center)[
  #table(
    columns: (1fr, 1fr, 1fr, 1fr, 8fr),
    align: center + horizon,
    table.header[*icode*][*ifun*][*rA*][*rB*][*V*],
    [C], [0], [F], [rB], [8 字节立即数],
    table.cell(colspan: 2)[1 字节], table.cell(colspan: 2)[1 字节], [8 字节],
  )
]

其中 `rA` 字段固定为 `F` (表示不使用) ，`rB` 指定目标寄存器。

- *各阶段行为*

#table(
  columns: (auto, 1fr),
  align: (center, left),
  table.header[*阶段*][*操作*],
  [取指], [`icode:ifun ← C:0`, `rA:rB ← M1[PC+1]`, `valC ← M8[PC+2]`, `valP ← PC+10`],
  [译码], [`valB ← R[rB]`],
  [执行], [`valE ← valB + valC`, 设置条件码 (ZF, SF, OF)],
  [访存], [ (无操作) ],
  [写回], [`R[rB] ← valE`],
  [更新 PC], [`PC ← valP`],
)

== HCL 修改详解

`iaddq` 指令的行为与 `OPq` 类似 (执行算术运算并设置条件码) ，但操作数来源不同：一个来自立即数 `valC`，另一个来自寄存器 `valB`。对 `seq-full.hcl` 的修改涉及以下部分：

```hcl
## Fetch 阶段：添加为合法指令
bool instr_valid = icode in
    { INOP, IHALT, IRRMOVQ, IIRMOVQ, IRMMOVQ, IMRMOVQ,
      IOPQ, IJXX, ICALL, IRET, IPUSHQ, IPOPQ, IIADDQ };  # + IIADDQ

## Fetch 阶段：需要寄存器字节
bool need_regids =
    icode in { IRRMOVQ, IOPQ, IPUSHQ, IPOPQ,
               IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ };      # + IIADDQ

## Fetch 阶段：需要立即数
bool need_valC =
    icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ,
               IJXX, ICALL, IIADDQ };                   # + IIADDQ

## Decode 阶段：从 rB 读取
word srcB = [
    icode in { IOPQ, IRMMOVQ, IMRMOVQ, IIADDQ } : rB;   # + IIADDQ
    ...
];

## Decode 阶段：写回 rB
word dstE = [
    icode in { IRRMOVQ } && Cnd : rB;
    icode in { IIRMOVQ, IOPQ, IIADDQ } : rB;            # + IIADDQ
    ...
];

## Execute 阶段：ALU 输入 A 使用立即数
word aluA = [
    icode in { IRRMOVQ, IOPQ } : valA;
    icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ } : valC;  # + IIADDQ
    ...
];

## Execute 阶段：ALU 输入 B 使用寄存器值
word aluB = [
    icode in { IRMMOVQ, IMRMOVQ, IOPQ, ICALL,
               IPUSHQ, IRET, IPOPQ, IIADDQ } : valB;    # + IIADDQ
    ...
];

## Execute 阶段：设置条件码
bool set_cc = icode in { IOPQ, IIADDQ };                # + IIADDQ
```

== 测试结果

ISA 检查通过，验证 `iaddq` 指令行为正确：

#align(center)[
  #image("images/report_4.png")
]

y86-code 回归测试全部通过：

#align(center)[
  #image("images/report_5.png")
]

ptest 测试套件 (含 iaddq 测试) 全部通过：

#align(center)[
  #image("images/report_6.png")
]

= Part C：优化 ncopy 函数与 PIPE 处理器

== 任务概述

Part C 的目标是优化 `ncopy.ys` (复制数组并统计正数个数) 和 `pipe-full.hcl` (流水线处理器) ，使平均 CPE 尽可能低，同时满足以下约束：

- `ncopy.ys` 代码不超过 1000 字节
- `pipe-full.hcl` 必须通过所有标准测试，保证正确无误
- `ncopy.ys` 必须通过 `./correctness.pl` 正确性测试

== 优化策略一：iaddq 指令

首先，我们可以将 Part B 实现的 `iaddq` 指令迁移到 PIPE 处理器中，替代 `irmovq + addq` 组合，以减少指令数量，例如：

```asm
# 优化前                          # 优化后
irmovq $8, %r10                  iaddq $8, %rdi
addq %r10, %rdi
```

这一优化可以使每次指针更新从 2 条指令减少为 1 条。

== 优化策略二：10× 循环展开

循环展开是减少循环控制开销的经典方法。通过测试，我发现代码大小与展开因子近似成正比 (8× ≈ 800 字节，12× ≈ 1200 字节) ，结合题目要求的 1000 字节限制，因此选择了 10× 展开。

每个元素的处理模式如下：

```asm
L0:
    mrmovq (%rdi), %r8          # 从 src 读取元素
    rmmovq %r8, (%rsi)          # 写入 dst
    andq %r8, %r8               # 设置条件码
    jle L1                      # 非正数跳过计数
    iaddq $1, %rax              # count++
L1:
    mrmovq 8(%rdi), %r8         # 处理下一个元素
    rmmovq %r8, 8(%rsi)
    andq %r8, %r8
    jle L2
    iaddq $1, %rax
L2:
    # ... 重复至 L9 ...
```

循环尾部更新指针并判断是否继续：

```asm
    iaddq $80, %rdi             # src += 10
    iaddq $80, %rsi             # dst += 10
    iaddq $-10, %rdx            # len -= 10
    jge L0                      # len >= 0 继续循环
```

== 优化策略三：达夫设备 (Duff's Device) 优化+跳转树

循环展开后需处理 0–9 个剩余元素。一种简单的处理方法是写成一个独立的循环依次处理，虽然简单，但是效率低下；另外一种改进方法是采用*达夫设备 (Duff's Device) 优化*，将余数处理的循环也展开，并借助跳转表直接跳转到对应的余数处理，这能够在 `O(1)` 时间复杂度内找到跳转目标。

但是在实际实现过程当中发现，由于 Y86-64 处理器不支持间接跳转，因此需要使用 `pushq` 和 `ret` 指令组合来实现跳转表的跳转，代码如下：

```asm
# 假设跳转表存储在 jump_table，余数在 %rdx (范围 0-9) 
# 每个跳转地址占 8 字节

irmovq jump_table, %r8      # 跳转表基地址
addq %rdx, %rdx             # rdx *= 2
addq %rdx, %rdx             # rdx *= 2 (现在 rdx *= 4)
addq %rdx, %rdx             # rdx *= 8 (计算偏移量)
addq %rdx, %r8              # r8 = &jump_table[rdx]
mrmovq (%r8), %r8           # r8 = 目标地址
pushq %r8                   # 将目标地址压栈
ret                         # 弹出并跳转

.align 8
jump_table:
    .quad R0
    .quad R1
    .quad R2
    # ... R3 到 R9 ...
```

其中不仅存在 Load-Use 冒险，`ret` 也会产生 3 个周期的延迟，实际效率并没有想象中的高。事实上，跳转表更加适合余数范围较大的场景，而我们的余数范围较小，因此可以考虑采用*跳转树*的方法来优化跳转目标的查找。

=== 跳转树结构

#align(center)[
  #block(height: 15em, width: 100%)[
    // Define node style
    #let node(label, r: 1.2em) = circle(radius: r, stroke: black, fill: white)[
      #set align(center + horizon)
      #text(size: 9pt)[#label]
    ]

    // Helper to draw connection
    #let connect(sx, sy, ex, ey) = place(top + center)[
      #curve(
        stroke: 0.5pt,
        curve.move((sx, sy)),
        curve.line((ex, ey)),
      )
    ]

    // --- Level 0: Root "3" ---
    #place(top + center, dy: 0em)[#node("0-9")]

    // --- Level 1: "0-2", "3", "4-9" ---
    #connect(0em, 2.4em, -10em, 4em) // to 0-2
    #connect(0em, 2.4em, 0em, 4em)   // to 3
    #connect(10em, 2.4em, 20em, 4em)  // to 4-9

    #place(top + center, dx: -10em, dy: 4em)[#node("0-2")]
    #place(top + center, dx: 0em, dy: 4em)[#node("3")]
    #place(top + center, dx: 10em, dy: 4em)[#node("4-9")]

    // --- Level 2: Sub-branches ---
    #connect(-10em, 6.4em, -13em, 8em) // 0-2 -> 0
    #connect(-10em, 6.4em, -10em, 8em) // 0-2 -> 1
    #connect(-10em, 6.4em, -7em, 8em)  // 0-2 -> 2

    #place(top + center, dx: -13em, dy: 8em)[#node("0", r: 0.9em)]
    #place(top + center, dx: -10em, dy: 8em)[#node("1", r: 0.9em)]
    #place(top + center, dx: -7em, dy: 8em)[#node("2", r: 0.9em)]

    #connect(20em, 6.4em, 16em, 8em)   // 4-9 -> 4-6
    #connect(24em, 6.4em, 28em, 8em)  // 4-9 -> 7-9

    #place(top + center, dx: 6em, dy: 8em)[#node("4-6")]
    #place(top + center, dx: 14em, dy: 8em)[#node("7-9")]

    // --- Level 3: Leaves 4-9 ---
    #connect(12em, 10.4em, 10em, 12em)   // 4-6 -> 4
    #connect(12em, 10.4em, 12em, 12em)   // 4-6 -> 5
    #connect(14em, 10.4em, 16em, 12em)   // 4-6 -> 6

    #place(top + center, dx: 4em, dy: 12em)[#node("4", r: 0.9em)]
    #place(top + center, dx: 6em, dy: 12em)[#node("5", r: 0.9em)]
    #place(top + center, dx: 8em, dy: 12em)[#node("6", r: 0.9em)]

    #connect(28em, 10.4em, 26em, 12em) // 7-9 -> 7
    #connect(28em, 10.4em, 28em, 12em) // 7-9 -> 8
    #connect(30em, 10.4em, 32em, 12em) // 7-9 -> 9

    #place(top + center, dx: 12em, dy: 12em)[#node("7", r: 0.9em)]
    #place(top + center, dx: 14em, dy: 12em)[#node("8", r: 0.9em)]
    #place(top + center, dx: 16em, dy: 12em)[#node("9", r: 0.9em)]
  ]
]

=== 设计亮点

- *非平衡树设计*：以 3 为界而非 4 或 5，可以使小余数分支深度更浅。之所以要这样处理，是因为实际评测当中，小数组占多数，可以观察到小余数 (0-3) 的处理频率更高，且小数组中余数处理 CPE 权重高，因此优先优化小余数处理可显著降低平均 CPE。

- *Fall-through 结构*：余数处理代码采用"瀑布式"设计，例如 R9 直接 fall-through 到 R8，R8 到 R7，以此类推，避免多余跳转指令。这与达夫设备的设计思路类似，但更加灵活，可以根据实际分支情况调整结构。

```asm
R9:
    mrmovq 64(%rdi), %r8
    rmmovq %r8, 64(%rsi)
    andq %r8, %r8
    jle R8
    iaddq $1, %rax
R8:                             # 直接 fall-through 到 R8，避免跳转
    mrmovq 56(%rdi), %r8
    rmmovq %r8, 56(%rsi)
    # ... 以此类推 ...
```

== 优化策略四：加载转发 (Load Forwarding) 

=== 问题分析

主循环中 `mrmovq` 紧跟 `rmmovq` 的序列存在 Load-Use 冒险。标准 PIPE 处理器采用加载互锁 (Load Interlock) 解决，即暂停一个周期等待 `mrmovq` 完成内存访问。

```asm
mrmovq (%rdi), %r8      # Memory 阶段产生 valM
rmmovq %r8, (%rsi)      # Decode 阶段需要 %r8 → 冲突！
```

教材指出"Load-Use 冒险不能通过转发解决"，因为 `mrmovq` 在 Memory 阶段才会产生 `valM`，而 `rmmovq` 在 Decode 阶段需要用到 `valA`，因此无法通过转发解决。

但是通过实际分析后，我发现 `rmmovq` 虽然在 Decode 阶段读取了 `%r8`，但真正使用这个值是在 *Memory 阶段* (写入内存) 。当 `rmmovq` 到达 Execute 阶段时，前一条 `mrmovq` 也同时进入 Memory 阶段，此时 `m_valM` 可用。因此可在 Execute 阶段新增转发路径，用正确的 `m_valM` 覆盖错误的 `valA`。

=== HCL 修改

在 `pipe-full.hcl` 中新增 `e_valA` 信号，并放宽冒险检测条件：

```hcl
## Execute 阶段：加载转发
word e_valA = [
    # rmmovq/pushq 且 srcA 冲突时，直接转发 m_valM
    E_icode in { IRMMOVQ, IPUSHQ } && E_srcA == M_dstM : m_valM;
    1 : E_valA;    # 默认使用原值
];

## 放宽冒险检测条件 (仅 srcB 冲突或 srcA 冲突且非 rmmovq/pushq 时才暂停) 
bool F_stall =
    E_icode in { IMRMOVQ, IPOPQ } &&
    (
        E_dstM == d_srcB ||
        (E_dstM == d_srcA && !(D_icode in { IRMMOVQ, IPUSHQ }))
    ) ||
    IRET in { D_icode, E_icode, M_icode };
```

类似修改同样应用于 `D_stall`、`D_bubble`、`E_bubble`。

== 测试结果

PIPE 回归测试通过：

#align(center)[
  #image("images/report_7.png")
]

ptest 测试套件通过 (含 iaddq) ：

#align(center)[
  #image("images/report_8.png")
]

`ncopy.ys` 正确性测试与字节数通过：

#align(center)[
  #image("images/report_9.png")
]

Benchmark 结果：

#align(center)[
  #image("images/report_10.png")
]


#align(center)[
  #table(
    columns: (80%, auto),
    align: (left, center),
    table.header[*优化阶段*][*CPE*],
    [原始版本], [15.18],
    [\+ iaddq], [11.46],
    [\+ 10× 展开], [9.18],
    [\+ 余数处理优化], [7.88],
    [\+ 加载转发], [*7.46*],
  )
]

最终 CPE 为 *7.46*，达到满分标准 (< 7.5) 。

= 实验心得

本次实验围绕 Y86-64 处理器的设计与优化展开，主要收获集中在以下两个技术点：

== 跳转树优化与设计

循环展开是经典的优化手段，但展开后的余数处理往往被忽视。本实验中，通过对达夫设备进行改进，将跳转表替换为跳转树。更关键的是，通过分析评测数据分布 (小数组权重高) ，采用非平衡设计优先优化小余数情况，进一步提升了平均 CPE 表现。这一思路体现了"面向评测优化"的工程实践方法。

== 加载转发的突破

教材明确指出 Load-Use 冒险不能通过转发解决，需要使用加载互锁。本实验中，通过分析 `mrmovq` + `rmmovq` 序列的特殊性——`rmmovq` 在 Memory 阶段才真正需要数据——发现可以在 Execute 阶段新增转发路径，绕过加载互锁的限制。这一优化将每个元素的处理周期减少 1，进一步降低了 CPE。

这一经历提示，在工程实践中，教材结论往往基于一般情况，针对特定场景进行深入分析可能发现突破口。

= 附录：源代码

源代码文件也一并提交至附件。

== `sum.ys`

```asm
.pos 0
# sum.ys - Iteratively sum linked list elements
# 姓名：左逸龙
# 学号：1120231863
    irmovq stack, %rsp
    call main
    halt

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

main:
    irmovq ele1, %rdi
    call sum_list
    ret

sum_list:
    pushq %rbx
    xorq %rax, %rax
    jmp test

loop:
    mrmovq (%rdi), %rbx
    addq %rbx, %rax
    mrmovq 8(%rdi), %rdi

test:
    andq %rdi, %rdi
    jne loop

done:
    popq %rbx
    ret

.pos 0x200
stack:
```

== `rsum.ys`

```asm
.pos 0
# rsum.ys - Recursively sum linked list elements
# 姓名：左逸龙
# 学号：1120231863
    irmovq stack, %rsp
    call main
    halt

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

main:
    irmovq ele1, %rdi
    call rsum_list
    ret

rsum_list:
    andq %rdi, %rdi
    je base_case
    pushq %rbx
    pushq %r12
    mrmovq (%rdi), %rbx
    mrmovq 8(%rdi), %r12
    rrmovq %r12, %rdi
    call rsum_list
    addq %rbx, %rax
    popq %r12
    popq %rbx
    ret

base_case:
    xorq %rax, %rax
    ret

.pos 0x200
stack:
```

== `copy.ys`

```asm
.pos 0
# copy.ys - Copy block and return XOR checksum
# 姓名：左逸龙
# 学号：1120231863
    irmovq stack, %rsp
    call main
    halt

.align 8
src:
    .quad 0x00a
    .quad 0x0b0
    .quad 0xc00
dest:
    .quad 0x111
    .quad 0x222
    .quad 0x333

main:
    irmovq src, %rdi
    irmovq dest, %rsi
    irmovq $3, %rdx
    call copy_block
    ret

copy_block:
    pushq %rbx
    xorq %rax, %rax
    irmovq $8, %r8
    irmovq $1, %r9
    jmp test

loop:
    mrmovq (%rdi), %rbx
    rmmovq %rbx, (%rsi)
    xorq %rbx, %rax
    addq %r8, %rdi
    addq %r8, %rsi
    subq %r9, %rdx

test:
    andq %rdx, %rdx
    jg loop

done:
    popq %rbx
    ret

.pos 0x200
stack:
```

== `seq-full.hcl`

```hcl
#/* $begin seq-all-hcl */
####################################################################
#  HCL Description of Control for Single Cycle Y86-64 Processor SEQ   #
#  Copyright (C) Randal E. Bryant, David R. O'Hallaron, 2010       #
####################################################################

## Your task is to implement the iaddq instruction
## The file contains a declaration of the icodes
## for iaddq (IIADDQ)
## Your job is to add the rest of the logic to make it work

#######################################################################
# 姓名：左逸龙
# 学号：1120231863
# Instruction: iaddq V, rB
#   Fetch:     icode:ifun <- C:0, rA:rB <- M[PC+1], valC <- M[PC+2], valP <- PC+10
#   Decode:    valB <- R[rB]
#   Execute:   valE <- valB + valC, condition codes updated
#   Memory:    (no access)
#   Write:     R[rB] <- valE
#   PC:        valP
#######################################################################

####################################################################
#    C Include's.  Don't alter these                               #
####################################################################

quote '#include <stdio.h>'
quote '#include "isa.h"'
quote '#include "sim.h"'
quote 'int sim_main(int argc, char *argv[]);'
quote 'word_t gen_pc(){return 0;}'
quote 'int main(int argc, char *argv[])'
quote '  {plusmode=0;return sim_main(argc,argv);}'

####################################################################
#    Declarations.  Do not change/remove/delete any of these       #
####################################################################

##### Symbolic representation of Y86-64 Instruction Codes #############
wordsig INOP 	'I_NOP'
wordsig IHALT	'I_HALT'
wordsig IRRMOVQ	'I_RRMOVQ'
wordsig IIRMOVQ	'I_IRMOVQ'
wordsig IRMMOVQ	'I_RMMOVQ'
wordsig IMRMOVQ	'I_MRMOVQ'
wordsig IOPQ	'I_ALU'
wordsig IJXX	'I_JMP'
wordsig ICALL	'I_CALL'
wordsig IRET	'I_RET'
wordsig IPUSHQ	'I_PUSHQ'
wordsig IPOPQ	'I_POPQ'
# Instruction code for iaddq instruction
wordsig IIADDQ	'I_IADDQ'

##### Symbolic represenations of Y86-64 function codes                  #####
wordsig FNONE    'F_NONE'        # Default function code

##### Symbolic representation of Y86-64 Registers referenced explicitly #####
wordsig RRSP     'REG_RSP'    	# Stack Pointer
wordsig RNONE    'REG_NONE'   	# Special value indicating "no register"

##### ALU Functions referenced explicitly                            #####
wordsig ALUADD	'A_ADD'		# ALU should add its arguments

##### Possible instruction status values                             #####
wordsig SAOK	'STAT_AOK'	# Normal execution
wordsig SADR	'STAT_ADR'	# Invalid memory address
wordsig SINS	'STAT_INS'	# Invalid instruction
wordsig SHLT	'STAT_HLT'	# Halt instruction encountered

##### Signals that can be referenced by control logic ####################

##### Fetch stage inputs		#####
wordsig pc 'pc'				# Program counter
##### Fetch stage computations		#####
wordsig imem_icode 'imem_icode'		# icode field from instruction memory
wordsig imem_ifun  'imem_ifun' 		# ifun field from instruction memory
wordsig icode	  'icode'		# Instruction control code
wordsig ifun	  'ifun'		# Instruction function
wordsig rA	  'ra'			# rA field from instruction
wordsig rB	  'rb'			# rB field from instruction
wordsig valC	  'valc'		# Constant from instruction
wordsig valP	  'valp'		# Address of following instruction
boolsig imem_error 'imem_error'		# Error signal from instruction memory
boolsig instr_valid 'instr_valid'	# Is fetched instruction valid?

##### Decode stage computations		#####
wordsig valA	'vala'			# Value from register A port
wordsig valB	'valb'			# Value from register B port

##### Execute stage computations	#####
wordsig valE	'vale'			# Value computed by ALU
boolsig Cnd	'cond'			# Branch test

##### Memory stage computations		#####
wordsig valM	'valm'			# Value read from memory
boolsig dmem_error 'dmem_error'		# Error signal from data memory


####################################################################
#    Control Signal Definitions.                                   #
####################################################################

################ Fetch Stage     ###################################

# Determine instruction code
word icode = [
	imem_error: INOP;
	1: imem_icode;		# Default: get from instruction memory
];

# Determine instruction function
word ifun = [
	imem_error: FNONE;
	1: imem_ifun;		# Default: get from instruction memory
];

bool instr_valid = icode in 
	{ INOP, IHALT, IRRMOVQ, IIRMOVQ, IRMMOVQ, IMRMOVQ,
	       IOPQ, IJXX, ICALL, IRET, IPUSHQ, IPOPQ, IIADDQ };

# Does fetched instruction require a regid byte?
bool need_regids =
	icode in { IRRMOVQ, IOPQ, IPUSHQ, IPOPQ, 
		     IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ };

# Does fetched instruction require a constant word?
bool need_valC =
	icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IJXX, ICALL, IIADDQ };

################ Decode Stage    ###################################

## What register should be used as the A source?
word srcA = [
	icode in { IRRMOVQ, IRMMOVQ, IOPQ, IPUSHQ  } : rA;
	icode in { IPOPQ, IRET } : RRSP;
	1 : RNONE; # Don't need register
];

## What register should be used as the B source?
word srcB = [
	icode in { IOPQ, IRMMOVQ, IMRMOVQ, IIADDQ } : rB;
	icode in { IPUSHQ, IPOPQ, ICALL, IRET } : RRSP;
	1 : RNONE;  # Don't need register
];

## What register should be used as the E destination?
word dstE = [
	icode in { IRRMOVQ } && Cnd : rB;
	icode in { IIRMOVQ, IOPQ, IIADDQ } : rB;
	icode in { IPUSHQ, IPOPQ, ICALL, IRET } : RRSP;
	1 : RNONE;  # Don't write any register
];

## What register should be used as the M destination?
word dstM = [
	icode in { IMRMOVQ, IPOPQ } : rA;
	1 : RNONE;  # Don't write any register
];

################ Execute Stage   ###################################

## Select input A to ALU
word aluA = [
	icode in { IRRMOVQ, IOPQ } : valA;
	icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ } : valC;
	icode in { ICALL, IPUSHQ } : -8;
	icode in { IRET, IPOPQ } : 8;
	# Other instructions don't need ALU
];

## Select input B to ALU
word aluB = [
	icode in { IRMMOVQ, IMRMOVQ, IOPQ, ICALL, 
		      IPUSHQ, IRET, IPOPQ, IIADDQ } : valB;
	icode in { IRRMOVQ, IIRMOVQ } : 0;
	# Other instructions don't need ALU
];

## Set the ALU function
word alufun = [
	icode == IOPQ : ifun;
	1 : ALUADD;
];

## Should the condition codes be updated?
bool set_cc = icode in { IOPQ, IIADDQ };

################ Memory Stage    ###################################

## Set read control signal
bool mem_read = icode in { IMRMOVQ, IPOPQ, IRET };

## Set write control signal
bool mem_write = icode in { IRMMOVQ, IPUSHQ, ICALL };

## Select memory address
word mem_addr = [
	icode in { IRMMOVQ, IPUSHQ, ICALL, IMRMOVQ } : valE;
	icode in { IPOPQ, IRET } : valA;
	# Other instructions don't need address
];

## Select memory input data
word mem_data = [
	# Value from register
	icode in { IRMMOVQ, IPUSHQ } : valA;
	# Return PC
	icode == ICALL : valP;
	# Default: Don't write anything
];

## Determine instruction status
word Stat = [
	imem_error || dmem_error : SADR;
	!instr_valid: SINS;
	icode == IHALT : SHLT;
	1 : SAOK;
];

################ Program Counter Update ############################

## What address should instruction be fetched at

word new_pc = [
	# Call.  Use instruction constant
	icode == ICALL : valC;
	# Taken branch.  Use instruction constant
	icode == IJXX && Cnd : valC;
	# Completion of RET instruction.  Use value from stack
	icode == IRET : valM;
	# Default: Use incremented PC
	1 : valP;
];
#/* $end seq-all-hcl */
```

== `ncopy.ys`

```asm
#/* $begin ncopy-ys */
##################################################################
# ncopy.ys - Copy a src block of len words to dst.
# Return the number of positive words (>0) contained in src.
#
# 姓名：左逸龙
# 学号：1120231863
#
# ======================== 优化说明 ========================
#
# 1. 加载转发 (Load Forwarding) - 配合 pipe-full.hcl 的修改
#    - 问题：标准 PIPE 中，mrmovq 后紧跟 rmmovq 使用同一寄存器会产生
#      1 个周期的气泡（load-use 冒险）
#    - 解决：在 pipe-full.hcl 中修改 e_valA 信号，当 Execute 阶段的
#      rmmovq 需要的数据正好由 Memory 阶段的 mrmovq 产生时，直接转发
#      m_valM，避免暂停
#    - 效果：每个元素节省 1 个周期
#
# 2. 10x 循环展开 (Loop Unrolling)
#    - 思路：每次循环处理 10 个元素，减少循环控制开销
#    - 展开因子选择：10x 在代码大小（<1000字节）和性能之间取得平衡
#    - 每个元素的处理模式：
#      mrmovq offset(%rdi), %r8  # 从 src 读取
#      rmmovq %r8, offset(%rsi)  # 写入 dst（加载转发消除了气泡）
#      andq %r8, %r8             # 设置条件码
#      jle NextLabel             # 如果 <= 0 跳过计数
#      iaddq $1, %rax            # count++
#
# 3. iaddq 指令
#    - 使用 iaddq 替代 irmovq + addq 组合，减少指令数量
#    - 例如：iaddq $80, %rdi 代替 irmovq $80, %r10 + addq %r10, %rdi
#
# 4. 达夫设备 (Duff's Device) 优化+跳转树
#    - 问题：循环展开后需要处理 0-9 个剩余元素
#    - 思路：使用达夫设备 (Duff's Device) 优化+跳转树减少平均分支次数
#    - 结构：先与 3 比较分为 [0-2], [3], [4-9] 三组
#           再递归细分各子区间
#    - 优势：平均只需 2-3 次比较即可定位到正确的处理入口，相比跳转表，跳转树的效率更高
#
##################################################################
# Do not modify this portion
# Function prologue.
# %rdi = src, %rsi = dst, %rdx = len
ncopy:

##################################################################
# You can modify this portion

	# ========== 主循环：10x 展开 ==========
	# 首先将 len 减 10，判断是否能进入主循环
	iaddq $-10, %rdx
	jl Rem			# len < 10，跳转到余数处理

L0:
	# 处理第 0 个元素
	mrmovq (%rdi), %r8
	rmmovq %r8, (%rsi)
	andq %r8, %r8
	jle L1
	iaddq $1, %rax
L1:
	# 处理第 1 个元素
	mrmovq 8(%rdi), %r8
	rmmovq %r8, 8(%rsi)
	andq %r8, %r8
	jle L2
	iaddq $1, %rax
L2:
	# 处理第 2 个元素
	mrmovq 16(%rdi), %r8
	rmmovq %r8, 16(%rsi)
	andq %r8, %r8
	jle L3
	iaddq $1, %rax
L3:
	# 处理第 3 个元素
	mrmovq 24(%rdi), %r8
	rmmovq %r8, 24(%rsi)
	andq %r8, %r8
	jle L4
	iaddq $1, %rax
L4:
	# 处理第 4 个元素
	mrmovq 32(%rdi), %r8
	rmmovq %r8, 32(%rsi)
	andq %r8, %r8
	jle L5
	iaddq $1, %rax
L5:
	# 处理第 5 个元素
	mrmovq 40(%rdi), %r8
	rmmovq %r8, 40(%rsi)
	andq %r8, %r8
	jle L6
	iaddq $1, %rax
L6:
	# 处理第 6 个元素
	mrmovq 48(%rdi), %r8
	rmmovq %r8, 48(%rsi)
	andq %r8, %r8
	jle L7
	iaddq $1, %rax
L7:
	# 处理第 7 个元素
	mrmovq 56(%rdi), %r8
	rmmovq %r8, 56(%rsi)
	andq %r8, %r8
	jle L8
	iaddq $1, %rax
L8:
	# 处理第 8 个元素
	mrmovq 64(%rdi), %r8
	rmmovq %r8, 64(%rsi)
	andq %r8, %r8
	jle L9
	iaddq $1, %rax
L9:
	# 处理第 9 个元素
	mrmovq 72(%rdi), %r8
	rmmovq %r8, 72(%rsi)
	andq %r8, %r8
	jle Nxt
	iaddq $1, %rax
Nxt:
	# 更新指针，准备下一轮迭代
	iaddq $80, %rdi		# src += 10
	iaddq $80, %rsi		# dst += 10
	iaddq $-10, %rdx	# len -= 10
	jge L0			# 如果 len >= 0，继续循环

	# ========== 余数处理：二叉搜索 ==========
	# 此时 rdx 在 [-10, -1]，表示剩余 0-9 个元素
Rem:
	iaddq $7, %rdx		# rdx = len - 3 (因为之前减了10，现在+7相当于原始len-3)
	jl R02			# len < 3 → 处理 0-2 个元素
	jg R49			# len > 3 → 处理 4-9 个元素
				# len = 3 → 直接 fall-through 到 R3

	# ---------- 处理 3, 2, 1 个元素（fall-through 结构）----------
R3:
	mrmovq 16(%rdi), %r8
	rmmovq %r8, 16(%rsi)
	andq %r8, %r8
	jle R2
	iaddq $1, %rax
R2:
	mrmovq 8(%rdi), %r8
	rmmovq %r8, 8(%rsi)
	andq %r8, %r8
	jle R1
	iaddq $1, %rax
R1:
	mrmovq (%rdi), %r8
	rmmovq %r8, (%rsi)
	andq %r8, %r8
	jle Done
	iaddq $1, %rax
	ret			# 直接返回，节省 jmp Done 的 8 字节

	# ---------- 处理 4-9 个元素 ----------
R49:
	iaddq $-4, %rdx		# rdx = len - 7
	jl R46			# len < 7 → 处理 4-6 个元素
	je R7			# len = 7
	iaddq $-1, %rdx
	je R8			# len = 8
				# len = 9 → fall-through

	# 9-4 个元素的处理（fall-through 到 R3）
R9:
	mrmovq 64(%rdi), %r8
	rmmovq %r8, 64(%rsi)
	andq %r8, %r8
	jle R8
	iaddq $1, %rax
R8:
	mrmovq 56(%rdi), %r8
	rmmovq %r8, 56(%rsi)
	andq %r8, %r8
	jle R7
	iaddq $1, %rax
R7:
	mrmovq 48(%rdi), %r8
	rmmovq %r8, 48(%rsi)
	andq %r8, %r8
	jle R6
	iaddq $1, %rax
R6:
	mrmovq 40(%rdi), %r8
	rmmovq %r8, 40(%rsi)
	andq %r8, %r8
	jle R5
	iaddq $1, %rax
R5:
	mrmovq 32(%rdi), %r8
	rmmovq %r8, 32(%rsi)
	andq %r8, %r8
	jle R4
	iaddq $1, %rax
R4:
	mrmovq 24(%rdi), %r8
	rmmovq %r8, 24(%rsi)
	andq %r8, %r8
	jle R3
	iaddq $1, %rax
	jmp R3			# 继续处理剩余的 3 个元素

	# ---------- 处理 4-6 个元素的分支入口 ----------
R46:
	iaddq $2, %rdx		# rdx = len - 5
	jl R4			# len = 4
	je R5			# len = 5
	jmp R6			# len = 6

	# ---------- 处理 0-2 个元素的分支入口 ----------
R02:
	iaddq $2, %rdx		# rdx = len - 1
	jl Done			# len = 0
	je R1			# len = 1
	jmp R2			# len = 2

##################################################################
# Do not modify the following section of code
# Function epilogue.
Done:
	ret
##################################################################
# Keep the following label at the end of your function
End:
#/* $end ncopy-ys */
```

== `pipe-full.hcl`

```hcl
#/* $begin pipe-all-hcl */
####################################################################
#    HCL Description of Control for Pipelined Y86-64 Processor     #
#    Copyright (C) Randal E. Bryant, David R. O'Hallaron, 2014     #
####################################################################

## Your task is to implement the iaddq instruction
## The file contains a declaration of the icodes
## for iaddq (IIADDQ)
## Your job is to add the rest of the logic to make it work

#######################################################################
# 姓名：左逸龙
# 学号：1120231863
#
# ====================== 实现说明 ======================
#
# 1. iaddq 指令实现
#
# iaddq V, rB: 将立即数 V 加到寄存器 rB，同时设置条件码
#
# 各阶段行为:
#   Fetch:   icode:ifun <- C:0
#            rA:rB <- M[PC+1]  (rA = F, 表示不使用)
#            valC <- M[PC+2]   (8字节立即数)
#            valP <- PC + 10
#   Decode:  valB <- R[rB]     (读取目标寄存器的当前值)
#   Execute: valE <- valB + valC, 设置 CC (条件码)
#   Memory:  (无操作)
#   Write:   R[rB] <- valE     (写回结果)
#   PC:      PC <- valP
#
# HCL 修改点:
#   - instr_valid: 添加 IIADDQ
#   - need_regids: 添加 IIADDQ (需要读取 rB)
#   - need_valC:   添加 IIADDQ (需要立即数)
#   - d_srcB:      添加 IIADDQ (从 rB 读取)
#   - d_dstE:      添加 IIADDQ (写入 rB)
#   - aluA:        添加 IIADDQ -> valC
#   - aluB:        添加 IIADDQ -> valB
#   - set_cc:      添加 IIADDQ (需要设置条件码)
#
# 2. 加载转发优化 (Load Forwarding)
#
# 问题背景:
#   在标准 PIPE 处理器中，以下代码会产生 1 个周期的暂停:
#     mrmovq (%rdi), %r8   # 从内存加载到 r8
#     rmmovq %r8, (%rsi)   # 立即使用 r8 -> load-use 冒险!
#
#   原因: mrmovq 在 Memory 阶段产生 valM，而 rmmovq 在 Decode
#   阶段就需要读取 r8。即使有转发，当 rmmovq 进入 Execute 时，
#   mrmovq 刚离开 Memory 阶段，数据无法及时转发。
#
# 解决方案:
#   观察到 rmmovq 实际上在 Memory 阶段才需要 valA（用于写内存），
#   而此时 mrmovq 已经完成 Memory 阶段，m_valM 可用。
#   因此可以将 m_valM 直接转发到 Execute 阶段的 e_valA。
#
# 实现修改:
#   1. e_valA 信号: 当 Execute 阶段是 rmmovq/pushq 且其 srcA
#      与 Memory 阶段的 dstM 匹配时，使用 m_valM
#
#   2. 冒险检测条件 (F_stall, D_stall, D_bubble, E_bubble):
#      放宽 load-use 冒险的检测条件，当下一条指令是 rmmovq/pushq
#      且冲突发生在 srcA 时，不产生暂停（因为可以转发）
#      条件变为: 只有当 dstM == srcB，或者
#      (dstM == srcA 且 下一条指令不是 rmmovq/pushq) 时才暂停
#
#######################################################################
####################################################################
#    C Include's.  Don't alter these                               #
####################################################################

quote '#include <stdio.h>'
quote '#include "isa.h"'
quote '#include "pipeline.h"'
quote '#include "stages.h"'
quote '#include "sim.h"'
quote 'int sim_main(int argc, char *argv[]);'
quote 'int main(int argc, char *argv[]){return sim_main(argc,argv);}'

####################################################################
#    Declarations.  Do not change/remove/delete any of these       #
####################################################################

##### Symbolic representation of Y86-64 Instruction Codes #############
wordsig INOP 	'I_NOP'
wordsig IHALT	'I_HALT'
wordsig IRRMOVQ	'I_RRMOVQ'
wordsig IIRMOVQ	'I_IRMOVQ'
wordsig IRMMOVQ	'I_RMMOVQ'
wordsig IMRMOVQ	'I_MRMOVQ'
wordsig IOPQ	'I_ALU'
wordsig IJXX	'I_JMP'
wordsig ICALL	'I_CALL'
wordsig IRET	'I_RET'
wordsig IPUSHQ	'I_PUSHQ'
wordsig IPOPQ	'I_POPQ'
# Instruction code for iaddq instruction
wordsig IIADDQ	'I_IADDQ'

##### Symbolic represenations of Y86-64 function codes            #####
wordsig FNONE    'F_NONE'        # Default function code

##### Symbolic representation of Y86-64 Registers referenced      #####
wordsig RRSP     'REG_RSP'    	     # Stack Pointer
wordsig RNONE    'REG_NONE'   	     # Special value indicating "no register"

##### ALU Functions referenced explicitly ##########################
wordsig ALUADD	'A_ADD'		     # ALU should add its arguments

##### Possible instruction status values                       #####
wordsig SBUB	'STAT_BUB'	# Bubble in stage
wordsig SAOK	'STAT_AOK'	# Normal execution
wordsig SADR	'STAT_ADR'	# Invalid memory address
wordsig SINS	'STAT_INS'	# Invalid instruction
wordsig SHLT	'STAT_HLT'	# Halt instruction encountered

##### Signals that can be referenced by control logic ##############

##### Pipeline Register F ##########################################

wordsig F_predPC 'pc_curr->pc'	     # Predicted value of PC

##### Intermediate Values in Fetch Stage ###########################

wordsig imem_icode  'imem_icode'      # icode field from instruction memory
wordsig imem_ifun   'imem_ifun'       # ifun  field from instruction memory
wordsig f_icode	'if_id_next->icode'  # (Possibly modified) instruction code
wordsig f_ifun	'if_id_next->ifun'   # Fetched instruction function
wordsig f_valC	'if_id_next->valc'   # Constant data of fetched instruction
wordsig f_valP	'if_id_next->valp'   # Address of following instruction
boolsig imem_error 'imem_error'	     # Error signal from instruction memory
boolsig instr_valid 'instr_valid'    # Is fetched instruction valid?

##### Pipeline Register D ##########################################
wordsig D_icode 'if_id_curr->icode'   # Instruction code
wordsig D_rA 'if_id_curr->ra'	     # rA field from instruction
wordsig D_rB 'if_id_curr->rb'	     # rB field from instruction
wordsig D_valP 'if_id_curr->valp'     # Incremented PC

##### Intermediate Values in Decode Stage  #########################

wordsig d_srcA	 'id_ex_next->srca'  # srcA from decoded instruction
wordsig d_srcB	 'id_ex_next->srcb'  # srcB from decoded instruction
wordsig d_rvalA 'd_regvala'	     # valA read from register file
wordsig d_rvalB 'd_regvalb'	     # valB read from register file

##### Pipeline Register E ##########################################
wordsig E_icode 'id_ex_curr->icode'   # Instruction code
wordsig E_ifun  'id_ex_curr->ifun'    # Instruction function
wordsig E_valC  'id_ex_curr->valc'    # Constant data
wordsig E_srcA  'id_ex_curr->srca'    # Source A register ID
wordsig E_valA  'id_ex_curr->vala'    # Source A value
wordsig E_srcB  'id_ex_curr->srcb'    # Source B register ID
wordsig E_valB  'id_ex_curr->valb'    # Source B value
wordsig E_dstE 'id_ex_curr->deste'    # Destination E register ID
wordsig E_dstM 'id_ex_curr->destm'    # Destination M register ID

##### Intermediate Values in Execute Stage #########################
wordsig e_valE 'ex_mem_next->vale'	# valE generated by ALU
boolsig e_Cnd 'ex_mem_next->takebranch' # Does condition hold?
wordsig e_dstE 'ex_mem_next->deste'      # dstE (possibly modified to be RNONE)

##### Pipeline Register M                  #########################
wordsig M_stat 'ex_mem_curr->status'     # Instruction status
wordsig M_icode 'ex_mem_curr->icode'	# Instruction code
wordsig M_ifun  'ex_mem_curr->ifun'	# Instruction function
wordsig M_valA  'ex_mem_curr->vala'      # Source A value
wordsig M_dstE 'ex_mem_curr->deste'	# Destination E register ID
wordsig M_valE  'ex_mem_curr->vale'      # ALU E value
wordsig M_dstM 'ex_mem_curr->destm'	# Destination M register ID
boolsig M_Cnd 'ex_mem_curr->takebranch'	# Condition flag
boolsig dmem_error 'dmem_error'	        # Error signal from instruction memory

##### Intermediate Values in Memory Stage ##########################
wordsig m_valM 'mem_wb_next->valm'	# valM generated by memory
wordsig m_stat 'mem_wb_next->status'	# stat (possibly modified to be SADR)

##### Pipeline Register W ##########################################
wordsig W_stat 'mem_wb_curr->status'     # Instruction status
wordsig W_icode 'mem_wb_curr->icode'	# Instruction code
wordsig W_dstE 'mem_wb_curr->deste'	# Destination E register ID
wordsig W_valE  'mem_wb_curr->vale'      # ALU E value
wordsig W_dstM 'mem_wb_curr->destm'	# Destination M register ID
wordsig W_valM  'mem_wb_curr->valm'	# Memory M value

####################################################################
#    Control Signal Definitions.                                   #
####################################################################

################ Fetch Stage     ###################################

## What address should instruction be fetched at
word f_pc = [
	# Mispredicted branch.  Fetch at incremented PC
	M_icode == IJXX && !M_Cnd : M_valA;
	# Completion of RET instruction
	W_icode == IRET : W_valM;
	# Default: Use predicted value of PC
	1 : F_predPC;
];

## Determine icode of fetched instruction
word f_icode = [
	imem_error : INOP;
	1: imem_icode;
];

# Determine ifun
word f_ifun = [
	imem_error : FNONE;
	1: imem_ifun;
];

# Is instruction valid?
bool instr_valid = f_icode in 
	{ INOP, IHALT, IRRMOVQ, IIRMOVQ, IRMMOVQ, IMRMOVQ,
	  IOPQ, IJXX, ICALL, IRET, IPUSHQ, IPOPQ, IIADDQ };

# Determine status code for fetched instruction
word f_stat = [
	imem_error: SADR;
	!instr_valid : SINS;
	f_icode == IHALT : SHLT;
	1 : SAOK;
];

# Does fetched instruction require a regid byte?
bool need_regids =
	f_icode in { IRRMOVQ, IOPQ, IPUSHQ, IPOPQ, 
		     IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ };

# Does fetched instruction require a constant word?
bool need_valC =
	f_icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IJXX, ICALL, IIADDQ };

# Predict next value of PC
word f_predPC = [
	f_icode in { IJXX, ICALL } : f_valC;
	1 : f_valP;
];

################ Decode Stage ######################################


## What register should be used as the A source?
word d_srcA = [
	D_icode in { IRRMOVQ, IRMMOVQ, IOPQ, IPUSHQ  } : D_rA;
	D_icode in { IPOPQ, IRET } : RRSP;
	1 : RNONE; # Don't need register
];

## What register should be used as the B source?
word d_srcB = [
	D_icode in { IOPQ, IRMMOVQ, IMRMOVQ, IIADDQ } : D_rB;
	D_icode in { IPUSHQ, IPOPQ, ICALL, IRET } : RRSP;
	1 : RNONE;  # Don't need register
];

## What register should be used as the E destination?
word d_dstE = [
	D_icode in { IRRMOVQ, IIRMOVQ, IOPQ, IIADDQ } : D_rB;
	D_icode in { IPUSHQ, IPOPQ, ICALL, IRET } : RRSP;
	1 : RNONE;  # Don't write any register
];

## What register should be used as the M destination?
word d_dstM = [
	D_icode in { IMRMOVQ, IPOPQ } : D_rA;
	1 : RNONE;  # Don't write any register
];

## What should be the A value?
## Forward into decode stage for valA
word d_valA = [
	D_icode in { ICALL, IJXX } : D_valP; # Use incremented PC
	d_srcA == e_dstE : e_valE;    # Forward valE from execute
	d_srcA == M_dstM : m_valM;    # Forward valM from memory
	d_srcA == M_dstE : M_valE;    # Forward valE from memory
	d_srcA == W_dstM : W_valM;    # Forward valM from write back
	d_srcA == W_dstE : W_valE;    # Forward valE from write back
	1 : d_rvalA;  # Use value read from register file
];

word d_valB = [
	d_srcB == e_dstE : e_valE;    # Forward valE from execute
	d_srcB == M_dstM : m_valM;    # Forward valM from memory
	d_srcB == M_dstE : M_valE;    # Forward valE from memory
	d_srcB == W_dstM : W_valM;    # Forward valM from write back
	d_srcB == W_dstE : W_valE;    # Forward valE from write back
	1 : d_rvalB;  # Use value read from register file
];

################ Execute Stage #####################################

## Select input A to ALU
word aluA = [
	E_icode in { IRRMOVQ, IOPQ } : E_valA;
	E_icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ } : E_valC;
	E_icode in { ICALL, IPUSHQ } : -8;
	E_icode in { IRET, IPOPQ } : 8;
	# Other instructions don't need ALU
];

## Select input B to ALU
word aluB = [
	E_icode in { IRMMOVQ, IMRMOVQ, IOPQ, ICALL, 
		     IPUSHQ, IRET, IPOPQ, IIADDQ } : E_valB;
	E_icode in { IRRMOVQ, IIRMOVQ } : 0;
	# Other instructions don't need ALU
];

## Set the ALU function
word alufun = [
	E_icode == IOPQ : E_ifun;
	1 : ALUADD;
];

## Should the condition codes be updated?
bool set_cc = E_icode in { IOPQ, IIADDQ } &&
	# State changes only during normal operation
	!m_stat in { SADR, SINS, SHLT } && !W_stat in { SADR, SINS, SHLT };

## Generate valA in execute stage
## Load forwarding: forward valM from memory stage for rmmovq/pushq
word e_valA = [
	E_icode in { IRMMOVQ, IPUSHQ } && E_srcA == M_dstM : m_valM;
	1 : E_valA;    # Pass valA through stage
];

## Set dstE to RNONE in event of not-taken conditional move
word e_dstE = [
	E_icode == IRRMOVQ && !e_Cnd : RNONE;
	1 : E_dstE;
];

################ Memory Stage ######################################

## Select memory address
word mem_addr = [
	M_icode in { IRMMOVQ, IPUSHQ, ICALL, IMRMOVQ } : M_valE;
	M_icode in { IPOPQ, IRET } : M_valA;
	# Other instructions don't need address
];

## Set read control signal
bool mem_read = M_icode in { IMRMOVQ, IPOPQ, IRET };

## Set write control signal
bool mem_write = M_icode in { IRMMOVQ, IPUSHQ, ICALL };

#/* $begin pipe-m_stat-hcl */
## Update the status
word m_stat = [
	dmem_error : SADR;
	1 : M_stat;
];
#/* $end pipe-m_stat-hcl */

## Set E port register ID
word w_dstE = W_dstE;

## Set E port value
word w_valE = W_valE;

## Set M port register ID
word w_dstM = W_dstM;

## Set M port value
word w_valM = W_valM;

## Update processor status
word Stat = [
	W_stat == SBUB : SAOK;
	1 : W_stat;
];

################ Pipeline Register Control #########################

# Should I stall or inject a bubble into Pipeline Register F?
# At most one of these can be true.
bool F_bubble = 0;
bool F_stall =
	# Conditions for a load/use hazard (relaxed for load forwarding)
	E_icode in { IMRMOVQ, IPOPQ } &&
	(
		E_dstM == d_srcB ||
		(E_dstM == d_srcA && !(D_icode in { IRMMOVQ, IPUSHQ }))
	) ||
	# Stalling at fetch while ret passes through pipeline
	IRET in { D_icode, E_icode, M_icode };

# Should I stall or inject a bubble into Pipeline Register D?
# At most one of these can be true.
bool D_stall = 
	# Conditions for a load/use hazard (relaxed for load forwarding)
	E_icode in { IMRMOVQ, IPOPQ } &&
	(
		E_dstM == d_srcB ||
		(E_dstM == d_srcA && !(D_icode in { IRMMOVQ, IPUSHQ }))
	);

bool D_bubble =
	# Mispredicted branch
	(E_icode == IJXX && !e_Cnd) ||
	# Stalling at fetch while ret passes through pipeline
	# but not condition for a load/use hazard (relaxed for load forwarding)
	!(
		E_icode in { IMRMOVQ, IPOPQ } &&
		(
			E_dstM == d_srcB ||
			(E_dstM == d_srcA && !(D_icode in { IRMMOVQ, IPUSHQ }))
		)
	) &&
	IRET in { D_icode, E_icode, M_icode };

# Should I stall or inject a bubble into Pipeline Register E?
# At most one of these can be true.
bool E_stall = 0;
bool E_bubble =
	# Mispredicted branch
	(E_icode == IJXX && !e_Cnd) ||
	# Conditions for a load/use hazard (relaxed for load forwarding)
	E_icode in { IMRMOVQ, IPOPQ } &&
	(
		E_dstM == d_srcB ||
		(E_dstM == d_srcA && !(D_icode in { IRMMOVQ, IPUSHQ }))
	);

# Should I stall or inject a bubble into Pipeline Register M?
# At most one of these can be true.
bool M_stall = 0;
# Start injecting bubbles as soon as exception passes through memory stage
bool M_bubble = m_stat in { SADR, SINS, SHLT } || W_stat in { SADR, SINS, SHLT };

# Should I stall or inject a bubble into Pipeline Register W?
bool W_stall = W_stat in { SADR, SINS, SHLT };
bool W_bubble = 0;
#/* $end pipe-all-hcl */
```