`define VLEN 128 // Adjust VLEN as needed
`define HEAP_SIZE 25 // Define the heap size
`define HEAP_IDX_WIDTH $clog2(`HEAP_SIZE) // Calculate the necessary bit width

module C3_custom_SIMD_instruction (
    input clk,
    input reset,
    input in_v,
    input [4:0] rd, // Differentiates between push and pop
    input [2:0] vrd1, vrd2,
    input [31:0] in_data,
    input [`VLEN-1:0] in_vdata1, in_vdata2,
    output out_v,
    output [4:0] out_rd,
    output [2:0] out_vrd1, out_vrd2,
    output [31:0] out_data,
    output [`VLEN-1:0] out_vdata1, out_vdata2
);

    // Heap RTL code
    reg [31:0] heap_array [0:`HEAP_SIZE-1]; // Array of HEAP_SIZE vector registers, each 32 bits wide
    reg [`HEAP_IDX_WIDTH-1:0] heap_size;
    reg [`HEAP_IDX_WIDTH-1:0] i;

    reg [4:0] state;
    reg [`HEAP_IDX_WIDTH-1:0] idx;
    reg [`HEAP_IDX_WIDTH-1:0] parent_idx;
    reg [`HEAP_IDX_WIDTH-1:0] left_idx;
    reg [`HEAP_IDX_WIDTH-1:0] right_idx;
    reg [`HEAP_IDX_WIDTH-1:0] largest_idx;

    reg [31:0] temp;
    reg [31:0] heap_data_out;

    localparam IDLE = 5'd0,
               PUSH = 5'd1,
               POP = 5'd2,
               HEAPIFY_UP = 5'd3,
               HEAPIFY_DOWN = 5'd4;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            heap_size <= 0;
            state <= IDLE;
            for (i = 0; i < `HEAP_SIZE; i = i + 1) begin
                heap_array[i] <= 32'd0; // Initialize all elements to zero
            end
        end else begin
            case (state)
                IDLE: begin
                    if (git == 5'd0 && in_v && heap_size < `HEAP_SIZE) begin // Push operation
                        $display("Pushing value %d", in_data);
                        heap_array[heap_size] <= in_data;
                        heap_size <= heap_size + 1;
                        state <= HEAPIFY_UP;
                        idx <= heap_size; // Start heapify-up from the newly added element
                    end else if (rd == 5'd1 && in_v && heap_size > 0) begin // Pop operation
                        $display("Popping value %d", heap_array[0]);
                        heap_data_out <= heap_array[0]; // Output the root element
                        heap_array[0] <= heap_array[heap_size-1]; // Move the last element to the root
                        heap_size <= heap_size - 1;
                        state <= HEAPIFY_DOWN;
                        idx <= 0; // Start heapify-down from the root
                    end
                end

                HEAPIFY_UP: begin
                    parent_idx = (idx - 1) >> 1;
                    if (idx > 0 && heap_array[idx] > heap_array[parent_idx]) begin
                        $display("Heapify up: swapping %d and %d", heap_array[idx], heap_array[parent_idx]);
                        temp = heap_array[idx];
                        heap_array[idx] = heap_array[parent_idx];
                        heap_array[parent_idx] = temp;
                        idx = parent_idx; // Move up to the parent index
                    end else begin
                        state <= IDLE;
                    end
                end

                HEAPIFY_DOWN: begin
                    left_idx = 2*idx + 1;
                    right_idx = 2*idx + 2;
                    largest_idx = idx;

                    if (left_idx < heap_size && heap_array[left_idx] > heap_array[largest_idx])
                        largest_idx = left_idx;
                    if (right_idx < heap_size && heap_array[right_idx] > heap_array[largest_idx])
                        largest_idx = right_idx;

                    if (largest_idx != idx) begin
                        $display("Heapify down: swapping %d and %d", heap_array[idx], heap_array[largest_idx]);
                        temp = heap_array[idx];
                        heap_array[idx] = heap_array[largest_idx];
                        heap_array[largest_idx] = temp;
                        idx = largest_idx; // Move down to the largest child index
                    end else begin
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

    assign out_data = (rd == 5'd1 && heap_size > 0) ? heap_data_out : 32'd0;
    assign out_vdata1 = 0;
    assign out_vdata2 = 0;

endmodule // C3_custom_SIMD_instruction
