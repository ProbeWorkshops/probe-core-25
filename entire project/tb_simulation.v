module tb_simulation;
// signals to be connected between image_read and image_write modules
reg HCLK, HRESETn;
wire          data_write;
wire [ 7 : 0] data_R0;
wire [ 7 : 0] data_G0;
wire [ 7 : 0] data_B0;
wire [ 7 : 0] data_R1;
wire [ 7 : 0] data_G1;
wire [ 7 : 0] data_B1;
wire enc_done;
wire write_done;
//--------------------------------------------------------------------------------------------------------------
//connecting image_read module
image_read u_image_read( 
    .HCLK	                (HCLK    ),
    .HRESETn	            (HRESETn ),
    .data_write	            (data_write),
    .DATA_R0	            (data_R0 ),
    .DATA_G0	            (data_G0 ),
    .DATA_B0	            (data_B0 ),
    .DATA_R1	            (data_R1 ),
    .DATA_G1	            (data_G1 ),
    .DATA_B1	            (data_B1 ),
	.ctrl_done				(enc_done)
); 
//--------------------------------------------------------------------------------------------------------------
//connecting image_write module
image_write u_image_write(
	.HCLK(HCLK),
	.HRESETn(HRESETn),
	.data_write(data_write),
   .DATA_WRITE_R0(data_R0),
   .DATA_WRITE_G0(data_G0),
   .DATA_WRITE_B0(data_B0),
   .DATA_WRITE_R1(data_R1),
   .DATA_WRITE_G1(data_G1),
   .DATA_WRITE_B1(data_B1),
	.Write_Done(write_done)
);	
//--------------------------------------------------------------------------------------------------------------
// generating clock pulses
initial begin 
    HCLK = 0;
    forever #10 HCLK = ~HCLK;
end
//--------------------------------------------------------------------------------------------------------------
// made reset as high to turn on the state machine
initial begin
    HRESETn     = 0;
    #25 HRESETn = 1;
end
//--------------------------------------------------------------------------------------------------------------
// stop the simulation once completed writing the entire image
always@(negedge HCLK) begin
    if(write_done) begin
        $stop;
    end
end

endmodule
