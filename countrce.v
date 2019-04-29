
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
// clock enabled counter
//
module countrce #(parameter WIDTH = 4)
   (
    output reg [WIDTH-1:0] q,
    input wire [WIDTH-1:0] d,
    input wire             ld, // load the counter
    input wire		   ce, //clock enable
    input wire		   rst, // synchronous reset
    input wire		   clk);

   wire [WIDTH-1:0] 	   qPone;   // count plus one
   genvar 		   i;
   generate
      assign qPone[0] = ~q[0];
      for (i=1; i< WIDTH; i=i+1)
	begin: generate_counter_N 
	   // toggle bit i if all preceeding bits are 1
	   assign qPone[i] = q[i] ^ &(q[i-1:0]);
	end
   endgenerate

   // sequential logic
   always @(posedge clk) begin
      if (rst)
	q <= {WIDTH{1'b0}};
      else begin
	 if (~ce)
	   q <= q;
	 else
	   if (ld)
	     q <= d;
	   else
	     q <= qPone;
      end
   end
endmodule

