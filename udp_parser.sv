module udp_parser 
(
    clock,
    reset,
    a_data_i,
    a_valid_i,
    a_ready_o,
    b_data_o,
    b_ready_i,
    b_valid_o,
);

    typedef enum logic [2:0]
    {
        IDLE        = 3'b000,
        S_FIRST_BEAT= 3'b001,
        S_DATA      = 3'b010,
        S_LAST_BEAT = 3'b101,
        S_DATA_OUT  = 3'b111
    } states;
    
    //inputsignals
    input   logic            clock;
    input   logic            reset;
    input   logic   [255:0]  a_data_i;
    input   logic            a_valid_i;
    input   logic            b_ready_i;
    
    //outout signals
    output  logic   [31:0]   b_data_o;
    output  logic            b_valid_o;
    output  logic            a_ready_o;
   
    states           state;
    logic   [255:0]  add_accumulator;
    logic   [255:0]  max_accumulator;
    logic   [7:0  ]  op_accumulator;
    logic   [5:0  ]  beat_count;
    logic   [31:0]   slice=0; 
    
    always_ff@(posedge clock) begin
        if (reset) begin
            state <= IDLE;
            beat_count <= 0;
            add_accumulator <= 256'b0;
            max_accumulator <= 256'b0;
            op_accumulator  <= 8'b0;
        end 
        else begin
            case(state)        
                IDLE : begin
                    if (a_ready_o && a_valid_i && beat_count == 0) begin
                        state <= S_FIRST_BEAT;
                        beat_count <= beat_count + 1;
                        add_accumulator <= 256'b0;
                        max_accumulator <= 256'b0;
                        op_accumulator  <= 8'b0;
                    end
                end
                S_FIRST_BEAT : begin
                    if (a_ready_o && a_valid_i && beat_count == 1) begin 
                        state <= S_DATA;
                        beat_count <= beat_count + 1;
                        op_accumulator <= a_data_i[167:160];                   
                        add_accumulator <= add_accumulator + a_data_i[31:0]+ a_data_i[63:32]+a_data_i[95:64]+a_data_i[127:96] +a_data_i[159:128];
                        for (int i = 0; i < 5; i++) begin
                            slice = a_data_i[i * 32 +: 32];
                                if (slice > max_accumulator) begin
                                    max_accumulator <= slice;
                                end
                        end
                    end
                end  
                S_DATA : begin
                    if (a_valid_i && beat_count > 1 ) begin
                        state <= S_DATA;
                        beat_count <= beat_count + 1;
                        add_accumulator <= add_accumulator + a_data_i [31:0] + a_data_i [63:32] + a_data_i [95:64] + a_data_i [127:96] + a_data_i [159:128] + a_data_i [191:160] + a_data_i [223:192] + a_data_i [255:224];
                        for (int i = 0; i < 8; i++) begin
                            slice = a_data_i[i * 32 +: 32];
                            if (slice > max_accumulator) begin
                                max_accumulator <= slice;
                            end
                            else if (a_ready_o && a_valid_i && beat_count == 61) begin 
                                state <=  S_LAST_BEAT;
                            end
                        end
                    end
                end
                S_LAST_BEAT : begin                
                    if (beat_count == 62 && a_ready_o && a_valid_i ) begin
                        state <= S_DATA_OUT;
                        beat_count <= beat_count + 1;
                        add_accumulator <= add_accumulator +a_data_i[159:128] + a_data_i[191:160] + a_data_i[223:192] + a_data_i[255:224];
                        for (int i = 0; i < 8; i++) begin
                            slice = a_data_i[i * 32 +: 32];
                            if (slice > max_accumulator) begin
                                max_accumulator <= slice;
                            end
                        end
                    end
                end
                S_DATA_OUT : begin
                    if (beat_count == 63) begin
                        state <= IDLE;
                        beat_count <= 0;
                    end
                end
            endcase
        end
    end
    
    always @(*) begin 
        case (state)
            S_DATA_OUT : begin
                if (op_accumulator == 8'b1) begin
                b_data_o = add_accumulator;
                a_ready_o = 1'b0;
                b_valid_o = 1'b1;
            end else if (op_accumulator == 8'b10) begin
                b_data_o = max_accumulator;
                a_ready_o = 1'b0;
                b_valid_o = 1'b1;
            end
            end
            default: begin
                b_data_o = 1'b0;
                a_ready_o = 1'b1;
                b_valid_o = 1'b0;
            end
        endcase
    end
endmodule




