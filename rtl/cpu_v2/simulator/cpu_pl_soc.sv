`ifdef IVERILOG_LINT
`include "../bus_arbiter.sv"
`endif


module cpu_pl_soc #(
    parameter INIT_H  = "",
    parameter MEMSIZE = 8192  //25600
) (
    input wire clk,
    input wire rst
);
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire [3:0] bus_wmask;

    wire [31:0] progMEM_waddr;
    wire [3:0] progMEM_wmask;
    wire [31:0] progMEM_wdata;
    wire [31:0] progMEM_rdata;
    wire progMEM_wen;

    // wire [3:0] debug;
    // wire de0 = debug[0];
    // wire de1 = debug[1];
    // wire de2 = debug[2];
    // wire de3 = debug[3];

    cpu_pipelined #(
        .PROGROM_SIZE_W(MEMSIZE),
        .INIT_H("../../../software/programs/test_embedded/build/ecp5_test.hex")
    ) core0 (
        .clk,
        .rst,
        .bus_addr,
        .bus_wdata,
        .bus_wmask,
        .bus_rdata,
        .bus_done,
        .bus_wen,
        .bus_ren,

        .progMEM_waddr,
        .progMEM_wdata,
        .progMEM_rdata,
        .progMEM_wen,
        .progMEM_wmask
    );

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wen;
    wire mem_ren;
    wire [31:0] mem_rdata;
    reg mem_done;
    wire mem_active;

    always @(posedge clk) begin
        mem_done <= (mem_ren | mem_wen) & mem_active;
    end

    assign mem_rdata = mem_active ? progMEM_rdata : '0;
    // assign mem_done = 0;  // HACK: Fix this to be "real" done
    assign mem_active = mem_addr < (MEMSIZE * 4);

    assign progMEM_waddr = {2'b0, mem_addr[31:2]};
    assign progMEM_wdata = mem_wdata;
    assign progMEM_wmask = mem_wmask;
    assign progMEM_wen = mem_wen & mem_active;

    bus_hub_2_pl hub (
        .clk,
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, pp_addr}),
        .device_data_write({mem_wdata, pp_wdata}),
        .device_write_mask({mem_wmask, pp_wmask}),
        .device_ren({mem_ren, pp_ren}),
        .device_wen({mem_wen, pp_wen}),
        .device_ready({mem_done, pp_done}),
        .device_data_read({mem_rdata, pp_rdata}),
        .device_active({mem_active, pp_active})
    );

    wire [31:0] pp_addr;
    wire [31:0] pp_wdata;
    wire [3:0] pp_wmask;
    wire pp_wen;
    wire pp_ren;
    wire [31:0] pp_rdata;
    wire pp_done;
    wire pp_active;

    wire [31:0] parallel_io;
    // assign led = parallel_io[0];

    parallel_output pp (
        .clk,
        .addr(pp_addr),
        .wdata(pp_wdata),
        .wmask(pp_wmask),
        .ren(pp_ren),
        .wen(pp_wen),
        .rdata(pp_rdata),
        .ready(pp_done),
        .active(pp_active),
        .io(parallel_io)
    );
endmodule
