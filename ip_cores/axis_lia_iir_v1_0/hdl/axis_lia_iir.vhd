---------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Create Date: 2024-07-10
-- Module Name: axis_lia_fir
-- Project Name: lia_impl
-- Target Devices: Red Pitaya
-- Tool Versions:
-- Description:

---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_lia_iir_filter is
    generic (
        -- General parameters
        reset_width          : integer;
        reset_index          : integer;
        -- IIR filter parameters
        iir_coeff_width      : integer;
        iir_coeff_frac_width : integer;
        iir_sos_stages       : integer := 1;
        -- AXI slave interface parameters
        s_axi_data_width     : integer := 32;
        s_axi_addr_width     : integer := 8;
        -- AXIS interface parameters
        s_axis_tdata_width   : integer := 32;
        m_axis_tdata_width   : integer := 32
        );
    port (
        -- Clock and reset
        aclk : in std_logic;
        rstn : in std_logic_vector(reset_width - 1 downto 0);

        -- AXI Slave interface
        s_axi_aresetn     : in  std_logic;
        s_axi_iir_awaddr  : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_iir_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_iir_awvalid : in  std_logic;
        s_axi_iir_awready : out std_logic;
        s_axi_iir_wdata   : in  std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_iir_wstrb   : in  std_logic_vector((s_axi_data_width/8) - 1 downto 0);
        s_axi_iir_wvalid  : in  std_logic;
        s_axi_iir_wready  : out std_logic;
        s_axi_iir_bresp   : out std_logic_vector(1 downto 0);
        s_axi_iir_bvalid  : out std_logic;
        s_axi_iir_bready  : in  std_logic;
        s_axi_iir_araddr  : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_iir_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_iir_arvalid : in  std_logic;
        s_axi_iir_arready : out std_logic;
        s_axi_iir_rdata   : out std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_iir_rresp   : out std_logic_vector(1 downto 0);
        s_axi_iir_rvalid  : out std_logic;
        s_axi_iir_rready  : in  std_logic;

        -- AXIS slave interface
        s_axis_i_tready : out std_logic;
        s_axis_i_tvalid : in  std_logic;
        s_axis_i_tdata  : in  std_logic_vector(s_axis_tdata_width - 1 downto 0);
        s_axis_q_tready : out std_logic;
        s_axis_q_tvalid : in  std_logic;
        s_axis_q_tdata  : in  std_logic_vector(s_axis_tdata_width - 1 downto 0);

        -- AXIS master interface
        m_axis_tready : in  std_logic;
        m_axis_tvalid : out std_logic;
        m_axis_tdata  : out std_logic_vector(m_axis_tdata_width - 1 downto 0)
        );
end entity axis_lia_iir_filter;

architecture Behavioral of axis_lia_iir_filter is

    alias reset : std_logic is rstn(reset_index);

    -- Output mux for the SOS stages
    signal sos_mux    : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal sos_stages : integer := 1;

    -- Output buffer and valid signal and state machine for outputing data
    type state_type is (IDLE, SEND_I, SEND_Q);
    signal state          : state_type                                        := IDLE;
    signal filt_out_valid : std_logic                                         := '0';
    signal i_out          : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');
    signal q_out          : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');
    signal i_out_buffer   : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');
    signal q_out_buffer   : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');

    -- tdata and tvalid array the sos stages
    type tdata_array is array(0 to iir_sos_stages-1) of std_logic_vector(s_axis_tdata_width-1 downto 0);
    type tvalid_array is array(0 to iir_sos_stages-1) of std_logic;
    -- tdata and tvalid registers for In-phase sos stages
    signal i_tdata_in   : tdata_array  := (others => (others => '0'));
    signal i_tdata_out  : tdata_array  := (others => (others => '0'));
    signal i_tvalid_in  : tvalid_array := (others => '0');
    signal i_tvalid_out : tvalid_array := (others => '0');
    -- tdata  and tvalid registers for Quadrature sos stages
    signal q_tdata_in   : tdata_array  := (others => (others => '0'));
    signal q_tdata_out  : tdata_array  := (others => (others => '0'));
    signal q_tvalid_in  : tvalid_array := (others => '0');
    signal q_tvalid_out : tvalid_array := (others => '0');

    -- Filter coefficients array
    constant coeff_per_sos : integer := 5;
    type coeff_array is array (1 to iir_sos_stages * coeff_per_sos) of std_logic_vector(s_axi_data_width - 1 downto 0);
    signal coeffs          : coeff_array;
    signal I_coeffs        : coeff_array;
    signal Q_coeffs        : coeff_array;
begin

    ----------------------------------------------------------------------------
    -- Module instantiation
    ----------------------------------------------------------------------------
    -- AXI Lite slave registers
    REGS : entity work.axis_lia_iir_slave
        generic map(
            c_s_axi_data_width => s_axi_data_width,
            c_s_axi_addr_width => s_axi_addr_width
            )
        port map (
            -- Register input/output signals
            sos_mux => sos_mux,
            -- SOS_0 coefficients
            b0_0    => coeffs(1),
            b0_1    => coeffs(2),
            b0_2    => coeffs(3),
            a0_1    => coeffs(4),
            a0_2    => coeffs(5),
            -- SOS_1 coefficients
            b1_0    => coeffs(6),
            b1_1    => coeffs(7),
            b1_2    => coeffs(8),
            a1_1    => coeffs(9),
            a1_2    => coeffs(10),
            -- SOS_2 coefficients
            b2_0    => coeffs(11),
            b2_1    => coeffs(12),
            b2_2    => coeffs(13),
            a2_1    => coeffs(14),
            a2_2    => coeffs(15),
            -- SOS_3 coefficients
            b3_0    => open,
            b3_1    => open,
            b3_2    => open,
            a3_1    => open,
            a3_2    => open,
            -- SOS_4 coefficients
            b4_0    => open,
            b4_1    => open,
            b4_2    => open,
            a4_1    => open,
            a4_2    => open,
            -- SOS_5 coefficients
            b5_0    => open,
            b5_1    => open,
            b5_2    => open,
            a5_1    => open,
            a5_2    => open,

            -- AXI Lite signals
            s_axi_aclk    => aclk,
            s_axi_aresetn => s_axi_aresetn,
            s_axi_awaddr  => s_axi_iir_awaddr,
            s_axi_awprot  => s_axi_iir_awprot,
            s_axi_awvalid => s_axi_iir_awvalid,
            s_axi_awready => s_axi_iir_awready,
            s_axi_wdata   => s_axi_iir_wdata,
            s_axi_wstrb   => s_axi_iir_wstrb,
            s_axi_wvalid  => s_axi_iir_wvalid,
            s_axi_wready  => s_axi_iir_wready,
            s_axi_bresp   => s_axi_iir_bresp,
            s_axi_bvalid  => s_axi_iir_bvalid,
            s_axi_bready  => s_axi_iir_bready,
            s_axi_araddr  => s_axi_iir_araddr,
            s_axi_arprot  => s_axi_iir_arprot,
            s_axi_arvalid => s_axi_iir_arvalid,
            s_axi_arready => s_axi_iir_arready,
            s_axi_rdata   => s_axi_iir_rdata,
            s_axi_rresp   => s_axi_iir_rresp,
            s_axi_rvalid  => s_axi_iir_rvalid,
            s_axi_rready  => s_axi_iir_rready
            );


    -- In-Phase sos filter stages
    GEN_I_FILT : for i in 0 to (iir_sos_stages - 1) generate
        I_SOS : entity work.sos
            generic map(
                iir_coeff_width      => iir_coeff_width,
                iir_coeff_frac_width => iir_coeff_frac_width,
                axis_tdata_width     => s_axis_tdata_width
                )
            port map (
                aclk          => aclk,
                reset         => reset,
                b0            => I_coeffs((i * coeff_per_sos) + 1)(iir_coeff_width - 1 downto 0),
                b1            => I_coeffs((i * coeff_per_sos) + 2)(iir_coeff_width - 1 downto 0),
                b2            => I_coeffs((i * coeff_per_sos) + 3)(iir_coeff_width - 1 downto 0),
                a1            => I_coeffs((i * coeff_per_sos) + 4)(iir_coeff_width - 1 downto 0),
                a2            => I_coeffs((i * coeff_per_sos) + 5)(iir_coeff_width - 1 downto 0),
                s_axis_tdata  => i_tdata_in(i),
                s_axis_tvalid => i_tvalid_in(i),
                m_tdata       => i_tdata_out(i),
                m_tvalid      => i_tvalid_out(i)
                );
    end generate GEN_I_FILT;

    -- Quadrature sos filter stages
    GEN_Q_FILT : for i in 0 to (iir_sos_stages - 1) generate
        Q_SOS : entity work.sos
            generic map(
                iir_coeff_width      => iir_coeff_width,
                iir_coeff_frac_width => iir_coeff_frac_width,
                axis_tdata_width     => s_axis_tdata_width
                )
            port map (
                aclk          => aclk,
                reset         => reset,
                b0            => Q_coeffs((i * coeff_per_sos) + 1)(iir_coeff_width - 1 downto 0),
                b1            => Q_coeffs((i * coeff_per_sos) + 2)(iir_coeff_width - 1 downto 0),
                b2            => Q_coeffs((i * coeff_per_sos) + 3)(iir_coeff_width - 1 downto 0),
                a1            => Q_coeffs((i * coeff_per_sos) + 4)(iir_coeff_width - 1 downto 0),
                a2            => Q_coeffs((i * coeff_per_sos) + 5)(iir_coeff_width - 1 downto 0),
                s_axis_tdata  => q_tdata_in(i),
                s_axis_tvalid => q_tvalid_in(i),
                m_tdata       => q_tdata_out(i),
                m_tvalid      => q_tvalid_out(i)
                );
    end generate GEN_Q_FILT;

    -- Registered data & valid input/output signals for sos stages
    REG_SOS_IO : process(aclk)
    begin
        if rising_edge(aclk) then
            -- In-phase data and valid registers for sos stages
            i_tdata_in(0)  <= s_axis_i_tdata;
            i_tdata_in(1)  <= i_tdata_out(0);
            i_tdata_in(2)  <= i_tdata_out(1);
            i_tvalid_in(0) <= s_axis_i_tvalid;
            i_tvalid_in(1) <= i_tvalid_out(0);
            i_tvalid_in(2) <= i_tvalid_out(1);

            -- Quadrature data and valid registers for sos stages
            q_tdata_in(0)  <= s_axis_q_tdata;
            q_tdata_in(1)  <= q_tdata_out(0);
            q_tdata_in(2)  <= q_tdata_out(1);
            q_tvalid_in(0) <= s_axis_q_tvalid;
            q_tvalid_in(1) <= q_tvalid_out(0);
            q_tvalid_in(2) <= q_tvalid_out(1);
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Signal assignments
    ----------------------------------------------------------------------------

    -- Additional registers to reduce signal fanout and improve timing closure
    process(aclk)
    begin
        if rising_edge(aclk) then
            I_coeffs <= coeffs;
            Q_coeffs <= coeffs;
        end if;
    end process;

    -- Output data and valid signal state machine
    OUTPUT : process(aclk)
    begin
        if rising_edge(aclk) then
            if reset = '0' then
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                i_out_buffer  <= (others => '0');
                q_out_buffer  <= (others => '0');
                state         <= IDLE;
            else
                -- Default assignments to prevent latches
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                i_out_buffer  <= i_out_buffer;
                q_out_buffer  <= q_out_buffer;
                state         <= state;

                case state is
                    -- Wait until the filter has valid output data
                    when IDLE =>
                        i_out_buffer <= i_out_buffer;
                        q_out_buffer <= q_out_buffer;
                        state        <= state;
                        if filt_out_valid = '1' then
                            i_out_buffer <= i_out;
                            q_out_buffer <= q_out;
                            state        <= SEND_I;
                        end if;

                    -- Send filtered in-phase data
                    when SEND_I =>
                        m_axis_tdata  <= i_out_buffer;
                        m_axis_tvalid <= '1';
                        state         <= SEND_Q;

                    -- Send filtered quadrature data
                    when SEND_Q =>
                        m_axis_tdata  <= q_out_buffer;
                        m_axis_tvalid <= '1';
                        state         <= IDLE;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    
    
    -- Just routing from master to slave, only tvalid is used to control the data flow
    s_axis_i_tready <= m_axis_tready;
    s_axis_q_tready <= m_axis_tready;
    
    -- Assign the final output to the AXI Stream output interface
    sos_stages <= to_integer(unsigned(sos_mux) - 1);
    i_out      <= i_tdata_out(sos_stages);
    q_out      <= q_tdata_out(sos_stages);
    filt_out_valid <= i_tvalid_out(sos_stages) and q_tvalid_out(sos_stages);

end Behavioral;
