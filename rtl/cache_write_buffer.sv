module cache_write_buffer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BUFFER_DEPTH = 4 
)(
    input wire clk,
    input wire rstn, 
    // Control Signals
    input wire flush_buffer,
    // input wire write_property;
    // output logic buffer_almost_full;
    // input wire critical_write;

    // Slave Interface
    input  logic [ADDR_WIDTH -1:0] s_awaddr,
    input  logic                   s_awvalid,
    output logic                   s_awready,

    input  logic [DATA_WIDTH -1:0] s_wdata,
    input  logic                   s_wvalid,
    output logic                   s_wready,

    output logic [1:0]             s_bresp,
    output logic                   s_bvalid,
    input  logic                   s_bready,

    // Master Interface
    output logic [ADDR_WIDTH -1:0] m_awaddr,
    output logic                   m_awvalid,
    input  logic                   m_awready,

    output logic [DATA_WIDTH -1:0] m_wdata,
    output logic                   m_wvalid,
    input  logic                   m_wready,

    input  logic [1:0]             m_bresp,
    input  logic                   m_bvalid,
    output logic                   m_bready
);

    reg [ADDR_WIDTH -1:0] addr_queue[BUFFER_DEPTH-1:0];
    reg [DATA_WIDTH -1:0] data_queue[BUFFER_DEPTH-1:0];
    reg [BUFFER_DEPTH-1:0] entry_valid_flags;
    integer write_index, read_index;

    logic buffer_is_full; 

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            reset_signals();
            current_fb_state <= VALID;
            current_wb_state <= IDLE;
        end else begin
            current_fb_state <= next_fb_state;
            current_wb_state <= next_wb_state;
            s_wready         <= !buffer_is_full;
            s_awready        <= !buffer_is_full;
            buffer_is_full   <= ((write_index + 1) % BUFFER_DEPTH) == read_index && entry_valid_flags[write_index];
        end
    end
    always_comb begin 
        if(s_awvalid && s_wvalid) begin
            handle_write_requests();
        end
        if(m_awready && m_wready) begin
            handle_lower_write();
        end
        if(flush_buffer) begin
            flush_buffer();
        end        
    end

    task reset_signals;
        write_index <= 1'b0;
        read_index  <= 1'b0;

        entry_valid_flags <= 1'b0;
        buffer_is_full    <= 1'b0;

        s_awready <= 1'b1;
        s_wready  <= 1'b1;
        s_bresp   <= 1'b0;
        s_bvalid  <= 1'b0;

        m_awvalid <= 1'b0;
        m_wvalid  <= 1'b0;
        m_bready  <= 1'b0;
    endtask 

    task handle_lower_write;
        m_awaddr  = addr_queue[read_index];
        m_wdata   = data_queue[read_index];
        m_awvalid = 1'b1;
        m_wvalid  = 1'b1;
    endtask

    task handle_write_requests;
        addr_queue[write_index] = s_awaddr;
        data_queue[write_index] = s_wdata;
        entry_valid_flags[write_index] = 1'b1;
        write_index = (write_index + 1) % BUFFER_DEPTH;
    endtask

    typedef enum integer { IDLE, VALID, INI_WRITE, WAIT_ACK, ADV_IDX, FLUSH_COMPLETE } flush_state_t;
    flush_state_t current_fb_state, next_fb_state;

    task flush_buffer;
        case(current_fb_state)
            VALID: begin
                if (entry_valid_flags[idx]) begin
                    next_state = WAIT_ACK;
                end else begin
                    next_state = ADV_IDX;
                end
            end 
            INI_WRITE: begin
                m_awvalid = 1'b1;
                m_wvalid  = 1'b1;
                next_fb_state = WAIT_ACK;
            end
            WAIT_ACK: begin
                if(m_awready && m_wready) begin
                    m_awaddr  = addr_queue[idx];
                    m_wdata   = data_queue[idx];
                    entry_valid_flags[idx] = 1'b0;
                    next_fb_state = ADV_IDX;
                end else begin
                    next_fb_state = WAIT_ACK;
                end
            end
            ADV_IDX: begin
                idx = (idx +1)%BUFFER_DEPTH;
                if (idx == write_index) 
                    next_fb_state = FLUSH_COMPLETE;
                else 
                    next_fb_state = VALID;
            end
            FLUSH_COMPLETE: begin
                flushed = 1'b1;
                next_state = VALID;
            end
        endcase
    endtask

endmodule


module cache_write_buffer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BUFFER_DEPTH = 4
)(
    input wire clk,
    input wire rstn, 
    input wire flush_buffer,

    input  logic [ADDR_WIDTH-1:0] s_awaddr,
    input  logic s_awvalid,
    output logic s_awready,

    input  logic [DATA_WIDTH-1:0] s_wdata,
    input  logic s_wvalid,
    output logic s_wready,

    output logic [1:0] s_bresp,
    output logic s_bvalid,
    input  logic s_bready,

    output logic [ADDR_WIDTH-1:0] m_awaddr,
    output logic m_awvalid,
    input  logic m_awready,

    output logic [DATA_WIDTH-1:0] m_wdata,
    output logic m_wvalid,
    input  logic m_wready,

    input  logic [1:0] m_bresp,
    input  logic m_bvalid,
    output logic m_bready
);

    typedef enum logic {IDLE, CHECK_WRITE_REQ, FLUSHING, WAIT_ACK} state_t;
    state_t current_state, next_state;

    logic [ADDR_WIDTH-1:0] addr_queue[BUFFER_DEPTH-1:0];
    logic [DATA_WIDTH-1:0] data_queue[BUFFER_DEPTH-1:0];
    logic [BUFFER_DEPTH-1:0] entry_valid_flags;
    integer write_index = 0, read_index = 0, idx;
    logic buffer_is_full, flush_initiated;

    // FSM for handling write requests and flushing
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            write_index <= 0;
            read_index <= 0;
            entry_valid_flags <= 0;
            current_state <= IDLE;
            flush_initiated <= 0;
        end else begin
            current_state <= next_state;
            case (next_state)
                CHECK_WRITE_REQ: begin
                    if (s_awvalid && s_wvalid && !buffer_is_full) begin
                        addr_queue[write_index] <= s_awaddr;
                        data_queue[write_index] <= s_wdata;
                        entry_valid_flags[write_index] <= 1'b1;
                        write_index <= (write_index + 1) % BUFFER_DEPTH;
                    end
                end
                FLUSHING: begin
                    if (!flush_initiated) begin
                        idx = read_index;
                        flush_initiated <= 1'b1;
                    end else if (entry_valid_flags[idx]) begin
                        m_awaddr <= addr_queue[idx];
                        m_wdata <= data_queue[idx];
                        m_awvalid <= 1'b1;
                        m_wvalid <= 1'b1;
                        if (m_awready && m_wready) begin
                            entry_valid_flags[idx] <= 1'b0;
                            m_awvalid <= 1'b0;
                            m_wvalid <= 1'b0;
                            idx <= (idx + 1) % BUFFER_DEPTH;
                        end
                    end
                    if (idx == write_index) begin
                        flush_initiated <= 1'b0; // Reset flushing flag once done
                        next_state <= IDLE; // Go back to IDLE state after flush completes
                    end
                end
                WAIT_ACK: begin
                    if (m_awready && m_wready) begin
                        entry_valid_flags[read_index] <= 1'b0;
                        read_index <= (read_index + 1) % BUFFER_DEPTH;
                        next_state <= IDLE;
                    end
                end
            endcase
        end
    end

    always_comb begin
        // Determine next state
        case (current_state)
            IDLE: next_state = flush_buffer ? FLUSHING : CHECK_WRITE_REQ;
            CHECK_WRITE_REQ: next_state = (s_awvalid && s_wvalid && !buffer_is_full) ? WAIT_ACK : IDLE;
            FLUSHING: next_state = FLUSHING; // Stay in FLUSHING until done
            WAIT_ACK: next_state = IDLE; // Default back to IDLE after processing a write request
            default: next_state = IDLE;
        endcase

        // Additional logic to manage buffer fullness and readiness
        buffer_is_full = ((write_index + 1) % BUFFER_DEPTH) == read_index;
        s_awready = !buffer_is_full && (current_state == CHECK_WRITE_REQ);
        s_wready = !buffer_is_full && (current_state == CHECK_WRITE_REQ);
        m_bready = 1'b1; // Always ready to accept a response from memory

        // Set the response to the slave interface based on memory's response
        s_bvalid = m_bvalid;
        s_bresp = m_bresp;
    end

    // Update buffer full flag and control signals for master interface based on buffer state
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer_is_full <= 1'b0;
            m_awvalid <= 1'b0;
            m_wvalid <= 1'b0;
        end else if (current_state == FLUSHING && m_awready && m_wready && entry_valid_flags[idx]) begin
            // Clear valid flags after successfully writing data to memory
            entry_valid_flags[idx] <= 1'b0;
            // Update buffer fullness flag
            buffer_is_full <= ((write_index + 1) % BUFFER_DEPTH) == (idx + 1) % BUFFER_DEPTH;
        end else if (current_state == CHECK_WRITE_REQ && s_awvalid && s_wvalid && !buffer_is_full) begin
            // Accept new write requests if not full
            buffer_is_full <= ((write_index + 1) % BUFFER_DEPTH) == read_index;
        end
    end

endmodule

