module in_service_register(
    // Inputs
    input [2:0] priority_rotate,
    input [7:0] interrupt,
    input latch_ISR,
    input [7:0] end_interrupt,
    // Outputs
    output reg [7:0] ISR,
    output reg [7:0] highest_level_in_service

);


	reg [7:0] next_ISR;

	
	//This assigns the new ISR by reseting the bits of the ended interrupts and by setting the bits of the new interrupt requests
	//assign next_ISR = (ISR & ~end_interrupt) | (latch_ISR == 1'b1 ? interrupt : 8'b00000000);
	always@(*)begin
		next_ISR = (ISR & ~end_interrupt) | ( interrupt&~ end_interrupt);
	end
	
	//Sets the value of the ISR
	always@(next_ISR)begin
		ISR <= next_ISR;
	end
	
	
	reg [7:0] next_highest_level_in_service;
	
	always@* begin
        next_highest_level_in_service = rotate_right(next_ISR, priority_rotate);
        next_highest_level_in_service = resolv_priority(next_highest_level_in_service);
        next_highest_level_in_service = rotate_left(next_highest_level_in_service, priority_rotate);
	end

	always@(next_highest_level_in_service)begin
		highest_level_in_service <= next_highest_level_in_service;

	end
	
	
/*---------------------------------------------------------------------	
Helper functions to find the highest priority interrupt after rotation
----------------------------------------------------------------------*/

function [7:0] rotate_right(input [7:0] source, input [2:0] rotate);
    case (rotate)
		3'b000:  rotate_right = { source[0],   source[7:1] };
        3'b001:  rotate_right = { source[1:0], source[7:2] };
        3'b010:  rotate_right = { source[2:0], source[7:3] };
        3'b011:  rotate_right = { source[3:0], source[7:4] };
        3'b100:  rotate_right = { source[4:0], source[7:5] };
        3'b101:  rotate_right = { source[5:0], source[7:6] };
        3'b110:  rotate_right = { source[6:0], source[7]   };
        3'b111:  rotate_right = source;
        default: rotate_right = source;
    endcase
  endfunction
  
  
  function [7:0] rotate_left(input [7:0] source, input [2:0] rotate);
    case (rotate)
         3'b000:  rotate_left = { source[6:0], source[7]   };
         3'b001:  rotate_left = { source[5:0], source[7:6] };
         3'b010:  rotate_left = { source[4:0], source[7:5] };
         3'b011:  rotate_left = { source[3:0], source[7:4] };
         3'b100:  rotate_left = { source[2:0], source[7:3] };
         3'b101:  rotate_left = { source[1:0], source[7:2] };
         3'b110:  rotate_left = { source[0],   source[7:1] };
         3'b111:  rotate_left = source;
         default: rotate_left = source;
    endcase
  endfunction
  
  
  
  function [7:0] resolv_priority(input [7:0] request);
        if      (request[0] == 1'b1)    resolv_priority = 8'b00000001;
        else if (request[1] == 1'b1)    resolv_priority = 8'b00000010;
        else if (request[2] == 1'b1)    resolv_priority = 8'b00000100;
        else if (request[3] == 1'b1)    resolv_priority = 8'b00001000;
        else if (request[4] == 1'b1)    resolv_priority = 8'b00010000;
        else if (request[5] == 1'b1)    resolv_priority = 8'b00100000;
        else if (request[6] == 1'b1)    resolv_priority = 8'b01000000;
        else if (request[7] == 1'b1)    resolv_priority = 8'b10000000;
        else                            resolv_priority = 8'b00000000;
  endfunction





endmodule   

