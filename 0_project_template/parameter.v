module file_read(
output reg workflow,                   // workflow as either full edit or subject selection
output reg [2:0] operation,            // operation to specify brightness / contrast / threshold / ...
output reg [31:0] read_value,          // stores the brightness / contrast / threshold value (depends on operation)
output reg       read_sign);           // represents brightness addition or subtraction

integer workflow_file, operation_file; // variables to open the text files
integer read_workflow, read_operation; // variables to read the opened text files

//start your code here...
    
endmodule


