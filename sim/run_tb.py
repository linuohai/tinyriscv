#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import platform
import argparse

def get_source_files(tb_type):
    """根据testbench类型返回相应的源文件列表"""
    
    # 公共的源文件
    common_files = [
        "../rtl/core/defines.v",
        "../rtl/soc/tinyriscv_soc_top.v",
        "../rtl/core/tinyriscv.v",
        "../rtl/core/ex.v",
        "../rtl/core/id.v",
        "../rtl/core/pc_reg.v",
        "../rtl/core/id_ex.v",
        "../rtl/core/ctrl.v",
        "../rtl/core/regs.v",
        "../rtl/core/if_id.v",
        "../rtl/core/div.v",
        "../rtl/core/clint.v",
        "../rtl/core/csr_reg.v",
        "../rtl/perips/rom.v",
        "../rtl/perips/ram.v",
        "../rtl/perips/uart.v",
        "../rtl/perips/gpio.v",
        "../rtl/perips/timer.v",
        "../rtl/perips/spi.v",
        "../rtl/perips/pwm.v",
        "../rtl/perips/I2C.v",
        "../rtl/debug/uart_debug.v",
        "../rtl/debug/jtag_top.v",
        "../rtl/debug/jtag_dm.v",
        "../rtl/debug/jtag_driver.v",
        "../rtl/utils/full_handshake_rx.v",
        "../rtl/utils/full_handshake_tx.v",
        "../rtl/utils/gen_buf.v",
        "../rtl/utils/gen_dff.v",
        "../rtl/core/rib.v"
    ]
    
    # 根据testbench类型添加特定的testbench文件
    if tb_type == "uart_debug":
        tb_file = "../tb/uart_debug_tb.v"
        output_name = "uart_debug_tb"
        source_files = [tb_file] + common_files
    elif tb_type == "i2c":
        tb_file = "../tb/i2c_tb.v"
        temp_sensor_file = "../tb/temp_sensor.v"  # 添加温度传感器模块
        output_name = "i2c_tb"
        source_files = [tb_file, temp_sensor_file] + common_files
    else:
        raise ValueError(f"Unsupported testbench type: {tb_type}")
    
    return source_files, output_name

def main():
    # 解析命令行参数
    parser = argparse.ArgumentParser(description='运行 TinyRISCV 仿真测试')
    parser.add_argument('testbench', 
                       choices=['uart_debug', 'i2c'], 
                       help='选择要运行的testbench类型')
    parser.add_argument('--wave', 
                       action='store_true', 
                       help='生成波形文件')
    
    args = parser.parse_args()
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # 设置工作目录为项目根目录
    os.chdir(os.path.join(script_dir, ".."))
    project_root = os.getcwd()
    
    # 创建仿真目录
    sim_dir = os.path.join(project_root, "sim")
    if not os.path.exists(sim_dir):
        os.makedirs(sim_dir)
    os.chdir(sim_dir)
    
    # 获取源文件列表
    try:
        source_files, output_name = get_source_files(args.testbench)
    except ValueError as e:
        print(f"错误: {e}")
        return 1
    
    # 修正Windows路径分隔符
    if platform.system() == "Windows":
        source_files = [f.replace("/", os.path.sep) for f in source_files]
    
    # 指定包含路径
    include_paths = [
        "-I../rtl/core",
        "-I../tb"
    ]
    
    if platform.system() == "Windows":
        include_paths = [p.replace("/", os.path.sep) for p in include_paths]
    
    # 编译命令
    compile_cmd = ["iverilog", "-o", output_name] + include_paths + source_files
    
    try:
        # 执行编译
        print(f"编译 {args.testbench} testbench 和相关模块...")
        print("执行命令: " + " ".join(compile_cmd))
        subprocess.run(compile_cmd, check=True)
        
        # 运行仿真
        print("运行仿真...")
        subprocess.run(["vvp", output_name], check=True)
        
        # 检查波形文件
        wave_file = f"{output_name}.vcd"
        if os.path.exists(wave_file):
            print(f"生成了波形文件 {wave_file}")
            if args.wave:
                print(f"可以使用命令 'gtkwave {wave_file}' 查看波形")
            
        print(f"{args.testbench} 仿真完成")
        
    except subprocess.CalledProcessError as e:
        print(f"错误: 执行命令失败: {e}")
        return 1
    except Exception as e:
        print(f"错误: {e}")
        return 1
    
    return 0

def print_usage():
    """打印使用说明"""
    print("使用方法:")
    print("  python run_tb.py uart_debug    # 运行UART debug测试")
    print("  python run_tb.py i2c           # 运行I2C测试")
    print("  python run_tb.py i2c --wave    # 运行I2C测试并提示查看波形")
    print("")
    print("可用的testbench类型:")
    print("  uart_debug : UART debug功能测试")
    print("  i2c        : I2C温度传感器测试")

if __name__ == "__main__":
    if len(sys.argv) == 1:
        print_usage()
        sys.exit(0)
    
    # 在Windows中等待用户按键退出
    ret = main()
    if platform.system() == "Windows":
        input("按回车键退出...")
    sys.exit(ret) 