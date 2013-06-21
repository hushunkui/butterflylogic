//////////////////////////////////////////////////////////////////////////////
//
// UART transmitter
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

module uart_tx #(
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
  input  wire          str_tvalid,
  input  wire [DW-1:0] str_tdata ,
  output wire          str_tready,
  // UART
  output reg           uart_txd
);

// UART transfer width (length)
localparam TW = DW + (PT!="NONE") + SW;

// stream signals
wire          str_transfer;

// baudrate signals
reg  [BL-1:0] txd_bdr;
reg           txd_ena;

// UART signals
reg           txd_run;  // transfer run status
reg     [3:0] txd_cnt;  // transfer length counter
reg  [DW-1:0] txd_dat;  // data shift register
reg           txd_prt;  // parity register

//////////////////////////////////////////////////////////////////////////////
// UART transmitter
//////////////////////////////////////////////////////////////////////////////

// stream logic
assign str_tready   = ~txd_run;
assign str_transfer = str_tvalid & str_tready;

// baudrate generator from clock (it counts down to 0 generating a baud pulse)
always @ (posedge clk, posedge rst)
if (rst) txd_bdr <= BN-1;
else     txd_bdr <= ~|txd_bdr ? BN-1 : txd_bdr - txd_run;

// enable signal for shifting logic
always @ (posedge clk, posedge rst)
if (rst)  txd_ena <= 1'b0;
else      txd_ena <= (txd_bdr == 'd1);

// bit counter
always @ (posedge clk, posedge rst)
if (rst)             txd_cnt <= 0;
else begin
  if (str_transfer)  txd_cnt <= TW;
  else if (txd_ena)  txd_cnt <= txd_cnt - 1;
end

// shift status
always @ (posedge clk, posedge rst)
if (rst)             txd_run <= 1'b0;
else begin
  if (str_transfer)  txd_run <= 1'b1;
  else if (txd_ena)  txd_run <= txd_cnt != 4'd0;
end

// data shift register
always @ (posedge clk)
if (str_transfer)  txd_dat <= str_tdata;
else if (txd_ena)  txd_dat <= {1'b1, txd_dat[DW-1:1]};

generate if (PT!="NONE") begin

// parity register
always @ (posedge clk)
if (str_transfer)  txd_prt <= (PT!="EVEN");
else if (txd_ena)  txd_prt <= txd_prt ^ txd_dat[0];

// output register
always @ (posedge clk, posedge rst)
if (rst)             uart_txd <= 1'b1;
else begin
  if (str_transfer)  uart_txd <= 1'b0;
  else if (txd_ena)  uart_txd <= (txd_cnt==SW+1) ? txd_prt : txd_dat[0];
end

end else begin

// output register
always @ (posedge clk, posedge rst)
if (rst)             uart_txd <= 1'b1;
else begin
  if (str_transfer)  uart_txd <= 1'b0;
  else if (txd_ena)  uart_txd <= txd_dat[0];
end

end endgenerate

endmodule
