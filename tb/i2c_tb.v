`timescale 1 ns / 1 ns

`include "../rtl/core/defines.v"

// I2C Testbench with separate Temperature Sensor module
module i2c_tb;

    // 参数化设置 (从uart_debug_tb.v复制)
    parameter PACKET_DATA_SIZE = 32;  // 每个包的数据大小（字节）
    parameter FILE_SIZE_INDEX = 24;     // 第一个包中文件大小字段索引
    parameter BAUD_PERIOD = 8680;       // 115200波特率下的位周期(ns)
    parameter TEST_FILE = "inst.data";   // I2C测试文件名
    parameter MAX_ROM_SIZE = 256;      // 最大ROM大小(字)

    // 时钟和复位
    reg clk;
    reg rst;
    reg uart_debug_pin;

    // I2C信号
    wire io_scl;
    wire io_sda;
    pullup(io_sda);

    // UART信号
    wire uart_tx_pin;
    reg uart_rx_pin;

    // 测试控制信号
    integer i, j, k, p, addr;
    reg [7:0] received_data;
    reg test_pass;
    reg verify_ok;

    // 文件处理相关 (从uart_debug_tb.v复制)
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

    // 温度传感器参数
    parameter [15:0] EXPECTED_TEMP_DATA = 16'h1900;

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

    // 监控CPU执行状态
    wire cpu_halt = tinyriscv_soc_top_0.u_tinyriscv.u_ctrl.hold_flag_o != 2'b00;
    
    // 监控I2C数据有效信号
    wire i2c_data_valid = tinyriscv_soc_top_0.s7_data_valid_i;
    
    // 监控读取的I2C数据
    wire [31:0] i2c_read_data = tinyriscv_soc_top_0.s7_data_i;

    // 模拟串口发送一个字节 (从uart_debug_tb.v复制)
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

    // 验证ROM内容 (从uart_debug_tb.v复制)
    task verify_rom_data;
        input integer words_to_check;
        output reg result;
        begin
            result = 1'b1;
            for (addr = 0; addr < words_to_check && addr < MAX_ROM_SIZE; addr = addr + 1) begin
                if (rom_data[addr] !== expected_rom_data[addr]) begin
                    $display("[ERROR] ROM Verification Failed at Address 0x%h: Expected = 0x%h, Actual = 0x%h", 
                             addr*4, expected_rom_data[addr], rom_data[addr]);
                    result = 1'b0;
                end
            end
            
            if (result) begin
                $display("[PASS] ROM Verification Successful! All %0d words match expected values", words_to_check);
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
                $display("[ERROR] Invalid UART start bit");
            end else begin
                #(BAUD_PERIOD); // 等待到第一个数据位中间
                
                // 接收8个数据位
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    data[bit_idx] = uart_tx_pin; // 低位在前
                    #(BAUD_PERIOD);
                end
                
                // 检查停止位（高电平）
                if (uart_tx_pin != 1'b1) begin
                    $display("[ERROR] Invalid UART stop bit");
                end
            end
        end
    endtask
    
    // UART接收并显示字符串
    task receive_uart_output;
        input integer timeout_cycles;
        reg [7:0] rx_byte;
        integer timeout_counter;
        integer char_counter;
        parameter MAX_CHARS = 1;  // 设置为固定接收的1个字符（温度高字节）
        begin
            timeout_counter = 0;
            char_counter = 0;
            $display("[INFO] Waiting for UART output (will stop after %0d chars)...", MAX_CHARS);
            
            while ((timeout_counter < timeout_cycles) && (char_counter < MAX_CHARS)) begin
                if (uart_tx_pin == 1'b0) begin  // 检测到起始位
                    uart_receive_byte(rx_byte);
                    $display("[DATA] Received UART data: 0x%h (expected: 0x%h)", rx_byte, EXPECTED_TEMP_DATA[14:7]);
                    
                    // 验证接收到的数据是否正确
                    if (rx_byte == EXPECTED_TEMP_DATA[14:7]) begin
                        test_pass = 1'b1;
                        $display("[PASS] I2C test PASSED! UART output matches expected temperature data");
                    end else begin
                        $display("[FAIL] I2C test FAILED! UART output (0x%h) doesn't match expected (0x%h)", 
                                rx_byte, EXPECTED_TEMP_DATA[14:7]);
                    end
                    
                    char_counter = char_counter + 1;
                    timeout_counter = 0;
                end else begin
                    #100;  // 等待100ns
                    timeout_counter = timeout_counter + 1;
                end
            end
            
            if (timeout_counter >= timeout_cycles) begin
                $display("[WARN] UART reception timeout (received %0d of %0d chars)", char_counter, MAX_CHARS);
            end else if (char_counter >= MAX_CHARS) begin
                $display("[PASS] UART reception completed - received all %0d chars", MAX_CHARS);
            end
        end
    endtask

    initial begin
        // 初始化信号
        clk = 0;
        rst = `RstEnable;
        uart_debug_pin = 1'b0;
        uart_rx_pin = 1'b1;
        test_pass = 1'b0;

        // 初始化变量
        for (k = 0; k < MAX_ROM_SIZE; k = k + 1) begin
            expected_rom_data[k] = 32'h0;
            rom_init_data[k] = 32'h0;
        end

        $display("[START] I2C Temperature Sensor Test Starting...");
        $display("[INFO] Expected temperature data: 0x%h", EXPECTED_TEMP_DATA);

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
        
        $display("[INFO] Test file: %s, Size: %0d bytes, Packets needed: %0d", TEST_FILE, file_size_bytes, packet_count + 1);
        
        // 复位释放
        #40
        rst = `RstDisable;
        #200
        
        // 激活UART Debug模块来加载程序
        uart_debug_pin = 1'b1;
        #100
        
        // === 发送数据包加载I2C测试程序 ===
        
        // 准备第一个包数据 (包0-文件信息包)
        for (p = 0; p < PACKET_DATA_SIZE; p = p + 1) begin
            packet_data[p] = 8'h00; // 初始化为0
        end
        
        // 设置文件名
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
        
        // 计算第一个包的CRC
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
        
        // 发送第一个包 (包0)
        $display("[SEND] Sending I2C test program packet #0");
        uart_send_byte(8'h00);
        for (j = 0; j < PACKET_DATA_SIZE; j = j + 1) begin
            uart_send_byte(packet_data[j]);
        end
        uart_send_byte(packet_crc[7:0]);
        uart_send_byte(packet_crc[15:8]);
        #(100000);
        
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
            
            // 计算CRC
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
            
            // 发送包
            $display("[SEND] Sending I2C test program packet %0d of %0d", i+1, packet_count);
            uart_send_byte(8'h01 + i[7:0]);
            for (j = 0; j < PACKET_DATA_SIZE; j = j + 1) begin
                uart_send_byte(packet_data[j]);
            end
            uart_send_byte(packet_crc[7:0]);
            uart_send_byte(packet_crc[15:8]);
            #(100000);
        end
        
        $display("[INFO] All %0d packets sent, waiting for processing...", packet_count);
        
        // 等待足够时间让数据写入ROM
        #10000000
        
        // 关闭UART Debug模块
        uart_debug_pin = 1'b0;
        #100
        
        // 验证ROM内容
        verify_rom_data(file_size_bytes/4, verify_ok);
        
        if (verify_ok) begin
            $display("[PASS] ROM verification successful, resetting processor to run I2C test program...");
            
            // 重新复位CPU开始执行I2C测试程序
            rst = `RstEnable;
            #100
            rst = `RstDisable;
            #100
            
            $display("[INFO] Processor reset, I2C test program should start running...");
            
            // 等待I2C操作完成并接收UART输出
            receive_uart_output(10000000); // 10M周期超时
            
        end else begin
            $display("[FAIL] ROM verification failed, cannot proceed with I2C test");
        end

        // 测试结果
        if (test_pass) begin
            $display("================== I2C TEST PASS ==================");
            $display("===================================================");
            $display("======= #####     ##     ####    #### =======");
            $display("======= #    #   #  #   #       #     =======");
            $display("======= #    #  #    #   ####    #### =======");
            $display("======= #####   ######       #       #=======");
            $display("======= #       #    #  #    #  #    #=======");
            $display("======= #       #    #   ####    #### =======");
            $display("===================================================");
        end else begin
            $display("================== I2C TEST FAIL ==================");
            $display("====================================================");
            $display("========######    ##       #    #     ========");
            $display("========#        #  #      #    #     ========");
            $display("========#####   #    #     #    #     ========");
            $display("========#       ######     #    #     ========");
            $display("========#       #    #     #    #     ========");
            $display("========#       #    #     #    ######========");
            $display("====================================================");
        end

        $finish;
    end

    // 测试超时
    initial begin
        #200000000; // 200ms超时
        $display("[WARN] Test Timeout! I2C communication may have failed.");
        $finish;
    end

    // 生成波形文件
    initial begin
        $dumpfile("i2c_tb.vcd");
        $dumpvars(0, i2c_tb);
    end

    // 实例化SoC顶层
    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

    // 实例化温度传感器
    temp_sensor temp_sensor_0(
        .clk(clk),
        .rst(rst),
        .scl(io_scl),
        .sda(io_sda)
    );

endmodule 