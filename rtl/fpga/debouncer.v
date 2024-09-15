module debouncer #(
    parameter WIDTH = 16
) (
    input clk,
    input signal, // "signal" is the glitchy, asynchronous to clk, active low push-button signal

    // from which we make three outputs, all synchronous to the clock
    output reg state,  // 1 as long as the push-button is active (down)
    output pressed,  // 1 for one clock cycle when the push-button goes down (i.e. just pushed)
    output released  // 1 for one clock cycle when the push-button goes up (i.e. just released)
);
    // First use two flip-flops to synchronize the signal signal the "clk" clock domain
    reg signal_sync_0;
    always @(posedge clk)
        signal_sync_0 <= ~signal;  // invert signal to make signal_sync_0 active high
    reg signal_sync_1;
    always @(posedge clk) signal_sync_1 <= signal_sync_0;

    // Next declare a 16-bits counter
    reg [WIDTH-1:0] signal_cnt;

    // When the push-button is pushed or released, we increment the counter
    // The counter has to be maxed out before we decide that the push-button state has changed
    wire signal_idle = (state == signal_sync_1);
    wire signal_cnt_max = &signal_cnt;  // true when all bits of signal_cnt are 1's

    always @(posedge clk)
        if (signal_idle) signal_cnt <= 0;  // nothing's going on
        else begin
            signal_cnt <= signal_cnt + 16'd1;  // something's going on, increment the counter
            if (signal_cnt_max) state <= ~state;  // if the counter is maxed out, signal changed!
        end

    assign pressed  = ~signal_idle & signal_cnt_max & ~state;
    assign released = ~signal_idle & signal_cnt_max & state;
endmodule
