module rom (
    input  wire [31:0] addr,
    output reg  [31:0] data
);
    always_comb begin
        case (addr)
            32'h0:   data = 32'h00001117;
            32'h4:   data = 32'h8e010113;
            32'h8:   data = 32'h0e000d13;
            32'hc:   data = 32'h0e000d93;
            32'h10:  data = 32'h000d2023;
            32'h14:  data = 32'h004d0d13;
            32'h18:  data = 32'hffaddce3;
            32'h1c:  data = 32'h038000ef;
            32'h20:  data = 32'h00000097;
            32'h24:  data = 32'hfe008093;
            32'h28:  data = 32'h00c000ef;
            32'h2c:  data = 32'h00100073;
            32'h30:  data = 32'hfd1ff06f;
            32'h34:  data = 32'h0000f7b7;
            32'h38:  data = 32'h00100713;
            32'h3c:  data = 32'h00e78023;
            32'h40:  data = 32'h00000013;
            32'h44:  data = 32'h00000013;
            32'h48:  data = 32'h00000013;
            32'h4c:  data = 32'h00078023;
            32'h50:  data = 32'hfedff06f;
            32'h54:  data = 32'hff010113;
            32'h58:  data = 32'h00812423;
            32'h5c:  data = 32'h01212023;
            32'h60:  data = 32'h0e000793;
            32'h64:  data = 32'h0e000713;
            32'h68:  data = 32'h00112623;
            32'h6c:  data = 32'h00912223;
            32'h70:  data = 32'h40e78933;
            32'h74:  data = 32'h02e78263;
            32'h78:  data = 32'h40295913;
            32'h7c:  data = 32'h0e000413;
            32'h80:  data = 32'h00000493;
            32'h84:  data = 32'h00042783;
            32'h88:  data = 32'h00148493;
            32'h8c:  data = 32'h00440413;
            32'h90:  data = 32'h000780e7;
            32'h94:  data = 32'hff24e8e3;
            32'h98:  data = 32'h0e000793;
            32'h9c:  data = 32'h0e000713;
            32'ha0:  data = 32'h40e78933;
            32'ha4:  data = 32'h40295913;
            32'ha8:  data = 32'h02e78063;
            32'hac:  data = 32'h0e000413;
            32'hb0:  data = 32'h00000493;
            32'hb4:  data = 32'h00042783;
            32'hb8:  data = 32'h00148493;
            32'hbc:  data = 32'h00440413;
            32'hc0:  data = 32'h000780e7;
            32'hc4:  data = 32'hff24e8e3;
            32'hc8:  data = 32'h00c12083;
            32'hcc:  data = 32'h00812403;
            32'hd0:  data = 32'h00412483;
            32'hd4:  data = 32'h00012903;
            32'hd8:  data = 32'h01010113;
            32'hdc:  data = 32'h00008067;
            32'he0:  data = 32'h00000000;
            default: data = 32'h00000000;
        endcase
    end
endmodule
