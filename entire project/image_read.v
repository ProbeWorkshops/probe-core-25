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
//reading mask.hex and retriving pixel values
initial begin
    $readmemh(INFILE1,total_memory1,0,WIDTH*HEIGHT*3-1); // read file from INFILE
end
//reading background.hex and retriving pixel values
initial begin
    $readmemh(INFILE2,total_memory2,0,WIDTH*HEIGHT*3-1); // read file from INFILE
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
// copying pixels to a temperory array and extracting black/white component of mask image
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3; i=i+1) begin
            temp_BMP1[i] = total_memory1[i+0][7:0]; 						// copying to temperory array
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_M[WIDTH*i+j] = temp_BMP1[WIDTH*3*(HEIGHT-i-1)+3*j+0]; 	// save mask component
            end
        end
    end
end
//--------------------------------------------------------------------------------------------------------------
// copying pixels to a temperory array and extracting R G B components of background image
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP2[i] = total_memory2[i+0][7:0]; 						// copying to temperory array
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_RB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+0]; 			// save Red component
                org_GB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+1];			// save Green component
                org_BB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+2];			// save Blue component
            end
        end
	end
end
//--------------------------------------------------------------------------------------------------------------
//for 15x15 gaussian kernel for blurring operation
always@(start) begin
    if(start == 1'b1) begin
		org_A[0]=41;  	org_A[1]=42;  	org_A[2]=42;  	org_A[3]=42;  	org_A[4]=43;  	org_A[5]=43;  	org_A[6]=43;  	org_A[7]=43;  	org_A[8]=43;  	org_A[9]=43;  	org_A[10]=43;  	org_A[11]=43;  	org_A[12]=42;  	org_A[13]=42;  	org_A[14]=42; 
		org_A[15]=42;  	org_A[16]=42;  	org_A[17]=43;  	org_A[18]=43;  	org_A[19]=43;  	org_A[20]=44;  	org_A[21]=44;  	org_A[22]=44;  	org_A[23]=44;  	org_A[24]=44;  	org_A[25]=44;  	org_A[26]=43;  	org_A[27]=43;  	org_A[28]=43;  	org_A[29]=42; 
		org_A[30]=42;  	org_A[31]=43;  	org_A[32]=43;  	org_A[33]=43;  	org_A[34]=44;  	org_A[35]=44;  	org_A[36]=44;  	org_A[37]=44;  	org_A[38]=44;  	org_A[39]=44;  	org_A[40]=44;  	org_A[41]=44;  	org_A[42]=43;  	org_A[43]=43;  	org_A[44]=43; 
		org_A[45]=42;  	org_A[46]=43;  	org_A[47]=43;  	org_A[48]=44;  	org_A[49]=44;  	org_A[50]=44;  	org_A[51]=45;  	org_A[52]=45;  	org_A[53]=45;  	org_A[54]=45;  	org_A[55]=44;  	org_A[56]=44;  	org_A[57]=44;  	org_A[58]=43;  	org_A[59]=43; 
		org_A[60]=43;  	org_A[61]=43;  	org_A[62]=44;  	org_A[63]=44;  	org_A[64]=44;  	org_A[65]=45;  	org_A[66]=45;  	org_A[67]=45;  	org_A[68]=45;  	org_A[69]=45;  	org_A[70]=45;  	org_A[71]=44;  	org_A[72]=44;  	org_A[73]=44;  	org_A[74]=43; 
		org_A[75]=43;  	org_A[76]=44;  	org_A[77]=44;  	org_A[78]=44;  	org_A[79]=45;  	org_A[80]=45;  	org_A[81]=45;  	org_A[82]=45;  	org_A[83]=45;  	org_A[84]=45;  	org_A[85]=45;  	org_A[86]=45;  	org_A[87]=44;  	org_A[88]=44;  	org_A[89]=43; 
		org_A[90]=43;  	org_A[91]=44;  	org_A[92]=44;  	org_A[93]=45;  	org_A[94]=45;  	org_A[95]=45;  	org_A[96]=45;  	org_A[97]=45;  	org_A[98]=45;  	org_A[99]=45;  	org_A[100]=45;  org_A[101]=45;  org_A[102]=45;  org_A[103]=44;  org_A[104]=44; 
		org_A[105]=43;  org_A[106]=44;  org_A[107]=44;  org_A[108]=45;  org_A[109]=45;  org_A[110]=45;  org_A[111]=45;  org_A[112]=45;  org_A[113]=45;  org_A[114]=45;  org_A[115]=45;  org_A[116]=45;  org_A[117]=45;  org_A[118]=44;  org_A[119]=44; 
		org_A[120]=43;  org_A[121]=44;  org_A[122]=44;  org_A[123]=45;  org_A[124]=45;  org_A[125]=45;  org_A[126]=45;  org_A[127]=45;  org_A[128]=45;  org_A[129]=45;  org_A[130]=45;  org_A[131]=45;  org_A[132]=45;  org_A[133]=44;  org_A[134]=44; 
		org_A[135]=43;  org_A[136]=44;  org_A[137]=44;  org_A[138]=45;  org_A[139]=45;  org_A[140]=45;  org_A[141]=45;  org_A[142]=45;  org_A[143]=45;  org_A[144]=45;  org_A[145]=45;  org_A[146]=45;  org_A[147]=45;  org_A[148]=44;  org_A[149]=44; 
		org_A[150]=43;  org_A[151]=44;  org_A[152]=44;  org_A[153]=44;  org_A[154]=45;  org_A[155]=45;  org_A[156]=45;  org_A[157]=45;  org_A[158]=45;  org_A[159]=45;  org_A[160]=45;  org_A[161]=45;  org_A[162]=44;  org_A[163]=44;  org_A[164]=43; 
		org_A[165]=43;  org_A[166]=43;  org_A[167]=44;  org_A[168]=44;  org_A[169]=44;  org_A[170]=45;  org_A[171]=45;  org_A[172]=45;  org_A[173]=45;  org_A[174]=45;  org_A[175]=45;  org_A[176]=44;  org_A[177]=44;  org_A[178]=44;  org_A[179]=43; 
		org_A[180]=42;  org_A[181]=43;  org_A[182]=43;  org_A[183]=44;  org_A[184]=44;  org_A[185]=44;  org_A[186]=45;  org_A[187]=45;  org_A[188]=45;  org_A[189]=45;  org_A[190]=44;  org_A[191]=44;  org_A[192]=44;  org_A[193]=43;  org_A[194]=43; 
		org_A[195]=42;  org_A[196]=43;  org_A[197]=43;  org_A[198]=43;  org_A[199]=44;  org_A[200]=44;  org_A[201]=44;  org_A[202]=44;  org_A[203]=44;  org_A[204]=44;  org_A[205]=44;  org_A[206]=44;  org_A[207]=43;  org_A[208]=43;  org_A[209]=43; 
		org_A[210]=42;  org_A[211]=42;  org_A[212]=43;  org_A[213]=43;  org_A[214]=43;  org_A[215]=43;  org_A[216]=44;  org_A[217]=44;  org_A[218]=44;  org_A[219]=44;  org_A[220]=43;  org_A[221]=43;  org_A[222]=43;  org_A[223]=43;  org_A[224]=42;
		k=0;
    	for(i=0;i<15*15;i=i+1) begin	// sum up all the values in the kernel
    		k=k+org_A[i];
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

		/**************************************/		
		/********THRESHOLD OPERATION  *********/
		/**************************************/
		// new pixel value = 0(if <threshold value) or 255(if >threshold value)
		if(operation==THRESHOLD_OPERATION) begin
			THRESHOLD=read_value;

			value = (org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
			if(value > THRESHOLD) begin
				processed_R0=255;
				processed_G0=255;
				processed_B0=255;
			end
			else begin
				processed_R0=0;
				processed_G0=0;
				processed_B0=0;
			end

			value1 = (org_R[WIDTH * row + col+1   ]+org_G[WIDTH * row + col+1   ]+org_B[WIDTH * row + col+1   ])/3;
			if(value1 > THRESHOLD) begin
				processed_R1=255;
				processed_G1=255;
				processed_B1=255;
			end
			else begin
				processed_R1=0;
				processed_G1=0;
				processed_B1=0;
			end		
		end

		/**************************************/		
		/******** CONTRAST OPERATION  *********/
		/**************************************/
		// new pixel value = [(old pixel value - 128) x contrast value] + 128
		if(operation==CONTRAST_OPERATION) begin
			ALPHA=read_value;

			adjusted_valueR0 = ((org_R[WIDTH * row + col   ] - 128) * ALPHA);
			adjusted_valueG0 = ((org_G[WIDTH * row + col   ] - 128) * ALPHA);
			adjusted_valueB0 = ((org_B[WIDTH * row + col   ] - 128) * ALPHA);
			adjusted_valueR1 = ((org_R[WIDTH * row + col   +1] - 128) * ALPHA);
			adjusted_valueG1 = ((org_G[WIDTH * row + col   +1] - 128) * ALPHA);
          	adjusted_valueB1 = ((org_B[WIDTH * row + col   +1] - 128) * ALPHA);
          
			processed_R0 = (adjusted_valueR0 + 128 < 0) ? 0 :
							(adjusted_valueR0 + 128 > 255) ? 255 :
							(adjusted_valueR0 + 128);
			processed_G0 = (adjusted_valueG0 + 128 < 0) ? 0 :
							(adjusted_valueG0 + 128 > 255) ? 255 :
							(adjusted_valueG0 + 128);
			processed_B0 = (adjusted_valueB0 + 128 < 0) ? 0 :
							(adjusted_valueB0 + 128 > 255) ? 255 :
							(adjusted_valueB0 + 128);
			processed_R1 = (adjusted_valueR1 + 128 < 0) ? 0 :
							(adjusted_valueR1 + 128 > 255) ? 255 :
							(adjusted_valueR1 + 128);
			processed_G1 = (adjusted_valueG1 + 128 < 0) ? 0 :
							(adjusted_valueG1 + 128 > 255) ? 255 :
							(adjusted_valueG1 + 128);
			processed_B1 = (adjusted_valueB1 + 128 < 0) ? 0 :
							(adjusted_valueB1 + 128 > 255) ? 255 :
							(adjusted_valueB1 + 128);
		end
		
		/**************************************/		
		/********    GAUSSIAN BLUR    *********/
		/**************************************/
		// new pixel value is the convolution of gaussian kernel with the neighbouring pixels
		if(operation==GAUSSIAN_BLUR_OPERATION) begin
			value=row<7?-row:-7;
			value1=row<HEIGHT-7?7:HEIGHT-row;
			value2=col<7?-col:-7;
			value4=col<WIDTH-7?7:WIDTH-col;
			blurpixG0=0;
			blurpixG1=0;
			blurpixB0=0;
			blurpixB1=0;
			blurpixR0=0;
			blurpixR1=0;
			for(i=value;i<value1;i=i+1) begin 
				for(j=value2;j<value4;j=j+1) begin
					blurpixR0 = blurpixR0+org_R[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];
					blurpixG0 = blurpixG0+org_G[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];
					blurpixB0 = blurpixB0+org_B[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];                                       
					blurpixR1 = blurpixR1+org_R[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];
					blurpixG1 = blurpixG1+org_G[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];
					blurpixB1 = blurpixB1+org_B[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];     
				end
			end
			processed_R0 = blurpixR0/k;
			processed_G0 = blurpixG0/k;
			processed_B0 = blurpixB0/k;                                       
			processed_R1 = blurpixR1/k;
			processed_G1 = blurpixG1/k;
			processed_B1 = blurpixB1/k;
		end
	
		/**************************************/		
		/********     BACK GROUND     *********/
		/**************************************/
		//new pixel value = pixel value of the background image
		if(operation==BACK_GROUND_OPERATION) begin
			processed_R0 = org_RB[WIDTH*(row)+ (col)];
			processed_G0 = org_GB[WIDTH*(row)+ (col)];
			processed_B0 = org_BB[WIDTH*(row)+ (col)];                                       
			processed_R1 = org_RB[WIDTH*(row)+ (col+1)];
			processed_G1 = org_GB[WIDTH*(row)+ (col)+1];
			processed_B1 = org_BB[WIDTH*(row)+ (col)+1];
		end

		/**************************************/		
		/********  FULL IMAGE EDIT    *********/
		/**************************************/
		// for full image to be processed, write the processed pixel value every time
		if(workflow==FULL_EDIT) begin
			DATA_R0=processed_R0;
			DATA_R1=processed_R1;
			DATA_G0=processed_G0;
			DATA_G1=processed_G1;
			DATA_B0=processed_B0;
			DATA_B1=processed_B1;
		end

		/**************************************/		
		/********   SUBJECT SELECTION *********/
		/**************************************/
		// for only the background to be processed, write the processed pixel value only if it is a background pixel
		if(workflow==SUBJECT_SEL) begin
			DATA_R0=(org_M[WIDTH*row+col  ])?org_R[WIDTH*(row)+ (col)  ]:processed_R0;
			DATA_R1=(org_M[WIDTH*row+col+1])?org_R[WIDTH*(row)+ (col+1)]:processed_R1;
			DATA_G0=(org_M[WIDTH*row+col  ])?org_G[WIDTH*(row)+ (col)  ]:processed_G0;
			DATA_G1=(org_M[WIDTH*row+col+1])?org_G[WIDTH*(row)+ (col+1)]:processed_G1;
			DATA_B0=(org_M[WIDTH*row+col  ])?org_B[WIDTH*(row)+ (col)  ]:processed_B0;
			DATA_B1=(org_M[WIDTH*row+col+1])?org_B[WIDTH*(row)+ (col+1)]:processed_B1;
		end
	end
end

endmodule
