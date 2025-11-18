module Registers (
    input wire iCLK, iRST, iRegWrite,
    input wire [4:0] iReadRegister1, iReadRegister2, iWriteRegister,
    input wire [31:0] iWriteData,
    output wire [31:0] oReadData1, oReadData2,
    input wire [4:0] iRegDispSelect,
    output reg [31:0] oRegDisp
);

    // Banco de 32 registradores de 32 bits
    reg [31:0] registers [0:31];
    
    // Inicialização
    integer i;
    always @(posedge iCLK or posedge iRST) begin
        if (iRST) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
            // Stack Pointer inicial
            registers[2] <= 32'h100103FC;  // sp
        end
        else if (iRegWrite && (iWriteRegister != 5'b0)) begin
            // x0 é sempre zero (hardwired)
            registers[iWriteRegister] <= iWriteData;
        end
    end
    
    // Leitura assíncrona
    assign oReadData1 = (iReadRegister1 == 5'b0) ? 32'b0 : registers[iReadRegister1];
    assign oReadData2 = (iReadRegister2 == 5'b0) ? 32'b0 : registers[iReadRegister2];
    
    // Terceira porta de leitura para display
    always @(*) begin
        oRegDisp = (iRegDispSelect == 5'b0) ? 32'b0 : registers[iRegDispSelect];
    end

endmodule
