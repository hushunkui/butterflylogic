`timescale 1ns/100ps

module tb_uart #(
  // UART RTL parameterization
  parameter int   DW = 8,           // data width (size of data byte)
  parameter       PT = "NONE",      // parity type "EVEN", "ODD", "NONE"
  parameter int   SW = 1,           // stop width (number of stop bits)
  // clocking parameters
  parameter int   FREQ = 50_000_000,
  parameter int   BAUD = 921_600
);

// system signals
logic clk = 1;
logic rst = 1;

always #10 clk = ~clk;

// RXD stream
logic [DW-1:0] str_rxd_tdata ;
logic          str_rxd_tvalid;
logic          str_rxd_tready;
// TXD stream
logic [DW-1:0] str_txd_tdata ;
logic          str_txd_tvalid;
logic          str_txd_tready;

// UART
logic          uart_rxd;
logic          uart_txd;

// test signals
int unsigned   error = 0;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

//
// Generate test sequence...
//
initial
begin
  repeat (10) @(posedge clk);
  rst = 0;
  repeat (10) @(posedge clk);
  uart.transmit (8'ha5);

  // report test status
  if (error)  $display ("FAILURE: there were %d errors during simulation.", error);
  else        $display ("SUCESS: there were no errors during simulation.");
  $finish;
end

////////////////////////////////////////////////////////////////////////////////
// bench module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.VW (DW)) str_txd (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (str_txd_tvalid),
  .tready  (str_txd_tready),
  .tdata   (str_txd_tdata )
);

// stream drain instance
str_drn #(.VW (DW)) str_rxd (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (str_rxd_tvalid),
  .tready  (str_rxd_tready),
  .tdata   (str_rxd_tdata )
);

uart_model #(
  .BAUD (BAUD)
) uart (
  .TxD  (uart_txd),
  .RxD  (uart_rxd)
);

////////////////////////////////////////////////////////////////////////////////
// DUT instance
////////////////////////////////////////////////////////////////////////////////

uart_tx #(
  .DW (DW),
  .PT (PT),
  .SW (SW),
  .BN (FREQ/BAUD)
) uart_tx (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // TXD stream
  .str_tvalid  (str_txd_tvalid),
  .str_tdata   (str_txd_tdata ),
  .str_tready  (str_txd_tready),
  // UART 
  .uart_txd    (uart_rxd)
);

uart_rx #(
  .DW (DW),
  .PT (PT),
  .SW (SW),
  .BN (FREQ/BAUD)
) uart_rx (
  // system signals
  .clk         (clk),
  .rst         (rst),
  // RXD stream
  .str_tvalid  (str_rxd_tvalid),
  .str_tdata   (str_rxd_tdata ),
  .str_tready  (str_rxd_tready),
  // UART 
  .uart_rxd    (uart_txd)
);

////////////////////////////////////////////////////////////////////////////////
// waveform related code
////////////////////////////////////////////////////////////////////////////////

initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule
