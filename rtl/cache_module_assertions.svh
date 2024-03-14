property p_s_aw_ack; // Proeperty_Slave_addresswrite_ack
    @(posedge aclk) disable iff (!aresetn)
    (s_l1_axi_awvalid) |-> ##1 s_l1_axi_awready;
endproperty
assert property (p_s_write_ack); 

property p_s_ar_ack;
    @(posedge aclk) disable iff(!aresetn)
    (s_l1_axi_arvalid) |-> ##1 s_l1_axi_arready;
endproperty
assert property (p_s_read_ack);

property p_awar_xaccess; // aw, ar exclusive access
    @(posedge aclk) disable iff (!aresetn)
    not (s_l1_axi_awready && s_l1_axi_arready);
endproperty
assert property (p_awar_xaccess);

property p_awvarv_xaccess; // awvalid, arvalid excl. access
    @(posedgeaclk) disable iff (!aresetn)
    not(s_l1_axi_awvalid && s_l1_axi_arvalid);
endproperty
assert property (p_awvarv_xaccess);

property p_rdata_integrity; 
    @(posedge aclk) disable iff (!aresetn) 
    (s_l1_axi_arvalid && s_l1_axi_arready) |-> 
    ##[1:$] (s_l1_axi_rvalid && $stable(s_l1_axi_rdata) until s_l1_axi_rready);
endproperty
assert property (p_rdata_integrity);

property p_bresp_validity;
    @(posedge aclk) disable iff (!aresetn)
    (s_l1_axi_bvalid && !s_l1_axi_bready) |-> ##1 !s_l1_axi_bvalid;
endproperty
assert property (p_bresp_validity);

property p_rresp_validity;
    @(posedge aclk) disable iff(!aresetn)
    (s_l1_axi_rvalid && !s_l1_axi_rready) |-> ##1 !s_l1_axi_rvalid;
endproperty
assert property (p_rresp_validity);

property p_cache_hit;
    @(posedge aclk) disable iff(!aresetn)
    (state == CACHE_HIT) |-> ##1 s_l1_axi_rvalid;
endproperty
assert property (p_cache_hit);

property p_handle_cache_read_completion;
    @(posedge aclk) disable iff (!aresetn)
    (arvalid_reg && ch_r_state == CH_FETCH) |-> 
    ##[0:$] (ch_r_state == CH_MOVE && s_l1_axi_rvalid && $fell(s_l1_axi_rvalid));
endproperty
assert property (p_handle_cache_read_completion);



