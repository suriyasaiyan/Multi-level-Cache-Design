package axi4_pkg;
  // AXI4 Interface Constants
  localparam ADDR_WIDTH = 32; // Address width
  localparam DATA_WIDTH = 32; // Data width
  localparam ID_WIDTH = 4;    // ID width for transactions
  localparam USER_WIDTH = 1;  // User signal width, adjust as needed

  // Burst type definitions
  typedef enum {
	FIXED = 2'b00, 
	INCR = 2'b01, 
	WRAP = 2'b10
  } axi_burst_type_e;

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
  // Given a start address and a byte count, calculate the AXI burst length required
  function automatic [7:0] calc_axi_burst_length(input [ADDR_WIDTH-1:0] start_addr, input int byte_count);
    int aligned_end_addr = (start_addr + byte_count - 1) >> log2(DATA_WIDTH/8);
    int aligned_start_addr = start_addr >> log2(DATA_WIDTH/8);
    return (aligned_end_addr - aligned_start_addr + 1);
  endfunction

endpackage
