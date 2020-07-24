module QLM_w6q8(
    input [15:0] x,
    input [15:0] y,
    output [31:0] p
    );
    
    // X branch 

    // First complement 
    wire [15:0] x_abs;
    assign x_abs = x ^ {16{x[15]}};
    
    // LOD + Priority Encoder
    wire [15:0] k_x0;
    wire zero_x0;
    wire [3:0] k_x0_enc;

    LOD16 lod_x0(
        .data_i(x_abs),
        .zero_o(zero_x0),
        .data_o(k_x0),
        .data_enc(k_x0_enc));
       
    // LBarrel 
    wire [4:0] x_shift;

    LBarrel Lshift_x0(
        .data_i(x_abs),
        .shift_i(k_x0),
        .data_o(x_shift));
        
    // Y branch 
    
    // First complement 
    wire [15:0] y_abs;
    assign y_abs = y ^ {16{y[15]}};
    
    // LOD + Priority Encoder
    wire [15:0] k_y0;
    wire zero_y0;
    wire [3:0] k_y0_enc;
    
    LOD16 lod_y0(
        .data_i(y_abs),
        .zero_o(zero_y0),
        .data_o(k_y0),
        .data_enc(k_y0_enc));
      
    // LBarrel 
    wire [4:0] y_shift;
    
    LBarrel Lshift_y0(
        .data_i(y_abs),
        .shift_i(k_y0),
        .data_o(y_shift));

    // Addition 
    wire [9:0] x_log;
    wire [9:0] y_log;
    wire [9:0] p_log;
    
    assign x_log = {1'b0,k_x0_enc,x_shift};
    assign y_log = {1'b0,k_y0_enc,y_shift};

    assign p_log = x_log + y_log;

    // Antilogarithm stage
    wire [21:0] p_l1b;
    wire [5:0] l1_input;
    
    assign l1_input = {1'b1,p_log[4:0]};
   
    L1Barrel L1shift_plog(
        .data_i(l1_input),
        .shift_i(p_log[8:5]),
        .data_o(p_l1b));
    // Low part 

    // Low part of product 
    wire [10:0] p_low;
    wire not_k_l5 = ~p_log[9];
    
    assign p_low = p_l1b[15:5] & {11{not_k_l5}};
    
    // Medium part of product 
    
    wire [5:0] p_med;
    
    assign p_med = p_log[9] ? p_l1b[5:0] : p_l1b[21:16];
    
    // High part of product 
    
    wire [14:0] p_high;

    assign p_high = p_l1b[20:6] & {15{p_log[9]}};
    // Final product
    
    wire [31:0] PP_abs;
    assign PP_abs = {p_high,p_med,p_low};

    // Sign conversion 
    wire p_sign;
    wire [31:0] PP_temp;
    
    
    assign p_sign = x[15] ^ y[15];
    assign PP_temp = PP_abs ^ {32{p_sign}};
    
    //Zero mux0
    wire notZeroA, notZeroB, notZeroD;
    assign notZeroA = ~zero_x0 ;
    assign notZeroB = ~zero_y0 ;
    assign notZeroD = notZeroA & notZeroB;
    
    assign p = notZeroD? PP_temp : 32'b0;

endmodule

module LOD16(
    input [15:0] data_i,
    output zero_o,
    output [15:0] data_o,
    output [3:0] data_enc
    );
	
    wire [15:0] z;
    wire [3:0] zdet;
    wire [3:0] select;
    //*****************************************
    // Zero detection logic:
    //*****************************************
    assign zdet[3] = |(data_i[15:12]);
    assign zdet[2] = |(data_i[11:8]) ;
    assign zdet[1] = 1'b0 ;
    assign zdet[0] = 1'b0;
    assign zero_o = ~( zdet[3]  | zdet[2] );
    //*****************************************
    // LODs:
    //*****************************************
    LOD4 lod4_2 (
        .data_i(data_i[15:12]), 
        .data_o(z[15:12])
    );

    LOD4 lod4_1 (
        .data_i(data_i[11:8]), 
        .data_o(z[11:8])
    );

    assign z[7:0] = 8'b0;
    //*****************************************
    // Select signals
    //*****************************************    
    LOD2 Middle(
        .data_i(zdet[3:2]), 
        .data_o(select[3:2])       
    );
    assign select[1:0] = 2'b0;

	 //*****************************************
	 // Multiplexers :
	 //*****************************************
	wire [11:0] tmp_out;
	
    Muxes2in1Array4 Inst_MUX214_3 (
        .data_i(z[15:12]), 
        .select_i(select[3]), 
        .data_o(tmp_out[11:8])
    );


	Muxes2in1Array4 Inst_MUX214_2 (
        .data_i(z[11:8]), 
        .select_i(select[2]), 
        .data_o(tmp_out[7:4])
    );


    assign tmp_out[3:0] = 4'b0;

    // Enconding
    wire [2:0] low_enc; 
    assign low_enc = tmp_out[7:5] | tmp_out[11:9];


    assign data_enc[3] = select[3] | select[2];
    assign data_enc[2] = select[3] | select[1];
    assign data_enc[1] = low_enc[2] | low_enc[1];
    assign data_enc[0] = low_enc[2] | low_enc[0];


    // One hot
    assign data_o[15:4] = tmp_out;
    assign data_o[3:0] = 4'b0;

endmodule

module LOD2(
    input [1:0] data_i,
    output [1:0] data_o
    );
	 
	 
	 //gates and IO assignments:
	 assign data_o[1] = data_i[1];
	 assign data_o[0] =(~data_i[1] & data_i[0]);
	 

endmodule


module LOD4(
    input [3:0] data_i,
    output [3:0] data_o
    );
	 
    
    wire mux0;
    wire mux1;
    wire mux2;
    
    // multiplexers:
    assign mux2 = (data_i[3]==1) ? 1'b0 : 1'b1;
    assign mux1 = (data_i[2]==1) ? 1'b0 : mux2;
    assign mux0 = (data_i[1]==1) ? 1'b0 : mux1;
    
    //gates and IO assignments:
    assign data_o[3] = data_i[3];
    assign data_o[2] =(mux2 & data_i[2]);
    assign data_o[1] =(mux1 & data_i[1]);
    assign data_o[0] =(mux0 & data_i[0]);

endmodule

module Muxes2in1Array2(
    input [1:0] data_i,
    input select_i,
    output [1:0] data_o
    );
    
	assign data_o[1] = select_i ? data_i[1] : 1'b0;
	assign data_o[0] = select_i ? data_i[0] : 1'b0;
	
endmodule

module Muxes2in1Array4(
    input [3:0] data_i,
    input select_i,
    output [3:0] data_o
    );

	assign data_o[3] = select_i ? data_i[3] : 1'b0;
	assign data_o[2] = select_i ? data_i[2] : 1'b0;
	assign data_o[1] = select_i ? data_i[1] : 1'b0;
	assign data_o[0] = select_i ? data_i[0] : 1'b0;
	
endmodule



module LBarrel(
    input [15:0] data_i,
    input [15:0] shift_i,
    output [4:0] data_o);
    
    assign data_o[4] = |(data_i[13:8] & shift_i[14:9]);

    assign data_o[3] = |(data_i[12:8] & shift_i[14:10]);

    assign data_o[2] = |(data_i[11:8] & shift_i[14:11]);
    
    assign data_o[1] = |(data_i[10:8] & shift_i[14:12]);

    assign data_o[0] = |(data_i[9:8] & shift_i[14:13]);

endmodule

module L1Barrel(
    input [5:0] data_i,
    input [3:0] shift_i,
    output reg [21:0] data_o);
    always @*
        case (shift_i)
           4'b0000: data_o = data_i;
           4'b0001: data_o = data_i << 1;
           4'b0010: data_o = data_i << 2;
           4'b0011: data_o = data_i << 3;
           4'b0100: data_o = data_i << 4;
           4'b0101: data_o = data_i << 5;
           4'b0110: data_o = data_i << 6;
           4'b0111: data_o = data_i << 7;
           4'b1000: data_o = data_i << 8;
           4'b1001: data_o = data_i << 9;
           4'b1010: data_o = data_i << 10;
           4'b1011: data_o = data_i << 11;
           4'b1100: data_o = data_i << 12;
           4'b1101: data_o = data_i << 13;
           4'b1110: data_o = data_i << 14;
           default: data_o = data_i << 15;
        endcase
endmodule