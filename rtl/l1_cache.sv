module l1_cache(
    axi4_lite_interface.slave cpu_l1_if,
    axi4_lite_interface.master l1_l2_if
);
    localparam  CACHE_SIZE    = 4 * 1024,   // 4 KB
                BLOCK_SIZE    = 4,          // 4 bytes
                ASSOCIATIVITY = 2,          // 2-way
                DATA_WIDTH    = 32,         // 32 bits
                INDEX_WIDTH   = $clog2(CACHE_SIZE / (BLOCK_SIZE * ASSOCIATIVITY)),
                TAG_WIDTH     = 32 - INDEX_WIDTH - $clog2(BLOCK_SIZE);

    logic [ASSOCIATIVITY -1:0] lru_way;
    logic [INDEX_WIDTH-1:0] addr_index;
    logic [TAG_WIDTH-1:0] addr_tag;
    
    logic hit_detected;
    int way, index;
    
    // LRU Function
    reg [ASSOCIATIVITY -1:0] max_count;
    reg [(1>>ASSOCIATIVITY) -1:0] lru_counter [0: (1<<INDEX_WIDTH)-1][0: ASSOCIATIVITY-1];

    // Cache Memory
    typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_WIDTH-1:0] tag;
        logic [DATA_WIDTH-1:0] data;
    } cache_line_t;
    cache_line_t cache_mem [0: (1<<INDEX_WIDTH)-1][0:ASSOCIATIVITY-1];

    // FSM
    typedef enum integer {IDLE, CHECK_TAG, WRITE_BACK, FILL} cache_state_t;
    cache_state_t state, next_state;

    always_ff @(posedge cpu_l1_if.s_axi_aclk or negedge cpu_l1_if.s_axi_aresetn) begin
        if (!cpu_l1_if.s_axi_aresetn) begin
            state <= IDLE; 
            reset_cache();
        end else begin
            state <= next_state; 
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                // reset_signals();
                if(cpu_l1_if.s_axi_awvalid) begin
                    addr_tag   = cpu_l1_if.s_axi_awaddr[31:32-TAG_WIDTH] ;
                    addr_index = cpu_l1_if.s_axi_awaddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    next_state = CHECK_TAG;
                end else if (cpu_l1_if.s_axi_arvalid) begin
                    addr_tag   = cpu_l1_if.s_axi_araddr[31:32-TAG_WIDTH] ;
                    addr_index = cpu_l1_if.s_axi_araddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    next_state = CHECK_TAG;
                end else begin
                    next_state = IDLE;  
                end
            end 
            CHECK_TAG:  check_tag();           
            WRITE_BACK: write_back();
            FILL:       cache_fill();               
            default:    next_state = IDLE; 
        endcase
    end

    // Utility Tasks
    task reset_cache;
        // Reset logic: Initialize cache to known state
        for (int i = 0; i < (1 << INDEX_WIDTH); i++) begin
            for (int j = 0; j < ASSOCIATIVITY; j++) begin           
                cache_mem[i][j]   <= '{valid: 0, dirty: 0, tag: 0, data: 0};
                lru_counter[i][j] <= j;
            end
        end
        // Default responses to CPU
        reset_signals();
            // Default responses to l2_CACHE
    endtask

    task reset_signals;
        // Default responses to CPU
        cpu_l1_if.s_axi_bready <= 1'b0; 
        cpu_l1_if.s_axi_wready <= 1'b0;
        cpu_l1_if.s_axi_bvalid <= 1'b0;
        cpu_l1_if.s_axi_bresp  <= 2'b00;

        cpu_l1_if.s_axi_rready <= 1'b0;
        cpu_l1_if.s_axi_rvalid <= 1'b0;
        cpu_l1_if.s_axi_rdata  <= 1'b0;
        cpu_l1_if.s_axi_rresp  <= 2'b00;
    endtask

    task check_tag;
        lru_way = get_lru_way(addr_index); // lru_way calls the LRU function and stores 
        hit_detected = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (cache_mem[i][addr_index].valid && (cache_mem[i][addr_index].tag == addr_tag)) begin
                hit_detected = 1;
                way          = i;
                break;
            end
        end
        if(hit_detected) 
            handle_cache_hit();
        else 
            handle_cache_miss();
    endtask
  
    task handle_cache_hit;
        if (cpu_l1_if.s_axi_arvalid) begin // Read operation
            cpu_l1_if.s_axi_rdata  = cache_mem[way][addr_index].data;
            cpu_l1_if.s_axi_rresp  = 2'B00;
            cpu_l1_if.s_axi_rvalid = 1'B1;
            cpu_l1_if.s_axi_rready = 1'B1;
        end else if(cpu_l1_if.s_axi_awvalid) begin// Write operation
            cache_mem[way][addr_index].data  = cpu_l1_if.s_axi_wdata;
            cache_mem[way][addr_index].dirty = 1;
            cpu_l1_if.s_axi_bresp  = 2'B0;
            cpu_l1_if.s_axi_bvalid = 1'B1;
            cpu_l1_if.s_axi_bready = 1'B1;
        end
        next_state = IDLE;
        update_lru_counters(addr_index, way);
    endtask

    task handle_cache_miss;
        // Default responses to CPU
        reset_signals();
        if (cache_mem[lru_way][addr_index].dirty)
            next_state = WRITE_BACK;
        else 
            next_state = FILL;
    endtask

    task write_back;
        l1_l2_if.m_axi_awaddr  = {cache_mem[addr_index][lru_way].tag, addr_index, {$clog2(BLOCK_SIZE){1'b0}}};
        l1_l2_if.m_axi_awvalid = 1'B1;
        l1_l2_if.m_axi_wdata   = cache_mem[lru_way][addr_index].data;
        //waiting for L2
        if(l1_l2_if.m_axi_bready)
            l1_l2_if.m_axi_awvalid = 0;
        next_state = FILL;
    endtask

    task cache_fill;
        l1_l2_if.m_axi_araddr  = cpu_l1_if.s_axi_araddr;
        l1_l2_if.m_axi_arvalid = 1'B1;
        // Waiting for l2
        if (l1_l2_if.m_axi_rready) begin
            // Handle receiving data from L2
            l1_l2_if.m_axi_arvalid               = 0;
            cache_mem[lru_way][addr_index].tag   = addr_tag;
            cache_mem[lru_way][addr_index].data  = l1_l2_if.m_axi_rdata;
            cache_mem[lru_way][addr_index].valid = 1'B1;
            cache_mem[lru_way][addr_index].dirty = 0;
            update_lru_counters(addr_index, lru_way);
            next_state = CHECK_TAG;
        end 
    endtask

    // LRU Function
    function integer get_lru_way(input integer set_index);
        begin
            max_count = 0;
            //max_count = -1; -1 here is 32'hFFFFFFFF turnication happens and max_count will be 3
            lru_way = 0;
            for (int i = 0; i < ASSOCIATIVITY; i++) begin            
                if (lru_counter[set_index][i] > max_count) begin
                    max_count = lru_counter[set_index][i];
                    lru_way   = i;
                end
            end
            get_lru_way       = lru_way;
        end
    endfunction

    // Update LRU_Counter Task
    task update_lru_counters(input int set_index, input int accessed_way);
        begin
            for (int i = 0; i < ASSOCIATIVITY; i++) begin
                if (i == accessed_way) begin
                    lru_counter[set_index][i] <= 0;
                end else if (lru_counter[set_index][i] != (ASSOCIATIVITY - 1)) begin
                    lru_counter[set_index][i] <= lru_counter[set_index][i] + 1;
                end
            end
        end
    endtask

endmodule