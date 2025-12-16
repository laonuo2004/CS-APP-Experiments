# Y86-64 处理器实验

## 实验简介

本次作业作为第4章处理器体系结构的配套实验，以Y86-64顺序和流水线处理器仿真器为基础，对Y86-64处理器进行性能优化。具体优化内容包括以下几个方面：

- **第一部分（Part A）**：编写Y86-64简单程序，熟悉Y86-64工具
- **第二部分（Part B）**：扩展SEQ模拟器支持新的指令
- **第三部分（Part C）**：在前两部分的基础上，优化Y86-64基准测试程序和流水线处理器设计

## 提交要求

- 将主要实验步骤说明和截图记录进实验报告
- 提交实验报告文件格式：`学号姓名-Y86-64处理器实验.pdf`
- 同时按照实验指导中要求提交相关文件，例如 `hcl`、`ys` 等文件

## 附件

- `simguid.pdf` - Y86-64处理器模拟器使用指南
- `archlab.pdf` - Y86-64流水线性能优化实验指导
- `sim.tar` - Y86-64处理器模拟器源代码和测试程序

---

## 注意事项

### 环境依赖安装

实验材料中附带 `archlab.pdf`，按照文档一步步操作。`make` 时，可能会提示缺少相关依赖，安装如下软件即可：

```bash
sudo apt install tcl tcl-dev tk tk-dev
sudo apt install flex
sudo apt install bison
```

### Part B 编译问题解决

在 Part B 部分实验时，编译 `ssim` 的时候出现了很多问题：

#### 问题 1：缺少 tk.h 头文件

执行 `make VERSION=full` 时报错，提示不存在 `tk.h` 这个头文件，这是由于实验文件太老。

**解决方法**：修改 `Makefile`

- 第 20 行改为：
  ```makefile
  TKINC=-isystem /usr/include/tcl8.6
  ```

- 第 26 行改为：
  ```makefile
  CFLAGS=-Wall -O2 -DUSE_INTERP_RESULT
  ```

#### 问题 2：matherr 未定义引用

接下来还会报错：

```
/usr/bin/ld: /tmp/ccKTMI04.o:(.data.rel+0x0): undefined reference to `matherr'
collect2: error: ld returned 1 exit status
make: *** [Makefile:44: ssim] Error 1
```

这是因为较新版本的 glibc 弃用了这部分内容。

**解决方法**：注释掉以下文件中的相关行：
- `/sim/pipe/psim.c` 第 806、807 行
- `/sim/seq/ssim.c` 第 844、845 行

即：注释掉源代码中有 `matherr` 的一行和它的下一行。

然后就能编译成功，忽略 Warning 信息。

### Part C 编译问题解决

在 Part C 部分，编译 `psim` 时按照 Part B 部分同样修改即可通过 `make`。

### 杂项（misc）目录 Makefile 修改

另外，在原杂项（misc）目录下 `Makefile` 中以下两行：

```makefile
CFLAGS=-Wall -O1 -g
LCFLAGS=-O1
```

更新为以下两行：

```makefile
CFLAGS=-Wall -O1 -g -fcommon
LCFLAGS=-O1 -fcommon
```
