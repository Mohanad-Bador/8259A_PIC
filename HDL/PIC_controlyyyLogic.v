`timescale 1ns / 1ps



module Controllyyyy_Logic(
 input write_ICW1,
 input write_ICW2_4,
 input write_OCW1,
 input write_OCW2,
 input write_OCW3,
 input INTA,
 input wire [7:0] data_bus,
 input [7:0] interrupt, 
 input [7:0] highest_level_in_service,
 input read,
 //cascade
 input [2:0] in_cascade_lines,
 output reg [2:0] out_cascade_lines, 
 output reg latch_ISR,
 input slave,
 output cascade_io,
 output slave_program_or_enable_buffer,

 output	reg level_or_edge_triggered_flag, 
 output reg special_fully_nested_config ,
 //reading register
 output reg read_enable,
 output reg IRR_OR_ISR,
 output reg INT,
 output reg [2:0] priority_rotate,
 output reg [7:0] interrupt_mask,
 output reg [7:0] end_interrupt,
 output reg freeze,
 output reg [7:0] clear_interrupt_request,
 
 output reg data_out_from_control_logic_flag,
 output reg [7:0] output_data
 

    );
	
	
    //iitialization commands
    parameter Ready=2'b00,ICW2=2'b01,ICW3=2'b10,ICW4=2'b11;
	// the next two registers are uesd for the initialization command words sequence 
    reg [1:0] next_command;
    reg [1:0] current_command;
    reg single_or_cascade_flag; 
    
	reg icw4_needed_flag; 
	reg call_address_interval_4_or_8_flag; 
	
	reg buffered_mode_config ;
	reg buffered_master_or_slave_config;
	reg is_Slave;
	reg slave_enabled;
	reg cascade_output_ack2;
	
    always@* begin
        if(write_ICW1==1)begin //first check if the coming input is ICW1
        next_command=ICW2; //next initialization command word will be ICW2
        end
		//if the current command word is ICW2,ICW3,ICW4
		//start determining the next command word 
        else if(write_ICW2_4==1) begin 
            case(current_command)
			//after getting ICW2, check if we are using single or cascade mode
                ICW2:begin
                    if(single_or_cascade_flag==0)begin
					next_command=ICW3;
					end
					else if(icw4_needed_flag==1)begin
					next_command=ICW4;
					end
					else 
					next_command=Ready;
                end
				//after getting ICW3 check if ICW4 is needed or not
				ICW3:begin
					if(icw4_needed_flag==1)
						next_command=ICW4;
					else
						next_command=Ready;
				end
				//after getting ICW4 set the next_command to be ready
				ICW4: begin
					next_command=Ready;
				end
				//default ready case used to avoid any latches
				default: begin
					next_command=Ready;
				end
            endcase
        end
		else
			next_command=current_command;
    end
	
	//update the current command with every clock cycle
	always@(*) begin
			current_command<=next_command;
	end
	//signals for initilization commands
	wire write_ICW2=(current_command == ICW2) & write_ICW2_4;
	wire write_ICW3=(current_command == ICW3) & write_ICW2_4;
	wire write_ICW4=(current_command == ICW4) & write_ICW2_4;
	
	//signals for operation command words		
	wire write_OCW1_register = (current_command==Ready) & write_OCW1;
	wire write_OCW2_register = (current_command==Ready) & write_OCW2;
	wire write_OCW3_register = (current_command==Ready) & write_OCW3;
	
	 // Service control state
	 
	 reg [1:0] next_control_s;
	 reg [1:0] control_s;
	 parameter Control_Ready=2'b00,ACK1=2'b01,ACK2=2'b10,POLL=2'b11;
	 //Acknowledge edge detection
	 
	 reg prev_INTA;
	 
	always@(INTA,prev_INTA)begin
		prev_INTA<=INTA;
	end
	
	wire negative_edge_INTA= prev_INTA & ~INTA;
	wire positive_edge_INTA=~ prev_INTA& INTA;
	
	
	//Detect read signal edge
	reg prev_read_signal;
	
	always@( read, prev_read_signal) begin
		prev_read_signal<= read;
	end
	
	wire negative_edge_read= prev_read_signal & ~read;
	
	//state machine for operation control words
	always@* begin
		case(control_s)
			Control_Ready:begin
				if((write_OCW3_register==1'b1)&&(data_bus[2]==1'b1))
					next_control_s=POLL;
				else if (write_OCW2_register==1'b1)
					next_control_s=Control_Ready;
				else if(negative_edge_INTA==1'b0)
					next_control_s=Control_Ready;
				else
					next_control_s=ACK1;
			end
			ACK1:begin
				if(positive_edge_INTA==1'b0)
					next_control_s=ACK1;
				else
					next_control_s=ACK2;
			end
			
			ACK2:begin
				if(positive_edge_INTA==1'b0)
					next_control_s=ACK2;
				else
					next_control_s=Control_Ready;
			end
			POLL:begin
				if(negative_edge_read==1'b0)
					next_control_s=POLL;
				else
					next_control_s=Control_Ready;
			end
			
			default:begin
				next_control_s=Control_Ready;
				
			end
		endcase
	end
	
	always @(write_ICW1,next_control_s)begin
		if(write_ICW1==1'b1)
			control_s<=Control_Ready;
		else
			control_s<=next_control_s;
	end
	

	//latch_ISR signal
	always@* begin
		if(write_ICW1==1'b1)
			latch_ISR = 1'b0;
		else if((control_s==Control_Ready)&&(next_control_s==POLL))
			latch_ISR = 1'b1;
		else if(is_Slave==1'b0)
			latch_ISR = (control_s==Control_Ready) & (next_control_s != Control_Ready);
		else 
			latch_ISR = (control_s == ACK2) & (slave_enabled == 1'b1) & (negative_edge_INTA==1'b1);
	end
	
	wire acknowledge_end = (control_s!=POLL)&(control_s!= Control_Ready)&(next_control_s==Control_Ready);
	wire poll_end        = (control_s==POLL)&(control_s != Control_Ready) &(next_control_s==Control_Ready);
	
		
	
	//
    // Initialization command word 1
    // A7-A5
	
	reg [10:0]  interrupt_vector_address;
	always@(write_ICW1)begin
		if(write_ICW1==1)
			interrupt_vector_address[2:0]<= data_bus[7:5];
		else
			interrupt_vector_address[2:0]<= interrupt_vector_address[2:0];
	end
	//IC4 bit
	always@(write_ICW1) begin
		if(write_ICW1==1)
			icw4_needed_flag<=data_bus[0];
		else
			icw4_needed_flag<=icw4_needed_flag;
		end
	//SNGL bit
	always@(write_ICW1) begin
	if(write_ICW1==1)
		single_or_cascade_flag<=data_bus[1];
	else
		single_or_cascade_flag<=single_or_cascade_flag;
	end
	//ADI bit
	always@(write_ICW1) begin
		if(write_ICW1==1)
			call_address_interval_4_or_8_flag<=data_bus[2];
		else
			call_address_interval_4_or_8_flag<=call_address_interval_4_or_8_flag;
	end
	//LTIM bit
	always@(write_ICW1) begin
		if(write_ICW1==1)
			level_or_edge_triggered_flag<=data_bus[3];
		else
			level_or_edge_triggered_flag<=level_or_edge_triggered_flag;
	end
	
	    // Initialization command word 2
    //
    // A15-A8 (MCS-80) or T7-T3 (8086, 8088)
	
	always@(write_ICW1 , write_ICW2) begin
		if(write_ICW1==1)
			interrupt_vector_address[10:3]<=3'b000;
		else if(write_ICW2==1)
			interrupt_vector_address[10:3]<=data_bus;
		else
			interrupt_vector_address[10:3]<=interrupt_vector_address[10:3];
	end
	
	
	// Initialization command word 3
	 reg [7:0] cascade_config;
	
	// S7-S0 (MASTER) or ID2-ID0 (SLAVE)
	always@(write_ICW1 ,write_ICW3)begin
		if(write_ICW1==1'b1)
			cascade_config <= 8'b00000000;
		else if(write_ICW3==1'b1)
			cascade_config<= data_bus;
		else
			cascade_config<=cascade_config;
		end
	
	
	// Initialization command word 4
	
	
	// special fully nested mode
	always@(write_ICW1,write_ICW4)begin
		if(write_ICW1==1'b1)
			special_fully_nested_config<=1'b0;
		else if(write_ICW4==1'b1)
			special_fully_nested_config<=data_bus[4];
		else 
			special_fully_nested_config<=special_fully_nested_config;
	end
	
	//Buffered mode configure
	always@(write_ICW1,write_ICW4)begin
		if(write_ICW1==1'b1)
			buffered_mode_config <=1'b0;
		else if(write_ICW4==1'b1)
			buffered_mode_config<=data_bus[3];
		else
			buffered_mode_config<=buffered_mode_config;
	end
	assign slave_program_or_enable_buffer = ~ buffered_mode_config;
	
	//Master/slave
	always@(write_ICW1,write_ICW4)begin
		if(write_ICW1==1'b1)
			buffered_master_or_slave_config<=1'b0;
		else if(write_ICW4==1'b1)
			buffered_master_or_slave_config<=data_bus[2];
		else
			buffered_master_or_slave_config<=buffered_master_or_slave_config;
	end
	
	//Automatic end of interrupt
	reg automatic_end_of_interrupt;
	
	always@(write_ICW1,write_ICW4)begin
		if(write_ICW1==1'b1)
			automatic_end_of_interrupt<=1'b0;
		else if(write_ICW4==1'b1)
			automatic_end_of_interrupt<=data_bus[1];
		else
			automatic_end_of_interrupt<=automatic_end_of_interrupt;
	end
	
	
	//CPU used
	reg u8086_or_mcs80_config ;
	always@(write_ICW1,write_ICW4)begin
		if(write_ICW1==1'b1)
			u8086_or_mcs80_config<=1'b0;
		else if(write_ICW4==1'b1)
			u8086_or_mcs80_config<=data_bus[0];
		else
			u8086_or_mcs80_config<=u8086_or_mcs80_config;
			
	end
		
		
			
	
	//
	//operation control word 1
	//
	reg special_mask_mode;
	//Interrupt Mask registers
	always@(write_ICW1 , write_OCW1_register) begin
		if(write_ICW1==1)
			interrupt_mask<= 8'b11111111;
		else if((write_OCW1_register==1'b1) && (special_mask_mode==1'b0))
			interrupt_mask <= data_bus;
		else
			interrupt_mask<=interrupt_mask;
	end
	
	
	//
	//operation control word 2
	//
	reg [7:0] acknowledge_interrupt ;
	reg [7:0] num2bit1;
	
	
	//End of interrupt mode
	always@(write_ICW1,automatic_end_of_interrupt,write_OCW2,highest_level_in_service)begin
		if(write_ICW1==1'b1)
			end_interrupt = 8'b11111111;
		else if((automatic_end_of_interrupt == 1'b1)&&(acknowledge_end== 1'b1))
			end_interrupt=acknowledge_interrupt;
		else if(write_OCW2==1'b1)begin
			case(data_bus[6:5])
				2'b01: 	 end_interrupt = highest_level_in_service;
				2'b11: begin
					//num2bit(data_bus[2:0],num2bit1);
					if(data_bus[2:0]==3'b000)  num2bit1 = 8'b00000001;
					if(data_bus[2:0]==3'b001)  num2bit1 = 8'b00000010;
					if(data_bus[2:0]==3'b010)  num2bit1 = 8'b00000100;
					if(data_bus[2:0]==3'b011)  num2bit1 = 8'b00001000;
					if(data_bus[2:0]==3'b100)  num2bit1 = 8'b00010000;
					if(data_bus[2:0]==3'b101)  num2bit1 = 8'b00100000;
					if(data_bus[2:0]==3'b110)  num2bit1 = 8'b01000000;
					if(data_bus[2:0]==3'b111)  num2bit1 = 8'b10000000;
					end_interrupt = num2bit1;
				end
                default: end_interrupt = 8'b00000000;
			endcase
		end
		else
			end_interrupt = 8'b00000000;
	end
	//Auto rotate mode 
	reg auto_rotate;
	
	always@(write_ICW1,write_OCW2)begin
		if (write_ICW1==1'b1)
			auto_rotate <= 1'b0;
		else if (write_OCW2==1'b1)begin
			case(data_bus[7:5])
				3'b000:  auto_rotate <= 1'b0;
                3'b100:  auto_rotate <= 1'b1;
				default: auto_rotate <= auto_rotate;
			endcase
		end
		else
			auto_rotate<=auto_rotate;
	end
	
	// Rotation
	reg [2:0] bit2num1;
	reg [2:0] bit2num2;
	always@ (write_ICW1,auto_rotate,acknowledge_end,write_OCW2,highest_level_in_service)begin
		if (write_ICW1==1'b1)
			priority_rotate <=3'b111;
		else if((auto_rotate==1'b1)&&(acknowledge_end==1'b1))begin
			//bit2num(acknowledge_interrupt,bit2num1);
			if(acknowledge_interrupt== 8'b00000001) bit2num1 = 3'b000;
			if(acknowledge_interrupt== 8'b00000010) bit2num1 = 3'b001;
			if(acknowledge_interrupt== 8'b00000100) bit2num1 = 3'b010;
			if(acknowledge_interrupt== 8'b00001000) bit2num1 = 3'b011;
			if(acknowledge_interrupt== 8'b00010000) bit2num1 = 3'b100;
			if(acknowledge_interrupt== 8'b00100000) bit2num1 = 3'b101;
			if(acknowledge_interrupt== 8'b01000000) bit2num1 = 3'b110;
			if(acknowledge_interrupt== 8'b10000000) bit2num1 = 3'b111;
			priority_rotate <= bit2num1;
		end
		else if(write_OCW2==1'b1)begin
			case(data_bus[7:5])
				3'b101:begin
					//bit2num(highest_level_in_service,bit2num2);
					if(highest_level_in_service== 8'b00000001) bit2num2 = 3'b000;
					if(highest_level_in_service== 8'b00000010) bit2num2 = 3'b001;
					if(highest_level_in_service== 8'b00000100) bit2num2 = 3'b010;
					if(highest_level_in_service== 8'b00001000) bit2num2 = 3'b011;
					if(highest_level_in_service== 8'b00010000) bit2num2 = 3'b100;
					if(highest_level_in_service== 8'b00100000) bit2num2 = 3'b101;
					if(highest_level_in_service== 8'b01000000) bit2num2 = 3'b110;
					if(highest_level_in_service== 8'b10000000) bit2num2 = 3'b111;
					priority_rotate <= bit2num2;
				end
				3'b110:  priority_rotate <= data_bus[2:0];
				3'b111:  priority_rotate <= data_bus[2:0];
				default: priority_rotate <= priority_rotate;
			endcase
		end
		else
			priority_rotate<=priority_rotate;
	end
			
	
	
	///////////////////////////////////////////////////////////////////////LATCH IN SERVICE////////////////////////////////////////
	// interrupt buffer

	 always@(write_ICW1, acknowledge_end,poll_end,latch_ISR,highest_level_in_service,acknowledge_interrupt) begin
        if (write_ICW1 == 1'b1)
            acknowledge_interrupt <= 8'b00000000;
        else if (acknowledge_end)
            acknowledge_interrupt <= 8'b00000000;
        else if (poll_end == 1'b1)
            acknowledge_interrupt <= 8'b00000000;
        else if (latch_ISR == 1'b1)
            acknowledge_interrupt <= highest_level_in_service;
        else
            acknowledge_interrupt <= acknowledge_interrupt;
    end
	
	
	
	//
    // Operation control word 3
    //
	
	//Read IRR or read ISR
	
	always@(write_ICW1,write_OCW3)begin
		if(write_ICW1==1'b1)begin
			read_enable<=1'b1;
			IRR_OR_ISR<=0;
		end
		else if(write_OCW3==1'b1)begin
			read_enable<=data_bus[1];
			IRR_OR_ISR<=data_bus[0];
		end
		else begin
			read_enable<=read_enable;
			IRR_OR_ISR<=IRR_OR_ISR;
		end
	end
	
	//Special mask mode signals (captured but not implemented)
	
	always@(write_ICW1,write_ICW3)begin
		if(write_ICW1==1'b1)
			special_mask_mode<=0;
		else if((write_ICW3==1'b1)&&(data_bus[6]==1'b1))
			special_mask_mode<=data_bus[5];
		else
			special_mask_mode<=special_mask_mode;
	end
	
	/*****************************************************
	*                  Cascading block                   * 
	******************************************************/	
	//Master or slave determination
	
	always@*begin
		if(single_or_cascade_flag==1'b1)
			is_Slave = 1'b0;
		else if (buffered_mode_config==1'b0)
			is_Slave = ~slave;//slave is the external input signal and ~ is because it is active low 
		else
			is_Slave = ~buffered_master_or_slave_config;//if we are in buffered mode the external signal slave is not used to determine the pic is slave or not instead we use the configuratin of the buffered mode
	end
		assign cascade_io = is_Slave;
	//Slave      Determines which slave is operating 
	
	
	always@* begin
		if(is_Slave==1'b0)
			slave_enabled = 1'b0;
		else if(cascade_config[2:0]!=in_cascade_lines)
			slave_enabled = 1'b0;
		else
			slave_enabled = 1'b1;
	end
	
	//
    // Cascade signals (master)
    //
	wire    interrupt_from_slave = (acknowledge_interrupt & cascade_config) != 8'b00000000; //Acknowledged interrupts flag 
	
	always@* begin
        if (single_or_cascade_flag == 1'b1)
            cascade_output_ack2 = 1'b1;
        else if (slave_enabled == 1'b1)
            cascade_output_ack2 = 1'b1;
        else if ((is_Slave == 1'b0) && (interrupt_from_slave == 1'b0))
            cascade_output_ack2= 1'b1;
        else
            cascade_output_ack2 = 1'b0;
    end
	// Output slave id
	reg [2:0] out_cascade;
    always@* begin
        if (is_Slave == 1'b1)
            out_cascade_lines <= 3'b000;
        else if ((control_s != ACK1) && (control_s != ACK2))
            out_cascade_lines <= 3'b000;
        else if (interrupt_from_slave == 1'b0)
            out_cascade_lines <= 3'b000;
        else begin
			//bit2num(acknowledge_interrupt,out_cascade);
			if(acknowledge_interrupt== 8'b00000001) out_cascade = 3'b000;
			if(acknowledge_interrupt== 8'b00000010) out_cascade = 3'b001;
			if(acknowledge_interrupt== 8'b00000100) out_cascade = 3'b010;
			if(acknowledge_interrupt== 8'b00001000) out_cascade = 3'b011;
			if(acknowledge_interrupt== 8'b00010000) out_cascade = 3'b100;
			if(acknowledge_interrupt== 8'b00100000) out_cascade = 3'b101;
			if(acknowledge_interrupt== 8'b01000000) out_cascade = 3'b110;
			if(acknowledge_interrupt== 8'b10000000) out_cascade = 3'b111;
            out_cascade_lines <= out_cascade;
		end
    end
	
	
	/*****************************************************
	*                   Interrupt Signals                * 
	******************************************************/
	
	//interrupt signal to cpu
	always@(write_ICW1, interrupt,acknowledge_end,poll_end) begin
		if(write_ICW1==1'b1)
			INT <= 1'b0;
		else if(interrupt != 8'b00000000)
			INT <= 1'b1;
		else if(acknowledge_end==1'b1)	
			INT <= 1'b0;
		else if(poll_end == 1'b1)
			INT <= 1'b0;
		else 
			INT <=INT;
	end
	
	//freeze signal to IRR
	always@(next_control_s) begin 
		if(next_control_s == Control_Ready)
			freeze <= 1'b0;
		else
			freeze <= 1'b1;
	
	end
	
	// clear interupt request for IRR
	
	always@* begin
		if(write_ICW1==1'b1)
			clear_interrupt_request = 8'b11111111;
		else if(latch_ISR==1'b0)
			clear_interrupt_request = 8'b00000000;
		else
			clear_interrupt_request = interrupt;
	
	end
	
	
	reg [7:0] interrupt_after_ack1;
	
	always@ (write_ICW1,control_s,highest_level_in_service)begin
		if(write_ICW1 == 1'b1)
			interrupt_after_ack1<= 8'b00000000;
		else if(control_s == ACK1)
			interrupt_after_ack1<= highest_level_in_service;
		else 
			interrupt_after_ack1<=interrupt_after_ack1;
	end
	
	//State machine that controls data output form the PIC to the data bus
	reg [2:0] interrupt_after1;
	reg [2:0] acknowledge_int;
	always@* begin
		if(INTA == 1'b0)begin
			case(control_s)
				Control_Ready:begin
					data_out_from_control_logic_flag = 1'b0;
					output_data = 8'b00000000;
				end
				ACK1:begin
					data_out_from_control_logic_flag = 1'b0;
					output_data = 8'b00000000;
				end
				ACK2:begin
					if(cascade_output_ack2 == 1'b1)begin
						data_out_from_control_logic_flag = 1'b1;
						if(is_Slave == 1'b1) begin
							 if(interrupt_after_ack1== 8'b00000001) interrupt_after1 = 3'b000;
							 if(interrupt_after_ack1== 8'b00000010) interrupt_after1 = 3'b001;
							 if(interrupt_after_ack1== 8'b00000100) interrupt_after1 = 3'b010;
							 if(interrupt_after_ack1== 8'b00001000) interrupt_after1 = 3'b011;
							 if(interrupt_after_ack1== 8'b00010000) interrupt_after1 = 3'b100;
							 if(interrupt_after_ack1== 8'b00100000) interrupt_after1 = 3'b101;
							 if(interrupt_after_ack1== 8'b01000000) interrupt_after1 = 3'b110;
							 if(interrupt_after_ack1== 8'b10000000) interrupt_after1 = 3'b111;
							output_data[2:0]=interrupt_after1;
						end
						else begin
							 if(acknowledge_interrupt== 8'b00000001) acknowledge_int = 3'b000;
							 if(acknowledge_interrupt== 8'b00000010) acknowledge_int = 3'b001;
							 if(acknowledge_interrupt== 8'b00000100) acknowledge_int = 3'b010;
							 if(acknowledge_interrupt== 8'b00001000) acknowledge_int = 3'b011;
							 if(acknowledge_interrupt== 8'b00010000) acknowledge_int = 3'b100;
							 if(acknowledge_interrupt== 8'b00100000) acknowledge_int = 3'b101;
							 if(acknowledge_interrupt== 8'b01000000) acknowledge_int = 3'b110;
							 if(acknowledge_interrupt== 8'b10000000) acknowledge_int = 3'b111;
							
							output_data[2:0]=acknowledge_int;
						end
						//8086 cpu only is handled
						if(u8086_or_mcs80_config == 1'b1)
							output_data={interrupt_vector_address[10:6],output_data[2:0]};
						else begin
							data_out_from_control_logic_flag = 1'b0;
							output_data = 8'b00000000;
						end
					end
					else begin
						data_out_from_control_logic_flag = 1'b0;
						output_data = 8'b00000000;
					end
				end
				default:begin
					data_out_from_control_logic_flag = 1'b0;
					output_data = 8'b00000000;
				end
			endcase
		end
		else begin
			data_out_from_control_logic_flag = 1'b0;
			output_data = 8'b00000000;
		end
	end
	
	
endmodule


