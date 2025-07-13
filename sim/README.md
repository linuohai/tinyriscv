# TinyRISCV 仿真测试

这个目录包含了TinyRISCV处理器的各种测试用例和仿真脚本。

## 可用的测试

### 1. UART Debug 测试
测试UART调试功能，验证程序下载和执行。

```bash
python run_tb.py uart_debug
```

### 2. I2C 温度传感器测试
测试I2C接口功能，验证扩展指令`INST_temp`的实现。

```bash
python run_tb.py i2c
```

## 脚本说明

- `run_tb.py` - 统一的测试运行脚本（推荐使用）
- `run_uart_debug_tb.py` - 原有的UART debug测试脚本（已不推荐）

## 使用方法

### 基本命令

```bash
# 查看帮助
python run_tb.py

# 运行特定测试
python run_tb.py <testbench_type>

# 生成波形文件提示
python run_tb.py <testbench_type> --wave
```

### 示例

```bash
# 运行I2C测试
python run_tb.py i2c

# 运行I2C测试并查看波形
python run_tb.py i2c --wave
gtkwave i2c_tb.vcd

# 运行UART debug测试
python run_tb.py uart_debug
```

## 环境要求

- Icarus Verilog (`iverilog`)
- Python 3.x
- GTKWave（用于查看波形文件）

## 文件结构

```
sim/
├── run_tb.py                 # 统一测试脚本
├── run_uart_debug_tb.py      # 原UART debug脚本  
├── README.md                 # 本文件
└── (生成的仿真文件)
    ├── *.vcd                 # 波形文件
    ├── uart_debug_tb         # 编译的仿真可执行文件
    └── i2c_tb                # 编译的仿真可执行文件
```

## 测试程序

测试程序位于 `tests/example/` 目录下：

- `I2C_test/` - I2C温度传感器测试程序
- `Temp/` - 温度读取测试程序  

## 故障排除

1. **编译错误**: 检查Icarus Verilog是否正确安装
2. **找不到文件**: 确保在正确的目录下运行脚本
3. **波形文件无法打开**: 检查GTKWave是否安装

## 添加新测试

要添加新的testbench：

1. 在 `tb/` 目录下创建新的testbench文件
2. 在 `run_tb.py` 的 `get_source_files()` 函数中添加新的测试类型
3. 更新 `choices` 列表和帮助文档

# compile_rtl.py

编译rtl代码。

使用方法：

`python compile_rtl.py [rtl目录相对路径]`

比如：

`python compile_rtl.py ..`

# sim_new_nowave.py

对指定的bin文件(重新生成inst.data文件)进行测试。

使用方法：

windows系统下：

`python sim_new_nowave.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data`

Linux系统下：

`python sim_new_nowave.py ../tests/isa/generated/rv32ui-p-add.bin inst.data`

# sim_default_nowave.py

对已经存在的inst.data文件进行测试。

使用方法：

`python sim_default_nowave.py`

# test_all_isa.py

一次性测试../tests/isa/generated目录下的所有指令。

使用方法：

`python test_all_isa.py`

