module pwm(
    input clk,
    input rst,

    // 总线信号
    input we_i,
    input[31:0] addr_i,
    input[31:0] data_i,

    output [31:0] data_o,
    output [3:0] pwm_o
);


// 内部寄存器
// 存储整个时钟周期的计数值
// 对应的地址分别为0x6000_0000, 0x6001_0000, 0x6002_0000, 0x6003_0000
reg [31:0] A_0_reg;
reg [31:0] A_1_reg;
reg [31:0] A_2_reg;
reg [31:0] A_3_reg;

// 存储每个时钟周期duty的计数值
// 对应的地址分别为0x6010_0000, 0x6011_0000, 0x6012_0000, 0x6013_0000
reg [31:0] B_0_reg;
reg [31:0] B_1_reg;
reg [31:0] B_2_reg;
reg [31:0] B_3_reg;

// 使能通道寄存器
// 对应的地址为0x6004_0000
reg [31:0] C_reg;



// 写寄存器
always @ (posedge clk) begin
    if (rst == 1'b0) begin
        A_0_reg <= 32'h0;
        A_1_reg <= 32'h0;
        A_2_reg <= 32'h0;
        A_3_reg <= 32'h0;
        B_0_reg <= 32'h0;
        B_1_reg <= 32'h0;
        B_2_reg <= 32'h0;
        B_3_reg <= 32'h0;
        C_reg <= 32'h0;
    end else begin
        if (we_i == 1'b1) begin
            case (addr_i[23:16])
                8'h00: A_0_reg <= data_i;
                8'h01: A_1_reg <= data_i;
                8'h02: A_2_reg <= data_i;
                8'h03: A_3_reg <= data_i;
                8'h10: B_0_reg <= data_i;
                8'h11: B_1_reg <= data_i;
                8'h12: B_2_reg <= data_i;
                8'h13: B_3_reg <= data_i;
                8'h04: C_reg <= data_i;
            endcase
        end
    end
end

// 计数器
reg [31:0] cnt_0;
reg [31:0] cnt_1;
reg [31:0] cnt_2;
reg [31:0] cnt_3;

always @ (posedge clk) begin
    if (rst == 1'b0 || C_reg[0] == 1'b0) begin
        cnt_0 <= 32'h0;
    end
    else if (cnt_0 == A_0_reg) begin
        cnt_0 <= 32'h0;
    end
    else begin
        cnt_0 <= cnt_0 + 1'b1;
    end
end

always @ (posedge clk) begin
    if (rst == 1'b0 || C_reg[1] == 1'b0) begin
        cnt_1 <= 32'h0;
    end
    else if (cnt_1 == A_1_reg) begin
        cnt_1 <= 32'h0;
    end
    else begin
        cnt_1 <= cnt_1 + 1'b1;
    end
end

always @ (posedge clk) begin
    if (rst == 1'b0 || C_reg[2] == 1'b0) begin
        cnt_2 <= 32'h0;
    end
    else if (cnt_2 == A_2_reg) begin
        cnt_2 <= 32'h0;
    end
    else begin
        cnt_2 <= cnt_2 + 1'b1;
    end
end

always @ (posedge clk) begin
    if (rst == 1'b0 || C_reg[3] == 1'b0) begin
        cnt_3 <= 32'h0;
    end
    else if (cnt_3 == A_3_reg) begin
        cnt_3 <= 32'h0;
    end
    else begin
        cnt_3 <= cnt_3 + 1'b1;
    end
end

assign pwm_o[0] = (A_0_reg != 32'h0) & (cnt_0 < B_0_reg) & C_reg[0];
assign pwm_o[1] = (A_1_reg != 32'h0) & (cnt_1 < B_1_reg) & C_reg[1];
assign pwm_o[2] = (A_2_reg != 32'h0) & (cnt_2 < B_2_reg) & C_reg[2];
assign pwm_o[3] = (A_3_reg != 32'h0) & (cnt_3 < B_3_reg) & C_reg[3];

assign  data_o = {32{!we_i}} & {
    {32{addr_i[23:16] == 8'h00}} & A_0_reg |
    {32{addr_i[23:16] == 8'h01}} & A_1_reg |
    {32{addr_i[23:16] == 8'h02}} & A_2_reg |
    {32{addr_i[23:16] == 8'h03}} & A_3_reg |
    {32{addr_i[23:16] == 8'h10}} & B_0_reg |
    {32{addr_i[23:16] == 8'h11}} & B_1_reg |
    {32{addr_i[23:16] == 8'h12}} & B_2_reg |
    {32{addr_i[23:16] == 8'h13}} & B_3_reg |
    {32{addr_i[23:16] == 8'h04}} & C_reg
};



endmodule


