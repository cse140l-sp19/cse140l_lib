//
// uartRxBuf
// this IP requires replayfifo.v or fake_replayfifo.v
// the fake version is used for software simulation
// while the other is used for HW synthesis.
//
// handle the interface to the buart receive logic
// bu_rxdata are pushed into a replay buffer
// and are also sent to ur_rxdata.
// when replay is asserted, the data may be replayed.
// Replaying occurs when replay is asserted for one cycle
// and then getByte is asserted.
// getByte should not be asserted at the same time as replay.
//
// Replay should only be asserted for one cycle or
// the oldest byte will be read over and over.
// That is
// replay <=1, getByte<=0
// replay <=0, getByte<=1
// replay <=0, getByte<=1,  // first data appear here
//
// until the entire buffer has been replayed.
// reset and erase reset all the pointers and
// therefore effectively erases the buffer.
//
// the data appear one cycle after getByte.
//
//
module uartRxBuf(
		 output [7:0] ur_rx_data,
		 output       ur_rx_data_rdy,
		 output reg   ur_done, // replay buffer is done with a replay
		 input [7:0]  rx_data, // rx data to fifo
		 input 	      rx_data_rdy, // rx data is valid

		 input 	      capture, // capture the input data in the replay fifo
		 input 	      replay, // replay the buffer
		 input 	      erase, // erase the buffer
                 input 	      getByte, // get the nextByte (level sensitive)
            	      
		 input 	      reset,
		 input 	      clk
		 );


   wire 		      crlfdone;
   wire 		      emitcr;
   wire 		      emitlf;
   

   // input registers
   //

   wire [7:0] 		      replayData;
   wire 		      replayDataEmptyB;

   reg 			      getByteD;
   
   always @(posedge clk) begin
      getByteD <= getByte;
      ur_done <= ~replayDataEmptyB;
      
   end
   
   assign ur_rx_data = getByteD ? replayData  : rx_data;
   assign ur_rx_data_rdy = getByteD | rx_data_rdy;
   
   replayfifo rp (
		  .rdata(replayData),	  
		  .emptyB(replayDataEmptyB),
		  .replay(replay),
		  .erase(erase),
		  .read(getByte),
		  .write(rx_data_rdy & capture),
		  .wdata(rx_data),
		  .reset(reset),
		  .clk(clk));
endmodule





