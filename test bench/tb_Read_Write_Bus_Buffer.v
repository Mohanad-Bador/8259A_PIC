module tb_Read_Write_Bus_Buffer;

  // Inputs
  reg [7:0] input_data;
  reg read_enable;
  reg write_enable;
  reg A0;
  reg chip_select;

  // Outputs
  wire [7:0] internal_data_bus;
  wire ICW1, ICW2_4, OCW1, OCW2, OCW3, read;

  // Instantiate the module
  Read_Write_Bus_Buffer uut (
    .input_data(input_data),
    .chip_select(chip_select),
    .read_enable(read_enable),
    .write_enable(write_enable),
    .A0(A0),
    .internal_data_bus(internal_data_bus),
    .ICW1(ICW1),
    .ICW2_4(ICW2_4),
    .OCW1(OCW1),
    .OCW2(OCW2),
    .OCW3(OCW3),
    .read(read)
  );

  // Clock generation (not used in this testbench)
  reg clk = 0;
  always #5 clk = ~clk;

  // Test scenario
  initial begin
    // Apply initial inputs
    input_data = 8'b10101010;
    chip_select = 1;
    read_enable = 0;
    write_enable = 0;
    A0 = 0;

    // Apply some stimulus
    #10 chip_select = 0;
    #10 write_enable = 1;
    #10 A0 = 1;
    #10 write_enable = 0;
    #10 A0 = 0;
    #10 read_enable = 1;

    // Monitor outputs
    $display("Time=%0t || Data_bus=%h Chip_select=%b Read_enable=%b Write_enable=%b A0=%b || Internal_Data_bus=%h ICW1=%b ICW2_4=%b OCW1=%b OCW2=%b OCW3=%b Read=%b",
             $time, input_data, chip_select,read_enable,write_enable,A0,internal_data_bus,
             ICW1,ICW2_4,OCW1,OCW2,OCW3,read);
             


    // Terminate the simulation after a certain time
    #100 $stop;

  end

endmodule