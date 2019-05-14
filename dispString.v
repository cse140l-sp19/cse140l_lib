//
// dispString
// this block takes in 8 bytes (b0 to b7 ) and streams them out
// to dOut one byte at a time. For each byte, the rdy
// output will be logic 1.
//
// dispString will start streaming when "go" is asserted for one cycle.
// dInP, and rdyInP are currently not used but could be used to chain
// multipleDisp strings together.
//
// update 5/11/19 - added more comments
//
module dispString(
		  output reg 	   rdy, // dOut  is valid
		  output reg [7:0] dOut, // data b0 -> b7
		  input wire [7:0] dInP, // future expansion
		  input wire 	   rdyInP, // future expansion
		  input wire [7:0] b0, // first byte to stream
		  input wire [7:0] b1,
		  input wire [7:0] b2,
		  input wire [7:0] b3,
		  input wire [7:0] b4,
		  input wire [7:0] b5,
		  input wire [7:0] b6,
		  input wire [7:0] b7, // last byte to stream
		  input wire 	   go, // start streaming
		  input wire 	   rst,
		  input wire 	   clk);

   reg [2:0] 			   cnt;
   wire [7:0] 			   dOutP;
   always @(posedge clk) begin
      if (rst)
	cnt <= 3'b000;
      else begin
	 if (go | (cnt != 3'b000))
	   cnt <= cnt + 1;
	 else
	   cnt <= cnt;
      end
      dOut <= dOutP;
      rdy <= go | (|cnt[2:0]);
   end

   assign dOutP = 
		 (cnt[2:0]==3'b000) ? {8{go}} & b0 :
		 (cnt[2:0]==3'b001) ? b1 :
		 (cnt[2:0]==3'b010) ? b2 :
		 (cnt[2:0]==3'b011) ? b3 :
		 (cnt[2:0]==3'b100) ? b4 :
		 (cnt[2:0]==3'b101) ? b5 :
  	         (cnt[2:0]==3'b110) ? b6 : b7;
   
   
   
endmodule // dispString

      
	
      
