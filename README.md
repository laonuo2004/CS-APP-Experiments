# CS-APP-Experiments

北京理工大学 23 级计科大三计算机系统导论希冀实验

## 建议

1. 希冀的虚拟机很卡，体验不是很好。好在代码都是通过 Gitlab 同步的，推荐在自己电脑上用熟悉的环境进行实验，然后通过 Gitlab 同步到希冀的虚拟机上进行评测。
2. Windows 用户推荐使用 WSL 来完成实验，经测试，结果和希冀是一样的，而且由于各种 IDE 都集成了 WSL 终端，所以用起来更加方便。

---

## 关于乐学实验（Y86-64 处理器实验）的环境配置

> **注意**：由于实验代码较老，因此在编译和运行时会遇到一些问题。虽然[乐学](Exp.4_lexue/README.md)提供了一些解决方案，但是并不完整。这里记录了我的实际解决方案。

### 运行环境

- Windows 10 19045.6691 ([WSLg 要求 Windows 10 Build 19044+ 或 Windows 11](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps))
- Ubuntu 24.04.1 LTS
- Kernel: 6.6.87.2-microsoft-standard-WSL2 (WSLg 要求 WSL2)

### 安装相关的包

```bash
sudo apt install tcl tcl-dev tk tk-dev
sudo apt install flex
sudo apt install bison

```

### 编译问题修复

#### 1. 修复多重定义错误

```c
// sim/misc/yas.h
// 修改前（第 13 行）
int lineno;

// 修改后
extern int lineno;

// sim/misc/hcl.y
// 修改前（第 15 行）
FILE *outfile;

// 修改后
extern FILE *outfile;

// sim/pipe/sim.h
// 修改前（第 47 行）
pipe_ptr pc_state, if_id_state, id_ex_state, ex_mem_state, mem_wb_state;

// 修改后
extern pipe_ptr pc_state, if_id_state, id_ex_state, ex_mem_state, mem_wb_state;
```

#### 2. 修复 `matherr` 未定义引用错误

```c
// sim/pipe/psim.c (第 806-807 行)
// sim/seq/ssim.c (第 844-845 行)

// 修改前
/* Hack for SunOS */
extern int matherr();
int *tclDummyMathPtr = (int *) matherr;

// 修改后
/* Hack for SunOS */
/* extern int matherr(); */
/* int *tclDummyMathPtr = (int *) matherr; */
```

#### 3. 更新 Tcl/Tk 路径 (所有 `Makefile`)

```makefile
# sim/Makefile
# sim/pipe/Makefile
# sim/seq/Makefile

# 修改前
TKINC=-isystem /usr/include/tcl8.5

# 修改后
TKINC=-isystem /usr/include/tcl8.6 # 根据实际安装版本修改
```

#### 4. 添加编译标志

```makefile
# sim/pipe/Makefile
# sim/seq/Makefile

# 修改前
CFLAGS=-Wall -O2

# 修改后
CFLAGS=-Wall -O2 -DUSE_INTERP_RESULT
```

#### 5. 启用 GUI 模式

```makefile
# sim/Makefile
# 取消注释以启用 GUI
GUIMODE=-DHAS_GUI
```

### 编译

```bash
cd sim
make clean
make

```

如果一切正常，应该能够成功编译所有组件。

### 运行 GUI 界面

如果满足之前提到的环境条件的话，安装 WSL 的同时会附带 WSLg，因此不用额外配置就可以直接运行 GUI 界面。

```bash
# 顺序模拟器
cd sim/seq
./ssim -g ../y86-code/asum.yo

# 流水线模拟器
cd sim/pipe
./psim -g ../y86-code/asum.yo
```

**注意**：
- 必须使用 `-g` 参数才能启动 GUI 模式（默认是 TTY 模式）
- 必须提供 `.yo` 文件作为参数（GUI 模式必需）

如果 WSLg 不可用的话，可以改用 X11
