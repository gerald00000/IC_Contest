`timescale 1ns/10ps
module JAM (
    input CLK,
    input RST,
    output reg [2:0] W,
    output [2:0] J,
    input [6:0] Cost,
    output reg [3:0] MatchCount,
    output reg [9:0] MinCost,
    output reg Valid );

parameter STATE_IDLE = 2'd0;
parameter STATE_INPUT = 2'd1;
parameter STATE_OUT = 2'd2;
parameter STATE_ALG = 2'd3;

integer i;

reg [1:0]cur_state;
reg [1:0]nx_state;
reg [2:0]n[0:7];
reg [2:0]nx_n[0:7];
reg [2:0]change1;
reg [2:0]change2;
reg [2:0]count1;
reg [2:0]count2;
reg [3:0]delay;
reg [9:0]totalCost;
reg [2:0]flag;
reg stop_count1;
reg stop_w;
reg [2:0]cost_delay;

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        cur_state <= STATE_IDLE;
    end
    else begin
        cur_state <= nx_state;
    end
end

always@( * )begin
    case(cur_state)
        STATE_IDLE: nx_state = STATE_INPUT;
        STATE_INPUT: begin
            if(cost_delay == 1)begin
                if(flag == 3'd7) nx_state = STATE_OUT;
                else if(delay > 1) nx_state = STATE_ALG;
                else nx_state = STATE_INPUT;
            end
            else begin
                nx_state = STATE_INPUT;
            end
        end
        STATE_OUT: nx_state = STATE_OUT;
        STATE_ALG: nx_state = STATE_INPUT;
    endcase
end

//ALG
always@(posedge CLK or posedge RST)begin
    if(RST)begin
        for(i = 0 ; i < 8 ; i = i + 1) n[i] <= i;
    end
    else if(cur_state == STATE_INPUT && cost_delay == 1 && delay > 1)begin
        for(i = 0 ; i < 8 ; i = i + 1) n[i] <= nx_n[i];
    end
    else begin
        for(i = 0 ; i < 8 ; i = i + 1) n[i] <= n[i];
    end
end

//INPUT
always@(posedge CLK or posedge RST)begin
    if(RST)begin
        for(i = 0 ; i < 8 ; i = i + 1) nx_n[i] <= i;
    end
    else if(cur_state == STATE_INPUT && count2 == change1 && stop_count1)begin
        if(delay == 0)begin
            nx_n[change1] <= nx_n[change2];
            nx_n[change2] <= nx_n[change1];
        end
        else if(delay == 1)begin
            case(change1)
                5:begin
                    nx_n[6] <= nx_n[7];
                    nx_n[7] <= nx_n[6];
                end
                4:begin
                    nx_n[7] <= nx_n[5];
                    nx_n[5] <= nx_n[7];
                end
                3:begin
                    nx_n[7] <= nx_n[4];
                    nx_n[6] <= nx_n[5];
                    nx_n[5] <= nx_n[6];
                    nx_n[4] <= nx_n[7];
                end
                2:begin
                    nx_n[7] <= nx_n[3];
                    nx_n[6] <= nx_n[4];
                    nx_n[4] <= nx_n[6];
                    nx_n[3] <= nx_n[7];
                end
                1:begin
                    nx_n[7] <= nx_n[2];
                    nx_n[6] <= nx_n[3];
                    nx_n[5] <= nx_n[4];
                    nx_n[4] <= nx_n[5];
                    nx_n[3] <= nx_n[6];
                    nx_n[2] <= nx_n[7];
                end
                0:begin
                    nx_n[7] <= nx_n[1];
                    nx_n[6] <= nx_n[2];
                    nx_n[5] <= nx_n[3];
                    nx_n[3] <= nx_n[5];
                    nx_n[2] <= nx_n[6];
                    nx_n[1] <= nx_n[7];
                end
                default:begin
                    nx_n[0] <= nx_n[0];
                    nx_n[1] <= nx_n[1];
                    nx_n[2] <= nx_n[2];
                    nx_n[3] <= nx_n[3];
                    nx_n[4] <= nx_n[4];
                    nx_n[5] <= nx_n[5];
                    nx_n[6] <= nx_n[6];
                    nx_n[7] <= nx_n[7];
                end 
            endcase
        end
        else begin
            nx_n[0] <= nx_n[0];
            nx_n[1] <= nx_n[1];
            nx_n[2] <= nx_n[2];
            nx_n[3] <= nx_n[3];
            nx_n[4] <= nx_n[4];
            nx_n[5] <= nx_n[5];
            nx_n[6] <= nx_n[6];
            nx_n[7] <= nx_n[7];
        end
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        change1 <= 7;
    end
    else if(cur_state == STATE_INPUT)begin
        if(n[count1] > n[count1-1])begin
            change1 <= count1 - 1;
        end
        else begin
            change1 <= change1;
        end
    end
    else begin
        change1 <= 7;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        change2 <= 7;
    end
    else if(cur_state == STATE_INPUT && stop_count1)begin
        if((n[count2] - n[change1]) > 0 && (n[count2] - n[change1]) < (n[count2] - n[change2]))begin
            change2 <= count2;
        end
        else begin
            change2 <= change2;
        end
    end
    else begin
        change2 <= 7;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        count1 <= 7;
    end
    else if(cur_state == STATE_INPUT && !stop_count1)begin
        if(n[count1] > n[count1-1])begin
            count1 <= count1;
        end
        else begin
            count1 <= count1 - 1;
        end
    end
    else begin
        count1 <= 7;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        stop_count1 <= 0;
    end
    else if(cur_state == STATE_INPUT)begin
        if(n[count1] > n[count1-1])begin
            stop_count1 <= 1;
        end
        else begin
            stop_count1 <= stop_count1;
        end
    end
    else begin
        stop_count1 <= 0;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        count2 <= 7;
    end
    else if(cur_state == STATE_INPUT && stop_count1)begin
        if(count2 > change1)begin
            count2 <= count2 - 1;
        end
        else begin
            count2 <= count2;
        end
    end
    else begin
        count2 <= 7;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        delay <= 0;
    end
    else if(cur_state == STATE_INPUT && count2 == change1 && stop_count1)begin
        delay <= delay + 1;
    end
    else begin
        delay <= 0;
    end
end

//INPUT

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        W <= 0;
    end
    else if(cur_state == STATE_INPUT && !stop_w)begin
        if(W < 7)begin
            W <= W + 1;
        end
        else begin
            W <= W;
        end
    end
    else if(cur_state == STATE_ALG)begin
        W <= 1;
    end
    else begin
        W <= 0;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        stop_w <= 0;
    end
    else if(cur_state == STATE_INPUT)begin
        if(W == 7)begin
            stop_w <= 1;
        end
        else begin
            stop_w <= stop_w;
        end
    end
    else begin
        stop_w <= 0;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        cost_delay <= 0;
    end
    else if(cur_state == STATE_INPUT)begin
        if(stop_w)begin
            cost_delay <= cost_delay + 1;
        end
        else begin
            cost_delay <= cost_delay;
        end
    end
    else begin
        cost_delay <= 0;
    end
end

assign J = n[W];

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        totalCost <= 0;
    end
    else if(cur_state == STATE_INPUT)begin
        if(cost_delay != 2 && W > 0)begin
            totalCost <= totalCost + Cost;
        end
        else begin
            totalCost <= totalCost;
        end
    end
    else begin
        totalCost <= 0;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        MinCost <= 0;
    end
    else if(cur_state == STATE_INPUT && cost_delay == 1)begin
        if(MinCost == 0)begin
            MinCost <= totalCost;
        end
        else if(MinCost > totalCost)begin
            MinCost <= totalCost;
        end
        else begin
            MinCost <= MinCost;
        end
    end
    else begin
        MinCost <= MinCost;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        MatchCount <= 0;
    end
    else if(cur_state == STATE_INPUT && cost_delay == 1 && delay > 1)begin
        if(MinCost == totalCost)begin
            MatchCount <= MatchCount + 1;
        end
        else if(MinCost > totalCost || MinCost == 0)begin
            MatchCount <= 1;
        end
        else begin
            MatchCount <= MatchCount;
        end
    end
    else begin
        MatchCount <= MatchCount;
    end
end

always@(posedge CLK or posedge RST)begin
    if(RST)begin
        flag <= 0;
    end
    else if(cur_state == STATE_INPUT)begin
        if(0 < W && !stop_w)begin
            if((n[W-1] - 1) == n[W])begin
                flag <= flag + 1;
            end
            else begin
                flag <= flag;
            end
        end
        else begin
            flag <= flag;
        end
    end
    else begin
        flag <= 0;
    end
end

//OUT
always@(posedge CLK or posedge RST)begin
    if(RST)begin
        Valid <= 0;
    end
    else if(cur_state == STATE_OUT)begin
        Valid <= 1;
    end
    else begin
        Valid <= 0;
    end
end

endmodule
