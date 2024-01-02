
`define TB_CYCLE        20
`define TB_FINISH_COUNT 429496729
`timescale 1ns / 10ps

module tb_pic8259;

   

    //
    // Generate wave file to check
    //
`ifdef IVERILOG
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end
`endif

    //
    // Generate clock
    //
    reg   clock;
    initial clock = 1'b1;
    always #(`TB_CYCLE / 2) clock = ~clock;

    //
    // Generate reset
    //
    reg reset;
    initial begin
        reset = 1'b1;
            # (`TB_CYCLE * 10)
        reset = 1'b0;
    end

    //
    // Cycle counter
    //
    reg   [31:0]  tb_cycle_counter;
    always @(negedge clock, posedge reset) begin
        if (reset)
            tb_cycle_counter <= 32'h0;
        else
            tb_cycle_counter <= tb_cycle_counter + 32'h1;
    end

    always@(*) begin
        if (tb_cycle_counter == `TB_FINISH_COUNT) begin
            $display("***** SIMULATION TIMEOUT ***** at %d", tb_cycle_counter);
`ifdef IVERILOG
            $finish;
`elsif  MODELSIM
            $stop;
`else
            $finish;
`endif
        end
    end

    //
    // Module under test
    //
    reg           chip_select_n;
    reg           read_enable_n;
    reg           write_enable_n;
    reg           address;
    reg   [7:0]   data_bus_in;
    wire   [7:0]   data_bus_out;
    wire           data_bus_io;
    reg   [2:0]   cascade_in;
    wire   [2:0]   cascade_out;
    wire           cascade_io;
    reg           slave_program_n;
    wire           buffer_enable;
    wire           slave_program_or_enable_buffer;
    reg           interrupt_acknowledge_n;
    wire           interrupt_to_cpu;
    reg   [7:0]   interrupt_request;

    pic8259 pic8259 (
      .chip_select_n                       (chip_select_n),
      .read_enable_n                       (read_enable_n),
      .write_enable_n                       (write_enable_n),
      .address                       (address),
      .data_bus_in                       (data_bus_in),
      .data_bus_out                       (data_bus_out),
      .data_bus_io                       (data_bus_io),
      .cas_in                       (cascade_in),
      .cas_out                       (cascade_out),
      .cas_io                       (cascade_io),
      .sp_n                       (slave_program_n),
      .buffer_enable                       (buffer_enable),
      .interrupt_acknowledge_n                       (interrupt_acknowledge_n),
      .interrupt_to_cpu                       (interrupt_to_cpu),
      .interrupt_request                       (interrupt_request)
    
    );
    
    
    
    //
    // Task : Initialization
    //
    task TASK_INIT;
    begin
        #(`TB_CYCLE * 0);
        chip_select_n           = 1'b1;
        read_enable_n           = 1'b1;
        write_enable_n          = 1'b1;
        address                 = 1'b0;
        data_bus_in             = 8'b00000000;
        cascade_in              = 3'b000;
        slave_program_n         = 1'b0;
        interrupt_acknowledge_n = 1'b1;
        interrupt_request       = 8'b00000000;
        #(`TB_CYCLE * 12);
    end
    endtask
    
    //
    // Task : Write data
    //
    task TASK_WRITE_DATA(input addr, input [7:0] data);
    begin
        #(`TB_CYCLE * 0);
        chip_select_n   = 1'b0;
        write_enable_n  = 1'b0;
        address         = addr;
        data_bus_in     = data;
        #(`TB_CYCLE * 1);
        chip_select_n   = 1'b1;
        write_enable_n  = 1'b1;
        address         = 1'b0;
        data_bus_in     = 8'b00000000;
        #(`TB_CYCLE * 1);
    end
    endtask

    //
    // Task : Read data
    //
    task TASK_READ_DATA(input addr);
    begin
        #(`TB_CYCLE * 0);
        chip_select_n   = 1'b0;
        read_enable_n   = 1'b0;
        address         = addr;
        #(`TB_CYCLE * 1);
        chip_select_n   = 1'b1;
        read_enable_n   = 1'b1;
        #(`TB_CYCLE * 1);
    end
    endtask
    
    //
    // Task : Send non specific EOI
    //
    task TASK_SEND_NON_SPECIFIC_EOI;
    begin
        TASK_WRITE_DATA(1'b0, 8'b00100000);
    end
    endtask
    
    //
    // Task : Send specific EOI
    //
    task TASK_SEND_SPECIFIC_EOI(input [2:0] int_no);
    begin
        TASK_WRITE_DATA(1'b0, {8'b01100, int_no});
    end
    endtask
    
    //
    // Task : TASK_INTERRUPT_REQUEST
    //
    task TASK_INTERRUPT_REQUEST(input [7:0] request);
    begin
        #(`TB_CYCLE * 0);
        interrupt_request = request;
        #(`TB_CYCLE * 1);
        interrupt_request = 8'b00000000;
    end
    endtask
    //
    // Task : Send ack (8086)
    //
    task TASK_SEND_ACK_TO_8086;
    begin
        #(`TB_CYCLE * 0);
        interrupt_acknowledge_n = 1'b1;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b0;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b1;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b0;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b1;
    end
    endtask
    
    //
    // Task : Send ack (8086)
    //
    task TASK_SEND_ACK_TO_8086_SLAVE(input [2:0] slave_id);
    begin
        #(`TB_CYCLE * 0);
        interrupt_acknowledge_n = 1'b1;
        cascade_in = 3'b000;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b0;
        #(`TB_CYCLE / 2);
        cascade_in = slave_id;
        #(`TB_CYCLE / 2);
        interrupt_acknowledge_n = 1'b1;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b0;
        #(`TB_CYCLE * 1);
        interrupt_acknowledge_n = 1'b1;
        cascade_in = 3'b000;
    end
    endtask
        //
    // TASK : 8086 interrupt test
    //


    end
    endtask
    initial begin
    TASK_INIT();
    #(`TB_CYCLE * 0);
    ///$display("***** T7-T3=0b'00000 ***** at %d", tb_cycle_counter);
        // ICW1
        //TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        //TASK_WRITE_DATA(1'b1, 8'b11111000);
        // ICW4
        //TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        //TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        //TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b00000010);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b00000100);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b00001000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b00010000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b00100000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b101);

        TASK_INTERRUPT_REQUEST(8'b01000000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b110);

        TASK_INTERRUPT_REQUEST(8'b10000000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b111);

        $display("***** T7-T3=0b'00001 ***** at %d", tb_cycle_counter);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        //TASK_WRITE_DATA(1'b1, 8'b00001000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        //TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b000);

        //$display("***** T7-T3=0b'00010 ***** at %d", tb_cycle_counter);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        //TASK_WRITE_DATA(1'b1, 8'b00010000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b000);

        $display("***** T7-T3=0b'00100 ***** at %d", tb_cycle_counter);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00100000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b000);

        $display("***** T7-T3=0b'01000 ***** at %d", tb_cycle_counter);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b01000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b000);

        $display("***** T7-T3=0b'10000 ***** at %d", tb_cycle_counter);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b10000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_SPECIFIC_EOI(3'b000);
        #(`TB_CYCLE * 12);
    #(`TB_CYCLE * 1);
    $stop;
    end




endmodule
