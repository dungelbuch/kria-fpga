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

-- Import IEEE standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_lia_fir is
    generic (
        -- General parameters
        reset_width         : integer;
        reset_index         : integer;
        -- AXI slave interface parameters
        s_axi_data_width    : integer := 32;
        s_axi_addr_width    : integer := 6;
        -- AXIS interface parameters
        s_axis_tdata_width  : integer := 32;
        m_axis_tdata_width  : integer := 32;
        -- FIR filter parameters
        fir_coeff_width     : integer := 25;
        fir_coeff_frac_bits : integer := 24;
        fir_out_width       : integer := 64  -- increase in 8 bit steps
        );
    port (
        aclk              : in  std_logic;
        rstn              : in  std_logic_vector(reset_width - 1 downto 0);
        -- AXI Slave interface
        s_axi_aresetn     : in  std_logic;
        s_axi_fir_awaddr  : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_fir_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_fir_awvalid : in  std_logic;
        s_axi_fir_awready : out std_logic;
        s_axi_fir_wdata   : in  std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_fir_wstrb   : in  std_logic_vector((s_axi_data_width/8) - 1 downto 0);
        s_axi_fir_wvalid  : in  std_logic;
        s_axi_fir_wready  : out std_logic;
        s_axi_fir_bresp   : out std_logic_vector(1 downto 0);
        s_axi_fir_bvalid  : out std_logic;
        s_axi_fir_bready  : in  std_logic;
        s_axi_fir_araddr  : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_fir_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_fir_arvalid : in  std_logic;
        s_axi_fir_arready : out std_logic;
        s_axi_fir_rdata   : out std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_fir_rresp   : out std_logic_vector(1 downto 0);
        s_axi_fir_rvalid  : out std_logic;
        s_axi_fir_rready  : in  std_logic;

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

end axis_lia_fir;

architecture behavioral of axis_lia_fir is
    -- Control signals
    signal rst                 : std_logic := '1';
    signal rst_counter         : integer   := 0;
    constant rst_hold_duration : integer   := 3;

    -- FIR filter output signals
    -- filt_out_tready not needed, since no backpressure from receiver expected
    signal i_filt_out_tdata  : std_logic_vector(fir_out_width - 1 downto 0) := (others => '0');
    signal i_filt_out_tvalid : std_logic                                    := '0';
    signal q_filt_out_tdata  : std_logic_vector(fir_out_width - 1 downto 0) := (others => '0');
    signal q_filt_out_tvalid : std_logic                                    := '0';
    signal filt_out_valid    : std_logic                                    := '0';

    -- Signals for state machine to control data output
    type state_type is (IDLE, SEND_I, SEND_Q);
    signal state        : state_type                                        := IDLE;
    signal i_filt       : std_logic_vector(m_axis_tdata_width - 1 downto 0) := (others => '0');
    signal q_filt       : std_logic_vector(m_axis_tdata_width - 1 downto 0) := (others => '0');
    signal i_out_buffer : std_logic_vector(m_axis_tdata_width - 1 downto 0) := (others => '0');
    signal q_out_buffer : std_logic_vector(m_axis_tdata_width - 1 downto 0) := (others => '0');

begin
    ----------------------------------------------------------------------------
    -- Instantiation of AXI slave register interface
    ----------------------------------------------------------------------------
    FIR_I : entity work.lia_fir
        port map(
            aclk               => aclk,
            aresetn            => rst,
            -- AXIS Slave Interface
            s_axis_data_tdata  => s_axis_i_tdata,
            s_axis_data_tready => s_axis_i_tready,
            s_axis_data_tvalid => s_axis_i_tvalid,
            -- AXIS Master Interface
            m_axis_data_tdata  => i_filt_out_tdata,
            m_axis_data_tvalid => i_filt_out_tvalid
            );

    FIR_Q : entity work.lia_fir
        port map(
            aclk               => aclk,
            aresetn            => rst,
            -- AXIS Slave Interface
            s_axis_data_tdata  => s_axis_q_tdata,
            s_axis_data_tready => s_axis_q_tready,
            s_axis_data_tvalid => s_axis_q_tvalid,
            -- AXIS Master Interface
            m_axis_data_tdata  => q_filt_out_tdata,
            m_axis_data_tvalid => q_filt_out_tvalid
            );

    ----------------------------------------------------------------------------
    -- Processes
    ----------------------------------------------------------------------------
    RESET : process (aclk, rst)
    begin
        -- The reset signal needs to be hold for a minimum of 2 clock cycles for
        -- the FIR filter to reset properly,
        if rising_edge(aclk) then
            if rstn(reset_index) = '0' then
                rst         <= '0';
                rst_counter <= 0;
            elsif rst_counter < rst_hold_duration then
                rst         <= '0';
                rst_counter <= rst_counter + 1;
            else
                rst <= '1';
            end if;
        end if;
    end process;

    MAIN : process (aclk)
    begin
        if rising_edge(aclk) then

            if (rstn(reset_index) = '0') then
                i_out_buffer  <= (others => '0');
                q_out_buffer  <= (others => '0');
                m_axis_tdata  <= (others => '0');
                m_axis_tvalid <= '0';
                state         <= IDLE;
            else
                -- Default assignments to prevent latches
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                i_out_buffer  <= i_out_buffer;
                q_out_buffer  <= q_out_buffer;
                state         <= state;

                case state is
                    -- Wait until the FIR filter has valid output data
                    when IDLE =>
                        m_axis_tvalid <= '0';
                        m_axis_tdata  <= (others => '0');
                        if filt_out_valid = '1' then
                            i_out_buffer <= i_filt;
                            q_out_buffer <= q_filt;
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

    filt_out_valid <= i_filt_out_tvalid and q_filt_out_tvalid;

    -- See IP's documentation for why this slicing is necessary
    i_filt <= i_filt_out_tdata((fir_coeff_frac_bits - 1) + m_axis_tdata_width downto fir_coeff_frac_bits);
    q_filt <= q_filt_out_tdata((fir_coeff_frac_bits - 1) + m_axis_tdata_width downto fir_coeff_frac_bits);

end behavioral;
