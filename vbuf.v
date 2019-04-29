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
// ***** ONLY CAN BE SYNTHERIZED BY LATTICE ICECUBE2 ******
//
// Descriptions:
//
//    data_in -- data input from UART RX
//    data_out -- data output to UART TX
//
//    use_7_segment_code (1'b1)
//      -- 0 only display inputs from terminal
//      -- 1 also take display format for 7-segment
//    segment1~4 (7'h7f)
//      segment  g f e d c b a
//      bit      6 5 4 3 2 1 0
//    dot_on -- dots between segment 2 and 3
//
// Example:
//  defparam uu1.CLKFREQ = 96000000;
//  defparam uu1.BAUD    = 115200;
//	vbuf uu1(
//	.reset (Gl_rst),
//	.vram_clk (clk),
//	.data_in(lab2_Gl_tx_data[7:0]),
//	.data_in_rdy(lab2_Gl_tx_data_rdy),
//	.use_7_segment_code (1'b1),    
//	.segment1 (7'h7f),            
//	.segment2 (7'h7f),
//	.segment3 (7'h7f),
//	.segment4 (7'h7f),
//	.dot_on   (1'b1),
//	.alarm_on (1'b0),
//  .enable_pulling_mode(1'b0);
//  .data_sink_busy(urat_tx_busy),
//  .cont_write_en(1'b0), // or 1
//	.data_out(Gl_tx_data[7:0]),
//	.data_out_rdy(Gl_tx_data_rdy)
//	);
//==========================================================================


module vbuf(
input  wire reset /*synthesis syn_useioff = 0 */,          
input  wire vram_clk ,       

input  wire [7:0] data_in /* synthesis syn_force_pads=0 syn_noprune=1*/,  
input  wire data_in_rdy ,    

input  wire use_7_segment_code,
input  wire [6:0] segment1,
input  wire [6:0] segment2,
input  wire [6:0] segment3,
input  wire [6:0] segment4,
input  wire       dot_on,
input  wire       alarm_on,

input  wire enable_pulling_mode,  //1: calling module pull data, data_sink_busy becomes pull_strobe
input  wire data_sink_busy,       //0: vbug push data to calling module, data_sink_buy is busy signal 
input  wire cont_write_en,        //1: calling module will write multiple bytes of data in one data_in_rdy strobe
                                  //0: calling module will not write multiple bytes of data in one rdy strobe and could
								  //   generate a long strobe

output wire [7:0] data_out , 
output wire data_out_rdy
) ;

`define USE_USER_LIB
//`define USE_N_BIT_ADDER  


//@96MHz & 921600 baud, each byte (8 + 2 stop + 1 start) need 1045.83 cycles to go through UART
//@48MHz & 460800 baud, each byte also need 1045.83 cycles
//@24MHz & 230400 baud, each byte also need 1045.83 cycles
//@12MHz & 115200 baud, each byte also need 1045.83 cycles
parameter CLKFREQ  = 12000000;    // frequency of incoming signal 'clk'
parameter BAUD     =  115200;
`define BITS_PER_BYTE 10  //1 start, 2 stop bits
`define PAD_CYCLES    60
localparam CYCLES_PER_BYTE = ((CLKFREQ / BAUD) * `BITS_PER_BYTE) + `PAD_CYCLES; //11'd1100; //11'd1050; 
localparam CYCLES_PER_4_BITS = CYCLES_PER_BYTE/2;
localparam COUNT_WIDTH = $clog2(CYCLES_PER_4_BITS);
//localparam CYCLES_PER_BYTE = 11'd1100; //11'd1050; 
//localparam CYCLES_PER_4_BITS = 10'd550;
//localparam COUNT_WIDTH = 10;

//parameter for display
localparam BYTES_PER_RAW = 32;
localparam RAWS_4_USER = 2;
localparam RAWS_4_CLK = 14;
localparam LAST_BYTES_4_USER  = (RAWS_4_USER*BYTES_PER_RAW - 1);               //user can input 64 bytes
localparam LAST_BYTES_4_CLK = ((RAWS_4_CLK + RAWS_4_USER)* BYTES_PER_RAW - 1); //64 - 511 is for displaying clk

//----- Read Port: hold read data that is read from sb_ram
reg [8:0] r_addr;       // local FF
wire [8:0] r_addr_wire; // output to SRAM module
assign r_addr_wire [8:0] = r_addr [8:0];

reg [7:0] r_data_reg;   // local FF
wire [7:0] r_data_wire; // input from SRAM module
assign data_out[7:0] = r_data_reg [7:0];

reg  r_data_rdy;       // local FF 
assign data_out_rdy = r_data_rdy;


//------------------- use read strobe ---------------------------------------------

//------------------- use internal clock divider to slow down the read -------------------
//  vram_rd_clk_h_l -- latch r_data_reg -- data_out_rdy_h -- data_out_rdy_l(a pulse of 1 clk)-- trig_rd_h -- trig_rd_l (a short pulse) - vram_rd_clk_h 
// trig to update read port's address
// read clk
reg vram_rd_clk;

wire r_clk_en;
assign r_clk_en = 1'b1;
localparam rd_clk_init   =  1;  //start from high
// control the read operation
`define COUNT_WIDTHH  COUNT_WIDTH
localparam PRE_COUNTER_WIDTH = 4;
localparam PRE_COUNTER_MAX_NUMBER = 15;
localparam SECOND_COUNTER_WIDTH = COUNT_WIDTH - PRE_COUNTER_WIDTH;
reg [COUNT_WIDTH-1:0] l_count;  
reg l_count_15;

`ifdef USE_USER_LIB
`ifdef USE_N_BIT_ADDER

defparam vbuf_count.N = COUNT_WIDTH;
wire [COUNT_WIDTH-1:0] l_count_next;
N_bit_adder vbuf_count(
.sum (l_count_next[COUNT_WIDTH-1:0])   , // Output of the adder
.carry()                                              , // Carry output of adder
.r1 (l_count[COUNT_WIDTH-1:0])               , // first input
.r2 (COUNT_WIDTH'h001)                       , // second input
.ci (1'b0)                                              // carry input
);

`else  // ~USE_N_BIT_ADDER

wire [COUNT_WIDTH-1:0] l_count_next;
defparam vbuf_count.N = COUNT_WIDTH;
N_bit_counter vbuf_count(
.result (l_count_next[COUNT_WIDTH-1:0])       , // Output
.r1 (l_count[COUNT_WIDTH-1:0])               , // input
.up (1'b1)
);
`endif  // ~USE_N_BIT_ADDER
`else   // ~USE_USER_LIB
wire [COUNT_WIDTH-1:0] l_count_next = l_count +1;
`endif

//generate signal for reading 1-byte from the read port
localparam l_count_reset = CYCLES_PER_4_BITS - 15;
localparam l_count_reset_l_n = CYCLES_PER_4_BITS & 'h00f; ///(PRE_COUNTER_MAX_NUMBER+1) * (PRE_COUNTER_MAX_NUMBER+1);
localparam l_count_trig_rd = `PAD_CYCLES/8;
localparam l_count_init    = CYCLES_PER_4_BITS/2 + 1;
localparam l_count_rise_rdy = `PAD_CYCLES/8;
//localparam l_count_lower_rdy = l_count_reset - `PAD_CYCLES/4;
// trig rd address to advance by 1
wire trig_rd = ~((vram_rd_clk) | (|(l_count[COUNT_WIDTH-1:0] ^ l_count_trig_rd)));

always @(posedge vram_clk or posedge reset) begin
    if(reset) begin
        l_count <= l_count_init;
        vram_rd_clk <= rd_clk_init;
        l_count_15 <= 0;
    end
    else begin
        if(~|(l_count ^ l_count_reset)) begin
            vram_rd_clk <= ~vram_rd_clk;
			l_count[COUNT_WIDTH-1:0] <= 8'h00;
        end
		else begin
            l_count <= l_count_next; 
            vram_rd_clk <= vram_rd_clk;
		end
		
		if((~|(l_count ^ l_count_rise_rdy)) & (vram_rd_clk))
		    r_data_rdy <= 1;
		//else 
		//if(~|(l_count ^ l_count_lower_rdy) & (vram_rd_clk))
		//    r_data_rdy <= 0;
		else r_data_rdy <= 0; //r_data_rdy;
    end
end
//----- end of read signal generator
//----- latch in rd_data at the negedge of vram_rd_clk
reg [1:0] vram_rd_clk_det;
wire vram_rd_data_strob = vram_rd_clk_det[1] & ~vram_rd_clk_det[0];
wire [7:0] r_data_reg_next = (vram_rd_data_strob)? r_data_wire[7:0]: r_data_reg[7:0];

// latch in @ the negedge of vram_rd_clk
always @ (negedge vram_clk or posedge reset) begin
    if(reset) begin
        vram_rd_clk_det[1:0] <= 2'b11;//{rd_clk_init, rd_clk_init};
    end
	else begin
        vram_rd_clk_det[1:0] <= {vram_rd_clk_det[0], vram_rd_clk};
        r_data_reg[7:0] <= r_data_reg_next;
    end
end
//------- end of latch in rd_data
//-------  update r_addr @ the falling edge of vram_rd_clk 
`ifdef USE_USER_LIB
`ifdef USE_N_BIT_ADDER
wire [8:0] o_adder_vbuf_r_addr;
defparam vbuf_raddr.N = 9;
N_bit_adder vbuf_raddr(
.sum (o_adder_vbuf_r_addr[8:0])     , // Output of the adder
.carry()                            , // Carry output of adder
.r1 (r_addr)                        , // first input
.r2 (9'h001)                        , // second input
.ci (1'b0)                            // carry input
);

`else // ~ USE_N_BIT_ADDER
wire [8:0] o_adder_vbuf_r_addr;
defparam vbuf_raddr.N = 9;
N_bit_counter vbuf_raddr(
.result (o_adder_vbuf_r_addr)     , // Output
.r1 (r_addr)                      , // input
.up (1'b1)
);
`endif // ~USE_N_BIT_ADDER
`endif // USE_USER_LIB

reg [1:0] trig_rd_det;
wire trig_rd_is_det = trig_rd_det[0] & ~trig_rd_det[1]; 
`ifdef USE_USER_LIB
wire [8:0] r_addr_next = (trig_rd_is_det)? o_adder_vbuf_r_addr[8:0]: r_addr[8:0];  
`else
wire [8:0] r_addr_next = (trig_rd_is_det)? r_addr + 1: r_addr[8:0];  
`endif

//always @(posedge trig_rd) begin
always @(posedge vram_clk) begin
    if(reset) begin
	    r_addr <= 0;
        trig_rd_det <= 0;
    end
	else begin
       trig_rd_det[1:0] <= {trig_rd_det[0], trig_rd};
       r_addr <= r_addr_next;
    end
end
//---------- end of update rd_addr

//---------- write port
//wire vram_wr_clk;
//assign vram_wr_clk = vram_clk; //l_count[3];
// address -- address 0-63 for user input
//                    64 - 509 for displying clk
reg       w_user_data_rdy;
reg [7:0] w_user_data_in;
reg       w_user_cr;
reg       w_user_lf;

reg [8:0] w_addr_user, w_addr_displaying;
wire [7:0] w_data_user = w_user_data_in[7:0];

always @ *//(posedge vram_clk)
begin
        w_user_cr = (~|(data_in ^ 8'h0D));
        w_user_lf = (~|(data_in ^ 8'h0A));
        w_user_data_rdy = (w_user_cr|w_user_cr)? 0 : data_in_rdy;
        w_user_data_in = data_in;
end

// bitmap [(512-64):0] for displaying clock
`define BUFFER_BITMAP
`ifdef BUFFER_BITMAP
reg [BYTES_PER_RAW*RAWS_4_CLK-1:0] bitmap;
`else
wire [BYTES_PER_RAW*RAWS_4_CLK-1:0] bitmap;
//a
assign bitmap[ 37: 34] = {segment4[0], segment4[0], segment4[0], segment4[0]}; //(segment4[0])? 4'hf: 4'h0;	
assign bitmap[ 43: 40] = {segment3[0], segment3[0], segment3[0], segment3[0]}; //(segment3[0])? 4'hf: 4'h0; 
assign bitmap[ 55: 52] = {segment2[0], segment2[0], segment2[0], segment2[0]}; //(segment2[0])? 4'hf: 4'h0; 	
assign bitmap[ 61: 58] = {segment1[0], segment1[0], segment1[0], segment1[0]}; //(segment1[0])? 4'hf: 4'h0;	
        
//f
assign bitmap[ 66] = segment4[5]; //(segment4[5])? 1'b1: 1'b0;	
assign bitmap[ 98] = segment4[5]; //(segment4[5])? 1'b1: 1'b0;	
assign bitmap[130] = segment4[5]; //(segment4[5])? 1'b1: 1'b0;	

assign bitmap[ 72] = segment3[5]; //(segment3[5])? 1'b1: 1'b0;	
assign bitmap[104] = segment3[5]; //(segment3[5])? 1'b1: 1'b0;	
assign bitmap[136] = segment3[5]; //(segment3[5])? 1'b1: 1'b0;	
		
assign bitmap[ 84] = segment2[5]; //(segment2[5])? 1'b1: 1'b0;	
assign bitmap[116] = segment2[5]; //(segment2[5])? 1'b1: 1'b0;	
assign bitmap[148] = segment2[5]; //(segment2[5])? 1'b1: 1'b0;	
		
assign bitmap[ 90] = segment1[5]; //(segment1[5])? 1'b1: 1'b0;	
assign bitmap[122] = segment1[5]; //(segment1[5])? 1'b1: 1'b0;	
assign bitmap[154] = segment1[5]; //(segment1[5])? 1'b1: 1'b0;	

//e
assign bitmap[194] = segment4[4]; //(segment4[4])? 1'b1: 1'b0;	
assign bitmap[226] = segment4[4]; //(segment4[4])? 1'b1: 1'b0;	
assign bitmap[258] = segment4[4]; //(segment4[4])? 1'b1: 1'b0;	

assign bitmap[200] = segment3[4]; //(segment3[4])? 1'b1: 1'b0;	
assign bitmap[232] = segment3[4]; //(segment3[4])? 1'b1: 1'b0;	
assign bitmap[264] = segment3[4]; //(segment3[4])? 1'b1: 1'b0;	
		
assign bitmap[212] = segment2[4]; //(segment2[4])? 1'b1: 1'b0;	
assign bitmap[244] = segment2[4]; //(segment2[4])? 1'b1: 1'b0;	
assign bitmap[276] = segment2[4]; //(segment2[4])? 1'b1: 1'b0;	
		
assign bitmap[218] = segment1[4]; //(segment1[4])? 1'b1: 1'b0;	
assign bitmap[250] = segment1[4]; //(segment1[4])? 1'b1: 1'b0;	
assign bitmap[282] = segment1[4]; //(segment1[4])? 1'b1: 1'b0;	
		
//d
assign bitmap[293:290] = {segment4[3], segment4[3], segment4[3], segment4[3]};//(segment4[3])? 4'hf: 4'h0;	
assign bitmap[299:296] = {segment3[3], segment3[3], segment3[3], segment3[3]};//(segment3[3])? 4'hf: 4'h0; 
assign bitmap[311:308] = {segment2[3], segment2[3], segment2[3], segment2[3]};//(segment2[3])? 4'hf: 4'h0; 	
assign bitmap[317:314] = {segment1[3], segment1[3], segment1[3], segment1[3]};//(segment1[3])? 4'hf: 4'h0;	

//c
assign bitmap[197] = segment4[2]; //(segment4[2])? 1'b1: 1'b0;	
assign bitmap[229] = segment4[2]; //(segment4[2])? 1'b1: 1'b0;	
assign bitmap[261] = segment4[2]; //(segment4[2])? 1'b1: 1'b0;	

assign bitmap[203] = segment3[2]; //(segment3[2])? 1'b1: 1'b0;	
assign bitmap[235] = segment3[2]; //(segment3[2])? 1'b1: 1'b0;	
assign bitmap[267] = segment3[2]; //(segment3[2])? 1'b1: 1'b0;	
		
assign bitmap[215] = segment2[2]; //(segment2[2])? 1'b1: 1'b0;	
assign bitmap[247] = segment2[2]; //(segment2[2])? 1'b1: 1'b0;	
assign bitmap[279] = segment2[2]; //(segment2[2])? 1'b1: 1'b0;	
		
assign bitmap[221] = segment1[2]; //(segment1[2])? 1'b1: 1'b0;	
assign bitmap[253] = segment1[2]; //(segment1[2])? 1'b1: 1'b0;	
assign bitmap[285] = segment1[2]; //(segment1[2])? 1'b1: 1'b0;	
		
//b
assign bitmap[ 69] = segment4[1]; //(segment4[1])? 1'b1: 1'b0;	
assign bitmap[101] = segment4[1]; //(segment4[1])? 1'b1: 1'b0;	
assign bitmap[133] = segment4[1]; //(segment4[1])? 1'b1: 1'b0;	
		
assign bitmap[ 75] = segment3[1]; //(segment3[1])? 1'b1: 1'b0;	
assign bitmap[107] = segment3[1]; //(segment3[1])? 1'b1: 1'b0;	
assign bitmap[139] = segment3[1]; //(segment3[1])? 1'b1: 1'b0;	
		
assign bitmap[ 87] = segment2[1]; //(segment2[1])? 1'b1: 1'b0;	
assign bitmap[119] = segment2[1]; //(segment2[1])? 1'b1: 1'b0;	
assign bitmap[151] = segment2[1]; //(segment2[1])? 1'b1: 1'b0;	
		
assign bitmap[ 93] = segment1[1]; //(segment1[1])? 1'b1: 1'b0;	
assign bitmap[125] = segment1[1]; //(segment1[1])? 1'b1: 1'b0;	
assign bitmap[157] = segment1[1]; //(segment1[1])? 1'b1: 1'b0;	

		
//g
assign bitmap[165:162] = {segment4[6], segment4[6], segment4[6], segment4[6]}; //(segment4[6])? 4'hf: 4'h0;	
assign bitmap[171:168] = {segment3[6], segment3[6], segment3[6], segment3[6]}; //(segment3[6])? 4'hf: 4'h0; 	
assign bitmap[183:180] = {segment2[6], segment2[6], segment2[6], segment2[6]}; //(segment2[6])? 4'hf: 4'h0; 	
assign bitmap[189:186] = {segment1[6], segment1[6], segment1[6], segment1[6]}; //(segment1[6])? 4'hf: 4'h0;	
		
//dot_on
assign bitmap[112:111] = {dot_on, dot_on}; //(dot_on)? 2'b11: 2'b00;	
assign bitmap[144:143] = {dot_on, dot_on}; //(dot_on)? 2'b11: 2'b00;	
assign bitmap[208:207] = {dot_on, dot_on}; //(dot_on)? 2'b11: 2'b00;	
assign bitmap[240:239] = {dot_on, dot_on}; //(dot_on)? 2'b11: 2'b00;	
`endif

wire [7:0] w_data_displaying;
wire [8:0] w_bitmap_indx;
assign w_bitmap_indx = w_addr_displaying - 9'd64;
assign w_data_displaying[7:0] = (w_addr_displaying == 511)? 8'h48 :
                                (w_addr_displaying == 510)? 8'h5b :
                                (w_addr_displaying == 509)?  8'h1b:
                                (bitmap[w_bitmap_indx]) ? 8'h2a : 8'h20;             


// wr_en starts from the negtive edge of vram_clk
// and is held till w_user_data_rdy goes down
reg [1:0]   vram_wr_tap_4_user;
wire        vram_wr_4_user_en;
assign vram_wr_4_user_en = w_user_data_rdy;//TST & ((~vram_clk) | vram_wr_tap_4_user[0]); // start from negative edge 

wire        vram_wr_4_clk_en;
assign vram_wr_4_clk_en = (use_7_segment_code) & (~vram_clk); // start from negative edge 

`ifdef USE_USER_LIB
`ifdef USE_N_BIT_ADDER
wire [8:0] o_adder_vbuf_w_addr_user;
defparam vbuf_w_addr_user.N = 9;
N_bit_adder vbuf_w_addr_user(
.sum (o_adder_vbuf_w_addr_user)     , // Output of the adder
.carry()                            , // Carry output of adder
.r1 (w_addr_user)                   , // first input
.r2 (9'h001)                        , // second input
.ci (1'b0)                            // carry input
);


wire [8:0] o_adder_vbuf_w_addr_displaying;
defparam vbuf_w_addr_displaying.N = 9;
N_bit_adder vbuf_w_addr_displaying(
.sum (o_adder_vbuf_w_addr_displaying)     , // Output of the adder
.carry()                                      , // Carry output of adder
.r1 (w_addr_displaying)                   , // first input
.r2 (9'h001)                                  , // second input
.ci (1'b0)                                      // carry input
);

`else // ~USE_N_BIT_ADDER
wire [8:0] o_adder_vbuf_w_addr_user;
defparam vbuf_w_addr_user.N = 9;
N_bit_counter vbuf_w_addr_user(
.result (o_adder_vbuf_w_addr_user)     , // Output of the adder
.r1 (w_addr_user)                      , // first input
.up (1'b1)
);

wire [8:0] o_adder_vbuf_w_addr_displaying;
defparam vbuf_w_addr_displaying.N = 9;
N_bit_counter vbuf_w_addr_displaying(
.result (o_adder_vbuf_w_addr_displaying)     , // Output
.r1 (w_addr_displaying)                      , // input
.up (1'b1)
);
`endif //USE_N_BIT_ADDER
`endif //USE_USER_LIB

wire det_rdy_edge = (cont_write_en)? w_user_data_rdy: (vram_wr_tap_4_user[0] & ~vram_wr_tap_4_user[1]);
wire not_special_char = ~(w_user_cr | w_user_lf);

always @(negedge vram_clk) begin
    if(reset) begin
        w_addr_user <= 9'h000;
        w_addr_displaying <= 9'd64;
        vram_wr_tap_4_user[1:0] <= 2'b00;
        
`ifdef BUFFER_BITMAP
        bitmap[ 31:  0] <= 32'h00000000;
        bitmap[ 63: 32] <= 32'h00000000;//32'h3cf00f3c;
        bitmap[ 95: 64] <= 32'h00000000;//32'h24900924;
        bitmap[127: 96] <= 32'h00000000;//32'h24918924;
        bitmap[159:128] <= 32'h00000000;//32'h24918924;
        bitmap[191:160] <= 32'h00000000;//32'h3cf00f3c;
        bitmap[223:192] <= 32'h00000000;//32'h24918924;
        bitmap[255:224] <= 32'h00000000;//32'h24918924;
        bitmap[287:256] <= 32'h00000000;//32'h24900924;
        bitmap[319:288] <= 32'h00000000;//32'h3cf00f3c;
        bitmap[351:320] <= 32'h00000000;
        bitmap[383:352] <= 32'h00000000;
        bitmap[415:384] <= 32'h00000000;
        bitmap[447:416] <= 32'h00000000;
`endif

    end
    else begin
       vram_wr_tap_4_user[1:0] <= {vram_wr_tap_4_user[0], w_user_data_rdy};
		
       w_addr_user <= ((use_7_segment_code) & (w_addr_user == LAST_BYTES_4_USER+1))? 0 : 

`ifdef USE_USER_LIB
                        (det_rdy_edge & not_special_char)? o_adder_vbuf_w_addr_user : //w_addr_user + 1 :
`else
                        (det_rdy_edge & not_special_char)? w_addr_user + 1 :
`endif
                      (w_user_cr) ?  9'h000:
                      (w_user_lf) ?  9'h000:
                      w_addr_user;
						
        // this 9-bit adder has the shortest time to finish.  can only operate at 48MHz using the ripple carry adder
        w_addr_displaying  <= (w_addr_displaying == LAST_BYTES_4_CLK)? 9'd64 :
`ifdef USE_USER_LIB
                                  (~vram_wr_4_user_en & use_7_segment_code)? o_adder_vbuf_w_addr_displaying[8:0] :  //w_addr_displaying + 1: //
`else
                                  (~vram_wr_4_user_en & use_7_segment_code)? w_addr_displaying + 1: //
`endif
                                                                             w_addr_displaying;
		
`ifdef BUFFER_BITMAP
        //a
        bitmap[ 37: 34] <= (segment4[0])? 4'hf: 4'h0;	

        bitmap[ 43: 40] <= (segment3[0])? 4'hf: 4'h0; 
		
        bitmap[ 55: 52] <= (segment2[0])? 4'hf: 4'h0; 	
		
        bitmap[ 61: 58] <= (segment1[0])? 4'hf: 4'h0;	
        
		//f
        bitmap[ 66] <= (segment4[5])? 1'b1: 1'b0;	
        bitmap[ 98] <= (segment4[5])? 1'b1: 1'b0;	
        bitmap[130] <= (segment4[5])? 1'b1: 1'b0;	

        bitmap[ 72] <= (segment3[5])? 1'b1: 1'b0;	
        bitmap[104] <= (segment3[5])? 1'b1: 1'b0;	
        bitmap[136] <= (segment3[5])? 1'b1: 1'b0;	
		
        bitmap[ 84] <= (segment2[5])? 1'b1: 1'b0;	
        bitmap[116] <= (segment2[5])? 1'b1: 1'b0;	
        bitmap[148] <= (segment2[5])? 1'b1: 1'b0;	
		
        bitmap[ 90] <= (segment1[5])? 1'b1: 1'b0;	
        bitmap[122] <= (segment1[5])? 1'b1: 1'b0;	
        bitmap[154] <= (segment1[5])? 1'b1: 1'b0;	

		//e
        bitmap[194] <= (segment4[4])? 1'b1: 1'b0;	
        bitmap[226] <= (segment4[4])? 1'b1: 1'b0;	
        bitmap[258] <= (segment4[4])? 1'b1: 1'b0;	

        bitmap[200] <= (segment3[4])? 1'b1: 1'b0;	
        bitmap[232] <= (segment3[4])? 1'b1: 1'b0;	
        bitmap[264] <= (segment3[4])? 1'b1: 1'b0;	
		
        bitmap[212] <= (segment2[4])? 1'b1: 1'b0;	
        bitmap[244] <= (segment2[4])? 1'b1: 1'b0;	
        bitmap[276] <= (segment2[4])? 1'b1: 1'b0;	
		
        bitmap[218] <= (segment1[4])? 1'b1: 1'b0;	
        bitmap[250] <= (segment1[4])? 1'b1: 1'b0;	
        bitmap[282] <= (segment1[4])? 1'b1: 1'b0;	
		
        //d
        bitmap[293:290] <= (segment4[3])? 4'hf: 4'h0;	

        bitmap[299:296] <= (segment3[3])? 4'hf: 4'h0; 
		
        bitmap[311:308] <= (segment2[3])? 4'hf: 4'h0; 	
		
        bitmap[317:314] <= (segment1[3])? 4'hf: 4'h0;	

		//c
        bitmap[197] <= (segment4[2])? 1'b1: 1'b0;	
        bitmap[229] <= (segment4[2])? 1'b1: 1'b0;	
        bitmap[261] <= (segment4[2])? 1'b1: 1'b0;	

        bitmap[203] <= (segment3[2])? 1'b1: 1'b0;	
        bitmap[235] <= (segment3[2])? 1'b1: 1'b0;	
        bitmap[267] <= (segment3[2])? 1'b1: 1'b0;	
		
        bitmap[215] <= (segment2[2])? 1'b1: 1'b0;	
        bitmap[247] <= (segment2[2])? 1'b1: 1'b0;	
        bitmap[279] <= (segment2[2])? 1'b1: 1'b0;	
		
        bitmap[221] <= (segment1[2])? 1'b1: 1'b0;	
        bitmap[253] <= (segment1[2])? 1'b1: 1'b0;	
        bitmap[285] <= (segment1[2])? 1'b1: 1'b0;	
		
		//b
        bitmap[ 69] <= (segment4[1])? 1'b1: 1'b0;	
        bitmap[101] <= (segment4[1])? 1'b1: 1'b0;	
        bitmap[133] <= (segment4[1])? 1'b1: 1'b0;	
		
        bitmap[ 75] <= (segment3[1])? 1'b1: 1'b0;	
        bitmap[107] <= (segment3[1])? 1'b1: 1'b0;	
        bitmap[139] <= (segment3[1])? 1'b1: 1'b0;	
		
        bitmap[ 87] <= (segment2[1])? 1'b1: 1'b0;	
        bitmap[119] <= (segment2[1])? 1'b1: 1'b0;	
        bitmap[151] <= (segment2[1])? 1'b1: 1'b0;	
		
        bitmap[ 93] <= (segment1[1])? 1'b1: 1'b0;	
        bitmap[125] <= (segment1[1])? 1'b1: 1'b0;	
        bitmap[157] <= (segment1[1])? 1'b1: 1'b0;	

		
        //g
		bitmap[165:162] <= (segment4[6])? 4'hf: 4'h0;	

        bitmap[171:168] <= (segment3[6])? 4'hf: 4'h0; 	
		
        bitmap[183:180] <= (segment2[6])? 4'hf: 4'h0; 	
 		
        bitmap[189:186] <= (segment1[6])? 4'hf: 4'h0;	
		
		//dot_on
        bitmap[112:111] <= (dot_on)? 2'b11: 2'b00;	
        bitmap[144:143] <= (dot_on)? 2'b11: 2'b00;	
        bitmap[208:207] <= (dot_on)? 2'b11: 2'b00;	
        bitmap[240:239] <= (dot_on)? 2'b11: 2'b00;	
`endif
	
	end

end

wire vram_wr_en;
assign vram_wr_en = vram_wr_4_user_en | vram_wr_4_clk_en;
wire [8:0] w_addr; 
assign w_addr[8:0] = (vram_wr_4_user_en)? w_addr_user [8:0] : w_addr_displaying[8:0];
wire [7:0] w_data;
assign w_data [7:0] = (vram_wr_4_user_en)? w_data_user[7:0] : w_data_displaying[7:0];
 
latticeDulPortRam512x8 mem0(
.RDATA_c(r_data_wire[7:0]),  //7:0
.RADDR_c(r_addr_wire[8:0]),  //8:0
.RCLK_c(vram_clk),        //vram_rd_clk),
.RCLKE_c(r_clk_en),
.RE_c(1'b1),

.WADDR_c(w_addr[8:0]),
.WCLK_c (vram_clk), //vram_wr_clk),
.WCLKE_c(vram_wr_en),
.WDATA_c(w_data[7:0]),
.WE_c (vram_wr_en)
);
endmodule

//--------------------------------
module latticeDulPortRam512x8(
output wire [7:0] RDATA_c,
input wire [8:0] RADDR_c,
input wire RCLK_c,
input wire RCLKE_c,
input wire RE_c,


input wire [8:0] WADDR_c,
input wire WCLK_c,
input wire WCLKE_c,
input wire [7:0] WDATA_c,
input wire WE_c
);

SB_RAM512x8 #(
//`define TEST_PAINT_SB_RAM
`ifdef TEST_PAINT_SB_RAM
.INIT_0 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_1 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_2 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_3 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_4 (256'h20202a2a2a2a20202a2a2a2a20202020202020202a2a2a2a20202a2a2a2a2020),
.INIT_5 (256'h20202a20202a20202a20202a20202020202020202a20202a20202a20202a2020),
.INIT_6 (256'h20202a20202a20202a20202a2020202a2a2020202a20202a20202a20202a2020),
.INIT_7 (256'h20202a20202a20202a20202a2020202a2a2020202a20202a20202a20202a2020),
.INIT_8 (256'h20202a2a2a2a20202a2a2a2a20202020202020202a2a2a2a20202a2a2a2a2020),
.INIT_9 (256'h20202a20202a20202a20202a20202020202020202a20202a20202a20202a2020),
.INIT_A (256'h20202a20202a20202a20202a2020202a2a2020202a20202a20202a20202a2020),
.INIT_B (256'h20202a20202a20202a20202a2020202a2a2020202a20202a20202a20202a2020),
.INIT_C (256'h20202a2a2a2a20202a2a2a2a20202020202020202a2a2a2a20202a2a2a2a2020),
.INIT_D (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_E (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_F (256'h485b1b2020202020202020202020202020202020202020202020202020202020)
`else
.INIT_0 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_1 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_2 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_3 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_4 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_5 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_6 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_7 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_8 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_9 (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_A (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_B (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_C (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_D (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_E (256'h2020202020202020202020202020202020202020202020202020202020202020),
.INIT_F (256'h2020202020202020202020202020202020202020202020202020202020202020)
`endif
) 
ram512X8_inst (
.RADDR(RADDR_c),
.RCLK(RCLK_c),
.RCLKE(RCLKE_c),
.RDATA(RDATA_c), 
.RE(RE_c),

.WADDR(WADDR_c),
.WCLK(WCLK_c),
.WCLKE(WCLKE_c),
.WDATA(WDATA_c),
.WE(WE_c)
)/* synthesis syn_noprune=1 */;

endmodule

