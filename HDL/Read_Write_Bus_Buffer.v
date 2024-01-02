module  Read_Write_Bus_Buffer(
  input reg [7:0]    input_data,
  input wire         read_enable,
  input wire         write_enable,
  input wire         A0,
  input wire         chip_select,
  
  // internal bus
  output reg [7:0]   internal_data_bus,
  output wire        ICW1,
  output wire        ICW2_4,
  output wire        OCW1,
  output wire        OCW2,
  output wire        OCW3,
  output wire        read
  );
  
  // Internal Signals
  reg   prev_write_enable;
  wire   write_flag;
  
  // Write Control 
  always @(*) begin
    internal_data_bus <= (~write_enable & ~chip_select) ? input_data :internal_data_bus;
    
  end
  always @(*) begin
    prev_write_enable <= (chip_select) ? 1'b1 :write_enable;
    
  end

  assign write_flag = ~prev_write_enable & write_enable;
  
  // Generate write request flags
  assign ICW1     = ~A0 & write_flag & internal_data_bus[4];
  assign ICW2_4   =  A0 & write_flag ;
  assign OCW1     =  A0 & write_flag ;
  assign OCW2     = ~A0 & write_flag  & ~internal_data_bus[4] & ~internal_data_bus[3];
  assign OCW3     = ~A0 & write_flag & ~internal_data_bus[4] & internal_data_bus[3];

  // Read Control
  assign read = ~read_enable  & ~chip_select;
    
endmodule