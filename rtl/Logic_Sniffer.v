//--------------------------------------------------------------------------------
// Logic_Sniffer.vhd
//
// Copyright (C) 2006 Michael Poppitz
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
//
//--------------------------------------------------------------------------------
//
// Details: http://www.sump.org/projects/analyzer/
//
// Logic Analyzer top level module. It connects the core with the hardware
// dependend IO modules and defines all inputs and outputs that represent
// phyisical pins of the fpga.
//
// It defines two constants FREQ and RATE. The first is the clock frequency 
// used for receiver and transmitter for generating the proper baud rate.
// The second defines the speed at which to operate the serial port.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//

`timescale 1ns/100ps

module Logic_Sniffer #(
  parameter SDW = 32, // sample data width
  parameter MDW = 32  // memory data width
)(
  // system signals
  input  wire        bf_clock,
  // logic analyzer signals
  input  wire        extClockIn,
  output wire        extClockOut,
  input  wire        extTriggerIn,
  output wire        extTriggerOut,
  //
  inout  wire [31:0] extData,
  // 
  output wire        dataReady,
  output wire        armLEDnn,
  output wire        triggerLEDnn,
  // host interface
  input  wire        spi_sclk,
  input  wire        spi_cs_n,
  input  wire        spi_mosi,
  output wire        spi_miso
);

// system signals
wire           sys_clk;
wire           sys_clk_p;
wire           sys_clk_n;
wire           sys_rst;

// external signals
wire           ext_clk_p;
wire           ext_clk_n;

// data path signals
wire           sti_clk_p;
wire           sti_clk_n;
wire [SDW-1:0] sti_data;
wire [SDW-1:0] sti_data_p;
wire [SDW-1:0] sti_data_n;

wire extClock_mode;
wire extTestMode;

//--------------------------------------------------------------------------------
// clocking
//--------------------------------------------------------------------------------

wire sys_clk_ref;
wire sys_clk_buf;

wire ext_clk_ref;
wire ext_clk_buf;

// DCM: Digital Clock Manager Circuit for Virtex-II/II-Pro and Spartan-3/3E
// Xilinx HDL Language Template version 8.1i
DCM #(
  .CLK_FEEDBACK("1X")
) dcm_sys_clk (
  .CLKIN    (bf_clock), // Clock input (from IBUFG, BUFG or DCM)
  .PSCLK    (1'b 0),    // Dynamic phase adjust clock input
  .PSEN     (1'b 0),    // Dynamic phase adjust enable input
  .PSINCDEC (1'b 0),    // Dynamic phase adjust increment/decrement
  .RST      (1'b 0),    // DCM asynchronous reset input
  // clock outputs
  .CLK2X    (sys_clk),
  .CLKFX    (sys_clk_p),
  .CLKFX180 (sys_clk_n),
  // feedback
  .CLK0     (sys_clk_ref),
  .CLKFB    (sys_clk_buf)
);

BUFG BUFG_sys_clk_fb (
  .I (sys_clk_ref),
  .O (sys_clk_buf)
);

DCM #(
  .CLK_FEEDBACK("2X")
) dcm_ext_clk (
  .CLKIN    (extClockIn), // Clock input (from IBUFG, BUFG or DCM)
  .PSCLK    (1'b 0),    // Dynamic phase adjust clock input
  .PSEN     (1'b 0),    // Dynamic phase adjust enable input
  .PSINCDEC (1'b 0),    // Dynamic phase adjust increment/decrement
  .RST      (1'b 0),    // DCM asynchronous reset input
  .CLK0     (ext_clk_p),
  .CLK180   (ext_clk_n),
  // feedback
  .CLK2X    (ext_clk_ref),
  .CLKFB    (ext_clk_buf)
);

BUFG BUFG_ext_clk_fb (
  .I (ext_clk_ref),
  .O (ext_clk_buf)
);

//
// Select between internal and external sampling clock...
//
//BUFGMUX bufmux_sti_clk [1:0] (
//  .O  ({sti_clk_p, sti_clk_n}),  // Clock MUX output
//  .I0 ({sys_clk_p, sys_clk_n}),  // Clock0 input
//  .I1 ({ext_clk_p, ext_clk_n}),  // Clock1 input
//  .S  (extClock_mode)            // Clock select
//);

assign sti_clk_p = sys_clk_p;
assign sti_clk_n = sys_clk_n;

//--------------------------------------------------------------------------------
// IO
//--------------------------------------------------------------------------------

// Use DDR output buffer to isolate clock & avoid skew penalty...
ODDR2 ODDR2 (
  .Q  (extClockOut),
  .D0 (1'b0),
  .D1 (1'b1),
  .C0 (sti_clk_n),
  .C1 (sti_clk_p),
  .S  (1'b0),
  .R  (1'b0)
);

//
// Configure the probe pins...
//
reg [10:0] test_counter;
always @ (posedge sys_clk, posedge sys_rst) 
if (sys_rst) test_counter <= 'b0;
else         test_counter <= test_counter + 'b1;
wire [15:0] test_pattern = {8{test_counter[10], test_counter[4]}};

IOBUF #(
  .DRIVE            (12),         // Specify the output drive strength
  .IBUF_DELAY_VALUE ("0"),        // Specify the amount of added input delay for the buffer,
                                  //  "0"-"12" (Spartan-3E only)
  .IFD_DELAY_VALUE  ("AUTO"),     // Specify the amount of added delay for input register,
                                  //  "AUTO", "0"-"6" (Spartan-3E only)
  .IOSTANDARD       ("DEFAULT"),  // Specify the I/O standard
  .SLEW             ("SLOW")      // Specify the output slew rate
) IOBUF [31:16] (
  .O  (sti_data[31:16]),          // Buffer output
  .IO (extData [31:16]),          // Buffer inout port (connect directly to top-level port)
  .I  (test_pattern),             // Buffer input
  .T  ({16{~extTestMode}})        // 3-state enable input, high=input, low=output
);

IBUF #(
  .CAPACITANCE      ("DONT_CARE"),
  .IBUF_DELAY_VALUE ("0"),
  .IBUF_LOW_PWR     ("TRUE"),
  .IFD_DELAY_VALUE  ("AUTO"),
  .IOSTANDARD       ("DEFAULT")
) IBUF [15:0] (
  .O  (sti_data[15:0]),           // Buffer output
  .I  (extData [15:0])            // Buffer input port (connect directly to top-level port)
);
    
IDDR2 #(
  .DDR_ALIGNMENT ("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
  .INIT_Q0       (1'b0),   // Sets initial state of the Q0 output to 1'b0 or 1'b1
  .INIT_Q1       (1'b0),   // Sets initial state of the Q1 output to 1'b0 or 1'b1
  .SRTYPE        ("SYNC")  // Specifies "SYNC" or "ASYNC" set/reset
) IDDR2 [31:0] (
  .Q0 (sti_data_p), // 1-bit output captured with C0 clock 
  .Q1 (sti_data_n), // 1-bit output captured with C1 clock
  .C0 (sti_clk_p),  // 1-bit clock input
  .C1 (sti_clk_n),  // 1-bit clock input
  .CE (1'b1),       // 1-bit clock enable input
  .D  (sti_data),   // 1-bit DDR data input
  .R  (1'b0),       // 1-bit reset input
  .S  (1'b0)        // 1-bit set input
);

//--------------------------------------------------------------------------------
// rtl instances
//--------------------------------------------------------------------------------

wire           mwr_tvalid;
wire           mwr_tready;
wire           mwr_tlast ;
wire [MDW-1:0] mwr_tdata ;

wire           mrd_tvalid;
wire           mrd_tready;
wire [MDW-1:0] mrd_tdata ; 
wire     [3:0] mrd_tkeep ;

wire [SDW-1:0] stableInput;

wire     [7:0] cmd_code;
wire    [31:0] cmd_data; 
wire           cmd_valid;

wire           cmd_valid_flags;

// Output dataReady to PIC (so it'll enable our SPI CS#)...
dly_signal dataReady_reg (sys_clk, mrd_tready, dataReady);

//
// Instantiate serial interface....
//

spi_slave spi_slave (
  // system signals
  .clk        (sys_clk), 
  .rst        (1'b0),
  // software reset
  .soft_reset (sys_rst),
  .dataIn     (stableInput),
  // input stream
  .mem_tvalid (mrd_tvalid), 
  .mem_tdata  (mrd_tdata ), 
  .mem_tkeep  (mrd_tkeep ),
  .mem_tready (mrd_tready),
  // output configuration
  .cmd_code   (cmd_code),
  .cmd_data   (cmd_data),
  .cmd_valid  (cmd_valid),
  // SPI signals
  .spi_sclk   (spi_sclk), 
  .spi_cs_n   (spi_cs_n),
  .spi_mosi   (spi_mosi),
  .spi_miso   (spi_miso)
);

//
// Instantiate core...
//

core #(
  .SDW (32),
  .MDW (32)
) core (
  // system signsls
  .clk             (sys_clk),
  .rst             (sys_rst),
  // input stream
  .sti_clk         (sti_clk_p),
  .sti_data_p      (sti_data_p),
  .sti_data_n      (sti_data_n),
  .extTriggerIn    (extTriggerIn),
  // command interface
  .cmd_code        (cmd_code),
  .cmd_data        (cmd_data),
  .cmd_valid       (cmd_valid),
  .cmd_valid_flags (cmd_valid_flags),
  // outputs...
  .sampleReady50   (),
  .stableInput     (stableInput),
  .extTriggerOut   (extTriggerOut),
  .extClock_mode   (extClock_mode),
  .extTestMode     (extTestMode),
  // indicators
  .indicator_arm   (armLEDnn),
  .indicator_trg   (triggerLEDnn),
  // memory read interface
  .outputBusy      (mrd_tready),
  .outputSend      (mrd_tvalid),
  .memoryRead      (read),
  // memory write interface
  .mwr_tvalid      (mwr_tvalid),
  .mwr_tlast       (mwr_tlast ),
  .mwr_tdata       (mwr_tdata )
);

// Instantiate the memory interface...
sram_interface sram_interface (
  // system signals
  .clk          (sys_clk),
  .rst          (sys_rst),
  // configuration/control signals
  .cmd_flags    (cmd_valid_flags), 
  .cmd_data     (cmd_data[5:2]),
  // write interface
  .mwr_tready   (),
  .mwr_tvalid   (mwr_tvalid),
  .mwr_tlast    (mwr_tlast ),
  .mwr_tdata    (mwr_tdata ),
  // read interface
  .mrd_tready   (read),
  .mrd_tvalid   (),
  .mrd_tkeep    (mrd_tkeep ),
  .mrd_tdata    (mrd_tdata )
);

endmodule
