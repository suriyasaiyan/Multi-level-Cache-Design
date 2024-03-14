module cache_module#(
    parameter C_AXI_ADDR_WIDTH = 32,
    parameter C_AXI_DATA_WIDTH = 32,
    // Cache params
    parameter CACHE_SIZE    = 4 * 1024,   // 4 KB
    parameter BLOCK_SIZE    = 4,          // 4 bytes
    parameter ASSOCIATIVITY = 2           // 2-way
)(
    // Clock and Reset
    input logic aclk,
    input logic aresetn,

    //////////////////////////////////////////////////////
    //////////// SLAVE
    //////////////////////////////////////////////////////

    // Slave Interface Write Address Channel
    input  logic [C_AXI_ADDR_WIDTH -1:0]     s_l1_axi_awaddr,
    input  logic                             s_l1_axi_awvalid,
    output logic                             s_l1_axi_awready,

    // Slave Interface Write Data Channel
    input  logic [C_AXI_DATA_WIDTH -1:0]     s_l1_axi_wdata,
    input  logic                             s_l1_axi_wvalid,
    output logic                             s_l1_axi_wready,

    // Slave Interface Write Response Channel
    output logic [1:0]                       s_l1_axi_bresp,
    output logic                             s_l1_axi_bvalid,
    input  logic                             s_l1_axi_bready,

    // Slave Interface Read Address Channel
    input  logic [C_AXI_ADDR_WIDTH -1:0]     s_l1_axi_araddr,
    input  logic                             s_l1_axi_arvalid,
    output logic                             s_l1_axi_arready,

    // Slave Interface Read Data Channel
    output logic [C_AXI_DATA_WIDTH -1:0]     s_l1_axi_rdata,
    output logic [1:0]                       s_l1_axi_rresp,
    output logic                             s_l1_axi_rvalid,
    input  logic                             s_l1_axi_rready,

    //////////////////////////////////////////////////////
    //////////// MASTER
    //////////////////////////////////////////////////////

    // Master Interface Write Address Channel
    output logic [C_AXI_ADDR_WIDTH -1:0]     m_l1_axi_awaddr,
    output logic                             m_l1_axi_awvalid,
    input  logic                             m_l1_axi_awready,

    // Master Interface Write Data Channel
    output logic [C_AXI_DATA_WIDTH -1:0]     m_l1_axi_wdata,
    output logic                             m_l1_axi_wvalid,
    input  logic                             m_l1_axi_wready,

    // Master Interface Write Response Channel
    input  logic [1:0]                       m_l1_axi_bresp,
    input  logic                             m_l1_axi_bvalid,
    output logic                             m_l1_axi_bready,

    // Master Interface Read Address Channel
    output logic [C_AXI_ADDR_WIDTH -1:0]     m_l1_axi_araddr,
    output logic                             m_l1_axi_arvalid,
    input  logic                             m_l1_axi_arready,

    // Master Interface Read Data Channel
    input  logic [C_AXI_DATA_WIDTH -1:0]     m_l1_axi_rdata,
    input  logic [1:0]                       m_l1_axi_rresp,
    input  logic                             m_l1_axi_rvalid,
    output logic                             m_l1_axi_rready
);  
    import cache_util_pkg::*;
    
    reg awvalid_reg, arvalid_reg;

    // Prefetch
    reg [C_AXI_ADDR_WIDTH-1:0] prev_addr;
    reg prefetch_signal;
    
    localparam INDEX_WIDTH   = $clog2(CACHE_SIZE /(BLOCK_SIZE * ASSOCIATIVITY)),
               TAG_WIDTH     = 32 -INDEX_WIDTH -$clog2(BLOCK_SIZE);

    logic [ASSOCIATIVITY -1:0]  lru_way;
    logic [INDEX_WIDTH-1:0]     addr_index;
    logic [TAG_WIDTH-1:0]       addr_tag;
    
    logic hit_detected;
    int way, index;
    
    // LRU Function
    reg [$clog2(ASSOCIATIVITY) -1:0] lru_counter [0: (1<<INDEX_WIDTH)-1][0: ASSOCIATIVITY-1];

    // Cache Memory
    typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_WIDTH-1:0] tag;
        logic [C_AXI_DATA_WIDTH -1:0] data;
    } cache_line_t;
    cache_line_t l1_cache_mem [0: (1<<INDEX_WIDTH)-1][0:ASSOCIATIVITY-1];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset logic: Initialize all states to their default values
            state       <= IDLE; 
            wb_state    <= WB_ADDR;
            cf_state    <= CF_ADDR;
            ch_r_state  <= CH_FETCH; 
            ch_w_state  <= CH_RECV;
            reset_cache(); 
        end else begin
            state    <= next_state;
            wb_state <= (state == WRITE_BACK) ? next_wb_state : WB_ADDR;
            cf_state <= (state == FILL)       ? next_cf_state : CF_ADDR;

            if(state == CACHE_HIT) begin
                if(arvalid_reg) 
                    ch_r_state <= ch_r_next_state;
                if(awvalid_reg) 
                    ch_w_state <= ch_w_next_state;
            end else begin
                ch_r_state <= CH_FETCH;
                ch_w_state <= CH_RECV;
            end
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                // reset_signals();
                if(s_l1_axi_awvalid) begin
                    s_l1_axi_awready = 1'b1; // Handshake
                    addr_tag         = s_l1_axi_awaddr[31:32-TAG_WIDTH];
                    addr_index       = s_l1_axi_awaddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    awvalid_reg      = 1'b1;
                    next_state       = CHECK_TAG;
                end else if (s_l1_axi_arvalid) begin
                    s_l1_axi_arready = 1'b1; // Handshake
                    addr_tag         = s_l1_axi_araddr[31:32-TAG_WIDTH] ;
                    addr_index       = s_l1_axi_araddr[32-TAG_WIDTH-1:32-TAG_WIDTH-INDEX_WIDTH];
                    arvalid_reg      = 1'b1;
                    next_state       = CHECK_TAG;
                end else begin
                    next_state = IDLE;  
                end
            end 
            CHECK_TAG:  check_tag();
            CACHE_HIT:  handle_cache_hit();           
            WRITE_BACK: write_back();
            FILL:       cache_fill();               
            default:    next_state = IDLE; 
        endcase
    end

    //////////////////////////////////////////////////////
    //////////// UTILITY TASKS
    //////////////////////////////////////////////////////

    task reset_signals;
        // regs
        awvalid_reg      <= 1'b0;
        arvalid_reg      <= 1'b0;
        prefetch_signal  <= 1'b0;

        // Default responses to CPU
        s_l1_axi_awready <= 1'b0;
        s_l1_axi_wready  <= 1'b0;
        s_l1_axi_bresp   <= 2'b00;
        s_l1_axi_bvalid  <= 1'b0;    
        s_l1_axi_arready <= 1'b0;
        s_l1_axi_rresp   <= 2'b00;
        s_l1_axi_rdata   <= 32'hDEADBEEF;
        s_l1_axi_rvalid  <= 1'b0;
        
        // Default responses to CPU
        m_l1_axi_awaddr  <= 32'hDEADBEEF;
        m_l1_axi_awvalid <= 1'b0;
        m_l1_axi_wdata   <= 32'hDEADBEEF;
        m_l1_axi_wvalid  <= 1'b0;
        m_l1_axi_bready  <= 1'b0;
        m_l1_axi_araddr  <= 32'hDEADBEEF;
        m_l1_axi_arvalid <= 1'b0;
        m_l1_axi_rready  <= 1'b0;
    endtask
    
    task reset_cache;
        // Reset logic: Initialize cache to known state
        for (int i = 0; i < (1 << INDEX_WIDTH); i++) begin
            for (int j = 0; j < ASSOCIATIVITY; j++) begin           
                l1_cache_mem[i][j] <= '{valid: 0, dirty: 0, tag: 0, data: 0};
                lru_counter[i][j]  <= j;
            end
        end
        // Default responses to CPU
        reset_signals();
        // Default responses to l2_CACHE
    endtask

    task check_tag;
        lru_way = get_lru_way(addr_index); // lru_way calls the LRU function and stores 
        hit_detected = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (l1_cache_mem[i][addr_index].valid && (l1_cache_mem[i][addr_index].tag == addr_tag)) begin
                hit_detected = 1;
                way          = i;
                break;
            end
        end
        if(hit_detected) begin
            next_state     = CACHE_HIT;
        end else begin
            reset_signals();
            if(l1_cache_mem[lru_way][addr_index].dirty) begin
                next_state = WRITE_BACK;
            end else begin
                next_state = FILL;
            end
        end
    endtask

    task handle_cache_hit;
        if (arvalid_reg) begin // Read operation
            case (ch_r_state)
                CH_FETCH: begin
                    // Fetch Data from Cache
                    s_l1_axi_rdata  = l1_cache_mem[way][addr_index].data;
                    s_l1_axi_rresp  = 2'B00;
                    s_l1_axi_rvalid = 1'B1;
                    ch_r_next_state = CH_MOVE;
                end
                CH_MOVE: begin
                    if (s_l1_axi_rvalid && s_l1_axi_rready) begin
                        // The master is ready to accept the data, can move to the next state
                        next_state = IDLE;
                        s_l1_axi_rvalid = 1'b0;
                        update_lru_counters(addr_index, way);
                        arvalid_reg = 1'b0; // Reset read valid flag
                        ch_r_next_state = CH_FETCH;
                    end
                end
            endcase
        end else if(awvalid_reg) begin // Write operation
            case (ch_w_state)
                CH_RECV: begin
                    l1_cache_mem[way][addr_index].data  = s_l1_axi_wdata;
                    l1_cache_mem[way][addr_index].dirty = 1;
                    s_l1_axi_bresp  = 2'B00;
                    s_l1_axi_bvalid = 1'B1;
                    ch_w_next_state = CH_UPDT;
                end
                CH_UPDT: begin
                    if (s_l1_axi_bvalid && s_l1_axi_bready) begin
                        // The master is ready to accept the write response, can move to the next state
                        next_state = IDLE;
                        s_l1_axi_bvalid = 1'b0;
                        update_lru_counters(addr_index, way);
                        awvalid_reg = 1'b0; 
                        ch_w_next_state = CH_RECV; 
                    end
                end
            endcase
        end
    endtask

    task write_back; 
        case (wb_state)
            WB_ADDR: begin
                m_l1_axi_awaddr  = {l1_cache_mem[addr_index][lru_way].tag, addr_index, {$clog2(BLOCK_SIZE){1'b0}}};
                m_l1_axi_awvalid = 1'B1;
                next_wb_state    = WB_DATA;
            end 
            WB_DATA: begin
                if (m_l1_axi_awready) begin
                    m_l1_axi_awvalid = 1'b0;
                    m_l1_axi_wdata   = l1_cache_mem[lru_way][addr_index].data;
                    m_l1_axi_wvalid  = 1'b1;
                    next_wb_state    = WB_RESP;
                end
            end
            WB_RESP: begin
                if (m_l1_axi_wready) begin
                    m_l1_axi_wvalid = 1'b0;
                    if (m_l1_axi_bvalid) begin
                        if (m_l1_axi_bresp == 2'b00) begin
                            m_l1_axi_bready = 1'b1;
                            next_state = FILL;
                        end
                        else begin
                            // Handle other bresp values or errors
                            next_state = IDLE;
                        end
                    end
                end
            end
            default: next_wb_state = WB_ADDR;
        endcase
    endtask

    task cache_fill;
        case(cf_state)
            CF_ADDR: begin
                m_l1_axi_araddr  = {l1_cache_mem[addr_index][lru_way].tag, addr_index, {$clog2(BLOCK_SIZE){1'b0}}};
                m_l1_axi_arvalid = 1'b1;
                next_cf_state    = CF_DATA;
            end
            CF_DATA: begin
                if (m_l1_axi_arready) begin
                    m_l1_axi_arvalid = 1'b0;
                    if(m_l1_axi_rresp == 2'b00) begin
                        l1_cache_mem[lru_way][addr_index].tag   = addr_tag;
                        l1_cache_mem[lru_way][addr_index].data  = m_l1_axi_rdata;
                        l1_cache_mem[lru_way][addr_index].valid = 1'B1;
                        l1_cache_mem[lru_way][addr_index].dirty = 0;
                        update_lru_counters(addr_index, lru_way);
                        next_state = CHECK_TAG;
                        next_cf_state = CF_ADDR;
                    end else begin
                        // for other responses
                    end
                end
            end
            default: next_cf_state = CF_ADDR;
        endcase
    endtask

    // LRU Function
    function integer get_lru_way(input int set_index);
        begin
            integer max_count = -1;
            integer lru_way = 0;
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