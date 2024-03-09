// Decentralized Control

module cache_controller(
    input wire clk,
    input wire reset,

    cpu_cache_ctrl_intf.cache_side      cpu_to_cache_ctrl,
    cache_ctrl_l1_intf.controller_side  cache_ctrl_to_l1,
);
    // Example internal signals and states
    logic [31:0] current_addr;
    logic operation_type; // 0 for read, 1 for write
    logic [31:0] write_data_buffer;

    cache_ctrl_l1_intf.controller_side ctrl_intf; // Name matches port in l1_cache
    l1_l2_intf.l1_side l1_intf; // Name matches port in l1_cache

    // Instantiate the l1_cache module using wildcard port connections
    l1_cache #(
        .CACHE_SIZE(4 * 1024), // Customize parameters as necessary
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(2),
        .DATA_WIDTH(32)
        // INDEX_WIDTH and TAG_WIDTH are derived parameters and not explicitly passed
    ) l1_cache_instance (
        .* // Automatically connects ports to signals of the same name
    );

    // State machine states
    typedef enum {IDLE, READ_L1, WRITE_L1, CHECK_L2, ACCESS_MEM, UPDATE_L1, RESPOND_CPU} state_t;
    state_t current_state, next_state;

    // State machine for cache controller logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        // Default to staying in the current state
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (cpu_to_cache_ctrl.cpu_req_valid) begin
                    current_addr = cpu_to_cache_ctrl.cpu_req_addr;
                    operation_type = cpu_to_cache_ctrl.cpu_req_op;
                    write_data_buffer = cpu_to_cache_ctrl.cpu_write_data;
                    next_state = operation_type ? WRITE_L1 : READ_L1;
                end
            end
            READ_L1: begin
                // Command L1 cache to perform read operation
                // Transition depends on L1 cache response
            end
            WRITE_L1: begin
                // Command L1 cache to perform write operation
                // Transition depends on L1 cache response
            end
            CHECK_L2: begin
                // Handle L1 miss, check L2 cache
                // Transition depends on L2 cache response
            end
            ACCESS_MEM: begin
                // Handle L2 miss, access main memory
            end
            UPDATE_L1: begin
                // Update L1 cache with data from L2 or memory
            end
            RESPOND_CPU: begin
                // Respond to CPU request
                if (cpu_to_cache_ctrl.cpu_req_valid == 0) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Implement the logic for each state, including interfacing with L1, L2, and memory
    // and handling the data path between these components based on cache hits and misses.

endmodule
