
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
//
//                     Lih-Feng Tsaur
//                     Bryan Chin
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------
//
// bcd2segment
//
// convert binary coded decimal to seven segment display
//
//                        aaa
//                       f   b 
//                       f   b
//                       f   b				
//                        ggg
//                       e   c
//                       e   c
//                       e   c
//                        ddd 
//
// segment[0] - a     segment[3] - d    segment[6] - g
// segment[1] - b     segment[4] - e
// segment[2] - c     segment[5] - f
//
module bcd2segment (
		  output wire [6:0] segment,  // 7 drivers for segment
		  input  wire [3:0] num,       // number to convert
		  input wire enable          // if 1, drive display, else blank
		  );

   reg 		       zero;
   reg 		       one;
   reg 		       two; 
   reg 		       three;
   reg 		       four;
   reg 		       five;
   reg 		       six;
   reg 		       seven;
   reg 		       eight;
   reg 		       nine;
   reg 		       ten;
   reg 		       eleven;
   reg 		       twelve;
   reg 		       thirteen;
   reg 		       fourteen;
   reg 		       fifteen;

   always @(num[3:0]) begin
      zero     = 1'b0;
      one      = 1'b0;
      two      = 1'b0;
      three    = 1'b0;
      four     = 1'b0;
      five     = 1'b0;
      six      = 1'b0;
      seven    = 1'b0;
      eight    = 1'b0;
      nine     = 1'b0;
      ten      = 1'b0;
      eleven   = 1'b0;
      twelve   = 1'b0;
      thirteen = 1'b0;
      fourteen = 1'b0;
      fifteen  = 1'b0;
      case (num[3:0])
	4'b0000 : zero     = 1;        // 0
	4'b0001 : one      = 1;        // 1
	4'b0010 : two      = 1;        // 2
	4'b0011 : three    = 1;        // 3
	4'b0100 : four     = 1;        // 4
	4'b0101 : five     = 1;        // 5 
	4'b0110 : six      = 1;        // 6
	4'b0111 : seven    = 1;        // 7
	4'b1000 : eight    = 1;        // 8
	4'b1001 : nine     = 1;        // 9
	4'b1010 : ten      = 1;        // A
	4'b1011 : eleven   = 1;        // b
	4'b1100 : twelve   = 1;        // C
	4'b1101 : thirteen = 1;        // d
	4'b1110 : fourteen = 1;        // E
	4'b1111 : fifteen  = 1;        // F
      endcase // case (num[3:0])
   end

   wire [6:0] segmentUQ;
   
   // a
   assign segmentUQ[0] =  (
		       zero | two | three | five | six | seven | eight | nine | ten |
		       twelve | fourteen | fifteen);
   // b
   assign segmentUQ[1] = (
		       zero | one | two | three | four | seven |
		       eight | nine | ten | thirteen);
   // c
   assign segmentUQ[2] = (
		      zero | one | three | four | five | six | seven |
		      eight | nine | ten | eleven | thirteen) ;
   
   // d
   // assign segmentUQ[3] = ( ... );
   
   // e
   // assign segmentUQ[4] = ( ... );

   
   // f
   // assign segmentUQ[5] = ( ... );

   // g
   // assign segmentUQ[6] = ( ... );

   assign segment = {7{enable}} & segmentUQ;
   
endmodule

   
   

   
   
   
   
   
   

   
   

