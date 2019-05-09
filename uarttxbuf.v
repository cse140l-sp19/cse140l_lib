module fifo (output wire [7:0] rdata,
	     output wire emptyB,
	     input 	 read,
	     input [7:0] wdata,
	     input 	 write,
	     input 	 reset,
	     input 	 clk);

   reg [8:0] 		 rdaddr;
   reg [8:0] 		 wraddr;

   assign emptyB = (rdaddr != wraddr);
   
//   initial begin
//      $monitor ($time,,,"write=%b wraddr=%x  wdata=%s, rdaddr=%x rdata=%s", 
//		write, wraddr, wdata, rdaddr, rdata);
//   end      


   always @(posedge clk) begin
      if (reset) begin
	 rdaddr <= 9'b0_0000_0000;
	 wraddr <= 9'b0_0000_0000;
      end
      else begin
	 if (read)
	   rdaddr <= rdaddr + 1;
	 else
	   rdaddr <= rdaddr;
	 
	 if (write)
	   wraddr <= wraddr + 1;
	 else
	   wraddr <= wraddr;
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


//
// uartTxBuf
// handle the interface to the buart transmit logic.
// The application can push into this buffer as fast as the
// clock rate.
// The buffer will unload at the UART transmit rate.
//
module uartTxBuf(
		 output [7:0] utb_txdata,
		 output       utb_txdata_rdy,
		 input [7:0]  txdata, // tx data to fifo
		 input 	      txDataValid, // tx data is valid
		 input        txBusy,      // tx uart is busy
		 input 	      reset,
		 input 	      clk
		 );

   wire 		      emptyB;
   wire 		      popFifo;
   
   fifo fifo (
	      .rdata(utb_txdata),
	      .emptyB(emptyB),
	      .read(popFifo),
	      .wdata(txdata),
	      .write(txDataValid),
	      .reset(reset),
	      .clk(clk)
	      );

   wire [1:0] 		      txState;
   
   tx_fsm tx_fsm (
		  .tx_data_rdy(utb_txdata_rdy),
		  .popFifo(popFifo),
		  .cstate(txState),
		  .emptyB(emptyB),
		  .txBusy(txBusy),
		  .rst(reset),
		  .clk(clk)
		  );
endmodule
// ---------------------------------------
//
// uart transmit interface state machine
//
//
module tx_fsm (
	       output reg tx_data_rdy,
	       output reg popFifo,
               output reg [1:0] cstate,
	       input 	  emptyB,
	       input 	  txBusy,
	       input 	  rst,
	       input 	  clk
	       );

//   reg [1:0] 	     cstate;
   reg [1:0] 	     nxtState;
   

   localparam IDLE= 2'b00, STARTTX = 2'b01, STROBETX = 2'b11, WAITTX = 2'b10;
   
   // next state logic
   always @(*) begin

      if (rst)
	nxtState = IDLE;
      else
	begin
	   case (cstate)
	     IDLE:
	       if (emptyB)
		 nxtState = STARTTX;
	       else
		 nxtState = IDLE;

	     STARTTX:
	       nxtState = STROBETX;

	     STROBETX:
	       nxtState = WAITTX;
	     
	     WAITTX:
	       if (txBusy)
		 nxtState = WAITTX;
	       else 
		 nxtState = IDLE;
	     default:
	       nxtState = IDLE;
	   endcase // case (cstate)
	end
   end

   // outputs

   always @(*) begin
      case (cstate)
	IDLE:
	  begin
	     tx_data_rdy = 1'b0;
	     popFifo = 1'b0;
	  end
	STARTTX:
   	  begin
	     tx_data_rdy = 1'b0;
	     popFifo = 1'b1;
	  end
	STROBETX:
	  begin
	     tx_data_rdy = 1'b1;
	     popFifo = 1'b0;
	  end
	WAITTX:
	  begin
	     tx_data_rdy = 1'b0;
	     popFifo = 1'b0;
	  end
	default:
	  begin
	     tx_data_rdy = 1'b0;
	     popFifo = 1'b0;
	  end
      endcase // case (cstate)
   end
	     
   always @(posedge clk) begin
      if (rst)
	cstate <= IDLE;
      else
	cstate <= nxtState;
   end
endmodule   





