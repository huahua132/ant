Ant 游戏引擎
=====

Ant 是由灵犀互娱开发的开源游戏引擎。现阶段仅将代码仓库公开，尚未正式发布。文档、示例等均待在 [Wiki](https://github.com/ejoy/ant/wiki) 上逐步完善。如有任何问题，可在 [Discussions](https://github.com/ejoy/ant/discussions) 发帖讨论。Issues 仅用于 Bug 跟踪，请不要在里面提问题。

### 更新并初始化第三方库：

> git submodule update --init

### 搭建编译环境

#### MSVC
- 安装Visual Studio

#### MINGW
- 下载并安装[msys2](https://www.msys2.org/)

- 修改镜像服务器
``` bash
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/i686/" > /etc/pacman.d/mirrorlist.mingw32
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/x86_64/" > /etc/pacman.d/mirrorlist.mingw64
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/\$arch/" > /etc/pacman.d/mirrorlist.msys
```

- 把ming64的路径加到环境变量
``` bash
echo "export MINGW=/mingw64" >> ~/.bash_profile
echo "export PATH=\$MINGW/bin:\$PATH" >> ~/.bash_profile
```

- 安装gcc/ninja
``` bash
pacman -Syu mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja
```

#### MACOS
- 安装xcode, ninja


### 编译

#### 编译构建工具 luamake

``` bash
git clone https://github.com/actboy168/luamake
cd luamake
git submodule update --init
.\compile\install.bat (msvc)
./compile/install.sh (mingw/linux/macos)
```

#### 编译runtime

``` bash
luamake
```

#### 编译tools

``` bash
luamake tools
```

#### 编译选项
``` bash
luamake [target] -mode [debug/release] #-mode默认是debug
```

### 运行
运行一个最简单的示例
``` bash
bin/msvc/debug/lua.exe test/simple/main.lua
```

### 启动编辑器

```bash
bin/msvc/debug/lua.exe tools/editor/main.lua
```

### 调试

- 安装VSCode；
- 安装**Lua Debug**插件；
- 添加调试配置到`.vscode/launch.json`
``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Debug",
            "luaexe": "${workspaceFolder}/bin/msvc/debug/lua.exe",
            "console": "integratedTerminal",
            "stopOnEntry": true,
            "outputCapture": [],
            "program": "test/simple/main.lua",
            "arg": []
        }
    ]
}
```

### 关于ant目录结构
- **bin**：编译结果，exe/dll/lib等
- **build**：编译的中间结果
- **clibs**：c/c++代码
- **engine**：引擎基础支持代码，包括包管理器、启动代码等
- **pkg**：引擎的各个功能包（包与包之间有依赖）
- **runtime**：引擎运行时的不同平台支持
- **test**：测试工程
- **tools**：引擎相关的工具
