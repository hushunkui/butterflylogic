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

module uart #(
  parameter DW = 8,          // data width (size of data byte)
  parameter PT = "NONE",     // parity type "EVEN", "ODD", "NONE"
  parameter SW = 1,          // stop width (number of stop bits)
  parameter BN = 2           // time period number (number of clock periods per bit)
)(
  // system signals
  input  wire          clk,  // clock
  input  wire          rst,  // reset (asynchronous)
  // RXD data stream
  output wire          str_rxd_tvalid,
  output wire [DW-1:0] str_rxd_tdata ,
  input  wire          str_rxd_tready,
  // TXD data stream
  input  wire          str_txd_tvalid,
  input  wire [DW-1:0] str_txd_tdata ,
  output wire          str_txd_tready,
  // data stream error status
  output wire          error_fifo,    // fifo overflow error
  output wire          error_parity,  // receive data parity error
  // UART
  input  wire          uart_rxd,
  input  wire          uart_txd
);

uart_tx #(
  .DW (DW),
  .PT (PT),
  .SW (SW),
  .BN (BN)
) uart_tx (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // TXD stream
  .str_tvalid  (str_txd_tvalid),
  .str_tdata   (str_txd_tdata ),
  .str_tready  (str_txd_tready),
  // UART 
  .uart_txd    (uart_txd)
);

uart_rx #(
  .DW (DW),
  .PT (PT),
  .SW (SW),
  .BN (BN)
) uart_rx (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // RXD stream
  .str_tvalid  (str_rxd_tvalid),
  .str_tdata   (str_rxd_tdata ),
  .str_tready  (str_rxd_tready),
  // error status
  .error_fifo  (error_fifo  ),
  .error_parity(error_parity),
  // UART 
  .uart_rxd    (uart_rxd)
);


endmodule
