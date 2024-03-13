package axi4_pkg;
  // AXI4 Interface Constants
  localparam C_AXI_ADDR_WIDTH = 32; // Address width
  localparam C_AXI_DATA_WIDTH = 32; // Data width

  // Response type definitions
  typedef enum {
	OKAY = 2'b00, 
	EXOKAY = 2'b01, 
	SLVERR = 2'b10, 
	DECERR = 2'b11
  } axi_resp_e;

  // AXI AR and AW cache type encoding
  typedef enum {
	NON_CACHEABLE = 4'b0000, 
	WRITE_THROUGH = 4'b0001, 
	WRITE_BACK = 4'b0011
  } axi_cache_type_e;

  // AXI AR and AW protection type encoding
  typedef enum {
    DEFAULT = 3'b000, // Normal, non-secure, data access
    PRIVILEGED = 3'b001,
    SECURE = 3'b010,
    SECURE_PRIVILEGED = 3'b011
  } axi_prot_type_e;

  // AXI lock type definitions
  typedef enum {
	NORMAL = 1'b0, 
	EXCLUSIVE = 1'b1
  } axi_lock_type_e;

  // Utility function: AXI burst length calculator
  function automatic [7:0] calc_axi_burst_length(input [ADDR_WIDTH-1:0] start_addr, input int byte_count);
    int aligned_end_addr = (start_addr + byte_count - 1) >> log2(DATA_WIDTH/8);
    int aligned_start_addr = start_addr >> log2(DATA_WIDTH/8);
    return (aligned_end_addr - aligned_start_addr + 1);
  endfunction
endpackage

package cache_util_pkg;
    // CACHE_HIT FSM
    typedef enum integer {CH_FETCH, CH_MOVE} ch_r_state_t;
    ch_r_state_t ch_r_state, ch_r_next_state;

    typedef enum integer {CH_RECV, CH_UPDT} ch_w_state_t;
    ch_w_state_t ch_w_state, ch_w_next_state;

    // CACHE_FILL FSM
    typedef enum integer {CF_ADDR, CF_DATA} cf_state_t;
    cf_state_t cf_state, next_cf_state;

    // WRITE_BACK FSM
    typedef enum integer {WB_ADDR, WB_DATA, WB_RESP} wb_state_t;
    wb_state_t wb_state, next_wb_state;

    // MAIN FSM
    typedef enum integer {IDLE, CHECK_TAG, CACHE_HIT, WRITE_BACK, FILL} cache_state_t;
    cache_state_t state, next_state;
endpackage