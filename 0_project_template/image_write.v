module image_write
#(parameter WIDTH 	= 512,							// Image width is 512 pixels
			HEIGHT 	= 512,							// Image height is 512 pixels
			INFILE  = "output.bmp",					// Output image
			BMP_HEADER_NUM = 54						// Header for bmp image
)
(
	input HCLK,										// Clock	
	input HRESETn,									// Reset active low
	input data_write,								// data will be written if high					
    input [7:0]  DATA_WRITE_R0,						// Red 8-bit data (odd)
    input [7:0]  DATA_WRITE_G0,						// Green 8-bit data (odd)
    input [7:0]  DATA_WRITE_B0,						// Blue 8-bit data (odd)
    input [7:0]  DATA_WRITE_R1,						// Red 8-bit data (even)
    input [7:0]  DATA_WRITE_G1,						// Green 8-bit data (even)
    input [7:0]  DATA_WRITE_B1,						// Blue 8-bit data (even)
	output 	reg	 Write_Done
);	
integer BMP_header  [0 : BMP_HEADER_NUM - 1];		// BMP header
reg [7:0 ] out_BMP  [0 : WIDTH*HEIGHT*3 - 1];		// Temporary memory for image
reg [18:0] data_count;								// Counting data
wire       done;									// done flag
// counting variables
integer i;
integer k, l, m;
integer fd; 
//--------------------------------------------------------------------------------------------------------------
//start your code here...

endmodule