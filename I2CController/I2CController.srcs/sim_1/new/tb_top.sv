`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2026 06:30:32 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top(

    );
      // Inputs to UUT
    logic clk;
    logic nrst;
    logic btn;
    logic btn_write;

    // Outputs / Inouts from UUT
    tri sda;
    tri scl;
    logic [7:0] sseg_data;
    logic [7:0] sseg_ctrl;
    logic [5:0] led;

    // Pull-up resistors for the open-drain I2C Bus lines
    pullup(sda);
    pullup(scl);

    // Slave emulation signals
    logic sda_out;
    logic sda_oe;
    assign sda = sda_oe ? sda_out : 1'bz;

    // Instantiate Unit Under Test (UUT)
    top uut (
        .clk(clk),
        .nrst(nrst),
        .sda(sda),
        .scl(scl),
        .sseg_data(sseg_data),
        .sseg_ctrl(sseg_ctrl),
        .btn(btn),
        .btn_write(btn_write),
        .led(led)
    );
 defparam uut.btn_debouncer.STABLE = 5;
    defparam uut.btn_write_debouncer.STABLE = 5;
    // 100MHz System Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Helper task to emulate slave issuing an ACK
    task automatic emulate_slave_rx_ack();
        sda_out = 1'b0; // Drive ACK low
        sda_oe = 1'b1;
        @(negedge scl);
        sda_oe = 1'b0; // Release bus
    endtask

    // Helper task to emulate slave sending a data byte back to the master
    task automatic emulate_slave_tx_byte(input logic [7:0] data_to_send);
        for (int i = 7; i >= 0; i--) begin
            sda_out = data_to_send[i];
            sda_oe = 1'b1;
            @(negedge scl);
        end
        sda_oe = 1'b0; // Release right at the 8th bit falling edge
    endtask

    // Main Test Sequence
    initial begin
        // ==========================================================
        // QUICK-COMMENT TOGGLE: Choose your active test mode here
        // ==========================================================
        // Un-comment ONLY one mode row, then hit save & relaunch in Vivado.
        bit run_read  = 1; bit run_write = 1; // Mode A: Read Test (btn)
        // bit run_read  = 0; bit run_write = 1; // Mode B: Write Test (btn_write)
        // ==========================================================

        // Initialize Input Signals
        clk = 0;
        nrst = 1;
        btn = 0;
        btn_write = 0;
        sda_out = 1'b1;
        sda_oe = 1'b0;

        // Release system reset
        #100;
        nrst = 0;
        #100;
        nrst = 1;
        #100;
        // ----------------------------------------------------------
        // EXECUTE SCENARIO A: READ TRANSACTION TEST
        // ----------------------------------------------------------
        if (run_read) begin
            $display("[TB] --- STARTING READ TRANSACTION VIA BUTTON DEBOUNCE ---");
            
            // Pulse the read button (simulating physical press long enough for debouncer)
               @(posedge clk);
            btn = 1;
                 repeat(10) @(posedge clk); // Hold high to settle debouncer and delay blocks
            btn = 0;
            
            // Wait for top FSM to assert the I2C transfer start (indicated by SDA drop)
            @(negedge sda);
            @(negedge scl); // Clear START bit edge boundary
            
            // --- 1st ACK: Device Address + W ---
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            $display("[TB] Slave ACKed Device Addr + Write");

            // --- 2nd ACK: Register Address Pointer (Targeting top's next_reg 8'h03) ---
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            $display("[TB] Slave ACKed Register Address Pointer");

            // --- 3rd ACK: Device Address + R (Repeated Start phase) ---
            @(negedge sda); // Watch for repeated start pattern
            @(negedge scl); 
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            $display("[TB] Slave ACKed Device Addr + Read (Repeated Start)");

            // --- Data Phase: Slave responds with value 8'hBE ---
            $display("[TB] Slave transmitting mock register contents: 8'hBE");
            emulate_slave_tx_byte(8'hBE);

            // Wait for the complete hardware transaction to wrap up
            wait(uut.master_finished == 1'b1);
            #40;
            
            // Validate display update mapping
            if (uut.dout === 8'hBE) begin
                $display("[TB] SUCCESS: Read byte 0xBE successfully captured in register!");
            end else begin
                $display("[TB] ERROR: Latch mismatch! Expected 0xBE, Got %h", uut.dout);
            end
        end

        // ----------------------------------------------------------
        // EXECUTE SCENARIO B: WRITE TRANSACTION TEST
        // ----------------------------------------------------------
        if (run_write) begin
            $display("[TB] --- STARTING WRITE TRANSACTION VIA BUTTON DEBOUNCE ---");
            
            // Pulse the write button
               @(posedge clk);
            btn_write = 1;
             repeat(10) @(posedge clk);
            btn_write = 0;
            // Wait for FSM activation sequence
            @(negedge sda);
            @(negedge scl); 

            // --- 1st ACK: Device Address + W ---
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            $display("[TB] Slave ACKed Device Addr + Write");

            // --- 2nd ACK: Register Address Pointer ---
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            $display("[TB] Slave ACKed Register Address Pointer (0x03)");

            // --- 3rd ACK: Data Payload (Capturing master's write data) ---
            $display("[TB] Monitoring data payload write sequence driven by top...");
            repeat(8) @(negedge scl);
            emulate_slave_rx_ack();
            
            // Wait for final STOP bus condition
            wait(uut.master_finished == 1'b1);
            $display("[TB] SUCCESS: Master write cycle complete.");
        end

        #1000;
        $finish;
    end
    
endmodule
