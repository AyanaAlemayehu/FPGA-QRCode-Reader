`timescale 1ns / 1ps
`default_nettype none

// QR CODE version 1 is at most 19 data blocks (assuming error correction level L (the worst case))

module decode
    #(parameter MOD_SIZE = 21)
    (
        input wire [440:0] qr_unmasked,
        output logic [3:0] data_type,
        output logic [7:0] data_length,
        output logic [7:0] bytes [18:0]
    );
    // uart sends LSB first

    always_comb begin
        data_type = ~{qr_unmasked[0+20*MOD_SIZE], qr_unmasked[0+19*MOD_SIZE], qr_unmasked[1+20*MOD_SIZE], qr_unmasked[1+19*MOD_SIZE]};
        data_length = ~{qr_unmasked[2+20*MOD_SIZE], qr_unmasked[2+19*MOD_SIZE], qr_unmasked[3+20*MOD_SIZE], qr_unmasked[3+19*MOD_SIZE], qr_unmasked[4+20*MOD_SIZE], qr_unmasked[4+19*MOD_SIZE], qr_unmasked[5+20*MOD_SIZE], qr_unmasked[5+19*MOD_SIZE]};
        bytes[0] = ~{qr_unmasked[6+20*MOD_SIZE], qr_unmasked[6+19*MOD_SIZE], qr_unmasked[7+20*MOD_SIZE], qr_unmasked[7+19*MOD_SIZE], qr_unmasked[8+20*MOD_SIZE], qr_unmasked[8+19*MOD_SIZE], qr_unmasked[9+20*MOD_SIZE], qr_unmasked[9+19*MOD_SIZE]};
        bytes[1] = ~{qr_unmasked[10+20*MOD_SIZE], qr_unmasked[10+19*MOD_SIZE], qr_unmasked[11+20*MOD_SIZE], qr_unmasked[11+19*MOD_SIZE], qr_unmasked[11+18*MOD_SIZE], qr_unmasked[11+17*MOD_SIZE], qr_unmasked[10+18*MOD_SIZE], qr_unmasked[10+17*MOD_SIZE]};
        bytes[2] = ~{qr_unmasked[9+18*MOD_SIZE], qr_unmasked[9+17*MOD_SIZE], qr_unmasked[8+18*MOD_SIZE], qr_unmasked[8+17*MOD_SIZE], qr_unmasked[7+18*MOD_SIZE], qr_unmasked[7+17*MOD_SIZE], qr_unmasked[6+18*MOD_SIZE], qr_unmasked[6+17*MOD_SIZE]};
        bytes[3] = ~{qr_unmasked[5+18*MOD_SIZE], qr_unmasked[5+17*MOD_SIZE], qr_unmasked[4+18*MOD_SIZE], qr_unmasked[4+17*MOD_SIZE], qr_unmasked[3+18*MOD_SIZE], qr_unmasked[3+17*MOD_SIZE], qr_unmasked[2+18*MOD_SIZE], qr_unmasked[2+17*MOD_SIZE]};
        bytes[4] = ~{qr_unmasked[1+18*MOD_SIZE], qr_unmasked[1+17*MOD_SIZE], qr_unmasked[0+18*MOD_SIZE], qr_unmasked[0+17*MOD_SIZE], qr_unmasked[0+16*MOD_SIZE], qr_unmasked[0+15*MOD_SIZE], qr_unmasked[1+16*MOD_SIZE], qr_unmasked[1+15*MOD_SIZE]};
        bytes[5] = ~{qr_unmasked[2+16*MOD_SIZE], qr_unmasked[2+15*MOD_SIZE], qr_unmasked[3+16*MOD_SIZE], qr_unmasked[3+15*MOD_SIZE], qr_unmasked[4+16*MOD_SIZE], qr_unmasked[4+15*MOD_SIZE], qr_unmasked[5+16*MOD_SIZE], qr_unmasked[5+15*MOD_SIZE]};
        bytes[6] = ~{qr_unmasked[6+16*MOD_SIZE], qr_unmasked[6+15*MOD_SIZE], qr_unmasked[7+16*MOD_SIZE], qr_unmasked[7+15*MOD_SIZE], qr_unmasked[8+16*MOD_SIZE], qr_unmasked[8+15*MOD_SIZE], qr_unmasked[9+16*MOD_SIZE], qr_unmasked[9+15*MOD_SIZE]};
        bytes[7] = ~{qr_unmasked[10+16*MOD_SIZE], qr_unmasked[10+15*MOD_SIZE], qr_unmasked[11+16*MOD_SIZE], qr_unmasked[11+15*MOD_SIZE], qr_unmasked[11+14*MOD_SIZE], qr_unmasked[11+13*MOD_SIZE], qr_unmasked[10+14*MOD_SIZE], qr_unmasked[10+13*MOD_SIZE]};
        bytes[8] = ~{qr_unmasked[9+14*MOD_SIZE], qr_unmasked[9+13*MOD_SIZE], qr_unmasked[8+14*MOD_SIZE], qr_unmasked[8+13*MOD_SIZE], qr_unmasked[7+14*MOD_SIZE], qr_unmasked[7+13*MOD_SIZE], qr_unmasked[6+14*MOD_SIZE], qr_unmasked[6+13*MOD_SIZE]};
        bytes[9] = ~{qr_unmasked[5+14*MOD_SIZE], qr_unmasked[5+13*MOD_SIZE], qr_unmasked[4+14*MOD_SIZE], qr_unmasked[4+13*MOD_SIZE], qr_unmasked[3+14*MOD_SIZE], qr_unmasked[3+13*MOD_SIZE], qr_unmasked[2+14*MOD_SIZE], qr_unmasked[2+13*MOD_SIZE]};
        bytes[10] = ~{qr_unmasked[1+14*MOD_SIZE], qr_unmasked[1+13*MOD_SIZE], qr_unmasked[0+14*MOD_SIZE], qr_unmasked[0+13*MOD_SIZE], qr_unmasked[0+12*MOD_SIZE], qr_unmasked[0+11*MOD_SIZE], qr_unmasked[1+12*MOD_SIZE], qr_unmasked[1+11*MOD_SIZE]};
        bytes[11] = ~{qr_unmasked[2+12*MOD_SIZE], qr_unmasked[2+11*MOD_SIZE], qr_unmasked[3+12*MOD_SIZE], qr_unmasked[3+11*MOD_SIZE], qr_unmasked[4+12*MOD_SIZE], qr_unmasked[4+11*MOD_SIZE], qr_unmasked[5+12*MOD_SIZE], qr_unmasked[5+11*MOD_SIZE]};
        bytes[12] = ~{qr_unmasked[6+12*MOD_SIZE], qr_unmasked[6+11*MOD_SIZE], qr_unmasked[7+12*MOD_SIZE], qr_unmasked[7+11*MOD_SIZE], qr_unmasked[8+12*MOD_SIZE], qr_unmasked[8+11*MOD_SIZE], qr_unmasked[9+12*MOD_SIZE], qr_unmasked[9+11*MOD_SIZE]};
        bytes[13] = ~{qr_unmasked[10+12*MOD_SIZE], qr_unmasked[10+11*MOD_SIZE], qr_unmasked[11+12*MOD_SIZE], qr_unmasked[11+11*MOD_SIZE], qr_unmasked[12+12*MOD_SIZE], qr_unmasked[12+11*MOD_SIZE], qr_unmasked[13+12*MOD_SIZE], qr_unmasked[13+11*MOD_SIZE]};
        bytes[14] = ~{qr_unmasked[10+12*MOD_SIZE], qr_unmasked[10+11*MOD_SIZE], qr_unmasked[11+12*MOD_SIZE], qr_unmasked[11+11*MOD_SIZE], qr_unmasked[12+12*MOD_SIZE], qr_unmasked[12+11*MOD_SIZE], qr_unmasked[13+12*MOD_SIZE], qr_unmasked[13+11*MOD_SIZE]};
        bytes[15] = ~{qr_unmasked[15+12*MOD_SIZE], qr_unmasked[15+11*MOD_SIZE], qr_unmasked[16+12*MOD_SIZE], qr_unmasked[16+11*MOD_SIZE], qr_unmasked[17+12*MOD_SIZE], qr_unmasked[17+11*MOD_SIZE], qr_unmasked[18+12*MOD_SIZE], qr_unmasked[18+11*MOD_SIZE]};
        bytes[16] = ~{qr_unmasked[19+12*MOD_SIZE], qr_unmasked[19+11*MOD_SIZE], qr_unmasked[20+12*MOD_SIZE], qr_unmasked[20+11*MOD_SIZE], qr_unmasked[20+10*MOD_SIZE], qr_unmasked[20+9*MOD_SIZE], qr_unmasked[19+10*MOD_SIZE], qr_unmasked[19+9*MOD_SIZE]};
        bytes[17] = ~{qr_unmasked[18+10*MOD_SIZE], qr_unmasked[18+9*MOD_SIZE], qr_unmasked[17+10*MOD_SIZE], qr_unmasked[17+9*MOD_SIZE], qr_unmasked[16+10*MOD_SIZE], qr_unmasked[16+9*MOD_SIZE], qr_unmasked[15+10*MOD_SIZE], qr_unmasked[15+9*MOD_SIZE]};
        bytes[18] = ~{qr_unmasked[13+10*MOD_SIZE], qr_unmasked[13+9*MOD_SIZE], qr_unmasked[12+10*MOD_SIZE], qr_unmasked[12+9*MOD_SIZE], qr_unmasked[11+10*MOD_SIZE], qr_unmasked[11+9*MOD_SIZE], qr_unmasked[10+10*MOD_SIZE], qr_unmasked[10+9*MOD_SIZE]};
    end

endmodule
