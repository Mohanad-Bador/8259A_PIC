module P8259IC(
	input		wire					chip_select_n,
	input		wire					read_enable_n,
	input		wire					write_enable_n,
	input		wire					address,
	input		wire	[7:0]			data_bus_in,
	output		reg		[7:0]			data_bus_out,
	output		reg						data_bus_io,
	input		wire	[2:0]			cascade_in,
	output		wire	[2:0]			cascade_out,
	output		wire					cascade_io,
	input		wire					slave_program_n,
	output		reg					buffer_enable,
	output		wire					slave_program_or_enable_buffer,
	input		wire					interrupt_acknowledge_n,
	output		wire				interrupt_to_cpu,
	input		wire	[7:0]			interrupt_request

);
	wire [7:0] internal_data_bus;
	wire write_initial_command_word_1;
	wire write_initial_command_word_2_4;
	wire write_operation_control_word_1;
	wire write_operation_control_word_2;
	wire write_operation_control_word_3;
	wire read;
	
	Read_write_Bus Bus_Control_Logic(
		.chip_select(chip_select_n),
		.read_enable(read_enable_n),
		.write_enable(write_enable_n),
		.A0(address),
		.data_bus_input(data_bus_in),
		.internal_data_bus(internal_data_bus),
		.write_ICW1(write_initial_command_word_1),
		.write_ICW2_4(write_initial_command_word_2_4),
		.write_OCW1(write_operation_control_word_1),
		.write_OCW2(write_operation_control_word_2),
		.write_OCW3(write_operation_control_word_3),
		.read(read)

	);
	wire out_control_logic_data;

	wire [7:0] control_logic_data;
	wire level_or_edge_toriggered_config;
	wire special_fully_nest_config;
	wire enable_read_register;
	wire read_register_isr_or_irr;
	wire [7:0] interrupt;
	wire [7:0] highest_level_in_service;
	wire [7:0] interrupt_mask;
	wire [7:0] interrupt_special_mask;
	wire [7:0] end_of_interrupt;
	wire [2:0] priority_rotate;
	wire freeze;
	wire latch_in_service;
	wire [7:0] clear_interrupt_request;
	
	Controllyyyy_Logic control_logic(
		.in_cascade_lines(cascade_in),
		.out_cascade_lines(cascade_out),
		.cascade_io(cascade_io),
		.slave(slave_program_n),
		.slave_program_or_enable_buffer(slave_program_or_enable_buffer),
		.INTA(interrupt_acknowledge_n),
		.INT(interrupt_to_cpu),
		.data_bus(internal_data_bus),
		.write_ICW1(write_initial_command_word_1),
		.write_ICW2_4(write_initial_command_word_2_4),
		.write_OCW1(write_operation_control_word_1),
		.write_OCW2(write_operation_control_word_2),
		.write_OCW3(write_operation_control_word_3),
		.read(read),
		.data_out_from_control_logic_flag(out_control_logic_data),
		.output_data(control_logic_data),
		.level_or_edge_triggered_flag(level_or_edge_toriggered_config),
		.special_fully_nested_config(special_fully_nest_config),
		.read_enable(enable_read_register),
		.IRR_OR_ISR(read_register_isr_or_irr),
		.interrupt(interrupt),
		.highest_level_in_service(highest_level_in_service),
		.interrupt_mask(interrupt_mask),
		.end_interrupt(end_of_interrupt),
		.priority_rotate(priority_rotate),
		.freeze(freeze),
		.latch_ISR(latch_in_service),
		.clear_interrupt_request(clear_interrupt_request)

	);
	wire [7:0] interrupt_request_register;
	IRRRRR irr(
		.level_or_edge_triggered_flag(level_or_edge_toriggered_config),
		.freeze(freeze),
		.clear_interrupt_request(clear_interrupt_request),
		.interrupt_requesting_phreferals(interrupt_request),
		.IRR(interrupt_request_register)
	
	);
	
	wire [7:0] in_service_register;
	priority_resolver PR(
		.priority_rotate(priority_rotate),
		.interrupt_mask(interrupt_mask),
		.special_fully_nested_config(special_fully_nest_config),
		.highest_level_in_service(highest_level_in_service),
		.IRR(interrupt_request_register),
		.ISR(in_service_register),
		.interrupt(interrupt)

	);
	
	in_service_register issr(
		.priority_rotate(priority_rotate),
		.interrupt(interrupt),
		.latch_ISR(latch_in_service),
		.end_interrupt(end_of_interrupt),
		.ISR(in_service_register),
		.highest_level_in_service(highest_level_in_service)
	

	);
	
	always @(*) begin
		if (out_control_logic_data == 1'b1) begin
			data_bus_io = 1'b0;
			data_bus_out = control_logic_data;
		end
		else if (read == 1'b0) begin
			data_bus_io = 1'b1;
			data_bus_out = 8'b00000000;
		end
		else if (address == 1'b1) begin
			data_bus_io = 1'b0;
			data_bus_out = interrupt_mask;
		end
		else if ((enable_read_register == 1'b1) && (read_register_isr_or_irr == 1'b0)) begin
			data_bus_io = 1'b0;
			data_bus_out = interrupt_request_register;
		end
		else if ((enable_read_register == 1'b1) && (read_register_isr_or_irr == 1'b1)) begin
			data_bus_io = 1'b0;
			data_bus_out = in_service_register;
		end
		else begin
			data_bus_io = 1'b1;
			data_bus_out = 8'b00000000;
		end
	end
	always@* begin
	   buffer_enable = (slave_program_or_enable_buffer == 1'b1 ? 1'b0 : ~data_bus_io);
  end
endmodule


