// Opcodes
parameter OC_LOAD = 5'b00000;
parameter OC_LOAD_FP = 5'b00001;
parameter OC_CUSTOM0 = 5'b00010;
parameter OC_MISC_MEM = 5'b00011;
parameter OC_OP_IMM = 5'b00100;
parameter OC_AUIPC = 5'b00101;
parameter OC_IMM_32 = 5'b00110;
parameter OC_48B_0 = 5'b00111;
parameter OC_STORE = 5'b01000;
parameter OC_STORE_FP = 5'b01001;
parameter OC_CUSTOM1 = 5'b01010;
parameter OC_AMO = 5'b01011;
parameter OC_OP = 5'b01100;
parameter OC_LUI = 5'b01101;
parameter OC_OP_32 = 5'b01110;
parameter OC_64B_0 = 5'b01111;
parameter OC_MADD = 5'b10000;
parameter OC_MSUB = 5'b10001;
parameter OC_NMSUB = 5'b10010;
parameter OC_NMADD = 5'b10011;
parameter OC_OP_FP = 5'b10100;
parameter OC_CUSTOM2_RV128 = 5'b10110;
parameter OC_48B_1 = 5'b10111;
parameter OC_BRANCH = 5'b11000;
parameter OC_JALR = 5'b11001;
parameter OC_JAL = 5'b11011;
parameter OC_SYSTEM = 5'b11100;
parameter OC_CUSTOM3_RV128 = 5'b11110;
parameter OC_85bP_0 = 5'b11111;

// ALU Functions
parameter FUNCT3_ADD_SUB = 3'h0;

parameter FUNCT3_XOR = 3'h4;
parameter FUNCT3_OR = 3'h6;
parameter FUNCT3_AND = 3'h7;
parameter FUNCT3_SLL = 3'h1;
parameter FUNCT3_SRL_SRA = 3'h5;
parameter FUNCT7_SRA = 7'h20;

parameter FUNCT3_SLT = 3'h2;
parameter FUNCT3_SLTU = 3'h3;


parameter FUNCT7_SUB = 7'h20;
parameter FUNCT7_I = 7'h00;
parameter FUNCT7_M = 7'h01;


// CSR definitions
parameter CSR_MCAUSE = 12'h342;

// Privleged instruction defenitions
parameter FUNCT3_PRIV = 0;
