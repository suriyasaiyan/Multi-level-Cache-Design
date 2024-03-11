module l2_cache(
    axi4_lite_interface.slave l2_l1_if,
    axi4_lite_interface.master l2_mem_if
);
    localparam  CACHE_SIZE    = 16 * 1024, // 16 KB
                BLOCK_SIZE    = 4,         // 4 bytes
                ASSOCIATIVITY = 4,         // 4-way
                DATA_WIDTH    = 32,        // 32 bits
                INDEX_WIDTH   = $clog2(CACHE_SIZE / (BLOCK_SIZE * ASSOCIATIVITY)),
                TAG_WIDTH     = 32 - INDEX_WIDTH - $clog2(BLOCK_SIZE);

    logic [ASSOCIATIVITY-1:0] lru_way;
    logic [INDEX_WIDTH-1:0] addr_index;
    logic [TAG_WIDTH-1:0] addr_tag;
    
    logic hit_detected;
    int way, index;
    
    // LRU Function
    reg [ASSOCIATIVITY-1:0] max_count;
    reg [ASSOCIATIVITY-1:0] lru_counter [0: (1<<INDEX_WIDTH)-1][0: ASSOCIATIVITY-1];

    // Cache Memory
    typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_WIDTH-1:0] tag;
        logic [DATA_WIDTH-1:0] data;
    } cache_line_t;
    cache_line_t cache_mem [0: (1<<INDEX_WIDTH)-1][0: ASSOCIATIVITY-1];

    // FSM
    typedef enum integer {IDLE, CHECK_TAG, WRITE_BACK, FILL} cache_state_t;
    cache_state_t state, next_state;

    always_ff @(posedge l2_l1_if.s_axi_aclk or negedge l2_l1_if.s_axi_aresetn) begin
        if (!l2_l1_if.s_axi_aresetn) begin
            state <= IDLE;
            reset_cache();
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                if(l2_l1_if.s_axi_awvalid) begin
                    addr_tag   = l2_l1_if.s_axi_awaddr[31:32-TAG_WIDTH];
                    addr_index = l2_l1_if.s_axi_awaddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    next_state = CHECK_TAG;
                end else if (l2_l1_if.s_axi_arvalid) begin
                    addr_tag   = l2_l1_if.s_axi_araddr[31:32-TAG_WIDTH];
                    addr_index = l2_l1_if.s_axi_araddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    next_state = CHECK_TAG;
                end else {
                    next_state = IDLE;  
                }
            end
            CHECK_TAG:  check_tag();           
            WRITE_BACK: write_back();
            FILL:       cache_fill();               
            default:    next_state = IDLE; 
        endcase
    end



endmodule
