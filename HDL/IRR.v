module interrupt_Request_reg (
    // Inputs from control logic
    input level_or_edge_triggered_config,
    input freeze,
    input [7:0] clear_interrupt_request,

    // External inputs
    input [7:0] interrupt_request_pin,

    // Outputs
    output reg [7:0] interrupt_request_register
);

    reg [7:0] low_input_latch;
    wire [7:0] interrupt_request_edge;

   genvar ir_bit_no;
    generate
    for (ir_bit_no = 0; ir_bit_no <= 7; ir_bit_no = ir_bit_no + 1) begin: Request_Latch
        //
        // Edge Sense
        //
        always @* begin
            if (clear_interrupt_request[ir_bit_no] == 1'b1)
                low_input_latch[ir_bit_no] = 1'b0;
            else if (interrupt_request_pin[ir_bit_no] == 1'b0)
                low_input_latch[ir_bit_no] = 1'b1;
            else
                low_input_latch[ir_bit_no] = low_input_latch[ir_bit_no];
        end

        assign interrupt_request_edge[ir_bit_no] = (low_input_latch[ir_bit_no] == 1'b1) & (interrupt_request_pin[ir_bit_no] == 1'b1);

        //
        // Request Latch
        //
        always @* begin
            if (clear_interrupt_request[ir_bit_no] == 1'b1)
                interrupt_request_register[ir_bit_no] = 1'b0;
            else if (freeze == 1'b1)
                interrupt_request_register[ir_bit_no] = interrupt_request_register[ir_bit_no];
            else if (level_or_edge_triggered_config == 1'b1)
                interrupt_request_register[ir_bit_no] = interrupt_request_pin[ir_bit_no];
            else
                interrupt_request_register[ir_bit_no] = interrupt_request_edge[ir_bit_no];
        end
    end
    endgenerate

endmodule
