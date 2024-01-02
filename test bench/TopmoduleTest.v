
`define TB_CYCLE        20
`define TB_FINISH_COUNT 429496729
`timescale 1ns / 10ps

module PIC8259A_TB;

   
    //
    // Generate clock
    //
    reg   tb_cycle_counter;
    initial tb_cycle_counter = 1'b1;
    always #(`TB_CYCLE / 2) tb_cycle_counter = ~tb_cycle_counter;

    

    


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

    P8259IC PIC_TEST_MODULE (
      .chip_select_n                       (chip_select_n),
      .read_enable_n                       (read_enable_n),
      .write_enable_n                       (write_enable_n),
      .address                       (address),
      .data_bus_in                       (data_bus_in),
      .data_bus_out                       (data_bus_out),
      .data_bus_io                       (data_bus_io),
      .cascade_in                       (cascade_in),
      .cascade_out                       (cascade_out),
      .cascade_io                       (cascade_io),
      .slave_program_n                       (slave_program_n),
      .buffer_enable                       (buffer_enable),
      .slave_program_or_enable_buffer                       (slave_program_or_enable_buffer),
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
    // Task : Send interrupt request
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
    // Task : Send specific EOI
    //
    task TASK_SEND_SPECIFIC_EOI(input [2:0] int_no);
    begin
        TASK_WRITE_DATA(1'b0, {8'b01100, int_no});
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
    task TASK_8086_NORMAL_INTERRUPT_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b11111000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

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
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b01000000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_INTERRUPT_REQUEST(8'b10000000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        #(`TB_CYCLE * 12);
    end
    endtask

    //
    // TASK : level torigger test
    //
    task TASK_LEVEL_TORIGGER_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000011);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
        
        #(`TB_CYCLE * 7);
        
        interrupt_request = 8'b00001000;
        #(`TB_CYCLE * 2);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 2);
        interrupt_request = 8'b00000000;

        #(`TB_CYCLE * 7);
        interrupt_request = 8'b10000000;
        #(`TB_CYCLE * 2);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 2);
        interrupt_request = 8'b00000000;


        #(`TB_CYCLE * 7);
        interrupt_request = 8'b00000010;
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 2);
        interrupt_request = 8'b00000000;

        #(`TB_CYCLE * 7);
        
    end
    endtask

    //
    // TASK : edge torigger test
    //
    task TASK_EDGE_TORIGGER_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00010111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000011);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
        TASK_INTERRUPT_REQUEST(8'b11100000);
        TASK_SEND_ACK_TO_8086();

        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00000010);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00000100);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00001000);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00010000);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00100000);

        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b01000000);

        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b10000000);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        TASK_INTERRUPT_REQUEST(8'b00000000);
        #(`TB_CYCLE * 12);
    end
    endtask

    //
    // TASK : interrupt mask test
    //
    task TASK_INTERRUPT_MASK_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b11111111);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Can't interrupt
        TASK_INTERRUPT_REQUEST(8'b11111111);
        #(`TB_CYCLE * 5);

        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b11111110);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11111111);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b11111101);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11111111);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b11111011);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11111111);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();


        #(`TB_CYCLE * 12);
    end
    endtask


    //
    // TASK : auto-eoi test
    //
    task TASK_AUTO_EOI_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b01100000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000011);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11000000);
        // ACK
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11000010);
        // ACK
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b00001000);
        // ACK
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 5);
    end
    endtask

    //
    // TASK : non specific test
    //
    task TASK_NON_SPECIFIC_EOI_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b10000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        // Interrupt
        TASK_INTERRUPT_REQUEST(8'b11100000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();
        
        #(`TB_CYCLE * 5);
        
        TASK_INTERRUPT_REQUEST(8'b11100010);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();
        
        #(`TB_CYCLE * 5);

        TASK_INTERRUPT_REQUEST(8'b11101000);
        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();
        #(`TB_CYCLE * 5);

    end
    endtask

    //
    // TASK : non specific test
    //
    task TASK_ROTATE_ON_AUTO_END_OF_INTERRUPT;
      begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000011);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW2
        TASK_WRITE_DATA(1'b0, 8'b10000111);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
        
        TASK_INTERRUPT_REQUEST(8'b00000100);
        TASK_SEND_ACK_TO_8086();
        TASK_WRITE_DATA(1'b0, 8'b00000000);
        

        TASK_INTERRUPT_REQUEST(8'b11111111);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 12);
      end
    endtask
    
    task TASK_ROTATE_ON_NON_SPECIFIC_END_OF_INTERRUPT;
      begin
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW2
        TASK_WRITE_DATA(1'b0, 8'b10100111);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
        TASK_INTERRUPT_REQUEST(8'b00001000);
        TASK_SEND_ACK_TO_8086();
        TASK_WRITE_DATA(1'b0, 8'b10100000);
        TASK_INTERRUPT_REQUEST(8'b11111111);

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();

        TASK_SEND_ACK_TO_8086();
        TASK_SEND_NON_SPECIFIC_EOI();
      end
    endtask
    
    task TASK_READING_IRR_TEST;
    begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00001101);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        $display("***** read irr ***** at ");
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001010);
        TASK_READ_DATA(1'b0);

        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_SEND_ACK_TO_8086();
        #(`TB_CYCLE * 1);

        TASK_INTERRUPT_REQUEST(8'b00000001);
        TASK_READ_DATA(1'b0);

        TASK_INTERRUPT_REQUEST(8'b00000010);
        TASK_READ_DATA(1'b0);

        TASK_INTERRUPT_REQUEST(8'b00000100);
        TASK_READ_DATA(1'b0);

        TASK_INTERRUPT_REQUEST(8'b00001000);
        TASK_READ_DATA(1'b0);

        TASK_INTERRUPT_REQUEST(8'b00010000);
        TASK_READ_DATA(1'b0);
        #(`TB_CYCLE * 12);
    end
    endtask
      task TASK_READING_ISR_TEST;
      begin
        #(`TB_CYCLE * 0);
        // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011111);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001011);
        #(`TB_CYCLE * 1);
        
        TASK_INTERRUPT_REQUEST(8'b00001000);
        
        
        TASK_SEND_ACK_TO_8086();
        TASK_READ_DATA(1'b0);
        #(`TB_CYCLE * 1);
        TASK_SEND_NON_SPECIFIC_EOI();
        #(`TB_CYCLE * 1);
        
        TASK_INTERRUPT_REQUEST(8'b00001100);
        TASK_SEND_ACK_TO_8086();
        TASK_READ_DATA(1'b0);
        #(`TB_CYCLE * 1);
        TASK_SEND_NON_SPECIFIC_EOI();
        #(`TB_CYCLE * 12);
      end
      endtask
        
	
	task CASCADE_MODE_MASTER;
	begin
	      #(`TB_CYCLE * 0);
		    // ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011101);
        // ICW2
       // TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW3
        TASK_WRITE_DATA(1'b1, 8'b10000111);
        // ICW4
      //  TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);

        slave_program_n         = 1'b1;

        // interrupt
        TASK_INTERRUPT_REQUEST(8'b00000100);

        TASK_SEND_ACK_TO_8086();
		TASK_SEND_NON_SPECIFIC_EOI();
		
		 #(`TB_CYCLE * 12);
	end
	endtask
	
	task CASCADE_MODE_SLAVE;
	begin
		#(`TB_CYCLE * 0);
		// ICW1
        TASK_WRITE_DATA(1'b0, 8'b00011101);
        // ICW2
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // ICW3
        TASK_WRITE_DATA(1'b1, 8'b10000111);
        // ICW4
        TASK_WRITE_DATA(1'b1, 8'b00000001);
        // OCW1
        TASK_WRITE_DATA(1'b1, 8'b00000000);
        // OCW3
        TASK_WRITE_DATA(1'b0, 8'b00001000);
		
		slave_program_n         = 1'b0;

        // interrupt
        TASK_INTERRUPT_REQUEST(8'b10000000);

		//  TASK_SEND_ACK_TO_8086_SLAVE(3'b000);
		//   TASK_SEND_ACK_TO_8086_SLAVE(3'b001);
		//  TASK_SEND_ACK_TO_8086_SLAVE(3'b010);
        // TASK_SEND_ACK_TO_8086_SLAVE(3'b011);
        // TASK_SEND_ACK_TO_8086_SLAVE(3'b100);
        // TASK_SEND_ACK_TO_8086_SLAVE(3'b101);
        //TASK_SEND_ACK_TO_8086_SLAVE(3'b110);
          TASK_SEND_ACK_TO_8086_SLAVE(3'b111);

        TASK_SEND_NON_SPECIFIC_EOI();

        #(`TB_CYCLE * 12);
	end
	endtask

    //
    // Test pattern
    //
    initial begin
        TASK_INIT();
      // TASK_8086_NORMAL_INTERRUPT_TEST();
      //TASK_AUTO_EOI_TEST();
      //TASK_NON_SPECIFIC_EOI_TEST();
      //TASK_EDGE_TORIGGER_TEST();
      //TASK_LEVEL_TORIGGER_TEST();
      //TASK_ROTATE_ON_AUTO_END_OF_INTERRUPT();
      //TASK_ROTATE_ON_NON_SPECIFIC_END_OF_INTERRUPT();
	    //CASCADE_MODE_MASTER();
		  //CASCADE_MODE_SLAVE();
		  //TASK_INTERRUPT_MASK_TEST();
      //TASK_READING_IRR_TEST();
      //TASK_READING_ISR_TEST();
      
        #(`TB_CYCLE * 1);

    end
endmodule

