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
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------
//  Example:
//
//   latticehx1k_pll96 latticehx1k_pll_inst(.REFERENCECLK(clk_in),
//                                     .PLLOUTCORE(clk),
//                                     .PLLOUTGLOBAL(PLLOUTGLOBAL),
//                                     .RESET(1'b1));
// ------------------------------------------------------------------------

   // for simple feedback path
   // pllout =   Frefclock * (DIVF+1) / [ 2^divq x (divr+1)]
   //  12 MHz * 4   / [ 2^0 x 1] = 48 MHz    // doesn't work in icecube2
   //  12 MHz * 8   / [ 2^1 x 1] = 48 MHz    // doesn't work in icecube2
   //  12 MHz * 64   / [ 2^4 x 1] = 48 MHz    // doesn't work in icecube2
   //  


module latticehx1k_pll(REFERENCECLK,
                       PLLOUTCORE,
                       PLLOUTGLOBAL,
                       RESET);

input wire REFERENCECLK;
input wire RESET;    /* To initialize the simulation properly, the RESET signal (Active Low) must be asserted at the beginning of the simulation */ 
output wire PLLOUTCORE;
output wire PLLOUTGLOBAL;

SB_PLL40_CORE latticehx1k_pll_inst(.REFERENCECLK(REFERENCECLK),
                                   .PLLOUTCORE(PLLOUTCORE),
                                   .PLLOUTGLOBAL(PLLOUTGLOBAL),
                                   .EXTFEEDBACK(),
                                   .DYNAMICDELAY(),
                                   .RESETB(RESET),
                                   .BYPASS(1'b0),
                                   .LATCHINPUTVALUE(),
                                   .LOCK(),
                                   .SDI(),
                                   .SDO(),
                                   .SCLK());

//\\ Fin=12, Fout=48;
defparam latticehx1k_pll_inst.DIVR = 4'b0000;
defparam latticehx1k_pll_inst.DIVF = 7'b0111111;
defparam latticehx1k_pll_inst.DIVQ = 3'b0110;
defparam latticehx1k_pll_inst.FILTER_RANGE = 3'b001;
defparam latticehx1k_pll_inst.FEEDBACK_PATH = "SIMPLE";
defparam latticehx1k_pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
defparam latticehx1k_pll_inst.FDA_FEEDBACK = 4'b0000;
defparam latticehx1k_pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
defparam latticehx1k_pll_inst.FDA_RELATIVE = 4'b0000;
defparam latticehx1k_pll_inst.SHIFTREG_DIV_MODE = 2'b00;
defparam latticehx1k_pll_inst.PLLOUT_SELECT = "GENCLK";
defparam latticehx1k_pll_inst.ENABLE_ICEGATE = 1'b0;

endmodule
