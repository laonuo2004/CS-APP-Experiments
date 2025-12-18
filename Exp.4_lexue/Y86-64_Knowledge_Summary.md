# Y86-64 处理器体系结构 知识点总结

> 本文档旨在为 CSAPP:3e 第四章 Arch Lab 实验提供详细的 Y86-64 参考资料。
> 
> 适用于：**Part A**（编写 Y86-64 汇编程序）、**Part B**（扩展 SEQ 处理器支持 `iaddq`）、**Part C**（优化 `ncopy` 函数和流水线处理器）

---

## 目录

1. [Y86-64 概述](#1-y86-64-概述)
2. [程序员可见状态](#2-程序员可见状态)
3. [Y86-64 指令集](#3-y86-64-指令集)
4. [Y86-64 汇编语法](#4-y86-64-汇编语法)
5. [函数调用约定](#5-函数调用约定)
6. [SEQ 顺序处理器](#6-seq-顺序处理器)
7. [PIPE 流水线处理器](#7-pipe-流水线处理器)
8. [HCL 硬件控制语言](#8-hcl-硬件控制语言)
9. [性能优化技术](#9-性能优化技术)
10. [Y86-64 开发工具](#10-y86-64-开发工具)

---

## 1. Y86-64 概述

Y86-64 是 CSAPP 作者为**教学目的设计的简化版 x86-64 指令集架构 (ISA)**。

### 1.1 设计目的

- 比 x86-64 更简单，更容易理解处理器工作原理
- 保留了 x86-64 的核心概念，但移除了复杂特性

### 1.2 主要特点

| 特性     | 描述                                 |
| -------- | ------------------------------------ |
| 数据宽度 | 只支持 **64 位整数**操作（称为"字"） |
| 指令长度 | **1-10 字节**不等                    |
| 寻址模式 | 仅支持**基址+偏移量**形式            |
| 内存传送 | **不支持**内存到内存直接传送         |
| 字节序   | **小端序 (Little-Endian)**           |

### 1.3 Y86-64 vs x86-64 对比

| 特性       | Y86-64                         | x86-64       |
| ---------- | ------------------------------ | ------------ |
| 寄存器数量 | 15 个 (无 %r15)                | 16 个        |
| 指令复杂度 | 简化版                         | 完整版       |
| 寻址模式   | 基址+偏移量                    | 多种复杂模式 |
| 内存传送   | 不支持内存→内存                | 支持         |
| 立即数运算 | 需先加载到寄存器（除 `iaddq`） | 可直接使用   |

---

## 2. 程序员可见状态

### 2.1 状态概览

```
┌─────────────────────────────────────────────────────────────────┐
│                     程序员可见状态                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────┐  ┌────┐  ┌──────────┐            │
│  │ 15个寄存器  │  │ 条件码  │  │ PC │  │  Stat    │            │
│  │ %rax..%r14 │  │ ZF SF OF│  │    │  │ AOK/HLT/ │            │
│  └─────────────┘  └─────────┘  └────┘  │ ADR/INS  │            │
│                                         └──────────┘            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    内存 (Memory)                            ││
│  │           字节数组，小端序存储，虚拟地址寻址                  ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 程序寄存器编码表

Y86-64 有 **15 个 64 位通用寄存器**，每个寄存器用 **4 位编号**标识：

| 编号 (十六进制) | 寄存器 | 编号 (十六进制) |    寄存器    |
| :-------------: | :----: | :-------------: | :----------: |
|      `0x0`      | `%rax` |      `0x8`      |    `%r8`     |
|      `0x1`      | `%rcx` |      `0x9`      |    `%r9`     |
|      `0x2`      | `%rdx` |      `0xA`      |    `%r10`    |
|      `0x3`      | `%rbx` |      `0xB`      |    `%r11`    |
|      `0x4`      | `%rsp` |      `0xC`      |    `%r12`    |
|      `0x5`      | `%rbp` |      `0xD`      |    `%r13`    |
|      `0x6`      | `%rsi` |      `0xE`      |    `%r14`    |
|      `0x7`      | `%rdi` |      `0xF`      | **无寄存器** |

> [!IMPORTANT]
> 编号 `0xF` 表示"不使用寄存器"，用于指令编码中不需要某个寄存器操作数的情况（如 `irmovq` 的 rA 字段）。

**特殊用途寄存器**：
- `%rsp` (编号 `0x4`)：**栈指针**，指向栈顶
- `%rax` (编号 `0x0`)：通常用于**函数返回值**

### 2.3 条件码 (Condition Codes)

条件码是 3 个单比特标志，由 `OPq` 类算术/逻辑指令设置：

|  标志  |     名称      | 值为 1 的条件                         |
| :----: | :-----------: | :------------------------------------ |
| **ZF** |   Zero Flag   | 最近操作结果 **等于 0**               |
| **SF** |   Sign Flag   | 最近操作结果 **为负数**（最高位为 1） |
| **OF** | Overflow Flag | 最近操作导致**补码溢出**              |

**条件组合表**（用于条件跳转和条件传送）：

| 条件  |    含义    | 判断表达式         |
| :---: | :--------: | :----------------- |
| `le`  | ≤ (有符号) | `(SF ^ OF)         | ZF` |
|  `l`  | < (有符号) | `SF ^ OF`          |
|  `e`  |     =      | `ZF`               |
| `ne`  |     ≠      | `~ZF`              |
| `ge`  | ≥ (有符号) | `~(SF ^ OF)`       |
|  `g`  | > (有符号) | `~(SF ^ OF) & ~ZF` |

### 2.4 程序状态码 (Stat)

|  值   | 名称  | 描述                           |
| :---: | :---: | :----------------------------- |
|   1   | `AOK` | 正常运行                       |
|   2   | `HLT` | 执行了 `halt` 指令，处理器停止 |
|   3   | `ADR` | 遇到非法内存地址               |
|   4   | `INS` | 遇到非法/未定义指令            |

---

## 3. Y86-64 指令集

### 3.1 指令编码格式

每条 Y86-64 指令的**第一个字节**分为两个 4 位字段：

```
字节 0          字节 1         字节 2-9
┌─────┬─────┐  ┌─────┬─────┐  ┌────────────────────┐
│icode│ifun │  │ rA  │ rB  │  │   valC (8 bytes)   │
│高4位│低4位│  │高4位│低4位│  │   立即数/偏移量     │
└─────┴─────┘  └─────┴─────┘  └────────────────────┘
    必须            可选              可选
```

- **icode (指令代码)**：标识指令类型（0-0xB，每种对应一类指令）
- **ifun (功能代码)**：区分同一类型下的不同操作（如不同条件的跳转）
- **rA, rB**：寄存器编号字段（各 4 位）
- **valC**：8 字节立即数或内存偏移量（小端序存储）

### 3.2 完整指令编码表

| 指令               | icode | ifun  | 格式         | 字节数 | 描述          |
| :----------------- | :---: | :---: | :----------- | :----: | :------------ |
| `halt`             |  `0`  |  `0`  | `00`         | **1**  | 停止处理器    |
| `nop`              |  `1`  |  `0`  | `10`         | **1**  | 空操作        |
| **数据传送指令**   |       |       |              |        |
| `rrmovq rA, rB`    |  `2`  |  `0`  | `20 rA rB`   | **2**  | 寄存器→寄存器 |
| `cmovle rA, rB`    |  `2`  |  `1`  | `21 rA rB`   | **2**  | 条件传送 (≤)  |
| `cmovl rA, rB`     |  `2`  |  `2`  | `22 rA rB`   | **2**  | 条件传送 (<)  |
| `cmove rA, rB`     |  `2`  |  `3`  | `23 rA rB`   | **2**  | 条件传送 (=)  |
| `cmovne rA, rB`    |  `2`  |  `4`  | `24 rA rB`   | **2**  | 条件传送 (≠)  |
| `cmovge rA, rB`    |  `2`  |  `5`  | `25 rA rB`   | **2**  | 条件传送 (≥)  |
| `cmovg rA, rB`     |  `2`  |  `6`  | `26 rA rB`   | **2**  | 条件传送 (>)  |
| `irmovq V, rB`     |  `3`  |  `0`  | `30 F rB V`  | **10** | 立即数→寄存器 |
| `rmmovq rA, D(rB)` |  `4`  |  `0`  | `40 rA rB D` | **10** | 寄存器→内存   |
| `mrmovq D(rB), rA` |  `5`  |  `0`  | `50 rA rB D` | **10** | 内存→寄存器   |
| **整数运算指令**   |       |       |              |        |
| `addq rA, rB`      |  `6`  |  `0`  | `60 rA rB`   | **2**  | rB ← rB + rA  |
| `subq rA, rB`      |  `6`  |  `1`  | `61 rA rB`   | **2**  | rB ← rB - rA  |
| `andq rA, rB`      |  `6`  |  `2`  | `62 rA rB`   | **2**  | rB ← rB & rA  |
| `xorq rA, rB`      |  `6`  |  `3`  | `63 rA rB`   | **2**  | rB ← rB ^ rA  |
| **跳转指令**       |       |       |              |        |
| `jmp Dest`         |  `7`  |  `0`  | `70 Dest`    | **9**  | 无条件跳转    |
| `jle Dest`         |  `7`  |  `1`  | `71 Dest`    | **9**  | 跳转如果 ≤    |
| `jl Dest`          |  `7`  |  `2`  | `72 Dest`    | **9**  | 跳转如果 <    |
| `je Dest`          |  `7`  |  `3`  | `73 Dest`    | **9**  | 跳转如果 =    |
| `jne Dest`         |  `7`  |  `4`  | `74 Dest`    | **9**  | 跳转如果 ≠    |
| `jge Dest`         |  `7`  |  `5`  | `75 Dest`    | **9**  | 跳转如果 ≥    |
| `jg Dest`          |  `7`  |  `6`  | `76 Dest`    | **9**  | 跳转如果 >    |
| **过程调用**       |       |       |              |        |
| `call Dest`        |  `8`  |  `0`  | `80 Dest`    | **9**  | 调用函数      |
| `ret`              |  `9`  |  `0`  | `90`         | **1**  | 函数返回      |
| **栈操作**         |       |       |              |        |
| `pushq rA`         |  `A`  |  `0`  | `A0 rA F`    | **2**  | 压栈          |
| `popq rA`          |  `B`  |  `0`  | `B0 rA F`    | **2**  | 弹栈          |

> [!NOTE]
> - `F` 表示 `0xF`，即"无寄存器"
> - `V` 表示 8 字节立即数值
> - `D` 表示 8 字节偏移量
> - `Dest` 表示 8 字节目标地址

### 3.3 iaddq 指令（Part B 核心）

`iaddq` 是需要在 Part B 中实现的扩展指令，用于**将立即数加到寄存器**：

| 指令          | icode | ifun  | 格式        | 字节数 |
| :------------ | :---: | :---: | :---------- | :----: |
| `iaddq V, rB` |  `C`  |  `0`  | `C0 F rB V` | **10** |

**语义**：`rB ← rB + V`，同时设置条件码

**编码示例**：`iaddq $8, %rsp`
```
C0 F4 08 00 00 00 00 00 00 00
│  ││ └────────────────────┘
│  ││         立即数 8 (小端序)
│  │└── rB = 4 (%rsp)
│  └─── rA = F (无寄存器)
└────── icode:ifun = C:0
```

**iaddq 各阶段行为表**：

|    阶段    | iaddq V, rB                                                                        |
| :--------: | :--------------------------------------------------------------------------------- |
|  **取指**  | icode:ifun ← M₁[PC] = C:0<br>rA:rB ← M₁[PC+1]<br>valC ← M₈[PC+2]<br>valP ← PC + 10 |
|  **译码**  | valB ← R[rB]                                                                       |
|  **执行**  | valE ← valB + valC<br>设置 CC                                                      |
|  **访存**  | (无操作)                                                                           |
|  **写回**  | R[rB] ← valE                                                                       |
| **更新PC** | PC ← valP                                                                          |

### 3.4 指令编码规律总结

|  指令长度   | 组成                           | 适用指令                                   |
| :---------: | :----------------------------- | :----------------------------------------- |
| **1 字节**  | icode:ifun                     | `halt`, `nop`, `ret`                       |
| **2 字节**  | icode:ifun + rA:rB             | `rrmovq`, `cmovXX`, `OPq`, `pushq`, `popq` |
| **9 字节**  | icode:ifun + 8字节地址         | `jXX`, `call`                              |
| **10 字节** | icode:ifun + rA:rB + 8字节常数 | `irmovq`, `rmmovq`, `mrmovq`, `iaddq`      |

---

## 4. Y86-64 汇编语法

### 4.1 基本语法

```assembly
# 这是注释（以 # 开头）

.pos 0x0                    # 设置起始地址为 0x0
    irmovq stack, %rsp      # 初始化栈指针
    call main               # 调用 main 函数
    halt                    # 停止

main:
    # 函数代码...
    ret

.pos 0x200
stack:                      # 栈底位置
```

### 4.2 伪指令 (Directives)

| 伪指令   | 语法             | 描述                                 |
| :------- | :--------------- | :----------------------------------- |
| `.pos`   | `.pos <address>` | 设置后续代码/数据的起始地址          |
| `.align` | `.align <n>`     | 对齐到 n 字节边界（n 必须是 2 的幂） |
| `.quad`  | `.quad <value>`  | 定义一个 8 字节（64位）整数值        |
| `.byte`  | `.byte <value>`  | 定义一个 1 字节值                    |

**示例**：定义链表数据结构
```assembly
.align 8                    # 8 字节对齐
ele1:
    .quad 0x00a             # 元素值
    .quad ele2              # 指向下一个元素的指针
ele2:
    .quad 0x0b0
    .quad ele3
ele3:
    .quad 0xc00
    .quad 0                 # NULL 指针，链表结束
```

### 4.3 标签 (Labels)

- 标签以冒号 `:` 结尾
- 标签代表其后指令/数据的内存地址
- 可用于跳转目标、函数名、数据引用

```assembly
loop:                       # 定义标签 loop
    # 循环体...
    jne loop                # 跳转到 loop
```

---

## 5. 函数调用约定

### 5.1 参数传递

前 6 个整数/指针参数通过寄存器传递：

| 参数顺序 | 寄存器 |
| :------: | :----: |
| 第 1 个  | `%rdi` |
| 第 2 个  | `%rsi` |
| 第 3 个  | `%rdx` |
| 第 4 个  | `%rcx` |
| 第 5 个  | `%r8`  |
| 第 6 个  | `%r9`  |

- 第 7 个及以后的参数通过栈传递（逆序压栈）
- 返回值放在 `%rax` 中

### 5.2 寄存器保存约定

|              类型               | 寄存器                                                               |  责任方  |
| :-----------------------------: | :------------------------------------------------------------------- | :------: |
|  **Caller-saved** (调用者保存)  | `%rax`, `%rcx`, `%rdx`, `%rsi`, `%rdi`, `%r8`, `%r9`, `%r10`, `%r11` |  调用者  |
| **Callee-saved** (被调用者保存) | `%rbx`, `%rbp`, `%r12`, `%r13`, `%r14`                               | 被调用者 |
|           **栈指针**            | `%rsp`                                                               |   特殊   |

> [!IMPORTANT]
> **Callee-saved 寄存器**：如果函数要使用这些寄存器，必须在函数开始时保存（push）它们的值，并在返回前恢复（pop）。

### 5.3 栈帧结构

```
高地址
┌─────────────────────┐
│   调用者栈帧         │
├─────────────────────┤
│   返回地址           │ ← call 指令自动压入
├─────────────────────┤
│   保存的 %rbp (可选) │ ← 如果使用帧指针
├─────────────────────┤
│   保存的 callee-saved│
│   寄存器             │
├─────────────────────┤
│   局部变量           │
├─────────────────────┤ ← %rsp (栈顶)
低地址
```

### 5.4 函数示例

```assembly
# 函数 sum_list(list_ptr ls) - 对应 Part A
sum_list:
    pushq %rbx              # 保存 callee-saved 寄存器
    xorq %rax, %rax         # 返回值 val = 0
    jmp test

loop:
    mrmovq (%rdi), %rbx     # val_node = ls->val
    addq %rbx, %rax         # val += val_node
    mrmovq 8(%rdi), %rdi    # ls = ls->next

test:
    andq %rdi, %rdi         # 测试 ls != NULL
    jne loop

    popq %rbx               # 恢复 callee-saved 寄存器
    ret
```

---

## 6. SEQ 顺序处理器

### 6.1 六个执行阶段

```
┌────────┐   ┌────────┐   ┌─────────┐   ┌────────┐   ┌──────────┐   ┌───────────┐
│ Fetch  │ → │ Decode │ → │ Execute │ → │ Memory │ → │ Write    │ → │ PC Update │
│ 取指   │   │ 译码   │   │ 执行    │   │ 访存   │   │ Back     │   │ 更新PC    │
│        │   │        │   │         │   │        │   │ 写回     │   │           │
└────────┘   └────────┘   └─────────┘   └────────┘   └──────────┘   └───────────┘
```

### 6.2 各阶段信号详解

| 信号           | 含义                         | 产生阶段 |
| :------------- | :--------------------------- | :------- |
| `icode`        | 指令代码                     | Fetch    |
| `ifun`         | 功能代码                     | Fetch    |
| `rA`, `rB`     | 寄存器编号                   | Fetch    |
| `valC`         | 指令中的常数值               | Fetch    |
| `valP`         | 下一条指令地址 (PC+指令长度) | Fetch    |
| `valA`         | 从寄存器 rA 读取的值         | Decode   |
| `valB`         | 从寄存器 rB 读取的值         | Decode   |
| `srcA`, `srcB` | 源寄存器编号                 | Decode   |
| `dstE`, `dstM` | 目标寄存器编号               | Decode   |
| `valE`         | ALU 运算结果                 | Execute  |
| `Cnd`          | 条件码判断结果               | Execute  |
| `valM`         | 从内存读取的值               | Memory   |

### 6.3 各指令的阶段行为表

|      阶段      | OPq rA, rB                                             | rmmovq rA, D(rB)                                                           | mrmovq D(rB), rA                                                           | pushq rA                                               | popq rA                                                | call Dest                                             | ret                                |
| :------------: | :----------------------------------------------------- | :------------------------------------------------------------------------- | :------------------------------------------------------------------------- | :----------------------------------------------------- | :----------------------------------------------------- | :---------------------------------------------------- | :--------------------------------- |
|   **Fetch**    | icode:ifun ← M₁[PC]<br>rA:rB ← M₁[PC+1]<br>valP ← PC+2 | icode:ifun ← M₁[PC]<br>rA:rB ← M₁[PC+1]<br>valC ← M₈[PC+2]<br>valP ← PC+10 | icode:ifun ← M₁[PC]<br>rA:rB ← M₁[PC+1]<br>valC ← M₈[PC+2]<br>valP ← PC+10 | icode:ifun ← M₁[PC]<br>rA:rB ← M₁[PC+1]<br>valP ← PC+2 | icode:ifun ← M₁[PC]<br>rA:rB ← M₁[PC+1]<br>valP ← PC+2 | icode:ifun ← M₁[PC]<br>valC ← M₈[PC+1]<br>valP ← PC+9 | icode:ifun ← M₁[PC]<br>valP ← PC+1 |
|   **Decode**   | valA ← R[rA]<br>valB ← R[rB]                           | valA ← R[rA]<br>valB ← R[rB]                                               | valB ← R[rB]                                                               | valA ← R[rA]<br>valB ← R[%rsp]                         | valA ← R[%rsp]<br>valB ← R[%rsp]                       | valB ← R[%rsp]                                        | valA ← R[%rsp]<br>valB ← R[%rsp]   |
|  **Execute**   | valE ← valB OP valA<br>Set CC                          | valE ← valB + valC                                                         | valE ← valB + valC                                                         | valE ← valB + (-8)                                     | valE ← valB + 8                                        | valE ← valB + (-8)                                    | valE ← valB + 8                    |
|   **Memory**   | —                                                      | M₈[valE] ← valA                                                            | valM ← M₈[valE]                                                            | M₈[valE] ← valA                                        | valM ← M₈[valA]                                        | M₈[valE] ← valP                                       | valM ← M₈[valA]                    |
| **Write Back** | R[rB] ← valE                                           | —                                                                          | R[rA] ← valM                                                               | R[%rsp] ← valE                                         | R[%rsp] ← valE<br>R[rA] ← valM                         | R[%rsp] ← valE                                        | R[%rsp] ← valE                     |
| **PC Update**  | PC ← valP                                              | PC ← valP                                                                  | PC ← valP                                                                  | PC ← valP                                              | PC ← valP                                              | PC ← valC                                             | PC ← valM                          |

---

## 7. PIPE 流水线处理器

### 7.1 流水线概述

流水线将指令执行分为多个阶段，允许**多条指令同时在不同阶段执行**：

```
时钟周期:    1     2     3     4     5     6     7     8
指令 1:    [F]   [D]   [E]   [M]   [W]
指令 2:          [F]   [D]   [E]   [M]   [W]
指令 3:                [F]   [D]   [E]   [M]   [W]
指令 4:                      [F]   [D]   [E]   [M]   [W]
```

**优势**：提高**吞吐量 (throughput)**，理想情况下每个时钟周期完成一条指令

### 7.2 流水线冒险 (Hazards)

#### 7.2.1 数据冒险 (Data Hazards)

当一条指令依赖于前面指令的结果时发生：

```assembly
irmovq $10, %rax      # 写 %rax
addq %rax, %rbx       # 读 %rax ← 依赖！
```

**类型**：
- **RAW (Read After Write)**：后一条指令读取前一条指令要写的值
- **WAR (Write After Read)**：后一条指令写入前一条指令要读的位置
- **WAW (Write After Write)**：两条指令都要写同一位置

#### 7.2.2 控制冒险 (Control Hazards)

当遇到改变程序流程的指令时发生：

```assembly
jne target            # 条件跳转，目标地址可能要到 Execute 才确定
addq %rax, %rbx       # 这条指令应该执行吗？
```

### 7.3 冒险解决方案

| 技术                  | 描述                                           | 适用场景           |
| :-------------------- | :--------------------------------------------- | :----------------- |
| **转发 (Forwarding)** | 将结果从产生阶段直接传递到需要的阶段，不等写回 | 大多数数据冒险     |
| **暂停 (Stalling)**   | 暂时停止流水线，等待数据就绪                   | Load-Use 冒险      |
| **气泡 (Bubble)**     | 插入空操作，相当于 NOP                         | 控制冒险、Load-Use |
| **分支预测**          | 预测跳转是否发生，投机执行                     | 控制冒险           |

#### 7.3.1 Load-Use 冒险示例

```assembly
mrmovq 0(%rax), %rbx  # Cycle 1: Fetch, Cycle 4: Memory 读取数据
addq %rbx, %rcx       # Cycle 2: Fetch, Cycle 3: Decode 需要 %rbx
                      # 数据还没准备好！需要暂停 1 个周期
```

**解决方案**：插入一个 bubble（暂停一个周期），让 `mrmovq` 完成内存访问

#### 7.3.2 转发路径

```
Execute 阶段的 valE ──┬──→ Decode 阶段的 valA/valB
                      │
Memory 阶段的 valE  ──┤
Memory 阶段的 valM  ──┘
```

### 7.4 PIPE 流水线寄存器

```
F_reg → D_reg → E_reg → M_reg → W_reg
 │        │        │        │        │
Fetch  Decode  Execute  Memory  WriteBack
```

每个流水线寄存器保存当前阶段的所有状态信息。

---

## 8. HCL 硬件控制语言

### 8.1 HCL 概述

HCL (Hardware Control Language) 用于描述处理器控制逻辑，被 `hcl2c` 转换为 C 代码进行模拟。

### 8.2 数据类型

| 类型           | 描述            | 示例             |
| :------------- | :-------------- | :--------------- |
| `bool`         | 布尔值 (0 或 1) | 条件码、控制信号 |
| `int` / `word` | 64 位整数       | 寄存器值、地址   |

### 8.3 信号声明

```hcl
# 布尔信号声明
boolsig need_regids 'need_regids'
boolsig need_valC   'need_valC'

# 字级信号声明
wordsig icode 'icode'
wordsig ifun  'ifun'
wordsig valA  'valA'
wordsig valC  'valC'
```

### 8.4 布尔表达式

```hcl
# 与、或、非
bool instr_valid = icode in { INOP, IHALT, IRRMOVQ, ... };

# 条件组合
bool need_regids = icode in { IRRMOVQ, IOPQ, IPUSHQ, IPOPQ, 
                               IIRMOVQ, IRMMOVQ, IMRMOVQ };
```

### 8.5 Case 表达式（多路选择器/MUX）

```hcl
# 语法：[ condition1 : value1; condition2 : value2; ... ; 1 : default_value ]

word aluA = [
    icode in { IRRMOVQ, IOPQ } : valA;
    icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ } : valC;
    icode in { ICALL, IPUSHQ } : -8;
    icode in { IRET, IPOPQ } : 8;
    1 : 0;  # 默认值
];
```

> [!TIP]
> Case 表达式按**从上到下**的顺序匹配，第一个满足条件的值被选中。最后的 `1 : default_value` 是默认情况。

### 8.6 iaddq 的 HCL 修改示例

要在 SEQ 处理器中支持 `iaddq`，需要修改以下信号：

```hcl
# 1. instr_valid - 添加 IIADDQ
bool instr_valid = icode in 
    { INOP, IHALT, IRRMOVQ, IIRMOVQ, IRMMOVQ, IMRMOVQ,
      IOPQ, IJXX, ICALL, IRET, IPUSHQ, IPOPQ, IIADDQ };

# 2. need_regids - iaddq 需要寄存器字节
bool need_regids = icode in 
    { IRRMOVQ, IOPQ, IPUSHQ, IPOPQ, IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ };

# 3. need_valC - iaddq 需要立即数
bool need_valC = icode in 
    { IIRMOVQ, IRMMOVQ, IMRMOVQ, IJXX, ICALL, IIADDQ };

# 4. srcB - 从 rB 读取
word srcB = [
    icode in { IOPQ, IRMMOVQ, IMRMOVQ, IIADDQ } : rB;
    # ...
];

# 5. dstE - 写回到 rB
word dstE = [
    icode in { IRRMOVQ } && Cnd : rB;
    icode in { IIRMOVQ, IOPQ, IIADDQ } : rB;
    # ...
];

# 6. aluA - ALU 输入 A 使用 valC
word aluA = [
    icode in { IRRMOVQ, IOPQ } : valA;
    icode in { IIRMOVQ, IRMMOVQ, IMRMOVQ, IIADDQ } : valC;
    # ...
];

# 7. aluB - ALU 输入 B 使用 valB
word aluB = [
    icode in { IOPQ, IRMMOVQ, IMRMOVQ, IIADDQ } : valB;
    # ...
];

# 8. set_cc - iaddq 设置条件码
bool set_cc = icode in { IOPQ, IIADDQ };
```

---

## 9. 性能优化技术

### 9.1 CPE (Cycles Per Element)

$$CPE = \frac{总周期数 (C)}{元素数量 (N)}$$

- **目标**：尽可能降低 CPE
- **基准版本 `ncopy`**：CPE ≈ 15.18
- **Part C 目标**：CPE < 9.00（最优 ≈ 7.48）

### 9.2 循环展开 (Loop Unrolling)

**原理**：每次循环迭代处理多个元素，减少循环控制开销

**示例**（2x 展开）：
```assembly
# 原始循环：每次处理 1 个元素
Loop:
    mrmovq (%rdi), %r10
    rmmovq %r10, (%rsi)
    # ... 处理 1 个元素 ...
    irmovq $8, %r8
    addq %r8, %rdi
    addq %r8, %rsi
    jg Loop

# 2x 展开：每次处理 2 个元素
Loop2:
    mrmovq (%rdi), %r10
    mrmovq 8(%rdi), %r11
    rmmovq %r10, (%rsi)
    rmmovq %r11, 8(%rsi)
    # ... 处理 2 个元素 ...
    irmovq $16, %r8
    addq %r8, %rdi
    addq %r8, %rsi
    jg Loop2
```

### 9.3 使用 iaddq 指令

**优化前**：
```assembly
irmovq $8, %r10       # 2 字节，需要 10 字节机器码
addq %r10, %rdi       # 2 字节
```

**优化后**：
```assembly
iaddq $8, %rdi        # 1 条指令，10 字节机器码
```

### 9.4 减少 Load-Use 冒险

**问题代码**：
```assembly
mrmovq (%rdi), %r10   # 读取内存
rmmovq %r10, (%rsi)   # 立即使用 → 需要暂停！
```

**优化代码**：
```assembly
mrmovq (%rdi), %r10   # 读取内存
mrmovq 8(%rdi), %r11  # 读取下一个元素，填充等待时间
rmmovq %r10, (%rsi)   # 现在 %r10 已经准备好
rmmovq %r11, 8(%rsi)
```

### 9.5 优化策略总结

| 策略           | 效果             | 适用场景  |
| :------------- | :--------------- | :-------- |
| 循环展开       | 减少循环控制开销 | Part C    |
| 使用 `iaddq`   | 减少指令数量     | Part B, C |
| 指令重排       | 避免流水线暂停   | Part C    |
| 条件传送       | 避免分支预测失败 | 条件计数  |
| 充分利用寄存器 | 减少内存访问     | 通用      |

### 9.6 ncopy 优化示例框架

```assembly
ncopy:
    # 对于大数组，使用展开循环
    # 对于剩余元素，使用简单循环

    iaddq $-8, %rdx         # len -= 8 (如果使用 8x 展开)
    jl Remain               # 如果 len < 8，跳到处理剩余

Loop8:
    # 处理 8 个元素...
    mrmovq (%rdi), %r8
    mrmovq 8(%rdi), %r9
    mrmovq 16(%rdi), %r10
    # ... 更多读取 ...
    
    rmmovq %r8, (%rsi)
    rmmovq %r9, 8(%rsi)
    rmmovq %r10, 16(%rsi)
    # ... 更多写入 ...
    
    # 检查正数并计数...
    
    iaddq $64, %rdi
    iaddq $64, %rsi
    iaddq $-8, %rdx
    jge Loop8

Remain:
    iaddq $8, %rdx          # 恢复 len
    # 处理剩余 0-7 个元素...
    
Done:
    ret
```

---

## 10. Y86-64 开发工具

| 工具    | 命令示例                 | 功能                              |
| :------ | :----------------------- | :-------------------------------- |
| `yas`   | `./yas sum.ys`           | 汇编器：`.ys` → `.yo`             |
| `yis`   | `./yis sum.yo`           | 指令集模拟器，显示寄存器/内存变化 |
| `ssim`  | `./ssim -t sum.yo`       | SEQ 处理器模拟器                  |
| `psim`  | `./psim -g driver.yo`    | PIPE 流水线处理器模拟器           |
| `hcl2c` | `./hcl2c < seq-full.hcl` | HCL → C 翻译器                    |

### 10.1 常用命令

```bash
# 编译汇编文件
./yas sum.ys

# 使用指令集模拟器测试
./yis sum.yo

# 使用 SEQ 模拟器测试 (TTY 模式)
./ssim -t sum.yo

# 使用 SEQ 模拟器测试 (GUI 模式)
./ssim -g sum.yo

# 构建带有 iaddq 的 SEQ 模拟器
make VERSION=full

# 运行回归测试
cd ../ptest && make SIM=../seq/ssim TFLAGS=-i

# 测试 ncopy 正确性
./correctness.pl

# 测试 ncopy 性能
./benchmark.pl
```

---

## 参考资料

- Bryant, R. E., & O'Hallaron, D. R. (2015). *Computer Systems: A Programmer's Perspective* (3rd ed.). Pearson.
- CS:APP 官方网站: http://csapp.cs.cmu.edu
- Y86-64 Processor Simulators Guide: `simguide.pdf`
