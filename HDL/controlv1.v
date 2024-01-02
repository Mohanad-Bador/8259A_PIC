`default_nettype none
`timescale 1ns / 1ps

module Controlyyy_Logic (
	// External input/output
	input		wire	[2:0]			cas_in,
	output	reg	[2:0]			cas_out,
	output	wire					cas_io,
	input		wire					sp_n,
	input		wire					intA_n,
	output	reg					int,
	// Internal bus
	input		wire	[7:0]			internal_data_bus,
	input		wire					write_icw_1,
	input		wire					write_icw_2_4,
	input		wire					write_ocw_1,
	input		wire					write_ocw_2,
	input		wire					write_ocw_3,
	input		wire					read,
	output	reg					out_control_logic_data,
	output	reg	[7:0]			control_logic_data,
	// Registers to interrupt detecting logics
	output	reg					level_or_edge_toriggered_config,
	output	reg					special_fully_nest_config,
	// Registers to Read logics
	output	reg					enable_read_register,
	output	reg					read_register_isr_or_irr,
	// Signals from interrupt detectiong logics
	input		wire	[7:0]			interrupt,
	input		wire	[7:0]			highest_level_in_service,
	// Interrupt control signals
	output	reg	[7:0]			interrupt_mask,
	output	reg	[7:0]			interrupt_special_mask,
	output	reg	[7:0]			end_of_interrupt,
	output	reg	[2:0]			priority_rotate,
	output	reg					freeze,
	output	reg					latch_in_service,
	output	reg	[7:0]			clear_interrupt_request
	);

	reg [4:0] interrupt_vector_address; //T7-T3
	reg call_address_interval_4_or_8_config;
	reg single_or_cascade_config;
	reg set_icw4_config;
	reg [7:0] cascade_device_config;
	reg buffered_mode_config;
	reg buffered_master_or_slave_config;
	reg auto_eoi_config;
	reg u8086_or_mcs80_config;
	reg special_mask_mode;
	reg enable_special_mask_mode;
	reg auto_rotate_mode;
	reg [7:0] acknowledge_interrupt;
	reg cascade_slave;
	reg cascade_slave_enable;
	reg cas_output_ack_2_3;

  parameter READY=2'b00,ICW2=2'b01,ICW3=2'b10,ICW4=2'b11;
	// the next two registers are uesd for the initialization command words sequence 
	reg [1:0] command_state;
	reg [1:0] next_command_state;
	// State transition logic for the control logic state machine
	  // State transition and update logic
  always @(posedge write_icw_1 or posedge write_icw_2_4) begin
    // Asynchronous state transition logic
    if (write_icw_1) begin
      next_command_state <= ICW2;
    end else if (write_icw_2_4) begin
      case (command_state)
        ICW2: next_command_state <= (single_or_cascade_config == 1'b0) ? ICW3 :
                                   (set_icw4_config == 1'b1) ? ICW4 : READY;
        ICW3: next_command_state <= (set_icw4_config == 1'b1) ? ICW4 : READY;
        ICW4: next_command_state <= READY;
        default: next_command_state <= READY;
      endcase
    end
  end

  // Synchronous state update
  always @(posedge write_icw_1 or posedge write_icw_2_4) begin
    if (write_icw_1 || write_icw_2_4) begin
      command_state <= next_command_state;
    end
  end

  // Wires indicating which ICW and OCW registers are being written
  
  wire write_icw_2 = (command_state == ICW2) & write_icw_2_4;

  wire write_icw_3 = (command_state == ICW3) & write_icw_2_4;

  wire write_icw_4 = (command_state == ICW4) & write_icw_2_4;

  wire write_ocw_1_registers = (command_state == READY) & write_ocw_1;
  wire write_ocw_2_registers = (command_state == READY) & write_ocw_2;
  wire write_ocw_3_registers = (command_state == READY) & write_ocw_3;

  // Detect read signal edge
  reg prev_read_signal;
  always @(posedge read)
    prev_read_signal <= read;
  wire nedge_read_signal = prev_read_signal & ~read;
  
  // Detect ACK edge
  reg prev_intA_n;
  always @(posedge intA_n)
    prev_intA_n <= intA_n;
  wire nedge_interrupt_acknowledge = prev_intA_n & ~intA_n;
  wire pedge_interrupt_acknowledge = ~prev_intA_n & intA_n;
  
  reg [1:0] next_control_state;
  reg [1:0] control_state;
  parameter CTL_READY = 2'b00, ACK1 = 2'b01, ACK2 = 2'b10, POLL = 2'b11;
  // Next state logic
	always @* begin
		case (control_state)
			CTL_READY: begin
				if (write_ocw_3_registers && internal_data_bus[2])
					next_control_state = POLL;
				else if (write_ocw_2_registers)
					next_control_state = CTL_READY;
				else if (nedge_interrupt_acknowledge == 0)
					next_control_state = CTL_READY;
				else
					next_control_state = ACK1;
			end
			ACK1: begin
				if (pedge_interrupt_acknowledge == 0)
					next_control_state = ACK1;
				else
					next_control_state = ACK2;
			end
			ACK2: begin
				if (pedge_interrupt_acknowledge == 0)
					next_control_state = ACK2;
				else
					next_control_state = CTL_READY;
			end
			POLL: begin
				if (nedge_read_signal == 0)
					next_control_state = POLL;
				else
					next_control_state = CTL_READY;
			end
			default: begin
				next_control_state = CTL_READY;
			end
		endcase
	end

	// State register without reset
	always @(posedge intA_n)
		control_state <= next_control_state;


	wire end_of_acknowledge_sequence = ((control_state != POLL) & (control_state != CTL_READY)) & (next_control_state == CTL_READY);
	wire end_of_poll_command = ((control_state == POLL) & (control_state != CTL_READY)) & (next_control_state == CTL_READY);
	
  // Initialization command word 1

	always @(posedge write_icw_1) begin
    	   // IC4 bit
    	   set_icw4_config <= internal_data_bus[0];
    	   // SNGL bit
        single_or_cascade_config <= internal_data_bus[1];
    	   // LTIM bit
				level_or_edge_toriggered_config <= internal_data_bus[3];
	end
		
	// Initialization command word 2

	always @(posedge write_icw_2)begin
        //T7-T3 (8086, 8088)
				interrupt_vector_address[4:0] = internal_data_bus[7:3];
	end

	// Initialization command word 3

	always @(posedge write_icw_3) begin
	     	// S7-S0 (MASTER) or ID2-ID0 (SLAVE)
			  cascade_device_config = internal_data_bus;
	end
	
	// Initialization command word 4
	
	always @(posedge write_icw_4) begin
	     //Automatic end of interrupt
       auto_eoi_config <= internal_data_bus[1];
	     //Master/slave
	     buffered_master_or_slave_config <= internal_data_bus[2];
	     //special fully nested mode
			 special_fully_nest_config <= internal_data_bus[4];     
  end
  
  // Operation control word 1

  always @(posedge write_ocw_1_registers) begin
        // Interrupt Mask registers
        interrupt_mask = internal_data_bus;
    // No need for an "else" statement here as the default condition is to keep the existing value
  end
  
  //operation control word 2
  
	//End of interrupt mode 	
	always @(*) begin
		if ((auto_eoi_config == 1'b1) && (end_of_acknowledge_sequence == 1'b1))
			end_of_interrupt = acknowledge_interrupt;
		else if (write_ocw_2 == 1'b1)
			casez (internal_data_bus[6:5])
				2'b01: end_of_interrupt = highest_level_in_service;
				2'b11: end_of_interrupt = num2bit(internal_data_bus[2:0]);
				default: end_of_interrupt = 8'b00000000;
			endcase
		else
			end_of_interrupt = 8'b00000000;
	end
	
	//Auto rotate mode 
	always @(posedge write_ocw_2) begin
			casez (internal_data_bus[7:5])
				3'b000: auto_rotate_mode <= 1'b0;
				3'b100: auto_rotate_mode <= 1'b1;
				default: auto_rotate_mode <= auto_rotate_mode;
			endcase
	end
	
	// Rotation
	always @(*)begin
		if ((auto_rotate_mode == 1'b1) && (end_of_acknowledge_sequence == 1'b1))
			priority_rotate <= bit2num(acknowledge_interrupt);
		else if (write_ocw_2 == 1'b1)begin
			casez (internal_data_bus[7:5])
				3'b101: priority_rotate <= bit2num(highest_level_in_service);
				3'b11z: priority_rotate <= internal_data_bus[2:0];
				default: priority_rotate <= priority_rotate;
			endcase
		end
  end
  
 	always @(posedge write_ocw_3_registers)begin
			enable_read_register <= internal_data_bus[1];
			read_register_isr_or_irr <= internal_data_bus[0];
	end

	// Operation control word 3
	//Cascading block
	
	//Master or slave determination
	always @(*)begin
		if (single_or_cascade_config == 1'b1)
			cascade_slave = 1'b0;
		else if (buffered_mode_config == 1'b0)
			cascade_slave = ~sp_n;
		else
			cascade_slave = ~buffered_master_or_slave_config;
	end
	assign cas_io = cascade_slave;
	
	//Slave:   Determines which slave is operating 
	always @(*)begin
		if (cascade_slave == 1'b0)
			cascade_slave_enable = 1'b0;
		else if (cascade_device_config[2:0] != cas_in)
			cascade_slave_enable = 1'b0;
		else
			cascade_slave_enable = 1'b1;
	end
	wire interrupt_from_slave_device = (acknowledge_interrupt & cascade_device_config) != 8'b00000000;
	
	//master: Cascade signals 
	always @(*)begin
		if (single_or_cascade_config == 1'b1)
			cas_output_ack_2_3 = 1'b1;
		else if (cascade_slave_enable == 1'b1)
			cas_output_ack_2_3 = 1'b1;
		else if ((cascade_slave == 1'b0) && (interrupt_from_slave_device == 1'b0))
			cas_output_ack_2_3 = 1'b1;
		else
			cas_output_ack_2_3 = 1'b0;
	end
	
	// Output slave id
	always @(*)begin
		if (cascade_slave == 1'b1)
			cas_out <= 3'b000;
		else if (((control_state != 32'd1) && (control_state != 32'd2)) && (control_state != 32'd3))
			cas_out <= 3'b000;
		else if (interrupt_from_slave_device == 1'b0)
			cas_out <= 3'b000;
		else
			cas_out <= bit2num(acknowledge_interrupt);
  end

	//Interrupt Signals
  //
	//interrupt signal to cpu
	always @(*)begin 
		if (interrupt != 8'b00000000)
			int <= 1'b1;
		else if (end_of_acknowledge_sequence == 1'b1)
			int <= 1'b0;
		else if (end_of_poll_command == 1'b1)
			int <= 1'b0;
		else
			int <= int;
	end
	
	//freeze signal to IRR
	always @(*)begin
    if (next_control_state == CTL_READY)
			freeze <= 1'b0;
		else
			freeze <= 1'b1;
	end
	
	// clear interupt request for IRR
	always @(*)begin 
		if (write_icw_1 == 1'b1)
			clear_interrupt_request = 8'b11111111;
		else if (latch_in_service == 1'b0)
			clear_interrupt_request = 8'b00000000;
		else
			clear_interrupt_request = interrupt;
	end
	
		//LATCH IN SERVICE
	// interrupt buffer
	always @(*)begin
		if (end_of_acknowledge_sequence)
			acknowledge_interrupt <= 8'b00000000;
		else if (end_of_poll_command == 1'b1)
			acknowledge_interrupt <= 8'b00000000;
		else if (latch_in_service == 1'b1)
			acknowledge_interrupt <= interrupt;
		else
			acknowledge_interrupt <= acknowledge_interrupt;
	end
	reg [7:0] interrupt_when_ack1;
	always @(*)begin
		if (control_state == ACK1)
			interrupt_when_ack1 <= interrupt;
		else
			interrupt_when_ack1 <= interrupt_when_ack1;
	end
	
		always @(*)
		if (intA_n == 1'b0)
			casez (control_state)
				CTL_READY:
					if (cascade_slave == 1'b0) begin
							out_control_logic_data = 1'b0;
							control_logic_data = 8'b00000000;
					end
					else begin
						out_control_logic_data = 1'b0;
						control_logic_data = 8'b00000000;
					end
				ACK1:
					if (cascade_slave == 1'b0) begin
							out_control_logic_data = 1'b0;
							control_logic_data = 8'b00000000;
					end
					else begin
						out_control_logic_data = 1'b0;
						control_logic_data = 8'b00000000;
					end
				ACK2:
					if (cas_output_ack_2_3 == 1'b1) begin
						out_control_logic_data = 1'b1;
						if (cascade_slave == 1'b1)
							control_logic_data[2:0] = bit2num(interrupt_when_ack1);
						else
							control_logic_data[2:0] = bit2num(acknowledge_interrupt);

						control_logic_data = {interrupt_vector_address[4:0], control_logic_data[2:0]};
					end
					else begin
						out_control_logic_data = 1'b0;
						control_logic_data = 8'b00000000;
					end
				default: begin
					out_control_logic_data = 1'b0;
					control_logic_data = 8'b00000000;
				end
			endcase
		else if ((control_state == POLL) && (read == 1'b1)) begin
			out_control_logic_data = 1'b1;
			if (acknowledge_interrupt == 8'b00000000)
				control_logic_data = 8'b00000000;
			else begin
				control_logic_data[7:3] = 5'b10000;
				control_logic_data[2:0] = bit2num(acknowledge_interrupt);
			end
		end
		else begin
			out_control_logic_data = 1'b0;
			control_logic_data = 8'b00000000;
		end


	function [7:0] num2bit;
		input [2:0] source;
		casez (source)
			3'b000: num2bit = 8'b00000001;
			3'b001: num2bit = 8'b00000010;
			3'b010: num2bit = 8'b00000100;
			3'b011: num2bit = 8'b00001000;
			3'b100: num2bit = 8'b00010000;
			3'b101: num2bit = 8'b00100000;
			3'b110: num2bit = 8'b01000000;
			3'b111: num2bit = 8'b10000000;
			default: num2bit = 8'b00000000;
		endcase
	endfunction
		function [2:0] bit2num;
		input [7:0] source;
		if (source[0] == 1'b1)
			bit2num = 3'b000;
		else if (source[1] == 1'b1)
			bit2num = 3'b001;
		else if (source[2] == 1'b1)
			bit2num = 3'b010;
		else if (source[3] == 1'b1)
			bit2num = 3'b011;
		else if (source[4] == 1'b1)
			bit2num = 3'b100;
		else if (source[5] == 1'b1)
			bit2num = 3'b101;
		else if (source[6] == 1'b1)
			bit2num = 3'b110;
		else if (source[7] == 1'b1)
			bit2num = 3'b111;
		else
			bit2num = 3'b111;
	endfunction
endmodule


module Control_Logic_tb;

  // Inputs
  reg [2:0] cas_in;
  reg sp_n, intA_n;
  reg [7:0] internal_data_bus;
  reg write_icw_1, write_icw_2_4, write_ocw_1, write_ocw_2, write_ocw_3, read;

  // Outputs
  wire [2:0] cas_out;
  wire cas_io;
  wire int;
  wire [7:0] control_logic_data;
  wire level_or_edge_triggered_config, special_fully_nest_config;
  wire enable_read_register, read_register_isr_or_irr;
  reg [7:0] interrupt, highest_level_in_service;
  wire [7:0] interrupt_mask, interrupt_special_mask, end_of_interrupt, clear_interrupt_request;
  wire [2:0] priority_rotate;
  wire freeze, latch_in_service;

  // Instantiate the Control_Logic module
  Control_Logic uut (
    .cas_in(cas_in),
    .cas_out(cas_out),
    .cas_io(cas_io),
    .sp_n(sp_n),
    .intA_n(intA_n),
    .int(int),
    .internal_data_bus(internal_data_bus),
    .write_icw_1(write_icw_1),
    .write_icw_2_4(write_icw_2_4),
    .write_ocw_1(write_ocw_1),
    .write_ocw_2(write_ocw_2),
    .write_ocw_3(write_ocw_3),
    .read(read),
    .out_control_logic_data(),
    .control_logic_data(control_logic_data),
    .level_or_edge_toriggered_config(level_or_edge_triggered_config),
    .special_fully_nest_config(special_fully_nest_config),
    .enable_read_register(enable_read_register),
    .read_register_isr_or_irr(read_register_isr_or_irr),
    .interrupt(interrupt),
    .highest_level_in_service(highest_level_in_service),
    .interrupt_mask(interrupt_mask),
    .interrupt_special_mask(interrupt_special_mask),
    .end_of_interrupt(end_of_interrupt),
    .priority_rotate(priority_rotate),
    .freeze(freeze),
    .latch_in_service(latch_in_service),
    .clear_interrupt_request(clear_interrupt_request)
  );

  // Testbench initial block
  initial begin
    // Initialize inputs
    cas_in = 3'b000;
    sp_n = 1;
    intA_n = 1;
    internal_data_bus = 8'h00;
    write_icw_1 = 0;
    write_icw_2_4 = 0;
    write_ocw_1 = 0;
    write_ocw_2 = 0;
    write_ocw_3 = 0;
    read = 0;

// Test case 1: Write ICW1
#20 internal_data_bus = 8'h03;
#10  write_icw_1 = 1;

 #10 write_icw_1 = 0;
// Test case 2: Write ICW2-4
 #20 internal_data_bus = 8'h09;
 #10 write_icw_2_4 = 1;

#10 write_icw_2_4 = 0;
// Test case 2: Write ICW2-4
#10 write_icw_2_4 = 1;

 #10write_icw_2_4 = 0;

// Test case 2: Write ICW2-4
#10 internal_data_bus = 8'h07;
#10  write_icw_2_4 = 1;

#10  write_icw_2_4 = 0;

#10 write_icw_2_4 = 1;

 #10write_icw_2_4 = 0;

// Test case 2: Write ICW2-4
#10 internal_data_bus = 8'h07;
#10  write_icw_2_4 = 1;

#10  write_icw_2_4 = 0;

// Test case 3: Write OCW1
#10 internal_data_bus = 8'h0F;
#10 write_ocw_1 = 1;

#10 write_ocw_1 = 0;
// Test case 4: Write OCW2
#10 internal_data_bus = 8'h0D;
#10 write_ocw_2 = 1;

#10 write_ocw_2 = 0;
// Test case 5: Write OCW3
#10 internal_data_bus = 8'h06;
#10 write_ocw_3 = 1;

    // Monitor signals
    $monitor("Time=%0t, Control_Logic Data=%h, Interrupt=%h", $time, control_logic_data, interrupt);

    // Run the simulation for a specific duration
    #100 $stop; // Stop simulation after 100 time units
  end

endmodule