module image_sharpening_no_padding (
    input wire clk,                  // Clock signal
    input wire reset,                // Reset signal
    input wire [7:0] image_in,       // Input pixel (8-bit grayscale)
    input wire valid_in,             // Valid signal for input pixel
    output reg [7:0] image_out,      // Output pixel (8-bit grayscale)
    output reg valid_out             // Valid signal for output pixel
);

    // Image size
    parameter WIDTH = 768;           // Image width
    parameter HEIGHT = 512;          // Image height

    // Line buffers for sliding window (3 rows)
    reg [7:0] line_buffer[2:0][0:WIDTH-1]; // 3 rows

    // Kernel for sharpening
    reg signed [3:0] kernel[2:0][2:0];
    initial begin
        kernel[0][0] =  0; kernel[0][1] = -1; kernel[0][2] =  0;
        kernel[1][0] = -1; kernel[1][1] =  5; kernel[1][2] = -1;
        kernel[2][0] =  0; kernel[2][1] = -1; kernel[2][2] =  0;
    end

    // Sliding window registers
    reg [7:0] window[2:0][2:0];

    // Counters for image processing
    integer x, y;

    // Processing logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all buffers and outputs
            for (x = 0; x < WIDTH; x = x + 1) begin
                line_buffer[0][x] <= 0;
                line_buffer[1][x] <= 0;
                line_buffer[2][x] <= 0;
            end
            valid_out <= 0;
            image_out <= 0;
        end else if (valid_in) begin
            // Shift line buffers
            for (x = 0; x < WIDTH; x = x + 1) begin
                line_buffer[0][x] <= line_buffer[1][x];
                line_buffer[1][x] <= line_buffer[2][x];
            end

            // Read new pixel into the last row
            line_buffer[2][WIDTH-1] <= image_in;

            // Update sliding window
            for (y = 0; y < 3; y = y + 1) begin
                for (x = 0; x < 3; x = x + 1) begin
                    window[y][x] <= line_buffer[y][x];
                end
            end

            // Apply convolution for sharpening if inside valid range
            if ((x > 1) && (x < WIDTH) && (y > 1) && (y < HEIGHT)) begin
                integer conv_result;
                conv_result = 0;

                for (y = 0; y < 3; y = y + 1) begin
                    for (x = 0; x < 3; x = x + 1) begin
                        conv_result = conv_result + (window[y][x] * kernel[y][x]);
                    end
                end

                // Clamp output to 8-bit range (0-255)
                if (conv_result < 0)
                    image_out <= 0;
                else if (conv_result > 255)
                    image_out <= 255;
                else
                    image_out <= conv_result[7:0];

                // Set valid output signal
                valid_out <= 1;
            end else begin
                valid_out <= 0; // Outside valid range
            end
        end else begin
            valid_out <= 0; // No valid input
        end
    end

endmodule
