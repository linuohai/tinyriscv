// core内时钟频率
`define CoreClock 50000000
// 100Kbps 时钟分频数
`define DIV_100K 500
`define N4_DIV_CNT 9'd125
`define N2_DIV_CNT 9'd250
`define N3_4_DIV_CNT 9'd375
`define STATE_NUM 8

module I2C(
    input wire clk,
    input wire rst,

    // 总线接口
    input wire we_i,
    // 不会往I2C写数据
    // input wire [31:0] data_i,
    input wire [31:0] addr_i,
    output reg [31:0] data_o,
    // 表示已经成功读到数据了
    output reg data_valid,
    
    // I2C接口
    output wire SCL,
    output reg out_SDA,
    input wire in_SDA,
    output reg sel_SDA
);

// I2C内部寄存器，但是因为本I2C的实现仅是为了读温度计数器，没有用设置写的功能，所以只保留输出数据寄存器和设备地址寄存器
reg [6:0] addr_reg; // 设备地址寄存器, 对应地址为0x7001_0000
reg [31:0] data_o_reg; // 输出数据寄存器, 对应地址为0x7002_0000

always @ (*) begin
    if (rst == 1'b0) begin
        addr_reg <= 7'd0;
        data_o <= 32'd0;
    end
    else if (we_i == 1'b0 && addr_i[19:16] == 4'h2) begin
        data_o <= data_o_reg;
    end
    else begin
        data_o <= 32'd0;
        addr_reg <= 7'b1001_000;
    end
end

// 数据有效在成功读到一次后一直保持有效
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        data_valid <= 1'b0;
    end
    else if (c_state == END_BIT) begin
        data_valid <= 1'b1;
    end
end


// 状态机状态
localparam IDLE         = `STATE_NUM'd0;
localparam START_BIT    = `STATE_NUM'd1;
localparam ADDR_SEND_R  = `STATE_NUM'd2;
localparam ACK_REC      = `STATE_NUM'd4;
localparam DATA_REC     = `STATE_NUM'd8;
localparam ACK_SEND     = `STATE_NUM'd16;
localparam NACK_SEND    = `STATE_NUM'd32;
localparam END_BIT      = `STATE_NUM'd64;  //在这个状态下把SDA拉低，知道N/4个周期后直接进入IDLE状态，会自动拉高

// 状态机寄存器
reg [`STATE_NUM-1:0] c_state;
reg [`STATE_NUM-1:0] n_state;

// 状态机转移
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state;
    end
end

// 分频器计数
reg [8:0] div_cnt;

always @ (posedge clk) begin
    if (rst == 1'b0) begin
        div_cnt <= 9'd0;
    end
    // 从1开始计数方便计算周期
    else if (div_cnt == 9'd`DIV_100K) begin
        div_cnt <= 9'd1;
    end
    else begin
        div_cnt <= div_cnt + 1'b1;
    end
end
// 在100K的频率下可以尝试用div_cnt[8]来生成SCLK，代价是占空比会略高于50%
// assign SCL = !div_cnt[8];

// 先是高电平然后是低电平，方便状态的转移
assign SCL = (div_cnt <= `N2_DIV_CNT);

// SDA的输入用一个reg存下来 
reg in_SDA_reg;
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        in_SDA_reg <= 1'b1;
    end
    else begin
        in_SDA_reg <= in_SDA;
    end
end


// bit计数器，写的时候表示已经发送了n个bit，但是不一定接受，且最后一次的bit不会被接受
// 读的时候表示已经接收了n个bit
reg [3:0] bit_cnt;
// byte计数器，表示现在正在接收第n个byte
reg [1:0] byte_cnt;
// 表示ACK_SEND已经度过了一个周期
reg ack_send_SCL;

// 状态机转移逻辑
always @ (*) begin
    if (rst == 1'b0) begin
        n_state <= IDLE;
    end
    else begin
        case (c_state)
            IDLE: begin                     // 在IDLE状态进入START_BIT状态要保证是一个全新的周期进入
                if (div_cnt == 9'd1) begin
                    n_state <= START_BIT;
                end
                else begin
                    n_state <= IDLE;
                end
            end
            START_BIT: begin
                if (div_cnt == `N2_DIV_CNT) begin
                    n_state <= ADDR_SEND_R;
                end
                else begin
                    n_state <= START_BIT;
                end
            end
            ADDR_SEND_R: begin
                if (bit_cnt == 4'd9) begin
                    n_state <= ACK_REC;
                end
                else begin
                    n_state <= ADDR_SEND_R;
                end
            end
            ACK_REC: begin
                if (in_SDA_reg == 1'b0 && div_cnt == `N4_DIV_CNT) begin
                    n_state <= DATA_REC;
                end
                else if (in_SDA_reg == 1'b1 && div_cnt == `N4_DIV_CNT) begin
                    n_state <= IDLE;                   // 因为跳转条件是div_cnt等于N4_DIV_CNT，所以必须跳到IDLE防止STAR_BIT操作不会被跳过
                end
                else begin
                    n_state <= ACK_REC;
                end
            end
            DATA_REC: begin
                if (bit_cnt == 4'd8 && byte_cnt == 2'd1) begin
                    n_state <= ACK_SEND;
                end
                else if (bit_cnt == 4'd8 && byte_cnt == 2'd2) begin
                    n_state <= NACK_SEND;
                end
                else begin
                    n_state <= DATA_REC;
                end
            end
            ACK_SEND: begin
                if (div_cnt == `N3_4_DIV_CNT && ack_send_SCL == 1'b1) begin
                    n_state <= DATA_REC;
                end
                else begin
                    n_state <= ACK_SEND;
                end
            end
            NACK_SEND: begin
                if (div_cnt == `N3_4_DIV_CNT && ack_send_SCL == 1'b1) begin
                    n_state <= END_BIT;
                end
                else begin
                    n_state <= NACK_SEND;
                end
            end
            END_BIT: begin
                if (div_cnt == `N4_DIV_CNT) begin
                    n_state <= IDLE ;
                end
                else begin
                    n_state <= END_BIT;
                end
            end
        endcase
    end
end

// 状态机每个状态的输出
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        bit_cnt <= 4'd0;
        byte_cnt <= 2'd0;
        out_SDA <= 1'b1;
        data_o_reg <= 32'd0;
        ack_send_SCL <= 1'b0;
    end
    else begin
        case (c_state)
            IDLE: begin
                out_SDA <= 1'b1;
                bit_cnt <= 4'd0;
                byte_cnt <= 2'd0;
                ack_send_SCL <= 1'b0;
            end
            START_BIT: begin
                bit_cnt <= 4'd0;
                if (div_cnt == `N4_DIV_CNT) begin
                    out_SDA <= 1'b0;
                end
                else if (div_cnt == `N2_DIV_CNT) begin
                    out_SDA <= 1'b1;
                end
            end
            ADDR_SEND_R: begin
                if (div_cnt == `N3_4_DIV_CNT) begin
                    bit_cnt <= bit_cnt + 1'b1;
                    case (bit_cnt)
                        4'd0: out_SDA <= addr_reg[6];
                        4'd1: out_SDA <= addr_reg[5];
                        4'd2: out_SDA <= addr_reg[4];
                        4'd3: out_SDA <= addr_reg[3];
                        4'd4: out_SDA <= addr_reg[2];
                        4'd5: out_SDA <= addr_reg[1];
                        4'd6: out_SDA <= addr_reg[0];
                        4'd7: out_SDA <= 1'b1;          // 表示读出
                        4'd8: out_SDA <= 1'b1;          // 主机放弃对SDA的控制
                        default: out_SDA <= 1'b1;
                    endcase
                end
            end
            ACK_REC: begin
                bit_cnt <= 4'd0;
                out_SDA <= 1'b1;
                byte_cnt <= 2'd0;
            end
            DATA_REC: begin
                ack_send_SCL <= 1'b0;
                if (div_cnt == `N4_DIV_CNT) begin
                    bit_cnt <= bit_cnt + 1'b1;
                    case (bit_cnt)
                        4'd0: begin 
                            byte_cnt <= byte_cnt + 1'b1;
                            if (byte_cnt == 2'd1) 
                                data_o_reg[7] <= in_SDA_reg;
                            else  
                                data_o_reg[15] <= in_SDA_reg;
                        end
                        4'd1: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[6] <= in_SDA_reg;
                            else  
                                data_o_reg[14] <= in_SDA_reg;
                        end
                        4'd2: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[5] <= in_SDA_reg;
                            else  
                                data_o_reg[13] <= in_SDA_reg;
                        end
                        4'd3: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[4] <= in_SDA_reg;
                            else  
                                data_o_reg[12] <= in_SDA_reg;
                        end
                        4'd4: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[3] <= in_SDA_reg;
                            else  
                                data_o_reg[11] <= in_SDA_reg;
                        end
                        4'd5: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[2] <= in_SDA_reg;
                            else  
                                data_o_reg[10] <= in_SDA_reg;
                        end
                        4'd6: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[1] <= in_SDA_reg;
                            else  
                                data_o_reg[9] <= in_SDA_reg;
                        end
                        4'd7: begin
                            if (byte_cnt == 2'd2) 
                                data_o_reg[0] <= in_SDA_reg;
                            else  
                                data_o_reg[8] <= in_SDA_reg;
                        end
                    endcase
                end
            end
            ACK_SEND: begin
                bit_cnt <= 4'd0;
                if (div_cnt == `N3_4_DIV_CNT) begin
                    out_SDA <= 1'b0;
                end
                if (div_cnt == `N4_DIV_CNT) begin
                    ack_send_SCL <= 1'b1;
                end
            end
            NACK_SEND: begin
                bit_cnt <= 4'd0;
                // 当在3/4周期的时候再拉高SDA，遵循在3/4周期变化的规律
                if (div_cnt == `N3_4_DIV_CNT) begin
                    out_SDA <= 1'b1; 
                end
                if (div_cnt == `N4_DIV_CNT) begin
                    ack_send_SCL <= 1'b1;
                end
            end
            END_BIT: begin
                bit_cnt <= 4'd0;
                out_SDA <= 1'b0;
                ack_send_SCL <= 1'b0;
                byte_cnt <= 2'd0;
                end
        endcase
    end
end

// sel_SDA的输出
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        sel_SDA <= 1'b1;
    end
    else begin
        sel_SDA <=  (c_state == START_BIT) || (c_state == ADDR_SEND_R) || 
                    (c_state == ACK_SEND)  || (c_state == END_BIT)  || 
                    (c_state == NACK_SEND); 
    end
end

endmodule





