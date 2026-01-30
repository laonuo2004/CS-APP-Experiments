本实验中，你需要实现一个简单的支持作业控制的Unix shell程序，目的是使你熟悉进程控制和信号处理的概念。

## 实验操作

用git获取实验初始文件：

1. 在虚拟桌面左边窗口的上方点击“GitLab”。
2. “点击复制”按钮，复制git仓库地址。
3. 关闭上述界面，在左边窗口的上方点击“更多”，选择“剪切板“。
4. 在剪切板中ctrl+v贴入git仓库地址。
5. 关闭上述界面，在命令行界面中输入下述命令，你要把http地址替换成你的仓库地址：

```bash
git clone http://172.16.2.166/2020302111371/expProject2026-674.git csapp-shlab
```

进入 *csapp-shlab* 目录，你就可以开始工作啦！

## 实验内容

1. 在 *tsh.c* 文件的最开始的注释中写上你的名字和学号。

```c
/* 
 * tsh - A tiny shell program with job control
 * 
 * <Put your name and student ID here>
 */
```

2. 在 *tsh.c* 文件中可以看到一个简单的Unix shell的功能框架。为了帮助你开始工作，我们已经实现了一些简单的功能。你的任务是完成下面列出的这些空函数。

- *eval*：主函数，分析和解释命令行
- *builtin_cmd*：识别和解释内置命令：*quit*，*fg*，*bg*和*jobs*
- *do_bgfg*：实现内置命令 *bg* 和 *fg*
- *waitfg*：等待一个前台作业结束
- *sigchld_handler*：捕获SIGCHILD信号
- *sigint_handler*：捕获SIGINT（*ctrl-c*）信号
- *sigtstp_handler*：捕获SIGTSTP（*ctrl-z*）信号

每次修改了 *tsh.c* 以后，都要用 *make* 重新编译它。要运行你的shell，就在命令行上输入：

```shell
linux>  ./tsh
tsh> [在此输入你的shell命令]
```

3. Unix shell概述

shell是一个交互式命令行解释器，代表用户运行程序。shell会不断输出提示符，等待 *stdin* 上的命令行输入，然后按照命令行内容的指示执行某些操作。

命令行是由空格分隔的一系列ASCII文本组成。命令行中的第一个单词是内置命令的名称或可执行文件的路径名，其余的单词是命令行参数。如果第一个单词是内置命令，那么shell会立即在当前进程中执行该命令。否则，这个词被认为是可执行程序的路径名。在这种情况下，shell会fork一个子进程，然后在子进程中加载和运行该程序。为解释一条命令行而创建的子进程统称为作业，通常，一个作业可以由多个子进程组成，子进程之间通过Unix pipe（管道）连接。

如果命令行以＆符号结尾，则作业将在后台运行，这意味着在打印提示符或者输入下一个命令行之前，shell不用等待上一个作业终止。否则，作业在前台运行，这意味着shell会等待上一个作业终止，然后才能等待下一个命令行。因此，在任何时候，最多只有一项工作可以在前台运行。但是，后台可以运行任意数量的作业。

比如，敲下面命令：

```shell
tsh> jobs
```

shell会执行内置 *job* 命令。输入

```shell
tsh> /bin/ls -l –d
```

在前台运行 *ls* 程序。通常shell会确保在程序开始执行主程序

```c
int main（int argc，char * argv []）
```

时，*argc* 和 *argv* 参数具有以下值：

- `argc == 3`,
- `argv[0] == "/bin/ls"`
- `argv[1]== "-l"`,
- `argv[2]== "-d"`.

或者，输入命令行

```shell
tsh> /bin/ls -l –d ＆
```

将会在后台运行 *ls* 程序。

Unix shell支持作业控制（job control）的概念，它允许用户在后台和前台之间来回切换作业，并改变作业中进程的进程状态（运行，暂停或终止）。键入 *ctrl-c* 会向前台作业中的每个进程发送SIGINT信号。SIGINT的默认操作是终止进程。类似地，键入 *ctrl-z* 会向前台作业中的每个进程发送SIGTSTP信号。SIGTSTP的默认操作是将进程置于暂停状态，直到它接收到SIGCONT信号被唤醒。Unix shell还提供支持作业控制的各种内置命令。比如：

- *job*：列出正在运行和已暂停的后台作业。
- *bg* <job>：将暂停的后台作业更改为运行状态的后台作业。
- *fg* <job>：将暂停或正在运行的后台作业更改为在前台运行。
- *kill* <job>：终止工作。

## 实验要求

你的tsh shell应该具有以下功能：

- 提示符应该是字符串“tsh>”。
- 用户键入的命令行应包含一个 *name* 和零个或多个参数，所有参数均由一个或多个空格分隔。如果 *name* 是一个内置命令，那么tsh应该立即处理它并等待下一个命令行。否则，tsh应该假设 *name* 是可执行文件的路径，它在一个新的子进程的上下文中加载并运行（在此上下文中，术语job指的就是这个新的子进程）。
- tsh不需要支持管道（|）或I/O重定向（<和>）。
- 键入 *ctrl-c*（*ctrl-z*）应该使SIGINT（SIGTSTP）信号发送到当前前台作业以及该作业的任何后代（例如，它产生的任何子进程）。如果没有前台作业运行，那么信号不会产生影响。
- 如果命令行以＆符号结束，则tsh应在后台运行该作业。否则应该在前台运行该作业。
- 每个作业都可以通过进程ID（PID）或作业ID（JID）来标识，JID是由tsh分配的正整数。 应在命令行上用前缀'％'表示JID。例如，“％5”表示JID 5，“5”表示PID 5（我们为你提供了管理作业列表所需的所有例程。）
- tsh应支持以下内置命令：
    - *quit* 终止shell。
    - *jobs* 列出所有后台作业。
    - *bg* <job> 通过发送SIGCONT信号重新启动 <job>，然后在后台运行它。<job> 参数可以是PID或JID。
    - *fg* <job> 通过发送一个SIGCONT信号重新启动 <job>，然后在前台运行它。<job> 参数可以是PID或JID。
- tsh应回收所有的僵尸子进程。如果任何作业因收到未捕获的信号而终止，则tsh应识别此事件并打印带有该作业的PID和有问题信号的描述信息。

## 检查你的答案

我们提供了几个检查你的答案的工具。

**参考shell实现** *tshref* 是实验要求的shell的参考实现。
如果不确定正确的行为，可以运行这个程序作为参考。
你的shell应该与其具有完全相同的输出（除了PID，PID每次运行都可能不同）。

**shell驱动程序** *sdriver.pl* 运行shell作为子进程，根据trace文件向它发送信号、输入命令，捕获输出。
用 *-h* 参数查看 *sdriver.pl* 的用法。

共有16个trace文件供 *sdriver.pl* 使用，可以测试你的shell的正确性。
序号小的文件测试简单的功能，高序号的会进行更复杂的测试。

你可以使用（比如）*trace01.txt* 运行驱动程序：

```console
linux> ./sdriver.pl -t trace01.txt -s ./tsh -a "-p"
```

（`-a "-p"` 参数告诉你的shell不输出提示符）

或者

```console
linux> make rtest01
```

类似地，运行 *tshref*：

```console
linux> ./sdriver.pl -t trace01.txt -s ./tshref -a "-p"
```

或者

```console
linux> make rtest01
```

*tshref.out* 给出了参考答案在所有trace下的输出，方便对比。

另外 *checktsh.pl* 可用于从 *trace01.txt* 开始逐个运行并对比你的shell和 *tshref*。

## 提示

- 阅读书第八章的每一个字。
- 使用trace文件来驱动你的开发。
  从 *trace01.txt* 开始，确保输出一样再针对下一个trace编写代码。
- 以下函数会非常有用：*waitpid*, *kill*, *fork*, *execve*, *setpgid*, *sigprocmask*。
  *waitpid* 的选项 *WUNTRACED* 和 *WNOHANG* 也会很有用。
- 注意发送信号时要发送给整个进程组而不要只发送给某一进程。
  *sdriver.pl* 会检查这一点。
- 注意处理 *addjob* 与 *sigchldhandler* 等的竞争。
- *more*, *less*, *vi* 和 *emacs* 这类程序会对终端做奇怪的设置。
  不要从你的shell中运行这类程序。
  运行简单的文本程序，如 `/bin/ls`，`/bin/ps` 和 `/bin/echo`。
- 当你从一个标准Unix shell中运行你的shell时，你的shell处在一个前台进程组中。
  如果你的shell创建了子进程，该进程默认也在同一个进程组中。
  因为输入 *ctrl-c* 会向前台进程组的每一个进程发送SIGINT，*ctrl-c* 会向你的Shell和每一个它的子进程发送SIGINT，这显然是不对的。

  这里是一个解决方法：*fork* 后 *execve* 前，子进程应该调用 *setpgid(0, 0)*，把子进程放入新的进程组，这个进程组号和子进程的PID一致。
  这样就可以保证永远只有你的shell在标准Unix Shell的前台进程组中。
  当输入 *ctrl-c* 时，你的shell应该捕捉SIGINT并转发给合适的前台进程组。

&nbsp;

## 自动评测

把 *tsh.c* 放到桌面上。

```shell
linux> cp ./tsh.c ~/Desktop
```

再点击 **自动评测** 即可。

评测脚本会运行与你使用的同样的16个trace，每个正确的trace记6.25分，总分100分。

评测时间可能会较长，但不会超过5分钟。

最终分数会四舍五入至整数.

## 代码存档

在所有的实验完成之后，在本地代码仓库所在目录下输入：

```javascript
git add tsh.c
git commit -m "final version"
git push -u origin master
```

在第一次执行 `git commit` 时还要设置邮箱和姓名：

![](README/653ll1645239540.jpg)

虚拟桌面左侧窗口中点击”GitLab“按钮，点击”提交GitLab仓库“按钮：

![](README/653ll1644843390.png)

完成代码提交存档。
