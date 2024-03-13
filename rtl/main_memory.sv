module main_memory #(
    parameter DATA_WIDTH = 32,      // Data bus width
    parameter ADDR_WIDTH = 32,      // Address bus width
)(
    input wire                     aclk,   
    input wire                     aresetn,  

    // Write address channel
    input wire [ADDR_WIDTH-1:0]    awaddr,
    input wire                     awvalid,
    output reg                     awready,

    // Write data channel
    input wire [DATA_WIDTH-1:0]    wdata,
    input wire                     wvalid,
    output reg                     wready,

    // Write response channel
    output reg [1:0]               bresp,
    output reg                     bvalid,
    input wire                     bready,

    // Read address channel
    input wire [ADDR_WIDTH-1:0]    araddr,
    input wire                     arvalid,
    output reg                     arready,

    // Read data channel
    output reg [DATA_WIDTH-1:0]    rdata,
    output reg [1:0]               rresp,
    output reg                     rvalid,
    input wire                     rready
);
    // Memory storage
    reg [DATA_WIDTH-1:0] memory [(1<<ADDR_WIDTH)-1:0];

    always @(posedge aclk) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready <= 1'b0;
            bvalid <= 1'b0;
            arready <= 1'b0;
            rvalid <= 1'b0;
        end else begin
            // Handle write requests
            if (awvalid && !awready) begin
                awready         <= 1'b1;
            end else if (wvalid && awready && !wready) begin
                memory[awaddr]  <= wdata;
                wready          <= 1'b1;
                bresp           <= 2'b00; // OKAY response
                bvalid          <= 1'b1;
            end else if (bvalid && bready) begin
                awready         <= 1'b0;
                wready          <= 1'b0;
                bvalid          <= 1'b0;
            end

            // Handle read requests
            if (arvalid && !arready) begin
                arready         <= 1'b1;
                rdata           <= memory[araddr];
                rresp           <= 2'b00; 
                rvalid          <= 1'b1;
            end else if (rvalid && rready) begin
                arready         <= 1'b0;
                rvalid          <= 1'b0;
            end
        end
    end
    
endmodule
