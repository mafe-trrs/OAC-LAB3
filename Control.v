`ifndef PARAM
	`include "Parametros.v"
`endif

module Control (
    input  wire clock,
    input  wire reset,
    input  wire [6:0] opcode,
    input  wire [2:0] funct3, 
    
    output reg EscrevePCCond, EscrevePC, IouD, EscreveMem, LeMem, EscreveIR,
    output reg Mem2Reg, 
    output reg [1:0] OrigPC, 
    output reg [1:0] ALUOp,
    output reg [1:0] OrigBULA, 
    output reg OrigAULA, EscreveReg,
    output reg [3:0] Estado
);

    // Estados
    localparam [3:0]
        S_FETCH     = 4'd0,
        // S_WAIT removido para evitar ambiguidade
        S_DECODE    = 4'd2,
        S_MEM_ADDR  = 4'd3,
        S_MEM_READ  = 4'd4,
        S_MEM_WRITE = 4'd5,
        S_MEM_WB    = 4'd6,
        S_EXEC_R    = 4'd7,
        S_R_WB      = 4'd8,
        S_EXEC_I    = 4'd9,
        S_I_WB      = 4'd10,
        S_BRANCH    = 4'd11,
        S_JAL       = 4'd12,
        S_JALR      = 4'd13,
        S_LUI       = 4'd14;

    reg [3:0] estado_atual, proximo_estado;
    reg [1:0] wait_counter;

    // Lógica Sequencial + Contador
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_atual <= S_FETCH;
            wait_counter <= 0;
        end else begin
            estado_atual <= proximo_estado;
            
            // Se vamos continuar no mesmo estado de espera (Fetch ou Read), incrementa
            if (proximo_estado == S_FETCH || proximo_estado == S_MEM_READ) begin
                 // Só incrementa se não estivermos reiniciando o ciclo (ex: vindo de WB)
                 if (estado_atual == proximo_estado) 
                    wait_counter <= wait_counter + 1'b1;
                 else 
                    wait_counter <= 0;
            end else begin
                wait_counter <= 0;
            end
        end
    end

    always @(*) Estado = estado_atual;

    // Lógica de Próximo Estado
    always @(*) begin
        proximo_estado = estado_atual; // Default: fica onde está
        
        case (estado_atual)
            S_FETCH: begin
                // Espera o contador bater 1 (simulando latência)
                if (wait_counter >= 2'd1) proximo_estado = S_DECODE;
                else proximo_estado = S_FETCH; // Fica aqui esperando
            end
            
            S_DECODE: begin
                case (opcode)
                    OPC_RTYPE:  proximo_estado = S_EXEC_R;
                    OPC_OPIMM:  proximo_estado = S_EXEC_I;
                    OPC_LOAD:   proximo_estado = S_MEM_ADDR;
                    OPC_STORE:  proximo_estado = S_MEM_ADDR;
                    OPC_BRANCH: proximo_estado = S_BRANCH;
                    OPC_JAL:    proximo_estado = S_JAL;
                    OPC_JALR:   proximo_estado = S_JALR;
                    OPC_LUI:    proximo_estado = S_LUI;
                    default:    proximo_estado = S_FETCH;
                endcase
            end

            S_MEM_ADDR: proximo_estado = (opcode == OPC_LOAD) ? S_MEM_READ : S_MEM_WRITE;
            
            S_MEM_READ: begin
                // LW também espera memória
                if (wait_counter >= 2'd1) proximo_estado = S_MEM_WB;
                else proximo_estado = S_MEM_READ; // Fica aqui esperando
            end
            
            S_MEM_WRITE, S_MEM_WB, S_R_WB, S_I_WB, S_BRANCH, S_JAL, S_JALR, S_LUI: proximo_estado = S_FETCH;
            
            S_EXEC_R:   proximo_estado = S_R_WB;
            S_EXEC_I:   proximo_estado = S_I_WB;
            default:    proximo_estado = S_FETCH;
        endcase
    end

    // Saídas de Controle
    always @(*) begin
        // Defaults (zera tudo para evitar latches)
        EscrevePCCond=0; EscrevePC=0; IouD=0; EscreveMem=0; LeMem=0; EscreveIR=0;
        Mem2Reg=0; EscreveReg=0; OrigAULA=0; OrigPC=0; ALUOp=2'b00; OrigBULA=0;

        case (estado_atual)
            S_FETCH: begin
                LeMem = 1; 
                IouD = 0;       // Endereço = PC
                OrigAULA = 0;   // PC
                OrigBULA = 1;   // 4
                ALUOp = 2'b00;  // ADD
                OrigPC = 0;     // Resultado ULA
                
                // Só grava IR e atualiza PC no FINAL da espera
                if (wait_counter >= 2'd1) begin
                    EscrevePC = 1;
                    EscreveIR = 1;
                end
            end

            S_DECODE: begin OrigAULA=0; OrigBULA=2; ALUOp=0; end // Calc Branch Target
            
            S_EXEC_R: begin OrigAULA=1; OrigBULA=0; ALUOp=2'b10; end
            S_EXEC_I: begin OrigAULA=1; OrigBULA=2; ALUOp=2'b00; end
            
            S_LUI:    begin 
                OrigAULA=1; OrigBULA=2; 
                ALUOp=2'b11; // Manda 11 -> ALUControl -> OPLUI (10) -> ALU passa B
                EscreveReg=1; 
            end

            S_MEM_ADDR: begin OrigAULA=1; OrigBULA=2; ALUOp=0; end
            
            S_MEM_READ: begin 
                LeMem=1; 
                IouD=1; // Endereço = ALUOut
                // Não grava nada, só espera o dado chegar
            end
            
            S_MEM_WB:   begin EscreveReg=1; Mem2Reg=1; end
            S_MEM_WRITE:begin EscreveMem=1; IouD=1; end
            S_R_WB, S_I_WB: begin EscreveReg=1; Mem2Reg=0; end
            
            S_BRANCH:   begin 
                OrigAULA=1; OrigBULA=0; ALUOp=2'b01; // Sub
                EscrevePCCond=1; OrigPC=1; // Target
            end
            
            S_JAL:      begin EscrevePC=1; OrigPC=1; EscreveReg=1; end
            S_JALR:     begin OrigAULA=1; OrigBULA=2; ALUOp=0; EscrevePC=1; OrigPC=0; EscreveReg=1; end
        endcase
    end
endmodule