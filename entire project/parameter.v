module file_read(
    output reg workflow,
    output reg [2:0] operation,
    output reg [31:0] read_value,
    output reg       read_sign);

    integer workflow_file, operation_file;
    integer read_workflow, read_operation;
    
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
    initial begin
        workflow_file = $fopen("workflow.txt", "r");
        if (workflow_file == 0) begin
            $display("Error opening edit option file!");
            $stop;
        end
        read_workflow = $fscanf(workflow_file, "%d", workflow);
        $fclose(workflow_file);
    end
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


