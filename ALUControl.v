`ifndef PARAM
	`include "Parametros.v"
`endif

module ALUControl (
    input  [1:0] ALUOp,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output logic [4:0] ALUControl
);

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = OPADD;  // ALUOp = 00 -> SOMA (para lw, sw, addi, jalr)
        2'b01: ALUControl = OPSUB;  // ALUOp = 01 -> SUBTRAÇÃO (para beq)
        2'b10: begin  // ALUOp = 10 -> Tipo-R (decodifica funct3/funct7)
            case (funct3)
                FUNCT3_ADD: begin
                    if (funct7 == FUNCT7_SUB)
                        ALUControl = OPSUB;
                    else
                        ALUControl = OPADD;
                end
                FUNCT3_AND: ALUControl = OPAND;
                FUNCT3_OR:  ALUControl = OPOR;
                FUNCT3_SLT: ALUControl = OPSLT;
                default:    ALUControl = OPNULL;
            endcase
        end
        2'b11: ALUControl = OPLUI;  // ALUOp = 11 -> LUI (passa o imediato pela ULA)
        default: ALUControl = OPNULL;
    endcase
end

endmodule
