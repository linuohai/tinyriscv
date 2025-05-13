`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

// UART Debug Testbench
module uart_debug_tb;

    // 参数化设置
    parameter PACKET_DATA_SIZE = 32;  // 每个包的数据大小（字节）
    parameter FIRST_PACKET_CRC0_INDEX = 129; // CRC低字节索引
    parameter FIRST_PACKET_CRC1_INDEX = 130; // CRC高字节索引
    parameter FILE_SIZE_INDEX = 28;     // 第一个包中文件大小字段索引
    parameter BAUD_PERIOD = 8680;       // 115200波特率下的位周期(ns)
    parameter TEST_FILE = "inst.data";   // 测试文件名
    parameter MAX_ROM_SIZE = 256;      // 最大ROM大小(字)

    reg clk;
    reg rst;
    reg uart_debug_pin;  // uart debug使能信号

    // UART Tx/Rx信号
    wire uart_tx_pin; 
    reg uart_rx_pin;
    
    // 用于各种任务和循环的整数变量
    integer i, j, k, p, addr;
    reg verify_ok;
    
    // 文件处理相关
    integer file_size_bytes;       // 文件大小(字节)
    integer packet_count;          // 包的数量
    
    // 仿真ROM数据，直接使用$readmemh读取
    reg [31:0] rom_init_data[0:MAX_ROM_SIZE-1];  // 十六进制文件数据
    
    // 期望的ROM数据，用于比较
    reg [31:0] expected_rom_data[0:MAX_ROM_SIZE-1]; 
    
    // 数据包和CRC
    reg [7:0] packet_data[0:PACKET_DATA_SIZE-1];
    reg [15:0] packet_crc;
    
    // CRC计算用临时变量
    reg [15:0] temp_crc;
    integer pos, bit_index;

    // 字节缓冲区，用于构建数据包
    reg [7:0] byte_buffer[0:MAX_ROM_SIZE*4-1];  // 每个字4个字节

    // 时钟信号，50MHz
    always #10 clk = ~clk;  

    // 监控ROM中的内容
    wire [31:0] rom_data[0:MAX_ROM_SIZE-1]; 
    genvar gi;
    generate
        for (gi = 0; gi < MAX_ROM_SIZE; gi = gi + 1) begin : ROM_MONITOR
            assign rom_data[gi] = tinyriscv_soc_top_0.u_rom._rom[gi];
        end
    endgenerate
    
    // 模拟串口发送一个字节
    task uart_send_byte;
        input [7:0] data;
        integer bit_idx; // 添加局部变量
        begin
            // 起始位 (低电平)
            uart_rx_pin = 1'b0;
            #(BAUD_PERIOD);

            // 数据位 (低位在前)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx_pin = data[bit_idx];
                #(BAUD_PERIOD);
            end

            // 停止位 (高电平)
            uart_rx_pin = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask

    // 验证ROM内容
    task verify_rom_data;
        input integer words_to_check;
        output reg result;
        begin
            result = 1'b1;
            for (addr = 0; addr < words_to_check && addr < MAX_ROM_SIZE; addr = addr + 1) begin
                if (rom_data[addr] !== expected_rom_data[addr]) begin
                    $display("ROM Verification Failed at Address 0x%h: Expected = 0x%h, Actual = 0x%h", 
                             addr*4, expected_rom_data[addr], rom_data[addr]);
                    result = 1'b0;
                end
            end
            
            if (result) begin
                $display("ROM Verification Successful! All %0d words match expected values", words_to_check);
            end
        end
    endtask
    
    // UART接收字节任务
    task uart_receive_byte;
        output [7:0] data;
        integer bit_idx;
        begin
            data = 8'h00;
            
            // 等待起始位（低电平）
            // @(negedge uart_tx_pin);
            #(BAUD_PERIOD/2); // 等待半个位时间，到达起始位中间
            
            // 确认是起始位
            if (uart_tx_pin != 1'b0) begin
                $display("Error: Invalid UART start bit");
            end else begin
                #(BAUD_PERIOD); // 等待到第一个数据位中间
                
                // 接收8个数据位
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    data[bit_idx] = uart_tx_pin; // 低位在前
                    #(BAUD_PERIOD);
                end
                
                // 检查停止位（高电平）
                if (uart_tx_pin != 1'b1) begin
                    $display("Error: Invalid UART stop bit");
                end
            end
        end
    endtask
    
    // UART接收并显示字符串，设置固定接收10个字符后结束
    task receive_uart_output;
        input integer timeout_cycles;
        reg [7:0] rx_byte;
        integer timeout_counter;
        integer char_counter;    // 计数收到的字符
        parameter MAX_CHARS = 10;  // 设置为固定接收10个字符
        begin
            timeout_counter = 0;
            char_counter = 0;
            $display("Waiting for UART output (will stop after %0d chars)...", MAX_CHARS);
            
            while ((timeout_counter < timeout_cycles) && (char_counter < MAX_CHARS)) begin
                if (uart_tx_pin == 1'b0) begin  // 检测到起始位
                    uart_receive_byte(rx_byte);
                    $write("%c", rx_byte);  // 打印字符
                    $fflush();  // 刷新输出
                    
                    char_counter = char_counter + 1;  // 增加字符计数
                    timeout_counter = 0;  // 重置超时计数器
                end else begin
                    #100;  // 等待100ns
                    timeout_counter = timeout_counter + 1;
                end
            end
            
            if (timeout_counter >= timeout_cycles) begin
                $display("\nUART reception timeout (received %0d of %0d chars)", char_counter, MAX_CHARS);
            end else if (char_counter >= MAX_CHARS) begin
                $display("\nUART reception completed - received all %0d chars", MAX_CHARS);
            end
        end
    endtask

    initial begin
        // 初始化信号
        clk = 0;
        rst = `RstEnable;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        
        // 初始化变量
        for (k = 0; k < MAX_ROM_SIZE; k = k + 1) begin
            expected_rom_data[k] = 32'h0;
            rom_init_data[k] = 32'h0;
        end

        // 直接读取十六进制文件到rom_init_data数组
        $readmemh(TEST_FILE, rom_init_data);
        
        // 计算有效数据的大小(字)
        file_size_bytes = 0;
        for (k = 0; k < MAX_ROM_SIZE; k = k + 1) begin
            if (rom_init_data[k] !== 32'h0) begin
                file_size_bytes = (k + 1) * 4; // 每个字是4字节
            end
        end
        
        // 确保至少有一个字的数据
        if (file_size_bytes == 0) begin
            file_size_bytes = 4;
        end
        
        // 将字数据转换为字节数组(小端序)
        for (k = 0; k < MAX_ROM_SIZE; k = k + 1) begin
            byte_buffer[k*4]   = rom_init_data[k][7:0];        // 最低字节
            byte_buffer[k*4+1] = rom_init_data[k][15:8];       // 次低字节
            byte_buffer[k*4+2] = rom_init_data[k][23:16];      // 次高字节
            byte_buffer[k*4+3] = rom_init_data[k][31:24];      // 最高字节
            
            // 同时设置期望值
            expected_rom_data[k] = rom_init_data[k];
        end
        
        // 计算所需包数
        packet_count = (file_size_bytes + PACKET_DATA_SIZE - 1) / PACKET_DATA_SIZE; // 向上取整
        
        $display("UART Debug Test Starting...");
        $display("Test file: %s, Size: %0d bytes, Packets needed: %0d", TEST_FILE, file_size_bytes, packet_count + 1); // +1表示包0
        
        // 复位释放
        #40
        rst = `RstDisable;
        #200
        
        // 激活UART Debug模块
        uart_debug_pin = 1'b1;
        #100
        
        // 准备第一个包数据 (包0-文件信息包)
        for (p = 0; p < PACKET_DATA_SIZE; p = p + 1) begin
            packet_data[p] = 8'h00; // 初始化为0
        end
        
        // 设置文件名 - 简单起见，使用硬编码字符
        packet_data[0] = "i";  // inst.data的"i"
        packet_data[1] = "n";  // 等等
        packet_data[2] = "s";
        packet_data[3] = "t";
        packet_data[4] = ".";
        packet_data[5] = "d";
        packet_data[6] = "a";
        packet_data[7] = "t";
        packet_data[8] = "a";
        
        // 文件大小
        packet_data[FILE_SIZE_INDEX]     = (file_size_bytes >> 24) & 8'hFF; // MSB
        packet_data[FILE_SIZE_INDEX + 1] = (file_size_bytes >> 16) & 8'hFF;
        packet_data[FILE_SIZE_INDEX + 2] = (file_size_bytes >> 8) & 8'hFF;
        packet_data[FILE_SIZE_INDEX + 3] = file_size_bytes & 8'hFF;         // LSB
        
        // 计算第一个包的CRC - 直接内联计算，不使用任务
        temp_crc = 16'hFFFF;
        for (pos = 0; pos < PACKET_DATA_SIZE; pos = pos + 1) begin
            temp_crc = temp_crc ^ packet_data[pos];
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if ((temp_crc & 16'h0001) != 0) begin
                    temp_crc = temp_crc >> 1;
                    temp_crc = temp_crc ^ 16'hA001;
                end else begin
                    temp_crc = temp_crc >> 1;
                end
            end
        end
        packet_crc = temp_crc;
        
        // 发送第一个包 (包0) - 不使用任务，直接内联发送
        $display("Sending packet #0");
        // 发送包序号
        uart_send_byte(8'h00);
        // 发送数据
        for (j = 0; j < PACKET_DATA_SIZE; j = j + 1) begin
            uart_send_byte(packet_data[j]);
        end
        // 发送CRC (低字节在前)
        uart_send_byte(packet_crc[7:0]);
        uart_send_byte(packet_crc[15:8]);
        // 等待处理时间
        #(100000);
        $display("Completed sending packet #0");
        
        // 发送剩余的数据包
        for (i = 0; i < packet_count; i = i + 1) begin
            // 准备包数据
            for (p = 0; p < PACKET_DATA_SIZE; p = p + 1) begin
                if ((i * PACKET_DATA_SIZE + p) < file_size_bytes) begin
                    packet_data[p] = byte_buffer[i * PACKET_DATA_SIZE + p];
                end else begin
                    packet_data[p] = 8'h00; // 填充0
                end
            end
            
            // 计算CRC - 直接内联计算，不使用任务
            temp_crc = 16'hFFFF;
            for (pos = 0; pos < PACKET_DATA_SIZE; pos = pos + 1) begin
                temp_crc = temp_crc ^ packet_data[pos];
                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    if ((temp_crc & 16'h0001) != 0) begin
                        temp_crc = temp_crc >> 1;
                        temp_crc = temp_crc ^ 16'hA001;
                    end else begin
                        temp_crc = temp_crc >> 1;
                    end
                end
            end
            packet_crc = temp_crc;
            
            // 发送包 - 直接内联发送，不使用任务
            $display("Sending packet %0d of %0d", i+1, packet_count);
            // 发送包序号
            uart_send_byte(8'h01 + i[7:0]);
            // 发送数据
            for (j = 0; j < PACKET_DATA_SIZE; j = j + 1) begin
                uart_send_byte(packet_data[j]);
            end
            // 发送CRC (低字节在前)
            uart_send_byte(packet_crc[7:0]);
            uart_send_byte(packet_crc[15:8]);
            // 等待处理时间
            #(100000);
            
            // 在for循环内部，发送完每个包后添加：
            $display("Completed sending packet %0d of %0d", i+1, packet_count);
        end
        
        // 在所有包发送完后添加：
        $display("All %0d packets sent, waiting for processing...", packet_count);
        
        // 等待足够时间让数据写入ROM
        #1000000
        
        // 关闭UART Debug模块
        uart_debug_pin = 1'b0;
        #100
        
        // 验证ROM内容 - 只检查有效字数
        verify_rom_data(file_size_bytes/4, verify_ok);
        
        if (verify_ok) begin
            $display("ROM verification successful, now resetting processor to run the program...");
            
            // 1. 重新复位核心
            rst = `RstEnable;
            #100
            rst = `RstDisable;
            #100
            
            // 2. 确保UART debug模式关闭
            uart_debug_pin = 1'b0;
            
            $display("Processor reset, UART Debug mode disabled, starting to receive UART output...");
            
            // 3. 接收SoC的UART输出信息
            receive_uart_output(10000000); // 设置足够长的超时周期来接收输出
            
            $display("~~~~~~~~~~~~~~~~~~~ UART DEBUG TEST PASS ~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
            $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ UART DEBUG TEST FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        end
        
        $finish;
    end

    // 模拟超时
    initial begin
        #200000000
        $display("Test Timeout! Possible issue detected.");
        $finish;
    end

    // 生成波形文件
    initial begin
        $dumpfile("uart_debug_tb.vcd");
        $dumpvars(0, uart_debug_tb);
    end

    // 实例化SoC顶层
    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin)
    );

endmodule 