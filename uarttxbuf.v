//
// uartTxBuf
// handle the interface to the buart transmit logic.
// The application can push into this buffer as fast as the
// clock rate.
// after the application asserts printBuf for one cycle, a
// CR and LF will be printed, the contenst of the buffer will be sent out
// over utb_txdata and when the buffer is empty, another CR and LF will be send out.
// when uartTxBuf is not printing the contents of the fifo (printBuf is low or
// the fifo is empty), the rxdata will be sent out as utb_txdata (loopback).
//
//
module uartTxBuf(
		 output [7:0] utb_txdata,
		 output       utb_txdata_rdy,
		 input [7:0]  txdata, // tx data to fifo
		 input 	      txDataValid, // tx data is valid
		 input [7:0]  rxdata,      // data from the uart
		 input        rxDataValid, // data from the uart is valid
		 input 	      txBusy, // tx uart is busy
		 input 	      printBuf, // when printBuf is asserted, the buffer will be printed over utb_txdata.	      
		 input 	      reset,
		 input 	      clk
		 );


   wire 		      printingBuf;  // printing from the buffer
   wire [7:0] 		      fifo_txdata;     // data from the fifo
   wire 		      fifo_txdata_rdy; // rdy associated with the fifo
 		      
   wire 		      crlfdone;
   wire 		      emitcr;
   wire 		      emitlf;
   
   //
   // loopback or fifo data
   //
   // filter out esc from loopback;
   wire 		      rxDataValidNoEsc;
   assign rxDataValidNoEsc = rxDataValid & (rxdata != 8'h1b);
   


   assign utb_txdata = emitcr ? 8'h0d : emitlf ? 8'h0a :
		       printingBuf ?  fifo_txdata : rxdata;
   assign utb_txdata_rdy = emitcr | 
			   emitlf | 
			   ~emitcr & ~emitlf & printingBuf & fifo_txdata_rdy | rxDataValidNoEsc;
   
//   assign utb_txdata_rdy = printingBuf ? fifo_txdata_rdy : 
//			   (emitcr | emitlf |rxDataValid);
   
   
   
   reg [7:0]	      txdataD;      // register txdata to remove glitches
   reg 		      txDataValidD;  // register txDataValid to remove glitches
   
   always @(posedge clk) begin
      txdataD <= txdata;
      txDataValidD <= txDataValid;
   end


   wire 		      emptyB;
   wire 		      popFifo;
   
   fifo fifo (
	      .rdata(fifo_txdata),
	      .emptyB(emptyB),
	      .read(popFifo),
	      .wdata(txdataD),
	      .write(txDataValidD),
	      .reset(reset),
	      .clk(clk)
	      );

   wire [1:0] 		      txState;
   wire 		      startcrlf;
   
   tx_fsm tx_fsm (
		  .tx_data_rdy(fifo_txdata_rdy),
		  .popFifo(popFifo),
		  .printingBuf(printingBuf),
		  .startcrlf(startcrlf),
		  .crlfdone(crlfdone),
		  .emptyB(emptyB),
		  .txBusy(txBusy),
		  .printBuf(printBuf),
		  .rst(reset),
		  .clk(clk)
		  );

   emitcrlf_fsm emitcrlf_fsm (
			      .crlfdone(crlfdone),
			      .emitcr(emitcr),
			      .emitlf(emitlf),
			      .startcrlf(startcrlf),
			      .txBusy(txBusy),
			      .rst(reset),
			      .clk(clk)
			      );
   


endmodule


//
// a simple fifo
//


`ifdef LCLFIFO
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
`endif


//
// emitcrlf_fsm
//
// control the sending of a CR and LINEFEED
//
module emitcrlf_fsm(
		    output reg crlfdone,
		    output reg emitcr,
		    output reg emitlf,
		    input      startcrlf,
		    input      txBusy,
		    input      rst,
		    input      clk
		    );
   
   reg [1:0] 		       cstate, nstate;
   localparam 
     IDLE     = 2'b00,  
     WTEMITCR = 2'b10,
     EMITCR   = 2'b01, 
     EMITLF   = 2'b11;
   
   always @(*) begin
      emitcr = 0;
      emitlf = 0;
      crlfdone = 0;
      case (cstate)
	IDLE:
	  if (startcrlf)
	    nstate = WTEMITCR;
	  else
	    nstate = IDLE;

	WTEMITCR:
	  begin
	     if (~txBusy) begin
		emitcr = 1;
		nstate = EMITCR;
	     end
	     else
	       nstate = WTEMITCR;
	  end

	EMITCR:
	  if (~txBusy) begin
	     nstate = EMITLF;
	     emitlf = 1;
	  end
	  else
	    nstate = EMITCR;

	EMITLF:
	  if (~txBusy) begin
	     nstate = IDLE;
	     crlfdone = 1;
	  end
	  else
	    nstate = EMITLF;

      endcase // case (cstate)
   end
   always @(posedge clk)
     if (rst)
       cstate <= IDLE;
     else
       cstate <= nstate;

endmodule
      
// ---------------------------------------
//
// uart transmit interface state machine
//
//
module tx_fsm (
	       output reg  tx_data_rdy,
	       output reg  popFifo,
               output wire printingBuf,
	       output reg  startcrlf,
	       input       crlfdone,
	       input 	   emptyB,
	       input 	   txBusy,
	       input 	   printBuf, 
	       input 	   rst,
	       input 	   clk
	       );

   
   reg [2:0] 	     cstate;
   reg [2:0] 	     nxtState;
   

   localparam 
     IDLE      = 3'b000, 
     EMITCRLF0 = 3'b001,
     STARTTX   = 3'b010, 
     STROBETX  = 3'b011,
     WAITTX    = 3'b100,
     EMITCRLF1 = 3'b101;
   

   assign printingBuf = (cstate != IDLE);

   // next state logic
   always @(*) begin
      startcrlf = 0;
      if (rst)
	nxtState = IDLE;
      else
	begin
	   case (cstate)
	     IDLE:
	       begin
		  startcrlf = printBuf;
		  if (emptyB & printBuf) begin
		     nxtState = EMITCRLF0;
		  end
		  else 
		    nxtState = IDLE;
	       end
	     EMITCRLF0:
	       if (crlfdone)
		 nxtState = STARTTX;
	       else
		 nxtState = EMITCRLF0;
	     
	     STARTTX:
	       nxtState = STROBETX;

	     STROBETX:
	       nxtState = WAITTX;
	     
	     WAITTX:
	       if (txBusy)
		 nxtState = WAITTX;
	       else if (emptyB)
		 nxtState = STARTTX;
	       else begin
		  nxtState = EMITCRLF1;
		  startcrlf = 1;
	       end

	     EMITCRLF1:
	       if (crlfdone)
		 nxtState = IDLE;
	       else
		 nxtState = EMITCRLF1;

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





