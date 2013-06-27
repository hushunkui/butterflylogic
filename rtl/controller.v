//--------------------------------------------------------------------------------
// controller.vhd
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
// Controls the capturing & readback operation.
// 
// If no other operation has been activated, the controller samples data
// into the memory. When the run signal is received, it continues to do so
// for fwd * 4 samples and then sends bwd * 4 samples  to the transmitter.
// This allows to capture data from before the trigger match which is a nice 
// feature.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module controller (
  // system signals
  input  wire        clk,
  input  wire        rst,
  // configuration
  input  wire        cmd_valid,
  input  wire [31:0] cmd_data,
  // stream controll
  input  wire        run,
  input  wire        arm,
  // input stream
  input  wire        sti_valid,
  input  wire [31:0] sti_data,
  // memory read interface
  input  wire        busy,
  output reg         send,
  output reg         memoryRead,
  // memory write interface
  output reg  [31:0] mwr_tdata ,
  output reg         mwr_tvalid,
  output reg         mwr_tlast
);

reg [15:0] fwd; // Config registers...
reg [15:0] bwd;

reg next_send;
reg next_memoryRead;
reg next_mwr_tvalid;
reg next_mwr_tlast ;

reg [17:0] counter, next_counter; 
wire [17:0] counter_inc = counter+1'b1;

always @(posedge clk) 
mwr_tdata <= sti_data;

//
// Control FSM...
//
localparam [2:0]
  IDLE =     3'h0,
  SAMPLE =   3'h1,
  DELAY =    3'h2,
  READ =     3'h3,
  READWAIT = 3'h4;

reg [2:0] state, next_state; 

initial state = IDLE;
always @(posedge clk, posedge rst) 
if (rst) begin
  state       <= IDLE;
  mwr_tvalid  <= 1'b0;
  mwr_tlast   <= 1'b0;
  memoryRead  <= 1'b0;
end else begin
  state       <= next_state;
  mwr_tvalid  <= next_mwr_tvalid;
  mwr_tlast   <= next_mwr_tlast;
  memoryRead  <= next_memoryRead;
end

always @(posedge clk)
begin
  counter <= next_counter;
  send    <= next_send; 
end

// FSM to control the controller action
always @*
begin
  next_state      = state;
  next_counter    = counter;
  next_mwr_tvalid = 1'b0;
  next_mwr_tlast  = 1'b0;
  next_memoryRead = 1'b0;
  next_send       = 1'b0;

  case(state)
    IDLE :
    begin
      next_counter = 0;
      next_mwr_tvalid = 1;
      if (run) next_state = DELAY;
      else if (arm) next_state = SAMPLE;
    end

    // default mode: write data samples to memory
    SAMPLE : 
    begin
      next_counter = 0;
      next_mwr_tvalid = sti_valid;
      if (run) next_state = DELAY;
    end

    // keep sampling for 4 * fwd + 4 samples after run condition
    DELAY : 
    begin
      if (sti_valid) begin
        next_mwr_tvalid = 1'b1;
        next_counter = counter_inc;
        if (counter == {fwd,2'b11}) begin  // IED - Evaluate only on sti_valid to make behavior
          next_mwr_tlast = 1'b1;     // match between sampling on all-clocks verses occasionally.
          next_counter = 0;                // Added LastWrite flag to simplify write->read memory handling.
          next_state = READ;
        end
      end
    end

    // read back 4 * bwd + 4 samples after DELAY
    // go into wait state after each sample to give transmitter time
    READ :
    begin
      next_memoryRead = 1'b1;
      next_send = 1'b1;
      if (counter == {bwd,2'b11}) begin
        next_counter = 0;
        next_state = IDLE;
      end else begin
        next_counter = counter_inc;
        next_state = READWAIT;
      end
    end

    // wait for the transmitter to become ready again
    READWAIT : 
    begin
      if (!busy && !send) next_state = READ;
    end
  endcase
end


//
// Set speed and size registers if indicated...
//
always @(posedge clk) 
if (cmd_valid) {fwd, bwd} <= cmd_data[31:0];

endmodule
