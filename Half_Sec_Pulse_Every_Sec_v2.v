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
// --------------------------------------------------------------------
//           
//                     Lih-Feng Tsaur
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------
// Generate 0.5 sec pule every sec 
// NOTE: default clk freq (CLK_FREQ) is set to 96MHz.  
//
// Revision History : 0.0
//
// Example:
//   wire o_One_Sec_Pulse_50_50;
//   defparam uu0.CLK_FREQ = 96000000;
//   Half_Sec_Pulse_Per_Sec uu0 (
//        .i_rst (Gl_rst),       //reset
//        .i_clk (clk),       //system clk 12MHz 
//        .o_sec_tick (o_One_Sec_Pulse_50_50)  //0.5sec 1 and 0.5sec 0
//   );


module Half_Sec_Pulse_Per_Sec(
input  wire i_rst,       //reset
input  wire i_clk,       //system clk 12MHz 
output wire o_sec_tick   //0.5sec 1 and 0.5sec 0
);

`define USE_USER_LIB

parameter CLK_FREQ = 96000000;
localparam CLK_CYCLES_PER_HALF_SEC = CLK_FREQ/2;
localparam COUNTER_WIDTH = $clog2(CLK_CYCLES_PER_HALF_SEC+15);

reg [4-1:0] l_precount;
reg [COUNTER_WIDTH-1-4:0] l_count;   // (96000000/2) needs 26 bits to present it
                                   // not sure if timing will close every time of synthersize
reg [1:0] delay_line;								   
//---------------------------------------------------------------
// output
reg  sec_clk;    
assign o_sec_tick = sec_clk;

//---------------------------------------------------------------
//combinational logics
`ifdef USE_USER_LIB

wire [4-1:0] o_adder_div_precntr11;
defparam vbuf_precount_cntrl1.N = 4;
N_bit_counter vbuf_precount_cntrl1(
.result (o_adder_div_precntr11[4-1:0])       , // Output
.r1 (l_precount[4-1:0])                      , // input
.up (1'b1)
);

wire [COUNTER_WIDTH-1-4:0] o_adder_div_cntr11;
defparam vbuf_count_cntrl1.N = COUNTER_WIDTH-4;
N_bit_counter vbuf_count_cntrl1(
.result (o_adder_div_cntr11[COUNTER_WIDTH-1-4:0])       , // Output
.r1 (l_count[COUNTER_WIDTH-1-4:0])                      , // input
.up (1'b1)
);

`endif // USE_USER_LIB
//---------------------------------------------------------------
// sequential logics
// slow down the clk by 16x
wire [COUNTER_WIDTH-1:0] l_count_test = {l_count, l_precount} ^ (CLK_CYCLES_PER_HALF_SEC);
always@(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        l_count <= 0;
		l_precount<=0;
        sec_clk <= 0;
		delay_line <= 2'b00;
    end
    else begin
`ifdef USE_USER_LIB
        l_precount[3:0] <= o_adder_div_precntr11[3:0];
		delay_line[1:0] <= {delay_line[0], &l_precount};
    
	    l_count <= (~|(l_count_test))?                0: 
		           (delay_line[0] & ~delay_line[1])? o_adder_div_cntr11: l_count;
		
		sec_clk <= (~|(l_count_test))? ~sec_clk : sec_clk;
		
`else
        l_count <= l_count + 'h1;
`endif
    end
end

endmodule
