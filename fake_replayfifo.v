
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
		   output reg [7:0] rdata,
		   output wire 	    emptyB,
		   input 	    replay, // reset the read pointer
		   input 	    erase, // erase the buffer 	    
		   input 	    read,
		   input [7:0] 	    wdata,
		   input 	    write,
		   input 	    reset,
		   input 	    clk);

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


   reg [7:0] mfifo[511:0];
   
   always @(posedge clk) begin
      if (read)
	rdata <= mfifo[rdaddr];
      else
	rdata <= rdata;
   end
	
   always @(posedge clk) begin
      if (write)
	mfifo[wraddr] <= wdata;
   end
endmodule // fifo
