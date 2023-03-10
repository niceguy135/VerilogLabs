`timescale 1ns / 1ps
package kuznechik_cipher_p;
    typedef enum logic [4:0] {
        S_IDLE  = 5'b00001,
        S_KEYP  = 5'b00010,
        S_SP    = 5'b00100,
        S_LP    = 5'b01000,
        S_FIN   = 5'b10000
    } FSM;
endpackage : kuznechik_cipher_p

module kuznechik_cipher(
    input               clk_i,      // ???????? ??????
                        resetn_i,   // ?????????? ?????? ?????? ? ???????? ??????? LOW
                        request_i,  // ?????? ??????? ?? ?????? ??????????
                        ack_i,      // ?????? ????????????? ?????? ????????????? ??????
                [127:0] data_i,     // ????????? ??????

    output              busy_o,     // ??????, ?????????? ? ????????????? ??????
                                    // ?????????? ??????? ?? ??????????, ?????????
                                    // ?????? ? ???????? ?????????? ???????????
                                    // ???????
           logic          valid_o,    // ?????? ?????????? ????????????? ??????
           logic  [127:0] data_o      // ????????????? ??????
);

import kuznechik_cipher_p::*;

logic [127:0] key_mem [0:9];

logic [7:0] S_box_mem [0:255];

logic [7:0] L_mul_16_mem  [0:255];
logic [7:0] L_mul_32_mem  [0:255];
logic [7:0] L_mul_133_mem [0:255];
logic [7:0] L_mul_148_mem [0:255];
logic [7:0] L_mul_192_mem [0:255];
logic [7:0] L_mul_194_mem [0:255];
logic [7:0] L_mul_251_mem [0:255];

initial begin
    $readmemh("keys.mem",key_mem );
    $readmemh("S_box.mem",S_box_mem );

    $readmemh("L_16.mem", L_mul_16_mem );
    $readmemh("L_32.mem", L_mul_32_mem );
    $readmemh("L_133.mem",L_mul_133_mem);
    $readmemh("L_148.mem",L_mul_148_mem);
    $readmemh("L_192.mem",L_mul_192_mem);
    $readmemh("L_194.mem",L_mul_194_mem);
    $readmemh("L_251.mem",L_mul_251_mem);
end

///////////////////////////////////// ?????????
localparam int ROUND_CNT  = 10;
localparam int LIN_CNT    = 16; 
localparam int DATA_WIDTH = 128;
/////////////////////////////////////

FSM curState, nextState;

logic [127:0] curData;

logic [$clog2(ROUND_CNT)-1:0] roundCounter;
logic [$clog2(LIN_CNT)-1:0] linCounter;

logic valid;
logic busy;
assign busy_o = busy;

assign valid_o = valid;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [127:0] non_linear_tmp;   

generate
    genvar k;

    for(k = 0; k < 16; k = k + 1) // ?????????? ??????????????
        assign non_linear_tmp[8 * ( k + 1 ) - 1 : 8 * k] = S_box_mem[curData[8 * ( k + 1 ) - 1 : 8 * k]];

endgenerate
////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] line_shift = L_mul_148_mem[curData[127:120]] ^ L_mul_32_mem[curData[119:112]]  ^ L_mul_133_mem[curData[111:104]]  ^ L_mul_16_mem[curData[103:96]] 
            ^ L_mul_194_mem[curData[95:88]] ^ L_mul_192_mem[curData[87:80]]   ^ curData[79:72]                   ^ L_mul_251_mem[curData[71:64]] 
            ^ curData[63:56]                ^ L_mul_192_mem[curData[55:48]]   ^ L_mul_194_mem[curData[47:40]]    ^ L_mul_16_mem[curData[39:32]] 
            ^ L_mul_133_mem[curData[31:24]] ^ L_mul_32_mem[curData[23:16]]    ^ L_mul_148_mem[curData[15:8]]     ^ curData[7:0];
////////////////////////////////////////////////////////////////////////////////////////////////////////////


always_ff @(posedge clk_i) begin : proc_state_t
    if(~resetn_i) begin
        curState <= S_IDLE;
    end else begin
        curState <= nextState;
    end
end

always_comb begin : proc_state
    unique case (curState)
        S_IDLE: nextState = request_i ? S_KEYP : S_IDLE;

        S_KEYP: nextState = (roundCounter == ROUND_CNT - 1) ? S_FIN : S_SP;        

        S_SP :  nextState = S_LP;

        S_LP:   nextState = (linCounter == LIN_CNT - 1) ? S_KEYP : S_LP;

        S_FIN:  nextState = ack_i ? S_IDLE : S_FIN;

    default : nextState = S_IDLE;
    endcase
end


always_ff @(posedge clk_i) begin : proc_ctrl
    if(~resetn_i) begin
        valid <= 0;
        roundCounter <= {ROUND_CNT{1'b0}};
        busy <= 1'b0;
    end else begin
        unique case (curState)
            S_IDLE: begin

                roundCounter <= {ROUND_CNT{1'b0}};
                linCounter   <= {LIN_CNT{1'b0}};
                valid     <= 0;

                curData <= request_i ? data_i : curData;
                busy     <= request_i ? 1'b1 : 1'b0;

            end // S_IDLE

            S_KEYP: begin

                if(roundCounter == ROUND_CNT - 1) begin // ???? ?????? 10 ???????
                    valid  <= 1;
                    busy   <= 1'b0;
                    data_o <= curData ^ key_mem[roundCounter];
                end else begin
                    curData  <= curData ^ key_mem[roundCounter]; // ????????? ?????
                    roundCounter <= roundCounter + 1'b1;
                end


            end // S_KEYP
            S_SP : begin
                
                curData <= non_linear_tmp;

            end
            S_LP: begin
                curData <= {line_shift, curData[DATA_WIDTH-1:8]}; // ???????? ??????????????
                linCounter <= linCounter + 1'b1;
            end
            S_FIN: begin

                valid <= ack_i ? 0 : valid;

            end
        default : begin
            valid     <= valid;
            data_o    <= data_o;
            curData  <= curData;
            linCounter   <= linCounter;
            roundCounter <= roundCounter;
        end
        endcase
    end
end


endmodule
