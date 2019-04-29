
// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2019 by UCSD CSE 140L
// --------------------------------------------------------------------
//
// Permission:
//
//   This code for use in UCSD CSE 140L.
//   It is synthesisable for Lattice iCEstick 40HX.  
//
// Disclaimer:
//
//   This Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  
//
// -------------------------------------------------------------------- //           
//                     Lih-Feng Tsaur
//                     Bryan Chin
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------

//
// rregce
//
// clock enabled register with reset
//
// load a new value if ce = 1 and rising edge of clock, else
// hold the old value.
//
//
module regrce #(parameter WIDTH = 1)
   (
    output reg [WIDTH-1:0] q,
    input wire [WIDTH-1:0]  d,
    input wire		   ce,    //clock enable
    input wire             rst,   // synchronous reset
    input wire		   clk);

   always @(posedge clk) begin
      if (rst)
	q <= {WIDTH{1'b0}};
      else begin
	 if (ce)
	   q <= d;
	 else
	   q <= q;
      end
   end

endmodule

