`include "parameter.v"
module image_read
#(
  parameter WIDTH 	= 768,
			HEIGHT 	= 512,
			INFILE  = "kodim23.hex",
			VALUE= 100,								// value for Brightness operation
			THRESHOLD= 90,							// Threshold value for Threshold operation
			SIGN=1
)
(
	input HCLK,										// clock					
	input HRESETn,
	output reg data_write,
    output reg [7:0]  DATA_R0,				// 8 bit Red data (even)
    output reg [7:0]  DATA_G0,				// 8 bit Green data (even)
    output reg [7:0]  DATA_B0,				// 8 bit Blue data (even)
    output reg [7:0]  DATA_R1,				// 8 bit Red  data (odd)
    output reg [7:0]  DATA_G1,				// 8 bit Green data (odd)
    output reg [7:0]  DATA_B1,				// 8 bit Blue data (odd)
	output			  ctrl_done				// Done flag
);
localparam		ST_IDLE 	= 1'b0,
				ST_DATA		= 1'b1;
reg cstate;
reg nstate;
reg HRESETn_d;
reg start;
reg [7 : 0]   total_memory [0 : WIDTH*HEIGHT*3-1];
integer temp_BMP   [0 : WIDTH*HEIGHT*3 - 1];			
integer org_R  [0 : WIDTH*HEIGHT - 1];
integer org_G  [0 : WIDTH*HEIGHT - 1];
integer org_B  [0 : WIDTH*HEIGHT - 1];
integer i, j;
integer value,value1,value2,value4;
reg [ 8:0] row;
reg [9:0] col;
reg [17:0] data_count;
initial begin
    $readmemh(INFILE,total_memory,0,WIDTH*HEIGHT*3-1);
end
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP[i] = total_memory[i+0][7:0]; 
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_R[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+0]; // save Red component
                org_G[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+1];// save Green component
                org_B[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+2];// save Blue component
            end
        end
    end
end
always@(posedge HCLK, negedge HRESETn)begin
    if(!HRESETn) begin
        start <= 0;
        HRESETn_d<=0;
    end
    else begin						//       	|		|
        HRESETn_d<=HRESETn;
		if(HRESETn==1'b1 && HRESETn_d==1'b0)
			start <= 1'b1;
		else
			start <= 1'b0;
    end
end
always@(posedge HCLK, negedge HRESETn)begin
    if(~HRESETn) begin
        cstate <= ST_IDLE;
    end
    else begin
        cstate <= nstate; // update next state 
    end
end
always @(*) begin
	case(cstate)
		ST_IDLE: begin
			if(start)
				nstate = ST_DATA;
			else
				nstate = ST_IDLE;
		end
		ST_DATA: begin
			if(ctrl_done)
				nstate = ST_IDLE;
		end
	endcase
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        row <= 0;
		col <= 0;
    end
	else begin
		if(cstate == ST_DATA) begin
			if(col == WIDTH - 2) begin
				row <= row + 1;
			end
			if(col == WIDTH - 2) 
				col <= 0;
			else 
				col <= col + 2; // reading 2 pixels in parallel
		end
	end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        data_count <= 0;
    end
    else begin
        if(cstate == ST_DATA)
			data_count <= data_count + 1;
    end
end
assign ctrl_done = (data_count == 196607)? 1'b1: 1'b0;
always @(*) begin
	data_write   = 1'b0;
	DATA_R0 = 0;
	DATA_G0 = 0;
	DATA_B0 = 0;                                       
	DATA_R1 = 0;
	DATA_G1 = 0;
	DATA_B1 = 0;                                         
	if(cstate == ST_DATA) begin
		data_write   = 1'b1;
		`ifdef BRIGHTNESS_OPERATION	
		/**************************************/		
		/*		BRIGHTNESS ADDITION OPERATION */
		/**************************************/
		if(SIGN == 1) begin
		// R0
		if (org_R[WIDTH * row + col   ] + VALUE > 255)
			DATA_R0 = 255;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] + VALUE;
		// R1	
		if (org_R[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_R1 = 255;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] + VALUE;	
		// G0	
		if (org_G[WIDTH * row + col   ] + VALUE > 255)
			DATA_G0 = 255;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] + VALUE;
		if (org_G[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_G1 = 255;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] + VALUE;		
		// B0
		if (org_B[WIDTH * row + col   ] + VALUE > 255)
			DATA_B0 = 255;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] + VALUE;
		if (org_B[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_B1 = 255;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] + VALUE;
	end
	else begin
	/**************************************/		
	/*	BRIGHTNESS SUBTRACTION OPERATION */
	/**************************************/
		// R0
		if (org_R[WIDTH * row + col   ] - VALUE < 0)
			DATA_R0 = 0;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] - VALUE;
		// R1	
		if (org_R[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_R1 = 0;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] - VALUE;	
		// G0	
		if (org_G[WIDTH * row + col   ] - VALUE < 0)
			DATA_G0 = 0;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] - VALUE;
		if (org_G[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_G1 = 0;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] - VALUE;		
		// B
		if (org_B[WIDTH * row + col   ] - VALUE < 0)
			DATA_B0 = 0;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] - VALUE;
		if (org_B[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_B1 = 0;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] - VALUE;
	 end
		`endif
	
		/**************************************/		
		/*		INVERT_OPERATION  			  */
		/**************************************/
		`ifdef INVERT_OPERATION	
			value2 = (org_B[WIDTH * row + col  ] + org_R[WIDTH * row + col  ] +org_G[WIDTH * row + col  ])/3;
			DATA_R0=255-value2;
			DATA_G0=255-value2;
			DATA_B0=255-value2;
			value4 = (org_B[WIDTH * row + col+1  ] + org_R[WIDTH * row + col+1  ] +org_G[WIDTH * row + col+1  ])/3;
			DATA_R1=255-value4;
			DATA_G1=255-value4;
			DATA_B1=255-value4;		
		`endif
		/**************************************/		
		/********THRESHOLD OPERATION  *********/
		/**************************************/
		`ifdef THRESHOLD_OPERATION

		value = (org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
		if(value > THRESHOLD) begin
			DATA_R0=255;
			DATA_G0=255;
			DATA_B0=255;
		end
		else begin
			DATA_R0=0;
			DATA_G0=0;
			DATA_B0=0;
		end
		value1 = (org_R[WIDTH * row + col+1   ]+org_G[WIDTH * row + col+1   ]+org_B[WIDTH * row + col+1   ])/3;
		if(value1 > THRESHOLD) begin
			DATA_R1=255;
			DATA_G1=255;
			DATA_B1=255;
		end
		else begin
			DATA_R1=0;
			DATA_G1=0;
			DATA_B1=0;
		end		
		`endif
		// SHARPEN IMAGE OPERATION
		`ifdef SHARPEN_IMAGE

		
	end
end

endmodule

