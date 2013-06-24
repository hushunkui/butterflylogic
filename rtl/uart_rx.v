//////////////////////////////////////////////////////////////////////////////
//
// UART receiver
//
// Copyright (C) 2013 Iztok Jeras <iztok.jeras@gmail.com>
//
//////////////////////////////////////////////////////////////////////////////
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
//////////////////////////////////////////////////////////////////////////////

module uart_rx #(
  parameter DW = 8,          // data width (size of data byte)
  parameter PT = "NONE",     // parity type "EVEN", "ODD", "NONE"
  parameter SW = 1,          // stop width (number of stop bits)
  parameter BN = 2,          // time period number (number of clock periods per bit)
  parameter BL = $clog2(BN)  // time period log(number) (size of boudrate generator counter)
)(
  // system signals
  input  wire          clk,  // clock
  input  wire          rst,  // reset (asynchronous)
  // data stream
  output reg           str_tvalid,
  output reg  [DW-1:0] str_tdata ,
  input  wire          str_tready,
  // data stream error status
  output reg           error_fifo,    // fifo overflow error
  output reg           error_parity,  // receive data parity error
  // UART
  input  wire          uart_rxd
);

// UART transfer width (length)
localparam TW = DW + (PT!="NONE") + SW;

// stream signals
wire          str_transfer;

// baudrate signals
reg  [BL-1:0] rxd_bdr;
reg           rxd_ena;

// UART signals
reg           rxd_run;  // transfer run status
reg     [3:0] rxd_cnt;  // transfer length counter
reg  [DW-1:0] rxd_dat;  // data shift register
reg           rxd_prt;  // parity register

wire          rxd_start, rxd_end;
 
//////////////////////////////////////////////////////////////////////////////
// stream logic
//////////////////////////////////////////////////////////////////////////////

assign str_transfer = str_tvalid & str_tready;

// received data
always @ (posedge clk)
if (rxd_end)  str_tdata <= rxd_dat;

// received data valid
always @ (posedge clk, posedge rst)
if (rst)                 str_tvalid <= 1'b0;
else begin
  if (rxd_end)           str_tvalid <= 1'b1;
  else if (str_transfer) str_tvalid <= 1'b0;
end

// fifo overflow error
always @ (posedge clk, posedge rst)
if (rst)                 error_fifo <= 1'b0;
else begin
  if (str_transfer)      error_fifo <= 1'b0;
  else if (rxd_end)      error_fifo <= str_tvalid;
end

// receiving stream parity error
always @ (posedge clk, posedge rst)
if (rst)                 error_parity <= 1'b0;
else if (rxd_end)        error_parity <= rxd_prt;

//////////////////////////////////////////////////////////////////////////////
// UART receiver
//////////////////////////////////////////////////////////////////////////////

reg uart_rxd_dly;

// delay uart_rxd and detect a start negative edge
always @ (posedge clk)
uart_rxd_dly <= uart_rxd;

assign rxd_start = uart_rxd_dly & ~uart_rxd & ~rxd_run;

// baudrate generator from clock (it counts down to 0 generating a baud pulse)
always @ (posedge clk, posedge rst)
if (rst)          rxd_bdr <= BN-1;
else begin
  if (rxd_start)  rxd_bdr <= ((BN-1)>>1)-1;
  else            rxd_bdr <= ~|rxd_bdr ? BN-1 : rxd_bdr - rxd_run;
end

// enable signal for shifting logic
always @ (posedge clk, posedge rst)
if (rst)  rxd_ena <= 1'b0;
else      rxd_ena <= (rxd_bdr == 'd1);

// bit counter
always @ (posedge clk, posedge rst)
if (rst)             rxd_cnt <= 0;
else begin
  if (rxd_start)     rxd_cnt <= TW;
  else if (rxd_ena)  rxd_cnt <= rxd_cnt - 1;
end

// shift status
always @ (posedge clk, posedge rst)
if (rst)             rxd_run <= 1'b0;
else begin
  if (rxd_start)     rxd_run <= 1'b1;
  else if (rxd_ena)  rxd_run <= rxd_cnt != 4'd0;
end

assign rxd_end = ~|rxd_cnt & rxd_ena;

// data shift register
always @ (posedge clk)
if ((PT!="NONE") ? ~(txd_cnt==SW) & rxd_ena : rxd_ena)
  rxd_dat <= {uart_rxd, rxd_dat[DW-1:1]};

generate
if (PT!="NONE") begin: parity

// parity register
always @ (posedge clk)
if (rxd_start)     rxd_prt <= (PT!="EVEN");
else if (rxd_ena)  rxd_prt <= rxd_prt ^ uart_rxd;

end else begin

// parity register
always @ (posedge clk)
rxd_prt <= 0;

end
endgenerate

endmodule
