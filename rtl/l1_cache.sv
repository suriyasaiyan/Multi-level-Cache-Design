module l1_cache(
    input wire clk,
    input wire rst_n, // Active-low reset
    cache_ctrl_l1_intf.controller_side ctrl_intf,
    l1_l2_intf.l1_side l1_to_l2_intf
);
    localparam  CACHE_SIZE = 4 * 1024, // 4 KB
                BLOCK_SIZE = 4,        // 4 bytes
                ASSOCIATIVITY = 2,     // 2-way
                DATA_WIDTH = 32,       // 32 bits
                INDEX_WIDTH = $clog2(CACHE_SIZE / (BLOCK_SIZE * ASSOCIATIVITY)),
                TAG_WIDTH = 32 - INDEX_WIDTH - $clog2(BLOCK_SIZE);

    logic [ASSOCIATIVITY -1:0] lru_way;
    logic [INDEX_WIDTH-1:0] addr_index;
    logic [TAG_WIDTH-1:0] addr_tag;
    logic hit_detected;
    logic waiting_for_l2; // Indicates if L1 is waiting for data from L2

    int way, index;

    typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_WIDTH-1:0] tag;
        logic [DATA_WIDTH-1:0] data;
    } cache_line_t;

    cache_line_t cache_mem[0:ASSOCIATIVITY-1][0:(1<<INDEX_WIDTH)-1];

    // Decode address
    always_comb begin
        addr_tag = ctrl_intf.op_addr[31:32-TAG_WIDTH];
        addr_index = ctrl_intf.op_addr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
    end

    typedef enum integer {IDLE, CHECK_TAG, WRITE_BACK, FILL} cache_state_t;
    cache_state_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; 
            reset_cache();
        end else begin
            state <= next_state; 
        end
    end

    always_comb begin
        case (state)
            IDLE: 
                next_state = (ctrl_intf.op_valid) ? CHECK_TAG : IDLE;               

            CHECK_TAG: 
                check_tag();
             
            WRITE_BACK: 
                write_back();

            FILL: 
                fill();
                
            default: 
                next_state = IDLE; 
        endcase
    end

    task reset_cache;
        // Reset logic: Initialize cache to known state
            for (way = 0; way < ASSOCIATIVITY; way++) begin
                for (index = 0; index < (1 << INDEX_WIDTH); index++) begin
                    cache_mem[way][index] = '{valid: 0, dirty: 0, tag: 0, data: 0};
                end
            end
            // Default responses to control
            ctrl_intf.ready <= 0;
            waiting_for_l2 <= 0;

            // Default responses to l2 cache
            l1_to_l2_intf.l1_req_valid <= 0;
    endtask

    task check_tag;
        if (ctrl_intf.op_valid && !waiting_for_l2) begin 
            lru_way = get_lru_way(addr_index); // lru_way calls the LRU function and stores 

            hit_detected = 0;
            for (int i = 0; i < ASSOCIATIVITY; i++) begin
                if (cache_mem[i][addr_index].valid && (cache_mem[i][addr_index].tag == addr_tag)) begin
                    hit_detected = 1;
                    way = i;
                    break;
                end
            end

            if(hit_detected) 
                handle_cache_hit();
            else 
                handle_cache_miss();
        end
    endtask
  
    task handle_cache_hit;
        ctrl_intf.hit = 1; // Cache hit
        if (ctrl_intf.op_type == 0) begin // Read operation
            ctrl_intf.read_data = cache_mem[way][addr_index].data;
        end else begin // Write operation
            cache_mem[way][addr_index].data = ctrl_intf.write_data;
            cache_mem[way][addr_index].dirty = 1;
        end
        ctrl_intf.ready = 1;
        next_state = IDLE;
    endtask

    task handle_cache_miss;
        ctrl_intf.hit = 0;
        ctrl_intf.ready = 0;
        waiting_for_l2 = 1;

        if (cache_mem[lru_way][addr_index].dirty)
            next_state = WRITE_BACK;
        else 
            next_state = FILL;
        
    endtask

    task write_back;
        l1_to_l2_intf.l1_req_valid  = 1;
        l1_to_l2_intf.l1_req_addr   = ctrl_intf.op_addr;
        l1_to_l2_intf.l1_req_op     = ctrl_intf.op_type; 
        l1_to_l2_intf.l1_write_data = cache_mem[lru_way][addr_index].data;

        if(l1_to_l2_intf.l2_resp_valid = 1)
            l1_to_l2_intf.l1_req_valid = 0;

        next_state = FILL;

    endtask

    task cache_fill;
        l1_to_l2_intf.l1_req_valid = 1;
        l1_to_l2_intf.l1_req_addr = ctrl_intf.op_addr;
        l1_to_l2_intf.l1_req_op = 0 ;  // Read 
        // Waiting for l2
        if (l1_to_l2_intf.l2_resp_valid) begin
            // Handle receiving data from L2
            l1_to_l2_intf.l1_req_valid = 0;
            cache_mem[lru_way][addr_index].tag   = addr_tag;
            cache_mem[lru_way][addr_index].data  = l1_to_l2_intf.l2_resp_data;
            cache_mem[lru_way][addr_index].valid = 1;
            cache_mem[lru_way][addr_index].dirty = 0;

            waiting_for_l2 = 0;

            next_state = CHECK_TAG;
        end 

    endtask

    // LRU Function
    function integer get_lru_way(input integer set_index);
        integer i;
        reg [ASSOCIATIVITY-1:0] max_count;
        begin
            max_count = 0;
            //max_count = -1; -1 here is 32'hFFFFFFFF turnication happens and max_count will be 3
            lru_way = 0;
            for (i = 0; i < ASSOCIATIVITY; i = i + 1) begin            
                if (lru_counter[set_index][i] > max_count) begin
                    max_count = lru_counter[set_index][i];
                    lru_way = i;
                end
            end
            get_lru_way = lru_way;
        end
    endfunction

    task update_lru_counters(input integer set_index, input integer accessed_way);
        integer i;
        begin
            for (i = 0; i < ASSOCIATIVITY; i = i + 1) begin
                if (i == accessed_way) begin
                    lru_counter[set_index][i] <= 0;
                end else if (lru_counter[set_index][i] != (ASSOCIATIVITY - 1)) begin
                    lru_counter[set_index][i] <= lru_counter[set_index][i] + 1;
                end
            end
        end
    endtask

endmodule
 