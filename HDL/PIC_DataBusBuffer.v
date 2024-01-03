module  Data_bus_buffer_Read_write_Logic(
	input [7:0]    data_bus_input,
	input wire         chip_select,
	input wire         read_enable,
	input wire         write_enable,
	input wire          A0,
	
	
		// internal bus
	
	output reg [7:0]  internal_data_bus,
	output wire        write_ICW1,
	output wire        write_ICW2_4,
	output wire        write_OCW1,
	output wire        write_OCW2,
	output wire        write_OCW3,
	output wire        read
  );
  
     // Internal Signals
   
	reg   prev_write_enable;
	wire   write_flag;
	reg stable_address;
  
     // Write Control
     
	always @(write_enable , chip_select) begin
		internal_data_bus <= (~write_enable & ~chip_select) ? data_bus_input :internal_data_bus;
    
	end
	always @(chip_select , write_enable) begin
		prev_write_enable <= (chip_select) ? 1'b1 :write_enable;
	end
	
	assign write_flag = ~prev_write_enable & write_enable;
	always @( A0 )
			stable_address <= A0;
	
	// Generate write request flags
	assign write_ICW1     = (write_flag & ~stable_address)  & internal_data_bus[4];
	assign write_ICW2_4   = write_flag & stable_address  ;
	assign write_OCW1     = write_flag & stable_address  ;
	assign write_OCW2     = ((write_flag & ~stable_address) & ~internal_data_bus[4]) & ~internal_data_bus[3];
	assign write_OCW3     = ((write_flag & ~stable_address) & ~internal_data_bus[4]) & internal_data_bus[3];
	
  

    // Read Control
 
    assign read = ~read_enable  & ~chip_select;
    
    
    
    
endmodule
  
  
  