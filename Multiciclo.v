`ifndef PARAM
	`include "Parametros.v"
`endif

module Multiciclo (
    input  logic clockCPU, clockMem, reset,
    output logic [31:0] PC, Instr,
    input  logic [4:0] regin,
    output logic [31:0] regout,
    output logic [3:0] estado
);

    // Registradores Temporários
    reg [31:0] PC_reg, PCBack, IR, MDR, A, B_reg, ALUOut;
    
    // Fios
    wire [31:0] wIouD, MemData, RamIData, RamDData, WriteData, RData1, RData2, SrcA, SrcB, ImmGen, ALUResult;
    wire Zero;
    wire [4:0] ALUControl_out;
    
    // Sinais de Controle
    wire EscrevePCCond, EscrevePC, IouD, EscreveMem, LeMem, EscreveIR, Mem2Reg, EscreveReg, OrigAULA;
    wire [1:0] OrigPC, ALUOp, OrigBULA;
    
    assign PC = PC_reg;
    assign Instr = IR;

    // === MEMÓRIA UNIFICADA (Item 1.1) ===
    assign wIouD = (IouD == 1'b0) ? PC_reg : ALUOut;
    
    // Memória de Instruções (Acessa sempre, mas lógica escolhe saída)
    ramI MemInst (.address(wIouD[11:2]), .clock(clockMem), .data(32'b0), .wren(1'b0), .q(RamIData));
    
    // Memória de Dados (Só escreve se bit 28 for 1)
    ramD MemDados (.address(wIouD[11:2]), .clock(clockMem), .data(B_reg), .wren(EscreveMem & wIouD[28]), .q(RamDData));
    
    // Mux de Saída: Bit 28 define se lemos Dados ou Instrução
    assign MemData = (wIouD[28]) ? RamDData : RamIData;

    // === MÁQUINA DE ESTADOS ===
    Control ctrl (
        .clock(clockCPU), .reset(reset), 
        .opcode(IR[6:0]), .funct3(IR[14:12]),
        .EscrevePCCond(EscrevePCCond), .EscrevePC(EscrevePC), .IouD(IouD), 
        .EscreveMem(EscreveMem), .LeMem(LeMem), .EscreveIR(EscreveIR), 
        .Mem2Reg(Mem2Reg), .OrigPC(OrigPC), .ALUOp(ALUOp), 
        .OrigBULA(OrigBULA), .OrigAULA(OrigAULA), .EscreveReg(EscreveReg),
        .Estado(estado)
    );

    // === REGISTRADORES ===
    always @(posedge clockCPU or posedge reset) begin
        if (reset) begin
            PC_reg <= TEXT_ADDRESS; PCBack <= TEXT_ADDRESS;
            IR <= 0; MDR <= 0; A <= 0; B_reg <= 0; ALUOut <= 0;
        end else begin
            if (EscreveIR) IR <= MemData;
            MDR <= MemData; A <= RData1; B_reg <= RData2; ALUOut <= ALUResult;
            
            if (EscrevePC || (EscrevePCCond & Zero)) begin
                PCBack <= PC_reg;
                if (OrigPC == 2'b01) PC_reg <= ALUOut; else PC_reg <= ALUResult;
            end
        end
    end

    assign WriteData = (Mem2Reg) ? MDR : ALUOut;
    
    Registers regs (
        .iCLK(clockCPU), .iRST(reset), .iRegWrite(EscreveReg),
        .iReadRegister1(IR[19:15]), .iReadRegister2(IR[24:20]), .iWriteRegister(IR[11:7]), 
        .iWriteData(WriteData), .oReadData1(RData1), .oReadData2(RData2),
        .iRegDispSelect(regin), .oRegDisp(regout)
    );

    // === EXECUÇÃO (ALU e Imediatos) ===
    ImmGen imm ( .iInstrucao(IR), .oImm(ImmGen) );

    assign SrcA = (OrigAULA) ? A : PC_reg;
    assign SrcB = (OrigBULA == 2'b00) ? B_reg : (OrigBULA == 2'b01) ? 32'd4 : ImmGen;

    ALUControl alu_ctrl (
        .ALUOp(ALUOp), 
        .funct3(IR[14:12]), .funct7(IR[31:25]), 
        .ALUControl(ALUControl_out)
    );

    ALU alu (
        .iControl(ALUControl_out), 
        .iA(SrcA), .iB(SrcB), 
        .oResult(ALUResult), .Zero(Zero)
    );

endmodule