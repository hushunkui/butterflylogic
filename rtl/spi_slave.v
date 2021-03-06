//--------------------------------------------------------------------------------
// spi_slave.v
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
// spi_slave
//
//--------------------------------------------------------------------------------
//
// 01/22/2011 - Ian Davis - Added meta data generator.
//

`timescale 1ns/100ps

module spi_slave (
  // system signals
  input  wire        clk,
  input  wire        rst,
  // software reset
  output reg         soft_reset,
  // raw data input
  input  wire [31:0] dataIn,
  // stream signals
  input  wire        mem_tvalid,
  input  wire [31:0] mem_tdata,
  input  wire  [3:0] mem_tkeep,
  output wire        mem_tready,
  // command signals
  output wire  [7:0] cmd_code,
  output wire [31:0] cmd_data,
  output wire        cmd_valid,
  // SPI signals
  input  wire        spi_cs_n,
  input  wire        spi_sclk,
  input  wire        spi_mosi,
  output wire        spi_miso
);

// TODO: recode SPI into SPI clock synchronous code, use CDC for data bytes
// reg [7:0] spi_cnt;
// reg [7:0] spi_byte;
// 
// always @ (posedge spi_sclk, posedge spi_cs_n)
// if (spi_cs_n) spi_cnt <= 0;
// else          spi_cnt <= spi_cnt + 'b1;
// 
// always @ (posedge spi_sclk)
// spi_byte <= {spi_byte[6:0], spi_mosi};

//
// Registers...
//
reg query_id; 
reg query_metadata;
reg query_dataIn; 

//
// Synchronize inputs...
//
full_synchronizer spi_sclk_sync (clk, rst, spi_sclk, sync_sclk);
full_synchronizer spi_cs_n_sync (clk, rst, spi_cs_n, sync_cs_n);

//
// Instantaite the meta data generator...
//
wire [7:0] meta_data;
meta_handler meta_handler(
  // system signals
  .clock           (clk),
  .extReset        (rst),
  //
  .query_metadata  (query_metadata),
  .xmit_idle       (!mem_tready && !mem_tvalid && byteDone),
  .writeMeta       (writeMeta),
  .meta_data       (meta_data)
);

//
// Instantiate the heavy lifters...
//
spi_receiver spi_receiver(
  // system signals
  .clk          (clk),
  .rst          (rst),
  // SPI signals
  .spi_sclk     (sync_sclk),
  .spi_mosi     (spi_mosi),
  .spi_cs_n     (sync_cs_n),
  //
  .transmitting (mem_tready),
  //
  .cmd_code     (cmd_code ),
  .cmd_data     (cmd_data ),
  .cmd_valid    (cmd_valid)
);

spi_transmitter spi_transmitter(
  // system signals
  .clk          (clk),
  .rst          (rst),
  // SPI signals
  .spi_sclk     (sync_sclk),
  .spi_cs_n     (sync_cs_n),
  .spi_miso     (spi_miso),
  //
  .mem_tvalid   (mem_tvalid),
  .mem_tdata    (mem_tdata),
  .mem_tkeep    (mem_tkeep),
  .mem_tready   (mem_tready),
  //
  .writeMeta    (writeMeta),
  .meta_data    (meta_data),
  .query_id     (query_id), 
  .query_dataIn (query_dataIn),
  .dataIn       (dataIn),
  .byteDone     (byteDone)
);

//
// Process special SPI commands not handled by core decoder...
//
always @(posedge clk) 
begin
  if (cmd_valid) begin
    soft_reset     <= (cmd_code == 8'h00);
    query_id       <= (cmd_code == 8'h02);
    query_metadata <= (cmd_code == 8'h04);
    query_dataIn   <= (cmd_code == 8'h06);
  end else begin
    soft_reset     <= 1'b0;
    query_id       <= 1'b0;
    query_metadata <= 1'b0;
    query_dataIn   <= 1'b0;
  end
end

endmodule
