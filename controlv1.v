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

    // TODO

endmodule