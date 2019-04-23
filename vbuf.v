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
//
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

input  wire enable_async_read,  //1: use read data signal, 0: divide clk freq and output slowly
input  wire read_strobe,        // read at the rising edge of this signal
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
localparam CYCLES_PER_BYTE = ((`CLKFREQ / `BAUD) * `BITS_PER_BYTE) + 60; //11'd1100; //11'd1050; 
//parameter for display
localparam BYTES_PER_RAW = 32;
localparam RAWS_4_USER = 2;
localparam RAWS_4_CLK = 14;
localparam LAST_BYTES_4_USER  = (RAWS_4_USER*BYTES_PER_RAW - 1);               //user can input 64 bytes
//parameter LAST_BYTES_4_CLK = ((RAWS_4_CLK + RAWS_4_USER)* BYTES_PER_RAW - 3 - 1); //64 - 508 is for displaying clk
localparam LAST_BYTES_4_CLK = ((RAWS_4_CLK + RAWS_4_USER)* BYTES_PER_RAW - 1); //64 - 511 is for displaying clk

// hold data read from sb_ram
reg [8:0] r_addr;
wire [8:0] r_addr_wire;
assign r_addr_wire [8:0] = r_addr [8:0];
reg [7:0] r_data_reg;
wire [7:0] r_data_wire;
assign data_out[7:0] = r_data_reg [7:0];

//------------------- use read strobe ---------------------------------------------

//------------------- use internal clock divider to slow down the read -------------------
// control the read clk
reg [10:0] l_count;  

wire [10:0] cycles_per_byte = CYCLES_PER_BYTE;

`ifdef USE_USER_LIB

`ifdef USE_N_BIT_ADDER
defparam vbuf_count.N = 11;
wire [10:0] o_adder_vbuf_count;
N_bit_adder vbuf_count(
.sum (o_adder_vbuf_count[10:0])   , // Output of the adder
.carry()                          , // Carry output of adder
.r1 (l_count[10:0])               , // first input
.r2 (11'h001)                        , // second input
.ci (1'b0)                            // carry input
);

`else  // ~USE_N_BIT_ADDER
wire [10:0] o_adder_vbuf_count;
defparam vbuf_count.N = 11;
N_bit_counter vbuf_count(
.result (o_adder_vbuf_count)       , // Output
.r1 (l_count)                      , // input
.up (1'b1)
);
`endif  // ~USE_N_BIT_ADDER
`endif  // USE_USER_LIB
//generate clk for reading 1-byte from the read port
always @(posedge vram_clk) begin
    if(reset | enable_async_read) begin
        l_count <= 0;
    end
    else begin
        if(l_count[10:0] == cycles_per_byte)
            l_count <= 0;
        else 
`ifdef USE_USER_LIB
            l_count[10:0] <= o_adder_vbuf_count[10:0]; 
`else
            l_count[10:0] <= l_count+1; //o_adder_vbuf_count[10:0]; //
`endif
    end
end

//  trig_rd_h -- trig_rd_l - data_out_rdy_h .... data_out_rdy_l
assign data_out_rdy = l_count [10]; 

wire trig_rd;
assign trig_rd = (&l_count[9:1]) & (~l_count[10]);

// slow down read clk
wire vram_rd_clk;
assign vram_rd_clk = l_count[4];
//reg [1:0] vram_rd_clk_det;
// latch in @ the negedge of read clk
always @(negedge vram_rd_clk) begin
//always @ (negedge vram_clk) begin
//    vram_rd_clk_det[1:0] = {vram_rd_clk_det[0], vram_rd_clk};
    
//    r_data_reg[7:0] <= (vram_rd_clk_det[0] & ~vram_rd_clk_det[1])? r_data_wire[7:0]: r_data_reg[7:0];
    r_data_reg[7:0] <= r_data_wire[7:0];
end
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
//always @(posedge trig_rd) begin
always @(posedge vram_clk) begin
    if(reset)
	    r_addr <= 0;
	else
       trig_rd_det[1:0] = {trig_rd_det[0], trig_rd};
`ifdef USE_USER_LIB
        r_addr[8:0] <=  (trig_rd_det[0] & ~trig_rd_det[1])? o_adder_vbuf_r_addr[8:0]: r_addr[8:0]; 
        //r_addr[8:0] <=  o_adder_vbuf_r_addr[8:0]; 
`else
        r_addr[8:0] <=  (trig_rd_det[0] & ~trig_rd_det[1])? r_addr + 1: r_addr[8:0]; 
        //r_addr[8:0] <=  r_addr + 1; 
`endif
end

//---------- write port
//wire vram_wr_clk;
//assign vram_wr_clk = vram_clk; //l_count[3];
// address -- address 0-63 for user input
//                    64 - 509 for displying clk
reg       w_user_data_rdy;
reg [7:0] w_user_data;
reg       w_user_cr;
reg       w_user_lf;

reg [8:0] w_addr_user, w_addr_displaying_clk;
wire [7:0] w_data_user = w_user_data[7:0];

always @*// (posedge vram_clk)
begin
        w_user_data_rdy = 0;
        w_user_cr = 0;
        w_user_lf = 0;
        w_user_data[7:0] = 8'h00;

        if(~(|data_in[7:4]) & data_in[3] & data_in[2] & (~data_in[1]) & data_in[0])     //  == 8'h0D) begin    //CR
            w_user_cr = 1;
		else 
		if (~(|data_in[7:4]) & data_in[3] & (~data_in[2]) & data_in[1] & (~data_in[0])) //  == 8'h0A) begin    //LF
            w_user_lf = 1;
		else
		begin
            w_user_data_rdy = data_in_rdy;
            w_user_data[7:0] = data_in[7:0];
		end
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

wire [7:0] w_data_displaying_clk;
wire [8:0] w_bitmap_indx;
assign w_bitmap_indx = w_addr_displaying_clk - 9'd64;
assign w_data_displaying_clk[7:0] = (w_addr_displaying_clk == 511)? 8'h48 :
                                    (w_addr_displaying_clk == 510)? 8'h5b :
                                    (w_addr_displaying_clk == 509)?  8'h1b:
                                    (bitmap[w_bitmap_indx]) ? 8'h2a : 8'h20;             


// wr_en starts from the negtive edge of vram_clk
// and is held till w_user_data_rdy goes down
reg [1:0]   vram_wr_tap_4_user;
wire        vram_wr_4_user_en;
assign vram_wr_4_user_en = w_user_data_rdy & ((~vram_clk) | vram_wr_tap_4_user[0]); // start from negative edge 

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


wire [8:0] o_adder_vbuf_w_addr_displaying_clk;
defparam vbuf_w_addr_displaying_clk.N = 9;
N_bit_adder vbuf_w_addr_displaying_clk(
.sum (o_adder_vbuf_w_addr_displaying_clk)     , // Output of the adder
.carry()                                      , // Carry output of adder
.r1 (w_addr_displaying_clk)                   , // first input
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

wire [8:0] o_adder_vbuf_w_addr_displaying_clk;
defparam vbuf_w_addr_displaying_clk.N = 9;
N_bit_counter vbuf_w_addr_displaying_clk(
.result (o_adder_vbuf_w_addr_displaying_clk)     , // Output
.r1 (w_addr_displaying_clk)                      , // input
.up (1'b1)
);
`endif //USE_N_BIT_ADDER
`endif //USE_USER_LIB
always @(negedge vram_clk) begin
    if(reset) begin
        w_addr_user <= 9'h000;
        w_addr_displaying_clk <= 9'd64;
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
                        (vram_wr_tap_4_user[0] & ~vram_wr_tap_4_user[1] & ~w_user_cr & ~w_user_lf)? o_adder_vbuf_w_addr_user : //w_addr_user + 1 :
`else
                        (vram_wr_tap_4_user[0] & ~vram_wr_tap_4_user[1] & ~w_user_cr & ~w_user_lf)? w_addr_user + 1 :
`endif
                        (w_user_cr) ?  9'h000:
                        (w_user_lf) ?  9'h000:
                         w_addr_user;
						
        // this 9-bit adder has the shortest time to finish.  can only operate at 48MHz using the ripple carry adder
        w_addr_displaying_clk  <= (w_addr_displaying_clk == LAST_BYTES_4_CLK)? 9'd64 :
`ifdef USE_USER_LIB
                                  (~vram_wr_4_user_en & use_7_segment_code)? o_adder_vbuf_w_addr_displaying_clk[8:0] :  //w_addr_displaying_clk + 1: //
`else
                                  (~vram_wr_4_user_en & use_7_segment_code)? w_addr_displaying_clk + 1: //
`endif
                                                                             w_addr_displaying_clk;
		
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
assign w_addr[8:0] = (vram_wr_4_user_en)? w_addr_user [8:0] : w_addr_displaying_clk[8:0];
wire [7:0] w_data;
assign w_data [7:0] = (vram_wr_4_user_en)? w_data_user[7:0] : w_data_displaying_clk[7:0];
 
latticeDulPortRam512x8 mem0(
.RDATA_c(r_data_wire[7:0]),  //7:0
.RADDR_c(r_addr_wire[8:0]),        //8:0
.RCLK_c(vram_rd_clk), //vram_rd_clk),
.RCLKE_c(1'b1),
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

