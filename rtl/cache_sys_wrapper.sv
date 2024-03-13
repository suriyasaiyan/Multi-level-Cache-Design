module cache_sys_wrapper;
    // Clock and Reset
    wire aclk, aresetn; 

    // Signals between CPU and L1 Cache
    wire [31:0] cpu_awaddr, cpu_wdata, cpu_araddr, l1_rdata;
    wire cpu_awvalid, cpu_wvalid, cpu_arvalid, l1_awready, l1_wready, l1_arready, l1_rvalid;
    wire [1:0] l1_bresp, l1_rresp;
    wire l1_bvalid, cpu_bready, cpu_rready;

    // Signals between L1 Cache and L2 Cache
    wire [31:0] l1_awaddr, l1_wdata, l1_araddr, l2_rdata;
    wire l1_awvalid, l1_wvalid, l1_arvalid, l2_awready, l2_wready, l2_arready, l2_rvalid;
    wire [1:0] l2_bresp, l2_rresp;
    wire l2_bvalid, l1_bready, l1_rready;

    // Signals between L2 Cache and Main Memory (Assuming main memory interface is similar)
    wire [31:0] l2_awaddr, l2_wdata, l2_araddr, mem_rdata;
    wire l2_awvalid, l2_wvalid, l2_arvalid, mem_awready, mem_wready, mem_arready, mem_rvalid;
    wire [1:0] mem_bresp, mem_rresp;
    wire mem_bvalid, l2_bready, l2_rready;

    cpu cpu_inst(
        .aclk               (aclk),
        .aresetn            (aresetn),

        // Slave Interface for Write
        .awaddr             (cpu_awaddr),
        .awvalid            (cpu_awvalid),
        .awready            (l1_awready),

        .wdata              (cpu_wdata),
        .wvalid             (cpu_wvalid),
        .wready             (l1_wready),

        .bresp              (l1_bresp),
        .bvalid             (l1_bvalid),
        .bready             (cpu_bready),

        // Slave Interface for Read
        .araddr             (cpu_araddr),
        .arvalid            (cpu_arvalid),
        .arready            (l1_arready),

        .rdata              (l1_rdata),
        .rresp              (l1_rresp),
        .rvalid             (l1_rvalid),
        .rready             (cpu_rready)
    );

    cache_module #(
        .C_AXI_ADDR_WIDTH   (32),
        .C_AXI_DATA_WIDTH   (32),

        .CACHE_SIZE         (4 *1024),
        .BLOCK_SIZE         (4),
        .ASSOCIATIVITY      (2)
    ) l1_cache(
        .aclk               (aclk),
        .aresetn            (aresetn),

        // Connections with CPU (Slave Interface)
        .s_l1_axi_awaddr    (cpu_awaddr),
        .s_l1_axi_awvalid   (cpu_awvalid),
        .s_l1_axi_awready   (l1_awready),

        .s_l1_axi_wdata     (cpu_wdata),
        .s_l1_axi_wvalid    (cpu_wvalid),
        .s_l1_axi_wready    (l1_wready),

        .s_l1_axi_bresp     (l1_bresp),
        .s_l1_axi_bvalid    (l1_bvalid),
        .s_l1_axi_bready    (cpu_bready),

        .s_l1_axi_araddr    (cpu_araddr),
        .s_l1_axi_arvalid   (cpu_arvalid),
        .s_l1_axi_arready   (l1_arready),

        .s_l1_axi_rdata     (l1_rdata),
        .s_l1_axi_rresp     (l1_rresp),
        .s_l1_axi_rvalid    (l1_rvalid),
        .s_l1_axi_rready    (cpu_rready),

        // Connections with L2 Cache (Master Interface)
        .m_l1_axi_awaddr    (l1_awaddr),
        .m_l1_axi_awvalid   (l1_awvalid),
        .m_l1_axi_awready   (l2_awready),

        .m_l1_axi_wdata     (l1_wdata),
        .m_l1_axi_wvalid    (l1_wvalid),
        .m_l1_axi_wready    (l2_wready),

        .m_l1_axi_bresp     (l2_bresp),
        .m_l1_axi_bvalid    (l2_bvalid),
        .m_l1_axi_bready    (l1_bready),

        .m_l1_axi_araddr    (l1_araddr),
        .m_l1_axi_arvalid   (l1_arvalid),
        .m_l1_axi_arready   (l2_arready),

        .m_l1_axi_rdata     (l2_rdata),
        .m_l1_axi_rresp     (l2_rresp),
        .m_l1_axi_rvalid    (l2_rvalid),
        .m_l1_axi_rready    (l1_rready)
    );

    cache_module #(
        .C_AXI_ADDR_WIDTH   (32),
        .C_AXI_DATA_WIDTH   (32),

        .CACHE_SIZE         (16 * 1024), // 16KB L2 Cache
        .BLOCK_SIZE         (4),         // 4-byte blocks
        .ASSOCIATIVITY      (4)          // 4-way set associative
    ) l2_cache(
        .aclk               (aclk),
        .aresetn            (aresetn),

        // Connections with L1 Cache (Slave Interface)
        .s_l2_axi_awaddr    (l1_awaddr),
        .s_l2_axi_awvalid   (l1_awvalid),
        .s_l2_axi_awready   (l2_awready),

        .s_l2_axi_wdata     (l1_wdata),
        .s_l2_axi_wvalid    (l1_wvalid),
        .s_l2_axi_wready    (l2_wready),

        .s_l2_axi_bresp     (l2_bresp),
        .s_l2_axi_bvalid    (l2_bvalid),
        .s_l2_axi_bready    (l1_bready),

        .s_l2_axi_araddr    (l1_araddr),
        .s_l2_axi_arvalid   (l1_arvalid),
        .s_l2_axi_arready   (l2_arready),

        .s_l2_axi_rdata     (l2_rdata),
        .s_l2_axi_rresp     (l2_rresp),
        .s_l2_axi_rvalid    (l2_rvalid),
        .s_l2_axi_rready    (l1_rready),

        // Connections with Main Memory (Master Interface)
        .m_l2_axi_awaddr    (l2_awaddr),
        .m_l2_axi_awvalid   (l2_awvalid),
        .m_l2_axi_awready   (mem_awready),

        .m_l2_axi_wdata     (l2_wdata),
        .m_l2_axi_wvalid    (l2_wvalid),
        .m_l2_axi_wready    (mem_wready),

        .m_l2_axi_bresp     (mem_bresp),
        .m_l2_axi_bvalid    (mem_bvalid),
        .m_l2_axi_bready    (l2_bready),

        .m_l2_axi_araddr    (l2_araddr),
        .m_l2_axi_arvalid   (l2_arvalid),
        .m_l2_axi_arready   (mem_arready),

        .m_l2_axi_rdata     (mem_rdata),
        .m_l2_axi_rresp     (mem_rresp),
        .m_l2_axi_rvalid    (mem_rvalid),
        .m_l2_axi_rready    (l2_rready)
    );

    main_memory main_memory_inst(
        .aclk               (aclk),
        .aresetn            (aresetn),

        // Assuming similar interface to L1 and L2 cache
        .awaddr             (l2_awaddr),
        .awvalid            (l2_awvalid),
        .awready            (mem_awready),

        .wdata              (l2_wdata),
        .wvalid             (l2_wvalid),
        .wready             (mem_wready),

        .bresp              (mem_bresp),
        .bvalid             (mem_bvalid),
        .bready             (l2_bready),

        .araddr             (l2_araddr),
        .arvalid            (l2_arvalid),
        .arready            (mem_arready),

        .rdata              (mem_rdata),
        .rresp              (mem_rresp),
        .rvalid             (mem_rvalid),
        .rready             (l2_rready)
    );

endmodule
