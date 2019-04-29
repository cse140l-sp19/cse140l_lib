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
		  input wire go,
		  input wire 	   rst,
		  input wire 	   clk);

   reg [3:0] 			   cnt;
   wire [7:0] 			   dOutP;
   always @(posedge clk) begin
      if (rst)
	cnt <= 4'b0000;
      else begin
//	 if (go | (cnt != 4'b0000))
	 if (go)
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
		 (cnt[3:1]==3'b110) ? b6 : 8'h0d;
   
   
endmodule // dispString

      
	
      
