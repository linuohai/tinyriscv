#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import platform

def main():
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
    
    # 构建源文件路径列表
    source_files = [
        "../tb/uart_debug_tb.v",
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
    
    # 修正Windows路径分隔符
    if platform.system() == "Windows":
        source_files = [f.replace("/", os.path.sep) for f in source_files]
    
    # 指定包含路径，修复找不到defines.v的问题
    include_paths = [
        "-I../rtl/core",
        "-I../tb"
    ]
    
    if platform.system() == "Windows":
        include_paths = [p.replace("/", os.path.sep) for p in include_paths]
    
    # 编译命令 - 添加include路径
    compile_cmd = ["iverilog", "-o", "uart_debug_tb"] + include_paths + source_files
    
    try:
        # 执行编译
        print("编译testbench和相关模块...")
        print("执行命令: " + " ".join(compile_cmd))
        subprocess.run(compile_cmd, check=True)
        
        # 运行仿真
        print("运行仿真...")
        subprocess.run(["vvp", "uart_debug_tb"], check=True)
        
        # 检查波形文件
        if os.path.exists("uart_debug_tb.vcd"):
            print("生成了波形文件 uart_debug_tb.vcd")
            print("可以使用命令 'gtkwave uart_debug_tb.vcd' 查看波形")
            
        print("仿真完成")
        
    except subprocess.CalledProcessError as e:
        print(f"错误: 执行命令失败: {e}")
        return 1
    except Exception as e:
        print(f"错误: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    # 在Windows中等待用户按键退出
    ret = main()
    if platform.system() == "Windows":
        input("按回车键退出...")
    sys.exit(ret)