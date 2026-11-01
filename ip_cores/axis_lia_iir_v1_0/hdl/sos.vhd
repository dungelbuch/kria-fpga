---------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Create Date: 2024-08-01
-- Module Name: axis_lia_iir
-- Project Name: lia_impl
-- Target Devices: Red Pitaya
-- Tool Versions:
-- Description: Second-order-section for IIR filter (biquads), using AXI Stream
-- interface. Tready signal is not used, only tvalid signal is used to drive the
-- module. Overflow protection is not implemented yet.

---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sos is
    generic (
        -- IIR filter parameters
        iir_coeff_width      : integer := 64;
        iir_coeff_frac_width : integer := 60;
        -- AXIS interface parameters
        axis_tdata_width     : integer := 32
        );
    port (
        -- Clock and reset
        aclk  : in std_logic;
        reset : in std_logic;

        -- Filter coefficients
        b0 : in std_logic_vector(iir_coeff_width-1 downto 0);
        b1 : in std_logic_vector(iir_coeff_width-1 downto 0);
        b2 : in std_logic_vector(iir_coeff_width-1 downto 0);
        a1 : in std_logic_vector(iir_coeff_width-1 downto 0);
        a2 : in std_logic_vector(iir_coeff_width-1 downto 0);

        -- AXI Stream slave interface
        s_axis_tdata  : in std_logic_vector(axis_tdata_width-1 downto 0);
        s_axis_tvalid : in std_logic;

        -- AXI Stream master interface
        m_tdata  : out std_logic_vector(axis_tdata_width-1 downto 0);
        m_tvalid : out std_logic

        );
end entity sos;

architecture filt of sos is

    component multiplier
        port (
            CLK  : in  std_logic;
            A    : in  std_logic_vector(iir_coeff_width-1 downto 0);
            B    : in  std_logic_vector(axis_tdata_width-1 downto 0);
            CE   : in  std_logic;
            SCLR : in  std_logic;
            P    : out std_logic_vector(axis_tdata_width+iir_coeff_width-1 downto 0)
            );
    end component;

    -- Shift register for delay elements
    type input_shift_reg is array(0 to 2) of signed(axis_tdata_width-1 downto 0);
    type output_shift_reg is array(0 to 1) of signed(axis_tdata_width-1 downto 0);
    signal input  : input_shift_reg;
    signal output : output_shift_reg;

    -- Multiplication intermediate results
    signal mult_b0, mult_b1, mult_b2, mult_a1, mult_a2 : std_logic_vector(axis_tdata_width + iir_coeff_width - 1 downto 0);

    -- Accumulator intermediate results
    constant guard_bits_acc_b : integer := 2;
    constant guard_bits_acc_a : integer := 1;
    constant guard_bits       : integer := 3;
    signal res_acc_b          : signed((axis_tdata_width + iir_coeff_width + guard_bits_acc_b) - 1 downto 0);
    signal res_acc_a          : signed((axis_tdata_width + iir_coeff_width + guard_bits_acc_a) - 1 downto 0);
    signal res_int            : signed((axis_tdata_width + iir_coeff_width + guard_bits) - 1 downto 0);
    signal res_out            : signed(axis_tdata_width-1 downto 0);

    -- Shift register for tvalid signal
    constant filt_delay         : integer                                 := 5;
    signal tvalid_shift_reg_out : std_logic                               := '0';
    signal tvalid_shift_reg     : std_logic_vector(filt_delay-1 downto 0) := (others => '0');

begin

-- instantiate multipliers:
    MULT_COEFF_B0 : component multiplier
        port map(
            CLK  => aclk,
            A    => std_logic_vector(b0),
            B    => std_logic_vector(input(0)),
            CE   => '1',
            SCLR => not(reset),
            P    => mult_b0
            );
    MULT_COEFF_B1 : component multiplier
        port map(
            CLK  => aclk,
            A    => std_logic_vector(b1),
            B    => std_logic_vector(input(1)),
            CE   => '1',
            SCLR => not(reset),
            P    => mult_b1
            );
    MULT_COEFF_B2 : component multiplier
        port map(
            CLK  => aclk,
            A    => std_logic_vector(b2),
            B    => std_logic_vector(input(2)),
            CE   => '1',
            SCLR => not(reset),
            P    => mult_b2
            );
    MULT_COEFF_A1 : component multiplier
        port map(
            CLK  => aclk,
            A    => std_logic_vector(a1),
            B    => std_logic_vector(output(0)),
            CE   => '1',
            SCLR => not(reset),
            P    => mult_a1
            );
    MULT_COEFF_A2 : component multiplier
        port map(
            CLK  => aclk,
            A    => std_logic_vector(a2),
            B    => std_logic_vector(output(1)),
            CE   => '1',
            SCLR => not(reset),
            P    => mult_a2
            );

    DELAY_REG : process(aclk, reset)
    begin
        if reset = '0' then
            input(0)  <= (others => '0');
            input(1)  <= (others => '0');
            input(2)  <= (others => '0');
            output(0) <= (others => '0');
            output(1) <= (others => '0');
        elsif rising_edge(aclk) then
            if s_axis_tvalid = '1' then
                input(0)  <= signed(s_axis_tdata);
                input(1)  <= input(0);
                input(2)  <= input(1);
                output(0) <= res_out;
                output(1) <= output(0);
            end if;
        end if;
    end process;

    --MULT : process(aclk)
    --begin
    --    if rising_edge(aclk) then
    --        if reset = '0' then
    --            mult_b0 <= (others => '0');
    --            mult_b1 <= (others => '0');
    --            mult_b2 <= (others => '0');
    --            mult_a1 <= (others => '0');
    --            mult_a2 <= (others => '0');
    --        else
    --            mult_b0 <= signed(b0) * input(0);
    --            mult_b1 <= signed(b1) * input(1);
    --            mult_b2 <= signed(b2) * input(2);
    --            mult_a1 <= signed(a1) * output(0);
    --            mult_a2 <= signed(a2) * output(1);
    --        end if;
    --    end if;
    --end process;

    ----------------------------------------------------------------------------
    -- Signal assignment
    ----------------------------------------------------------------------------
    TVALID : process(aclk)
    begin
        if rising_edge(aclk) then
            if reset = '0' then
                tvalid_shift_reg_out <= '0';
            else
                tvalid_shift_reg     <= tvalid_shift_reg(tvalid_shift_reg'high-1 downto 0) & s_axis_tvalid;
                tvalid_shift_reg_out <= tvalid_shift_reg(tvalid_shift_reg'high);

            end if;
        end if;
    end process;

    -- Registered intermediate result to avoid fanout timing issues
    RES_REGS : process(aclk)
    begin
        if rising_edge(aclk) then
            res_acc_b <= resize(signed(mult_b0) + signed(mult_b1) + signed(mult_b2), res_acc_b'length);
            res_acc_a <= resize(signed(mult_a1) + signed(mult_a2), res_acc_a'length);
            res_int   <= resize(res_acc_b - res_acc_a, res_int'length);
            res_out   <= resize(shift_right(res_int, iir_coeff_frac_width), res_out'length);
        end if;
    end process;

    -- Output data and valid signal
    m_tdata  <= std_logic_vector(res_out);
    m_tvalid <= tvalid_shift_reg_out;

    


end filt;
