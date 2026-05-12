`timescale 1ns/1ps

module tb_face_detect;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg [9:0] win_x = 10'd0;
    reg [8:0] win_y = 9'd0;

    wire [31:0] rom_addr;
    wire        rom_ren;
    reg  [31:0] rom_data;

    wire [31:0] ii_addr;
    wire        ii_ren;
    reg  [17:0] ii_data;
    reg         ii_valid;

    wire busy;
    wire done;
    wire face_found;

    reg [31:0] rom_mem [0:63];
    reg [17:0] ii_mem [0:4095];
    reg [31:0] ii_req_addr;
    reg         ii_pending;

    int errors;

    face_detect #(
        .IMG_WIDTH(320),
        .SCALE_SHIFT(8)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .win_x(win_x),
        .win_y(win_y),
        .rom_addr(rom_addr),
        .rom_ren(rom_ren),
        .rom_data(rom_data),
        .ii_addr(ii_addr),
        .ii_ren(ii_ren),
        .ii_data(ii_data),
        .ii_valid(ii_valid),
        .busy(busy),
        .done(done),
        .face_found(face_found)
    );

    always #5 clk = ~clk;

    always @(*) begin
        rom_data = rom_mem[rom_addr[5:0]];
    end

    always @(posedge clk) begin
        #1;
        if (rst) begin
            ii_req_addr <= 32'd0;
            ii_pending  <= 1'b0;
            ii_valid    <= 1'b0;
            ii_data     <= 18'd0;
        end else begin
            ii_valid <= ii_pending;
            if (ii_pending) begin
                ii_data <= ii_mem[ii_req_addr[11:0]];
            end
            ii_pending  <= ii_ren;
            if (ii_ren) begin
                ii_req_addr <= ii_addr;
            end
        end
    end

    task automatic check(input bit cond, input string msg);
        begin
            if (!cond) begin
                errors++;
                $display("ERROR: %s (t=%0t)", msg, $time);
            end
        end
    endtask

    task automatic load_single_stage_rom(input bit should_pass);
        begin
            // Header
            rom_mem[0] = 32'h48415231; // HAR1
            rom_mem[1] = 32'd8;        // q8
            rom_mem[2] = 32'd1;        // one stage

            // Stage header
            rom_mem[3] = 32'd1;        // one weak
            rom_mem[4] = should_pass ? 32'sd100 : 32'sd400; // stage threshold Q8

            // Weak classifier
            rom_mem[5] = 32'sd20;      // weak threshold Q8
            rom_mem[6] = 32'sd300;     // left leaf
            rom_mem[7] = -32'sd300;    // right leaf
            rom_mem[8] = 32'd1;        // one rect
            rom_mem[9] = 32'h00000202; // x=0 y=0 w=2 h=2
            rom_mem[10] = 32'sd256;    // weight = 1.0 in Q8
        end
    endtask

    task automatic init_integral_image;
        int i;
        begin
            for (i = 0; i < 4096; i++) ii_mem[i] = 32'd0;

            // For win=(0,0), rect=(0,0,2,2) with padded integral image:
            // A=ii(0,0)=0, B=ii(2,0)=0, C=ii(0,2)=0, D=ii(2,2)=16
            // sum = 0+16-0-0 = 16
            ii_mem[0] = 18'd0;
            ii_mem[2] = 18'd0;
            ii_mem[642] = 18'd0; // 2*321
            ii_mem[644] = 18'd16;
        end
    endtask

    task automatic run_case(input bit should_pass, input string label);
        begin
            load_single_stage_rom(should_pass);
            init_integral_image;

            @(negedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;

            wait(done);
            #1;
            check(face_found == should_pass, {label, " result mismatch"});
            @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        ii_req_addr = 32'd0;
        ii_pending = 1'b0;
        ii_valid = 1'b0;
        ii_data = 32'd0;
        rom_data = 32'd0;

        repeat (3) @(posedge clk);
        rst <= 1'b0;
        repeat (2) @(posedge clk);

        run_case(1'b1, "pass_case");
        run_case(1'b0, "fail_case");

        if (errors == 0) begin
            $display("PASS: tb_face_detect");
            $finish;
        end

        $fatal(1, "FAIL: tb_face_detect errors=%0d", errors);
    end

endmodule
