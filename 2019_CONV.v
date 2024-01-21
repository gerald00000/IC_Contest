`timescale 1ns/10ps
module  CONV(
	input			clk, 
	input			reset, 
	output reg		busy,	
	input			ready,				
	output reg[11:0]	iaddr,
	input signed[19:0]		idata,	
	output reg 	 	cwr,
	output reg[11:0] 	caddr_wr,
	output reg[19:0] 	cdata_wr,	
	output reg	 	crd,
	output reg[11:0]	caddr_rd,
	input	[19:0]		cdata_rd,
	output reg[2:0] 	csel
	);

reg [2:0]cur_state;
reg [2:0]nx_state;
reg [2:0]pre_state;
reg [2:0]mem_cur_state;
reg [2:0]mem_nx_state;
reg signed[39:0] conv_data0;
reg signed[39:0] conv_data1;
reg [5:0]x;
reg [5:0]y;
reg signed[19:0]conv_check;
reg [3:0]ary;
reg signed[39:0]k0;
reg signed[39:0]k1;
reg [3:0]mcount;
reg signed[19:0]max0;
reg signed[19:0]max1;

reg signed[19:0]kernel0;
reg signed[19:0]kernel1;

wire signed[19:0]conv_out0;
wire signed[19:0]conv_out1;
wire signed[39:0]bias00;
wire signed[39:0]bias11;

parameter STATE_IDLE = 3'd0;
parameter STATE_conv = 3'd1;
parameter STATE_l0mem = 3'd2;
parameter STATE_l1mem = 3'd3;
parameter STATE_l2mem = 3'd4;
parameter STATE_maxp = 3'd5;
parameter STATE_finish = 3'd6;

parameter STATE_mem_IDLE = 3'd0;
parameter STATE_l0mem0 = 3'd1;
parameter STATE_l0mem1 = 3'd2;
parameter STATE_l1mem0 = 3'd3;
parameter STATE_l1mem1 = 3'd4;
parameter STATE_l2mem0 = 3'd5;
parameter STATE_l2mem0_1 = 3'd6;

parameter bias0 = 20'h01310;
parameter bias1 = 20'hF7295;

parameter kernel0_0 = 20'h0A89E;
parameter kernel0_1 = 20'h092D5;
parameter kernel0_2 = 20'h06D43;
parameter kernel0_3 = 20'h01004;
parameter kernel0_4 = 20'hF8F71;
parameter kernel0_5 = 20'hF6E54;
parameter kernel0_6 = 20'hFA6D7;
parameter kernel0_7 = 20'hFC834;
parameter kernel0_8 = 20'hFAC19;

parameter kernel1_0 = 20'hFDB55;
parameter kernel1_1 = 20'h02992;
parameter kernel1_2 = 20'hFC994;
parameter kernel1_3 = 20'h050FD;
parameter kernel1_4 = 20'h02F20;
parameter kernel1_5 = 20'h0202D;
parameter kernel1_6 = 20'h03BD7;
parameter kernel1_7 = 20'hFD369;
parameter kernel1_8 = 20'h05E68;


//STATE
always @(posedge clk or posedge reset)begin
    if(reset)begin
        cur_state <= STATE_IDLE;
    end
    else begin
        cur_state <= nx_state;
    end
end

always @(*)begin
    nx_state = STATE_IDLE;
    case(cur_state)
    STATE_IDLE: nx_state = (ready)? STATE_IDLE : STATE_conv;
    STATE_conv: nx_state = (ary == 11)? STATE_l0mem : STATE_conv;
    STATE_l0mem: begin
        if(mem_cur_state == STATE_l0mem1)begin
            if(x == 63 && y == 63) begin
                nx_state = STATE_maxp;
            end
            else begin
                nx_state = STATE_conv;
            end
        end
        else begin
            nx_state = STATE_l0mem;
        end
    end
    STATE_l1mem: nx_state = (mem_cur_state == STATE_l1mem1)? STATE_l2mem : STATE_l1mem;
    STATE_l2mem: begin
        if(mem_cur_state == STATE_l2mem0_1)begin
            if(x == 62 && y == 62)begin
                nx_state = STATE_finish;
            end
            else begin
                nx_state = STATE_maxp;
            end
        end
        else begin
            nx_state = STATE_l2mem;
        end
    end
    STATE_maxp: nx_state = (mcount == 8)? STATE_l1mem : STATE_maxp;
    STATE_finish: nx_state = STATE_finish;
    endcase
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        pre_state <= STATE_IDLE;
    end
    else if(cur_state != nx_state)begin
        pre_state <= cur_state;
    end
    else begin
        pre_state <= pre_state;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        mem_cur_state <= STATE_IDLE;
    end
    else begin
        mem_cur_state <= mem_nx_state;
    end
end

always @(*)begin
    case(cur_state)
    STATE_l0mem: mem_nx_state = (mem_cur_state == STATE_l0mem0)? STATE_l0mem1 : STATE_l0mem0;
    STATE_l1mem: mem_nx_state = (mem_cur_state == STATE_l1mem1)? STATE_l2mem0 : STATE_l1mem1;
    STATE_l2mem: mem_nx_state = (mem_cur_state == STATE_l2mem0)? STATE_l2mem0_1 : STATE_l0mem0;
    STATE_maxp: begin
        if(mcount == 8)begin
            mem_nx_state = STATE_l1mem0;
        end
        else begin
            mem_nx_state = (mem_cur_state == STATE_l0mem1)? STATE_l0mem0 : STATE_l0mem1;
        end
    end
    default mem_nx_state = STATE_mem_IDLE;
    endcase
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        busy <= 0;
    end
    else if(cur_state == STATE_IDLE)begin
        busy <= 1;
    end
    else if(cur_state == STATE_finish)begin
        busy <= 0;
    end
    else begin
        busy <= busy;
    end 
end 

//csel
always @(*)begin
    case(cur_state)
        STATE_l0mem: csel = (mem_cur_state == STATE_l0mem1)? 3'b010 : 3'b001;
        STATE_l1mem: csel = (mem_cur_state == STATE_l1mem1)? 3'b100 : 3'b011;
        STATE_l2mem: csel = 3'b101;
        STATE_maxp: csel = (mem_cur_state == STATE_l0mem0)? 3'b001 : 3'b010;
        default: csel = 3'b000;
    endcase
end

//rd_mem
always @(*)begin
    if(cur_state == STATE_maxp)begin
        case (mcount)
        0: caddr_rd = 64 * y + x;
        1: caddr_rd = 64 * y + x;
        2: caddr_rd = 64 * y + x + 1;
        3: caddr_rd = 64 * y + x + 1;
        4: caddr_rd = 64 * y + x + 64;
        5: caddr_rd = 64 * y + x + 64;
        6: caddr_rd = 64 * y + x + 65;
        7: caddr_rd = 64 * y + x + 65;
        default: caddr_rd = 0;
        endcase
    end
    else begin
        caddr_rd = 0;
    end
end


//wr_mem
always @(*)begin
    case(cur_state)
    STATE_l0mem: caddr_wr = y * 64 + x;
    STATE_l1mem: caddr_wr = y * 16 + x / 2; 
    STATE_l2mem: caddr_wr = (mem_cur_state == STATE_l2mem0)? y * 32 + x : y * 32 + x + 1;
    default: caddr_wr = 0;
    endcase
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cdata_wr <= 'd0;
    end
    else if(cur_state == STATE_l0mem)begin
        if(mem_cur_state == STATE_l0mem0)begin
            cdata_wr <= (conv_out1 > 0)? conv_out1 : 'd0;
        end
        else begin
            cdata_wr <= (conv_out0 > 0)? conv_out0 : 'd0;
        end
    end
    else if(mcount == 8)begin
        cdata_wr <= max0;
    end
    else if(cur_state == STATE_l1mem)begin
        cdata_wr <= (mem_cur_state == STATE_l1mem0)? max1 : max0;
    end
    else if(cur_state == STATE_l2mem)begin
        cdata_wr <= (mem_cur_state == STATE_l2mem0)? max1 : 'd0;
    end
    else begin
        cdata_wr <= 'd0;
    end
end

//delay

//crd
always @(*) begin
    if(cur_state == STATE_maxp)begin
        crd = 1;
    end
    else begin
        crd = 0;
    end
end
//cwr
always @(*) begin
    if(cur_state == STATE_l1mem || cur_state == STATE_l2mem)begin
        cwr = 1;
    end
    else if(mem_cur_state != STATE_mem_IDLE && cur_state == STATE_l0mem)begin
        cwr = 1;
    end
    else begin
        cwr = 0;
    end
end

//conv
always @(posedge clk or posedge reset)begin
    if(reset)begin
        conv_data0 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        if(ary == 0)begin
            conv_data0 <= 'd0;
        end
        else if(2 < ary && ary < 12)begin
            conv_data0 <= conv_data0 + k0;
        end
        else begin
            conv_data0 <= conv_data0;
        end
    end
    else begin
        conv_data0 <= conv_data0;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        conv_data1 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        if(ary == 0)begin
            conv_data1 <= 'd0;
        end
        else if(2 < ary && ary < 12)begin
            conv_data1 <= conv_data1 + k1;
        end
        else begin
            conv_data1 <= conv_data1;
        end
    end
    else begin
        conv_data1 <= conv_data1;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        ary <= 0;
    end
    else if(cur_state == STATE_conv)begin
        if(ary == 12)begin
            ary <= 0;
        end
        else begin
            ary <= ary + 1;
        end
    end
    else begin
        ary <= ary;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        iaddr <= 0;
    end
    else if(cur_state == STATE_conv)begin
        case (ary)
            0: iaddr <= (x == 0 || y == 0)? iaddr : ((y - 1) * 64 + x - 1);
            1: iaddr <= (y == 0)? iaddr : ((y - 1) * 64 + x);
            2: iaddr <= (x == 63 || y == 0)? iaddr : ((y - 1) * 64 + x + 1);
            3: iaddr <= (x == 0)? iaddr : (y * 64 + x - 1);
            4: iaddr <= (y * 64 + x);
            5: iaddr <= (x == 63)? iaddr : (y * 64 + x + 1);
            6: iaddr <= (x == 0 || y == 63)? iaddr : ((y + 1) * 64 + x - 1);
            7: iaddr <= (y == 63)? iaddr : ((y + 1) * 64 + x);
            8: iaddr <= (x == 63 || y == 63)? iaddr : ((y + 1) * 64 + x + 1);
            default: iaddr <= iaddr;
        endcase
    end
    else begin
        iaddr <= 0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        conv_check <= 0;
    end
    else if(cur_state == STATE_conv)begin
            case (ary)
                1: conv_check <= (x == 0 || y == 0)? 0 : idata;
                2: conv_check <= (y == 0)? 0 : idata;
                3: conv_check <= (x == 63 || y == 0)? 0 : idata;
                4: conv_check <= (x == 0)? 0 : idata;
                5: conv_check <= idata;
                6: conv_check <= (x == 63)? 0 : idata;
                7: conv_check <= (x == 0 || y == 63)? 0 : idata;
                8: conv_check <= (y == 63)? 0 : idata;
                9: conv_check <= (x == 63 || y == 63)? 0 : idata;
                default: conv_check <= conv_check;
            endcase
    end
    else begin
        conv_check <= 0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        k0 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        if(1 < ary && ary < 11)begin
            k0 <= conv_check * kernel0;
        end
        else begin
            k0 <= 'd0;
        end
    end
    else begin
        k0 <= 'd0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        k1 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        if(1 < ary && ary < 11)begin
            k1 <= conv_check * kernel1;
        end
        else begin
            k1 <= 'd0;
        end
    end
    else begin
        k1 <= 'd0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        kernel0 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        case (ary)
            1: kernel0 <= (kernel0_0);
            2: kernel0 <= (kernel0_1);
            3: kernel0 <= (kernel0_2);
            4: kernel0 <= (kernel0_3);
            5: kernel0 <= (kernel0_4);
            6: kernel0 <= (kernel0_5);
            7: kernel0 <= (kernel0_6);
            8: kernel0 <= (kernel0_7);
            9: kernel0 <= (kernel0_8);
            default: kernel0 <= 'd0;
        endcase
    end
    else begin
        kernel0 <= 'd0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        kernel1 <= 'd0;
    end
    else if(cur_state == STATE_conv)begin
        case (ary)
            1: kernel1 <= (kernel1_0);
            2: kernel1 <= (kernel1_1);
            3: kernel1 <= (kernel1_2);
            4: kernel1 <= (kernel1_3);
            5: kernel1 <= (kernel1_4);
            6: kernel1 <= (kernel1_5);
            7: kernel1 <= (kernel1_6);
            8: kernel1 <= (kernel1_7);
            9: kernel1 <= (kernel1_8);
            default: kernel1 <= 'd0;
        endcase
    end
    else begin
        kernel1 <= 'd0;
    end
end

assign bias00 = conv_data0 + {4'b0,bias0,16'b0};
assign bias11 = conv_data1 + {4'b0,bias1,16'b0};

assign conv_out0 = ( bias00[15] )? bias00[35:16] + 1: bias00[35:16];
assign conv_out1 = ( bias11[15] )? bias11[35:16] + 1: bias11[35:16];

//max-pooling

always @(posedge clk or posedge reset) begin
    if(reset)begin
        mcount <= 0;
    end
    else if(cur_state == STATE_maxp)begin
        mcount <= mcount + 1;
    end
    else if(mem_cur_state == STATE_l2mem0_1)begin
        mcount <= 0;
    end
    else begin
        mcount <= mcount;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        max0 <= 'd0;
    end
    else if(cur_state == STATE_maxp)begin
        if(max0 < cdata_rd && mem_cur_state == STATE_l0mem0)begin
            max0 <= cdata_rd;
        end
        else begin
            max0 <= max0;
        end
    end
    else if(mem_cur_state == STATE_l2mem0)begin
        max0 <= 'd0;
    end
    else begin
        max0 <= max0;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        max1 <= 'd0;
    end
    else if(cur_state == STATE_maxp)begin
        if(!mcount)begin
            max1 <= 0;
        end
        else if(max1 < cdata_rd && mem_cur_state == STATE_l0mem1)begin
            max1 <= cdata_rd;
        end
        else begin
            max1 <= max1;
        end
    end
    else begin
        max1 <= max1;
    end
end


//x, y
always @(posedge clk or posedge reset)begin
    if(reset)begin
        x <= 0;
    end
    else if(cur_state == STATE_maxp && pre_state == STATE_l0mem)begin
        x <= 0;
    end
    else if(mem_cur_state == STATE_l2mem0_1)begin
        if(x == 62)begin
            x <= 0;
        end
        else begin
            x <= x + 2;
        end
    end
    else if(pre_state == STATE_conv && mem_cur_state == STATE_l0mem1)begin
        if(x == 63)begin
            x <= 0;
        end
        else begin
            x <= x + 1;
        end
    end 
    else begin
        x <= x;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        y <= 0;
    end
    else if(cur_state == STATE_maxp && pre_state == STATE_l0mem)begin
        y <= 0;
    end
    else if(mem_cur_state == STATE_l2mem0_1)begin
        if(x == 62)begin
            y <= y + 2;
        end
        else begin
            y <= y;
        end
    end
    else if(pre_state == STATE_conv && mem_cur_state == STATE_l0mem1)begin
        if(x == 63)begin
            if(y == 63)begin
                y <= 0;
            end
            else begin
                y <= y + 1;
            end
        end
        else begin
            y <= y;
        end
    end
    else begin
        y <= y;
    end
end




endmodule
