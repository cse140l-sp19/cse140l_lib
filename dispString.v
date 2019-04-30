
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
//
// dispString
//
// take each byte, b0, to b6 and send them
// out dOut one cycle at a time.
// we pulse rdy so dOut contains each byte for 2 cycles
// while we genearte a pulse on rdy.
// The last charcter (b6) is followed by a carriage return
//
module dispString(
		  output reg 	   rdy,
		  output reg [7:0] dOut,
		  input wire [7:0] b0,
		  input wire [7:0] b1,
		  input wire [7:0] b2,
		  input wire [7:0] b3,
		  input wire [7:0] b4,
		  input wire [7:0] b5,
		  input wire [7:0] b6,
		  input wire [7:0] b7,
		  input wire go,
		  input wire 	   rst,
		  input wire 	   clk);

   reg [3:0] 			   cnt;
   wire [7:0] 			   dOutP;
   always @(posedge clk) begin
      if (rst)
	cnt <= 4'b0000;
      else begin
	 if (go | (cnt != 4'b0000))
	   cnt <= cnt + 1;
	 else
	   cnt <= cnt;
      end
      dOut <= dOutP;
      rdy <= cnt[0];
   end

   assign dOutP = 
		  (cnt[3:1]==3'b000) ? b0 :
		  (cnt[3:1]==3'b001) ? b1 :
		  (cnt[3:1]==3'b010) ? b2 :
		  (cnt[3:1]==3'b011) ? b3 :
		  (cnt[3:1]==3'b100) ? b4 :
		  (cnt[3:1]==3'b101) ? b5 :
		  (cnt[3:1]==3'b110) ? b6 : b7;
   
   
   
endmodule // dispString

      
	
      
