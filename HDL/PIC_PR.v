module priority_resolver(
	  input [2:0] priority_rotate,
    input [7:0] interrupt_mask,
    input       special_fully_nested_config,
    input [7:0] highest_level_in_service,


    input [7:0] IRR,
    input [7:0] ISR,

    output reg [7:0] interrupt

);
	reg [7:0] masked_IRR ;
	
	always@* begin
		masked_IRR = IRR & ~ interrupt_mask;
	end
	
	reg [7:0] rotated_IRR;
    reg [7:0] rotated_ISR;
    reg [7:0] rotated_highest_level_in_service;
    reg [7:0] priority_mask;
    reg [7:0] rotated_interrupt;
	
	always@* begin
		rotated_IRR = rotate_right(masked_IRR,priority_rotate);
		rotated_highest_level_in_service = rotate_right(highest_level_in_service,priority_rotate);
		rotated_ISR = rotate_right(ISR,priority_rotate);
	
	end
	
	
	always@* begin
        if      (rotated_ISR[0] == 1'b1) priority_mask = 8'b00000000;
        else if (rotated_ISR[1] == 1'b1) priority_mask = 8'b00000001;
        else if (rotated_ISR[2] == 1'b1) priority_mask = 8'b00000011;
        else if (rotated_ISR[3] == 1'b1) priority_mask = 8'b00000111;
        else if (rotated_ISR[4] == 1'b1) priority_mask = 8'b00001111;
        else if (rotated_ISR[5] == 1'b1) priority_mask = 8'b00011111;
        else if (rotated_ISR[6] == 1'b1) priority_mask = 8'b00111111;
        else if (rotated_ISR[7] == 1'b1) priority_mask = 8'b01111111;
        else                             priority_mask = 8'b11111111;
    end
	
	
	
	always@* begin
		rotated_interrupt = resolv_priority(rotated_IRR) & priority_mask;
		interrupt = rotate_left(rotated_interrupt,priority_rotate);
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
