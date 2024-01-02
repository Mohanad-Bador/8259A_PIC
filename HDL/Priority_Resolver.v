
`default_nettype none

module Priority_Resolver (
	input		wire	[2:0] 		priorityRotate,
	input		wire	[7:0] 		interrupt_mask,
	input		wire	[7:0] 		interruptMask,
	input		wire					special_fully_nest_config,
	input		wire	[7:0] 		highestInServ,
	input		wire	[7:0] 		interrupt_request_register,
	input		wire	[7:0] 		inServREG,
	output	wire	[7:0] 		interrupt
	);


	wire [7:0] masked_interrupt_request;
	assign masked_interrupt_request = interrupt_request_register & ~interrupt_mask;
	wire [7:0] masked_in_service;
	assign masked_in_service = inServREG & ~interruptMask;
	wire [7:0] rotated_request;
	reg [7:0] rotated_in_service;
	wire [7:0] rotated_highestInServ;
	reg [7:0] priority_mask;
	wire [7:0] rotated_interrupt;

	assign rotated_request = rotate_right(masked_interrupt_request, priorityRotate);
	assign rotated_highestInServ = rotate_right(highestInServ, priorityRotate);
	always @(*) begin
		rotated_in_service = rotate_right(masked_in_service, priorityRotate);
		if (special_fully_nest_config == 1'b1)
			rotated_in_service = (rotated_in_service & ~rotated_highestInServ) | {rotated_highestInServ[6:0], 1'b0};
	end
	always @(*)begin
		if (rotated_in_service[0] == 1'b1)
			priority_mask = 8'b00000000;
		else if (rotated_in_service[1] == 1'b1)
			priority_mask = 8'b00000001;
		else if (rotated_in_service[2] == 1'b1)
			priority_mask = 8'b00000011;
		else if (rotated_in_service[3] == 1'b1)
			priority_mask = 8'b00000111;
		else if (rotated_in_service[4] == 1'b1)
			priority_mask = 8'b00001111;
		else if (rotated_in_service[5] == 1'b1)
			priority_mask = 8'b00011111;
		else if (rotated_in_service[6] == 1'b1)
			priority_mask = 8'b00111111;
		else if (rotated_in_service[7] == 1'b1)
			priority_mask = 8'b01111111;
		else
			priority_mask = 8'b11111111;
  end

	assign interrupt = rotate_left(rotated_interrupt, priorityRotate);
	
	//*******************************************************************
	//*******************************************************************
	//*******************************************************************
	//*******************************************************************
		function [7:0] rotate_right;
		input [7:0] source;
		input [2:0] rotate;
		casez (rotate)
			3'b000: rotate_right = {source[0], source[7:1]};
			3'b001: rotate_right = {source[1:0], source[7:2]};
			3'b010: rotate_right = {source[2:0], source[7:3]};
			3'b011: rotate_right = {source[3:0], source[7:4]};
			3'b100: rotate_right = {source[4:0], source[7:5]};
			3'b101: rotate_right = {source[5:0], source[7:6]};
			3'b110: rotate_right = {source[6:0], source[7]};
			3'b111: rotate_right = source;
			default: rotate_right = source;
		endcase
	endfunction
	
		assign rotated_interrupt = resolve_priority(rotated_request) & priority_mask;
	function [7:0] rotate_left;
		input [7:0] source;
		input [2:0] rotate;
		casez (rotate)
			3'b000: rotate_left = {source[6:0], source[7]};
			3'b001: rotate_left = {source[5:0], source[7:6]};
			3'b010: rotate_left = {source[4:0], source[7:5]};
			3'b011: rotate_left = {source[3:0], source[7:4]};
			3'b100: rotate_left = {source[2:0], source[7:3]};
			3'b101: rotate_left = {source[1:0], source[7:2]};
			3'b110: rotate_left = {source[0], source[7:1]};
			3'b111: rotate_left = source;
			default: rotate_left = source;
		endcase
	endfunction
	
		function [7:0] resolve_priority;
		input [7:0] request;
		if (request[0] == 1'b1)
			resolve_priority = 8'b00000001;
		else if (request[1] == 1'b1)
			resolve_priority = 8'b00000010;
		else if (request[2] == 1'b1)
			resolve_priority = 8'b00000100;
		else if (request[3] == 1'b1)
			resolve_priority = 8'b00001000;
		else if (request[4] == 1'b1)
			resolve_priority = 8'b00010000;
		else if (request[5] == 1'b1)
			resolve_priority = 8'b00100000;
		else if (request[6] == 1'b1)
			resolve_priority = 8'b01000000;
		else if (request[7] == 1'b1)
			resolve_priority = 8'b10000000;
		else
			resolve_priority = 8'b00000000;
	endfunction
endmodule

