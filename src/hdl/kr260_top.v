`timescale 1 ns / 1 ps

// Top level of the KR260 design: wraps the block design and connects it to the board pins.
// Logic outside the block design and further board I/O (see src/constraints/) go here.
module kr260_top (
    // User LEDs UF1, UF2 on the carrier
    output wire [1:0] led_o
);

  kr260_ps kr260_ps_i (
      .led_o(led_o)
  );

endmodule
