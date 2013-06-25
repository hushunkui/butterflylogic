//////////////////////////////////////////////////////////////////////////////
//
// host interface controller
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

module ctrl #(
  // memory port parameters
  parameter integer MDW = 32,
  // host port parameters
  parameter integer HDW = 8
)(
  // system signals
  input  wire           clk,
  input  wire           rst,
  // software reset
  output wire           soft_reset,
  // memory data stream
  input  wire           mem_tvalid,
  input  wire [MDW-1:0] mem_tdata ,
  output wire           mem_tready,
  // control stream
  output wire   [8-1:0] ctl_code ,
  output wire  [32-1:0] ctl_data ,
  output wire           ctl_valid,
  // RXD data stream
  input  wire           str_rxd_tvalid,
  input  wire [HDW-1:0] str_rxd_tdata ,
  output wire           str_rxd_tready,
  // TXD data stream
  output wire           str_txd_tvalid,
  output wire [HDW-1:0] str_txd_tdata ,
  input  wire           str_txd_tready
);

// stream transfer events
wire str_rxd_transfer;
wire str_txd_transfer;

assign str_rxd_transfer = str_rxd_tvalid & str_rxd_tready;
assign str_txd_transfer = str_txd_tvalid & str_txd_tready;

// controller state machine signals
reg  [2:0] cmd_cnt;
wire       cmd_type;

// configuration registers
reg ctl_id;
reg ctl_flow;

// command counter
always @(posedge clk, posedge rst) 
if (rst) begin
  ctl_cnt <= 3'b011;
end else if (str_rxd_transfer) begin
  if (~cmd_cnt[2]) begin
    // receiving command code
    ctl_cnt <= cmd_cnt + 3'd1;
  end else begin
    if (cmd_type) begin
      // long command
      ctl_cnt <= cmd_cnt + 3'd1;
    end else begin
      // short command
      cmd_cnt <= 3'b011;
    end
  end
end

// command code and data
always @(posedge clk) 
if (str_rxd_transfer) begin
  if (~cmd_cnt[2]) begin
    // receiving command code
    ctl_code <= str_rxd_tdata;
  end else if (cmd_type) begin
    // receiving long command data
    ctl_data [ctl_cnt[1:0]] <= str_rxd_tdata;
  end
end

// on/off transmitter flow controll
always @(posedge clk, posedge rst) 
if (rst) begin
  ctl_flow <= 1'b0;
end else if (ctl_valid) begin
  case (ctl_code)
    8'h11 : ctl_flow <= 1'b1;
    8'h13 : ctl_flow <= 1'b0;
  endcase
end

// software reset
always @(posedge clk, posedge rst) 
if (rst) soft_reset <= 1'b0;
else     soft_reset <= ctl_valid & (ctl_code == 8'h00);

endmodule
