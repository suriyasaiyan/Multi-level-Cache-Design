import axi_pkg::*;

interface axi_if;

	// Read Address Channel
	addr_t araddr;
	logic arvalid;
	logic arready;
	len_t arlen;
	size_t arsize;
	burst_t arburst;

	// Read Data Channel
	data_t rdata;
	resp_t rresp;
	logic rvalid;
	logic rready;
	logic rlast;

	// Write Address Channel
	addr_t awaddr;
	logic awvalid;
	logic awready;
	len_t awlen;
	size_t awsize;
	burst_t awburst;

	// Write Data Channel
	data_t wdata;
	strb_t wstrb;
	logic wvalid;
	logic wready;
	logic wlast;

	// Write Response Channel
	resp_t bresp;
	logic bvalid;
	logic bready;


	modport master (
		output araddr, arvalid, input arready, output arlen, arsize, arburst,
		input rdata, rresp, rvalid, output rready, input rlast,
		output awaddr, awvalid, input awready, output awlen, awsize, awburst,
		output 	wdata, wstrb, wvalid, input wready, output wlast,
		input bresp, bvalid, output bready
	);

	modport slave (
		input araddr, arvalid, output arready, input arlen, arsize, arburst,
		output rdata, rresp, rvalid, input rready, output rlast,
		input awaddr, awvalid, output awready, input awlen, awsize, awburst,
		input 	wdata, wstrb, wvalid, output wready, input wlast,
		output bresp, bvalid, input bready
	);

endinterface

interface cache_ctrl_l1_intf;
    // Control signals from the Cache Controller to L1 Cache
    logic       op_valid;
    logic[31:0] op_addr;
    logic       op_type; // 0 for read, 1 for write
    logic[31:0] write_data;
    logic       flush; // Signal to flush or invalidate cache lines if needed

    // Status and data signals from L1 Cache to Cache Controller
    logic       ready; // Indicates L1 Cache has completed the operation
    logic[31:0] read_data;
    logic       hit; // Indicates if the operation was a hit or miss in the L1 Cache

    // Modports for access control
    modport controller_side (
        output op_valid, op_addr, op_type, write_data, flush,
        input ready, read_data, hit
    );

    modport cache_side (
        input op_valid, op_addr, op_type, write_data, flush,
        output ready, read_data, hit
    );

endinterface


interface l1_l2_intf;
    // L1 Cache request signals
    logic       l1_req_valid;
    logic[31:0] l1_req_addr;
    logic       l1_req_op; // 0 for read, 1 for write
    logic[31:0] l1_write_data;

    // L2 Cache response signals
    logic       l2_resp_valid;
    logic[31:0] l2_resp_data;
    logic       l2_miss; // Indicates a miss in L2

    // Modports
    modport l1_side (
        output l1_req_valid, l1_req_addr, l1_req_op, l1_write_data,
        input l2_resp_valid, l2_resp_data, l2_miss
    );

    modport l2_side (
        input l1_req_valid, l1_req_addr, l1_req_op, l1_write_data,
        output l2_resp_valid, l2_resp_data, l2_miss
    );

endinterface

interface l2_mem_intf;
    // Memory access request signals
    logic       mem_req_valid;
    logic[31:0] mem_req_addr;
    logic       mem_req_op; // 0 for read, 1 for write
    logic[31:0] mem_write_data;

    // Memory access response signals
    logic       mem_resp_valid;
    logic[31:0] mem_resp_data;

    // Modports
    modport cache_side (
        output mem_req_valid, mem_req_addr, mem_req_op, mem_write_data,
        input mem_resp_valid, mem_resp_data
    );

    modport mem_side (
        input mem_req_valid, mem_req_addr, mem_req_op, mem_write_data,
        output mem_resp_valid, mem_resp_data
    );

endinterface



