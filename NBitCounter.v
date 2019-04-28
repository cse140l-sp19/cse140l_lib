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
// Example:
//  wire [10:0] o_adder_vbuf_count;
//  defparam vbuf_count.N = 11;
//  N_bit_counter vbuf_count(
//    .resuu<lt (o_adder_vbuf_count)       , // Output
//    .r1 (l_count)                      , // input
//    .up (1'b1)                           //1: count up, 0: count down
//  );
//
//  NOTE:  Don't turn on USE_HALF_ADDER, it is for illustration only
// Revision History : 0.0
//---------------------------------------------------------------------
//`define  USE_HALF_ADDER
module N_bit_counter (
result      , // Output
r1          ,  // input
up
);

parameter N = 4;
parameter N_1 = N - 1;
// Input Port Declarations       
input    [N_1:0]   r1         ;
input              up         ; 

// Output Port Declarations
output   [N_1:0]  result      ;

// Port Wires
wire     [N_1:0]    r1        ;
wire     [N_1:0]    result    ;

`ifdef   USE_HALF_ADDER
// Internal variables
wire     [N:0]      r2       ;
assign   r2[0] = 1'b1;
genvar i;
generate
    for (i = 1; i < N; i=i+1) 
    begin : counter_gen_label	
        half_adder adder_inst (
            .a(r1[i]),
            .b(r2[i]),
            .sum(result[i]),
		    .carry(r2[i+1])
        );
    end
endgenerate;

`else  //~USE_HALF_ADDER

// Internal variables
wire     [N_1:0]      ci       ;

assign result[0] = ~r1[0];
genvar i;
generate
    for (i = 1; i < N; i=i+1) 
    begin : counter_gen_label	
        assign ci[i] = (up)? &r1[i-1:0] : ~|r1[i-1:0];
        xor (result[i], r1[i], ci[i]);
    end
endgenerate

`endif

endmodule // End Of Module adder

`ifdef USE_HALF_ADDER
module half_adder(a, b, sum, carry);
input a;
input b;
output sum;
output carry;

xor(sum,a,b);
and(carry,a,b);

endmodule
`endif
