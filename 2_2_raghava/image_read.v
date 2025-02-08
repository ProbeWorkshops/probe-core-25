module image_read
#(
parameter WIDTH 	= 512,						// width of image is 512 pixels
		  HEIGHT 	= 512,						// height of image is 512 pixels
		  INFILE  	= "input.hex",				// input image
		  INFILE1	="mask.hex",				// mask generated from kaggle
		  INFILE2	="background.hex"			// desired background image
)
(
input			  HCLK,							// clock input					
input 			  HRESETn,						// reset input
output reg 		  data_write,					// will be set to high if machine is in data processing state
output reg [7:0]  DATA_R0,						// 8 bit Red data (even)
output reg [7:0]  DATA_G0,						// 8 bit Green data (even)
output reg [7:0]  DATA_B0,						// 8 bit Blue data (even)
output reg [7:0]  DATA_R1,						// 8 bit Red  data (odd)
output reg [7:0]  DATA_G1,						// 8 bit Green data (odd)
output reg [7:0]  DATA_B1,						// 8 bit Blue data (odd)
output			  ctrl_done						// will be set to high if processing done for whole image(Done flag)
);
localparam	ST_IDLE 	= 1'b0,					// represents machine is in idle state
			ST_DATA		= 1'b1;					// represents machine is in data processing state

localparam	FULL_EDIT	=1'b0,					// to apply image processing in whole image
			SUBJECT_SEL	=1'b1;					// to apply image processing only for background(subject left untouched)

localparam	BRIGHTNESS_OPERATION	=3'd0,		// to increase or decrease brightness
			INVERT_OPERATION		=3'd1,		// to convert into greyscale and invert pixels
			THRESHOLD_OPERATION		=3'd2,		// to make either black or white pixel(white pixel only if exceeds threshold value)
			CONTRAST_OPERATION		=3'd3,		// to increase or decrease contrast
			GAUSSIAN_BLUR_OPERATION	=3'd4,		// to blur the image
			BACK_GROUND_OPERATION	=3'd5;		// to change the background of the image(subject left untouched)

wire	    workflow;							// variable to decide full edit / only background level image processing
wire [ 2:0] operation;							// to decide the image processing operation
wire [31:0] read_value;							// to know amount of brightness, contrast or threshold to be changed
wire        read_sign;							// to know whether to increase or decrease brightness

file_read reader(.workflow(workflow),
				 .operation(operation),
				 .read_value(read_value),
				 .read_sign(read_sign));		// connecting with "file_read" module to retrive data from text file

integer	VALUE	  = 100;						// brightness value for Brightness operation (default value=100)
integer	THRESHOLD = 90;							// threshold value for Threshold operation (default value=90)
reg 	SIGN	  = 1;							// brightness addition(sign=1) or subtraction(sign=0) (default value=1)
real	ALPHA	  = 2.5;						// alpha value for contrast operation (<1 - decrease and >1 - increase) (default=2.5)

reg cstate;										// current state - state of machine in the current clock pulse
reg nstate;										// next state - state of machine in the next clock pulse
reg HRESETn_d;									// temperory variable used to create start pulse
reg start;										// start pulse to initiate the state machine

reg [7 : 0]   total_memory  [0 : WIDTH*HEIGHT*3-1]; // to store pixels(R G B) of input image
reg [7 : 0]   total_memory1 [0 : WIDTH*HEIGHT*3-1];	// to store pixels(R G B) of mask image (here R=G=B= 00 or ff)
reg [7 : 0]   total_memory2 [0 : WIDTH*HEIGHT*3-1]; // to store pixels(R G B) of background image
integer 	  temp_BMP   	[0 : WIDTH*HEIGHT*3-1];	// to take temperory copy of total_memory array(input image)
integer 	  temp_BMP1 	[0 : WIDTH*HEIGHT*3-1]; // to take temperory copy of total_memory1 array(mask image)
integer 	  temp_BMP2   	[0 : WIDTH*HEIGHT*3-1]; // to take temperory copy of total_memory2 array(background image)
integer       org_R  		[0 : WIDTH*HEIGHT-1];	// to extract Red component from input image
integer       org_G  		[0 : WIDTH*HEIGHT-1];	// to extract Green component from input image
integer       org_B  		[0 : WIDTH*HEIGHT-1];	// to extract Blue component from input image
integer       org_M  		[0 : WIDTH*HEIGHT-1];	// to find whether the pixel is black(00) or white(ff) in mask image
integer       org_RB 		[0 : WIDTH*HEIGHT-1]; 	// to extract Red component from background image
integer       org_GB 		[0 : WIDTH*HEIGHT-1];	// to extract Green component from background image
integer       org_BB  		[0 : WIDTH*HEIGHT-1];	// to extract Blue component from background image
reg 		  org_A 		[0 : (15*15)-1];		// to define kernel array for gaussian blur

integer i,j,k;										// temperory variable to count in for loops
integer value,value1,value2,value4;					// temperory variable to store intermediate data

integer processed_R0;								// new value of R0 pixel after processing
integer processed_R1;								// new value of R1 pixel after processing
integer processed_G0;								// new value of G0 pixel after processing
integer processed_G1;								// new value of G1 pixel after processing
integer processed_B0;								// new value of B0 pixel after processing
integer processed_B1; 								// new value of B1 pixel after processing

integer blurpixR0;									// intermediate sum of  kernel multiplication for R0 pixel
integer blurpixR1;									// intermediate sum of  kernel multiplication for R1 pixel
integer blurpixG0;									// intermediate sum of  kernel multiplication for G0 pixel
integer blurpixG1;									// intermediate sum of  kernel multiplication for G1 pixel
integer blurpixB0;									// intermediate sum of  kernel multiplication for B0 pixel
integer blurpixB1;									// intermediate sum of  kernel multiplication for B1 pixel

reg [ 8:0] row;										// row position of current pixel
reg [ 9:0] col;										// column position of current pixel
reg [17:0] data_count;								// number of pixels processed up until this time

//intermediate value for contrast calculation
reg signed [15:0]adjusted_valueR0;
reg signed [15:0]adjusted_valueG0;
reg signed [15:0]adjusted_valueB0;
reg signed [15:0]adjusted_valueR1;
reg signed [15:0]adjusted_valueG1;
reg signed [15:0]adjusted_valueB1;
//--------------------------------------------------------------------------------------------------------------
//reading input.hex and retriving pixel values
initial begin
    $readmemh(INFILE,total_memory,0,WIDTH*HEIGHT*3-1);
end
//--------------------------------------------------------------------------------------------------------------
// copying pixels to a temperory array and extracting R G B components of input image
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP[i] = total_memory[i+0][7:0]; 							// copying to temperory array
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_R[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+0]; 	// save Red component
                org_G[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+1];	// save Green component
                org_B[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+2];	// save Blue component
            end
        end
    end
end
//--------------------------------------------------------------------------------------------------------------
// logic to create start pulse			start pulse = 010000000000.......
//										clock pulse = ------------------> (0101010101...)
always@(posedge HCLK, negedge HRESETn)begin
    if(!HRESETn) begin
        start <= 0;
        HRESETn_d<=0;
    end
    else begin
        HRESETn_d<=HRESETn;
		if(HRESETn==1'b1 && HRESETn_d==1'b0)
			start <= 1'b1;
		else
			start <= 1'b0;
    end
end
//--------------------------------------------------------------------------------------------------------------
//defining state machine
always@(posedge HCLK, negedge HRESETn)begin
    if(~HRESETn) begin
        cstate <= ST_IDLE; // machine goes to idle state if reset
    end
    else begin
        cstate <= nstate;  // otherwise update to next state 
    end
end
always @(*) begin
	case(cstate)
		ST_IDLE: begin
			if(start)
				nstate = ST_DATA;	// if start pulse occurs, go idle state -> data processing state
			else
				nstate = ST_IDLE;	// if start pulse not occur, idle state -> idle state (remain in idle state)
		end
		ST_DATA: begin
			if(ctrl_done)
				nstate = ST_IDLE;	// if complete image is processed, data state -> idle state (turn off the machine)
		end
	endcase
end
//--------------------------------------------------------------------------------------------------------------
//pointing to pixels using row and column values
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin					// row and column should be erased if reset
        row <= 0;
		col <= 0;
    end
	else begin
		if(cstate == ST_DATA) begin		// if data processing state, move to next pixel
			if(col == WIDTH - 2) begin	
				row <= row + 1;			// go to next row after the current row ends
			end
			if(col == WIDTH - 2) 
				col <= 0;				// go back to first column after the current row ends
			else 
				col <= col + 2; 		// reading 2 pixels in parallel
		end
	end
end
//--------------------------------------------------------------------------------------------------------------
// counts the number of pixels processed till now
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
assign ctrl_done = (data_count == 131071)? 1'b1: 1'b0; // processing done if all pixels(512*512/2) are processed(taken two pixels at a one clock)
//--------------------------------------------------------------------------------------------------------------
//data processing logic
always @(*) begin
	data_write   = 1'b0;	// data writing not started yet

	//initialing variables with zeros
	DATA_R0 = 0;
	DATA_G0 = 0;
	DATA_B0 = 0;                                       
	DATA_R1 = 0;
	DATA_G1 = 0;
	DATA_B1 = 0;
    processed_R0 = 0;
	processed_G0 = 0;
	processed_B0 = 0;                                       
	processed_R1 = 0;
	processed_G1 = 0;
	processed_B1 = 0;
	                                         
	if(cstate == ST_DATA) begin 			// data processing starts if current state is data processing state 
		data_write   = 1'b1;				// data writing starts from here

		// no image processing operation occurs
//		processed_R0 = org_R[WIDTH * row + col   ];
//		processed_R1 = org_R[WIDTH * row + col+1 ];
//		processed_G0 = org_G[WIDTH * row + col   ];
//		processed_G1 = org_G[WIDTH * row + col+1 ];
//		processed_B0 = org_B[WIDTH * row + col   ];
//		processed_B1 = org_B[WIDTH * row + col+1 ];
		//writing the processed data
//		DATA_R0=processed_R0;
//		DATA_R1=processed_R1;
//		DATA_G0=processed_G0;
//		DATA_G1=processed_G1;
//		DATA_B0=processed_B0;
//		DATA_B1=processed_B1;
		if(operation==BRIGHTNESS_OPERATION) begin
			SIGN=read_sign;
			VALUE=read_value;

			if(SIGN == 1) begin
				/**************************************/		
				/*		BRIGHTNESS ADDITION OPERATION */
				/**************************************/
				// new pixel value = old pixel value + brightness value
				if (org_R[WIDTH * row + col   ] + VALUE > 255)
					processed_R0 = 255;
				else
					processed_R0 = org_R[WIDTH * row + col   ] + VALUE;

				if (org_R[WIDTH * row + col+1   ] + VALUE > 255)
					processed_R1 = 255;
				else
					processed_R1 = org_R[WIDTH * row + col+1   ] + VALUE;	
			
				if (org_G[WIDTH * row + col   ] + VALUE > 255)
					processed_G0 = 255;
				else
					processed_G0 = org_G[WIDTH * row + col   ] + VALUE;

				if (org_G[WIDTH * row + col+1   ] + VALUE > 255)
					processed_G1 = 255;
				else
					processed_G1 = org_G[WIDTH * row + col+1   ] + VALUE;		
				
				if (org_B[WIDTH * row + col   ] + VALUE > 255)
					processed_B0 = 255;
				else
					processed_B0 = org_B[WIDTH * row + col   ] + VALUE;

				if (org_B[WIDTH * row + col+1   ] + VALUE > 255)
					processed_B1 = 255;
				else
					processed_B1 = org_B[WIDTH * row + col+1   ] + VALUE;
			end
			else begin
				/**************************************/		
				/*	BRIGHTNESS SUBTRACTION OPERATION  */
				/**************************************/
				// new pixel value = old pixel value - brightness value
				if (org_R[WIDTH * row + col   ] - VALUE < 0)
					processed_R0 = 0;
				else
					processed_R0 = org_R[WIDTH * row + col   ] - VALUE;
				
				if (org_R[WIDTH * row + col+1   ] - VALUE < 0)
					processed_R1 = 0;
				else
					processed_R1 = org_R[WIDTH * row + col+1   ] - VALUE;	
				
				if (org_G[WIDTH * row + col   ] - VALUE < 0)
					processed_G0 = 0;
				else
					processed_G0 = org_G[WIDTH * row + col   ] - VALUE;

				if (org_G[WIDTH * row + col+1   ] - VALUE < 0)
					processed_G1 = 0;
				else
					processed_G1 = org_G[WIDTH * row + col+1   ] - VALUE;		
				
				if (org_B[WIDTH * row + col   ] - VALUE < 0)
					processed_B0 = 0;
				else
					processed_B0 = org_B[WIDTH * row + col   ] - VALUE;

				if (org_B[WIDTH * row + col+1   ] - VALUE < 0)
					processed_B1 = 0;
				else
					processed_B1 = org_B[WIDTH * row + col+1   ] - VALUE;
			end
		end
	
		/**************************************/		
		/*		INVERT_OPERATION  			  */
		/**************************************/
		// new pixel value = 255-(average of R G B)
		if(operation==INVERT_OPERATION) begin
			value2 = (org_B[WIDTH * row + col  ] + org_R[WIDTH * row + col  ] +org_G[WIDTH * row + col  ])/3;
			processed_R0=255-value2;
			processed_G0=255-value2;
			processed_B0=255-value2;

			value4 = (org_B[WIDTH * row + col+1  ] + org_R[WIDTH * row + col+1  ] +org_G[WIDTH * row + col+1  ])/3;
			processed_R1=255-value4;
			processed_G1=255-value4;
			processed_B1=255-value4;		
		end

		if(operation==THRESHOLD_OPERATION) begin
			//start your code here...
		end

		if(operation==CONTRAST_OPERATION) begin
			//start your code here...
		end
		
		if(operation==GAUSSIAN_BLUR_OPERATION) begin
			//start your code here...
		end
	
		if(operation==BACK_GROUND_OPERATION) begin
			//start your code here...
		end

		if(workflow==FULL_EDIT) begin
			DATA_R0=processed_R0;
			DATA_R1=processed_R1;
			DATA_G0=processed_G0;
			DATA_G1=processed_G1;
			DATA_B0=processed_B0;
			DATA_B1=processed_B1;
		end

		if(workflow==SUBJECT_SEL) begin
			//start your code here...
		end
	end
end

endmodule
