`default_nettype none

module In_Service (
	input		wire	[2:0]			priorityRotate,
	input		wire	[7:0]			interruptMask,
	input		wire	[7:0]			interrupt,
	input		wire					inServSignal,
	input		wire	[7:0]			endOfInterrupt,
	output	reg	[7:0]			inServREG,
	output	reg	[7:0]			highestInServ
	);
	reg [7:0] next_highestInServ;
  //inServSignal = 8'b00000000;
  //highestInServ = 8'b00000000;
	wire [7:0] next_inServREG;
	assign next_inServREG = (inServREG & ~endOfInterrupt) | (inServSignal == 1'b1 ? interrupt : 8'b00000000);
	always @(*)begin 
			inServREG <= next_inServREG;
			highestInServ <= next_highestInServ;
  end

	always @(*) begin
		next_highestInServ = next_inServREG & ~interruptMask;
		next_highestInServ = rotate_right(next_highestInServ, priorityRotate);
		next_highestInServ = resolve_priority(next_highestInServ);
		next_highestInServ = rotate_left(next_highestInServ, priorityRotate);
	end
  //*******************************************************************
  //*******************************************************************
  //*******************************************************************
  //*******************************************************************
  //*******************************************************************
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
endmodule




