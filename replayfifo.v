
//
// a simple replayfifo
//
// when the fifo is empty,
// we capture the first write address into
// the replay pointer.
// when replay is asserted, we reset the
// read point to the replay pointer.
//


module replayfifo (
		   output wire [7:0] rdata,
		   output wire 	     emptyB,
		   input 	     replay, // reset the read pointer
		   input             erase, 	     
		   input 	     read,
		   input [7:0] 	     wdata,
		   input 	     write,
		   input 	     reset,
		   input 	     clk);

   reg [8:0] 		 rdaddr;
   reg [8:0] 		 wraddr;
   reg [8:0] 		 replayAddr;
   
   assign emptyB = (rdaddr != wraddr);
   
//   initial begin
//      $monitor ($time,,,"write=%b wraddr=%x  wdata=%s, rdaddr=%x rdata=%s", 
//		write, wraddr, wdata, rdaddr, rdata);
//   end      


   always @(posedge clk) begin
      if (reset | erase) begin
	 rdaddr <= 9'b0_0000_0000;
	 wraddr <= 9'b0_0000_0000;
	 replayAddr <= 9'b0_0000_0000;
      end
      else begin
	 if (replay)
	   rdaddr <= replayAddr;
	 else
	   if (read)
	     rdaddr <= rdaddr + 1;
	   else
	     rdaddr <= rdaddr;
	 
	 if (write)
	   wraddr <= wraddr + 1;
	 else
	   wraddr <= wraddr;

	 if (write & ~emptyB)
	   replayAddr <= wraddr;
	 else
	   replayAddr <= replayAddr;
      end
   end // always @ (posedge clk)
   
   SB_RAM512x8 sb_ram512x8_inst (
		 .RDATA(rdata),
		 .RADDR(rdaddr),
		 .RCLK(clk),
		 .RCLKE(read),
		 .RE(read),
		 .WADDR(wraddr),
		 .WCLK(clk),
		 .WCLKE(write),
		 .WDATA(wdata),
		 .WE(write)
		 );
   
endmodule // fifo
