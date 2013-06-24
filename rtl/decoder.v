//--------------------------------------------------------------------------------
// decoder.vhd
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
// Takes the cmd_code from the command received by the receiver and decodes it.
// The decoded command will be executed for one cycle.
//
// The receiver keeps the cmd output active long enough so all the
// data is still available on its cmd output when the command has
// been decoded and sent out to other modules with the next
// clock cycle. (Maybe this paragraph should go in receiver.vhd?)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module decoder (
  // system signals
  input  wire       clk,
  input  wire       rst,
  // configuration/control signals
  input  wire       cmd_valid,
  input  wire [7:0] cmd_code,
  // decoded ouptputs
  output reg  [3:0] wrtrigmask   = 0,
  output reg  [3:0] wrtrigval    = 0,
  output reg  [3:0] wrtrigcfg    = 0,
  output reg        wrspeed      = 0,
  output reg        wrsize       = 0,
  output reg        wrFlags      = 0,
  output reg        wrTrigSelect = 0,
  output reg        wrTrigChain  = 0,
  output reg        finish_now   = 0,
  output reg        arm_basic    = 0,
  output reg        arm_adv      = 0,
  output reg        resetCmd     = 0
);

//
// Registers...
//
reg dly_cmd_valid;

//
// Control logic.  On rising edge of "cmd_valid" signal,
// parse "cmd_code" and make things happen...
//
always @(posedge clk) 
if (cmd_valid) begin
  // short commands
  resetCmd      <= (cmd_code == 8'h00);
  arm_basic     <= (cmd_code == 8'h01);
  // Query ID (decoded in spi_slave.v)
  // Selftest (reserved)
  // Query Meta Data (decoded in spi_slave.v)
  finish_now    <= (cmd_code == 8'h05);
  // Query input data (decoded in spi_slave.v)
  arm_adv       <= (cmd_code == 8'h0F);
  // XON (reserved)
  // XOFF (reserved)

  // long commands
  wrspeed       <= (cmd_code == 8'h80);
  wrsize        <= (cmd_code == 8'h81);
  wrFlags       <= (cmd_code == 8'h82);

  wrTrigSelect  <= (cmd_code == 8'h9E);
  wrTrigChain   <= (cmd_code == 8'h9F);

  wrtrigmask[0] <= (cmd_code == 8'hC0);
  wrtrigval [0] <= (cmd_code == 8'hC1);
  wrtrigcfg [0] <= (cmd_code == 8'hC2);
  wrtrigmask[1] <= (cmd_code == 8'hC4);
  wrtrigval [1] <= (cmd_code == 8'hC5);
  wrtrigcfg [1] <= (cmd_code == 8'hC6);
  wrtrigmask[2] <= (cmd_code == 8'hC8);
  wrtrigval [2] <= (cmd_code == 8'hC9);
  wrtrigcfg [2] <= (cmd_code == 8'hCA);
  wrtrigmask[3] <= (cmd_code == 8'hCC);
  wrtrigval [3] <= (cmd_code == 8'hCD);
  wrtrigcfg [3] <= (cmd_code == 8'hCE);
end else begin
  resetCmd      <= 0;
  arm_basic     <= 0;
  finish_now    <= 0;
  arm_adv       <= 0;
  wrspeed       <= 0;
  wrsize        <= 0;
  wrFlags       <= 0;
  wrTrigSelect  <= 0;
  wrTrigChain   <= 0;
  wrtrigmask    <= 0;
  wrtrigval     <= 0;
  wrtrigcfg     <= 0;
end

endmodule
