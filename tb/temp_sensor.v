`timescale 1 ns / 1 ns

// 简化的I2C温度传感器模块
// 只支持直接读取操作，不需要寄存器指针
module temp_sensor(
    input wire clk,
    input wire rst,
    input wire scl,
    inout wire sda
);

    // 传感器参数
    parameter [6:0] DEVICE_ADDR = 7'b1001000;  // 设备地址 0x48
    parameter [15:0] TEMP_DATA = 16'h1900;     // 温度数据

    // 状态机状态
    localparam IDLE       = 4'd0;
    localparam ADDR_REC   = 4'd1;
    localparam ADDR_ACK   = 4'd2;
    localparam DATA_H     = 4'd3;
    localparam DATA_H_ACK = 4'd4;
    localparam DATA_L     = 4'd5;
    localparam DATA_L_ACK = 4'd6;
    localparam WAIT_STOP  = 4'd7;

    // 状态机寄存器
    reg [3:0] state;
    reg [3:0] bit_counter;  // 改为4位以支持计数到8
    reg [7:0] addr_byte;
    reg [7:0] full_addr;    // 添加临时变量存储完整地址
    
    // 临时变量用于地址匹配
    wire [7:0] current_addr_data;
    wire [6:0] received_addr;
    wire received_rw_bit;
    
    assign current_addr_data = {addr_byte[7:1], sda};
    assign received_addr = current_addr_data[7:1];
    assign received_rw_bit = current_addr_data[0];
    
    // SDA控制
    reg sda_out;
    reg sda_oe;  // SDA输出使能
    
    // I2C信号边沿检测
    reg scl_prev, sda_prev;
    wire start_detected = scl_prev && sda_prev && scl && !sda;
    wire stop_detected = scl_prev && !sda_prev && scl && sda;
    wire scl_posedge = !scl_prev && scl;
    wire scl_negedge = scl_prev && !scl;

    // SDA三态控制
    assign sda = sda_oe ? sda_out : 1'bz;

    // 信号边沿检测
    always @(posedge clk) begin
        if (!rst) begin
            scl_prev <= 1'b1;
            sda_prev <= 1'b1;
        end else begin
            scl_prev <= scl;
            sda_prev <= sda;
        end
    end

    // 主状态机
    always @(posedge clk) begin
        if (!rst) begin
            state <= IDLE;
            bit_counter <= 4'd0;
            addr_byte <= 8'd0;
            full_addr <= 8'd0;
            sda_out <= 1'b1;
            sda_oe <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    sda_oe <= 1'b0;  // 释放SDA
                    if (start_detected) begin
                        state <= ADDR_REC;
                        bit_counter <= 4'd0;
                        // $display("Temperature sensor: START detected");
                    end
                end

                ADDR_REC: begin
                    // 接收地址阶段不控制SDA
                    sda_oe <= 1'b0;
                    
                    if (scl_posedge) begin
                        // 在SCL上升沿采样SDA
                        addr_byte[7-bit_counter] <= sda;
                        bit_counter <= bit_counter + 1;
                        
                        if (bit_counter == 4'd7) begin
                            // 接收完8位地址+读写位，注意这里bit_counter已经从0计数到7
                            // 说明已经接收了8位数据
                            bit_counter <= 4'd0;
                            // 构造完整的8位地址数据
                            full_addr <= current_addr_data;
                            // 检查地址匹配和读写位
                            if (received_addr == DEVICE_ADDR && received_rw_bit == 1'b1) begin
                                // 地址匹配且是读操作，准备发送ACK
                                state <= ADDR_ACK;
                                // $display("Temperature sensor: Address matched for read, will send ACK");
                            end else begin
                                // 地址不匹配，回到IDLE
                                state <= IDLE;
                                // $display("Temperature sensor: Address mismatch or write operation");
                            end
                        end
                    end
                end
                
                ADDR_ACK: begin
                    // 在地址接收完成后的SCL下降沿发送ACK
                    if (scl_negedge) begin
                        sda_out <= 1'b0;  // ACK
                        sda_oe <= 1'b1;
                        state <= DATA_H;
                        // $display("Temperature sensor: Sending ACK for address");
                    end
                end

                DATA_H: begin
                    if (scl_negedge) begin
                        // 在SCL下降沿准备数据位
                        if (bit_counter < 4'd8) begin
                            sda_out <= TEMP_DATA[15-bit_counter];
                            sda_oe <= 1'b1;
                            bit_counter <= bit_counter + 1;
                        end else begin
                            // bit_counter == 8，第9个SCL周期，释放SDA等待ACK
                            sda_oe <= 1'b0;
                            bit_counter <= 4'd0;
                            state <= DATA_H_ACK;
                            // $display("Temperature sensor: Sent high byte: 0x%h, waiting for ACK", TEMP_DATA[15:8]);
                        end
                    end
                end
                
                DATA_H_ACK: begin
                    // 在第9个SCL上升沿采样主机的ACK/NACK
                    if (scl_posedge) begin
                        if (sda == 1'b0) begin
                            // $display("Temperature sensor: Received ACK for high byte");
                            state <= DATA_L;  // 主机发送ACK，继续发送低字节
                        end else begin
                            // $display("Temperature sensor: Received NACK for high byte");
                            state <= WAIT_STOP;  // 主机发送NACK，等待STOP
                        end
                    end
                end

                DATA_L: begin
                    if (scl_negedge) begin
                        // 在SCL下降沿准备数据位
                        if (bit_counter < 4'd8) begin
                            sda_out <= TEMP_DATA[7-bit_counter];
                            sda_oe <= 1'b1;
                            bit_counter <= bit_counter + 1;
                        end else begin
                            // bit_counter == 8，第9个SCL周期，释放SDA等待ACK/NACK
                            sda_oe <= 1'b0;
                            bit_counter <= 4'd0;
                            state <= DATA_L_ACK;
                            // $display("Temperature sensor: Sent low byte: 0x%h, waiting for ACK/NACK", TEMP_DATA[7:0]);
                        end
                    end
                end
                
                DATA_L_ACK: begin
                    // 在第9个SCL上升沿采样主机的ACK/NACK
                    if (scl_posedge) begin
                        if (sda == 1'b1) begin
                            // $display("Temperature sensor: Received NACK for low byte (expected)");
                        end else begin
                            // $display("Temperature sensor: Received ACK for low byte (unexpected)");
                        end
                        state <= WAIT_STOP;  // 无论如何，都等待STOP
                    end
                end

                WAIT_STOP: begin
                    sda_oe <= 1'b0;  // 释放SDA
                    if (stop_detected) begin
                        state <= IDLE;
                        // $display("Temperature sensor: STOP detected, transaction complete");
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule 