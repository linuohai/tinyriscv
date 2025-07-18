# 时钟约束50MHz
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {clk}]; 
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {clk}];

# 时钟引脚
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN Y18 [get_ports clk]

# 复位引脚
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PACKAGE_PIN F20 [get_ports rst]

# 程序执行成功指示引脚
set_property IOSTANDARD LVCMOS33 [get_ports succ]
set_property PACKAGE_PIN F19 [get_ports succ]

# 串口发送引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property PACKAGE_PIN G16 [get_ports uart_tx_pin]

# 串口接收引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN G15 [get_ports uart_rx_pin]

# pwm 引脚
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[0]]
set_property PACKAGE_PIN E21 [get_ports pwm_o[0]]

set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[1]]
set_property PACKAGE_PIN D20 [get_ports pwm_o[1]]

set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[2]]
set_property PACKAGE_PIN C20 [get_ports pwm_o[2]]

set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[3]]
set_property PACKAGE_PIN D16 [get_ports pwm_o[3]]

# GPIO引脚
set_property IOSTANDARD LVCMOS33 [get_ports {gpio[*]}]
set_property PACKAGE_PIN J5 [get_ports {gpio[0]}]
set_property PACKAGE_PIN M3 [get_ports {gpio[1]}]
set_property PACKAGE_PIN J6 [get_ports {gpio[2]}]
set_property PACKAGE_PIN H5 [get_ports {gpio[3]}]
set_property PACKAGE_PIN G4 [get_ports {gpio[4]}]
set_property PACKAGE_PIN K6 [get_ports {gpio[5]}]
set_property PACKAGE_PIN K3 [get_ports {gpio[6]}]
set_property PACKAGE_PIN H4 [get_ports {gpio[7]}]
set_property PACKAGE_PIN M2 [get_ports {gpio[8]}]
set_property PACKAGE_PIN N4 [get_ports {gpio[9]}]
set_property PACKAGE_PIN L5 [get_ports {gpio[10]}]
set_property PACKAGE_PIN L4 [get_ports {gpio[11]}]
set_property PACKAGE_PIN M16 [get_ports {gpio[12]}]
set_property PACKAGE_PIN M17 [get_ports {gpio[13]}]
set_property PACKAGE_PIN B20 [get_ports {gpio[14]}]
set_property PACKAGE_PIN D17 [get_ports {gpio[15]}]

# I2C 引脚
set_property IOSTANDARD LVCMOS33 [get_ports io_scl]
set_property PACKAGE_PIN M22 [get_ports io_scl]

set_property IOSTANDARD LVCMOS33 [get_ports io_sda]
set_property PACKAGE_PIN N22 [get_ports io_sda]
set_property PULLUP true [get_ports io_sda]

# Debug 引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_debug_pin]
set_property PACKAGE_PIN M13 [get_ports uart_debug_pin]












