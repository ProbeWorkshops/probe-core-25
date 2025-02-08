module file_read(
output reg workflow,                   // workflow as either full edit or subject selection
output reg [2:0] operation,            // operation to specify brightness / contrast / threshold / ...
output reg [31:0] read_value,          // stores the brightness / contrast / threshold value (depends on operation)
output reg       read_sign);           // represents brightness addition or subtraction

integer workflow_file, operation_file; // variables to open the text files
integer read_workflow, read_operation; // variables to read the opened text files
    
/* 
workflow.txt            workflow
    full edit           0
    Subject selection   1
operation.txt           operation   read_value   read_sign
    brightness          0                        0-subtraction  1-addition
    invertion           1           0-default    0-default
    threshold           2                        0-default
    contrast            3                        0-default
    gaussian blur       4           0-default    0-default
    edit background     5           0-default    o-default
*/
//--------------------------------------------------------------------------------------------------------------
// reading workflow.txt file
initial begin
    workflow_file = $fopen("workflow.txt", "r");
    if (workflow_file == 0) begin
        $display("Error opening edit option file!");
        $stop;
    end
    read_workflow = $fscanf(workflow_file, "%d", workflow);
    $fclose(workflow_file);
end
//--------------------------------------------------------------------------------------------------------------
// reading operation.txt file
initial begin
    operation = 0;
    operation_file = $fopen("operation.txt", "r");
    if (operation_file == 0) begin
        $display("Error opening edit option file!");
        $finish;
    end
    read_operation = $fscanf(operation_file, "%d\n%f\n%d", operation,read_value,read_sign);
    $fclose(operation_file);
end
endmodule


