---------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Module Name: axis_dummy_data_generator.vhd
-- Project Name: Dummy Data Generator
-- Target Devices: Red Pitaya
-- Tool Versions: Vivado 2020.1
-- Description:
--      This module is supposed to generate dummy data (counter) and send it via
--      AXIS to the ram-writer module to write the data into RP RAM
---------------------------------------------------------------------------------

-- Import standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_dummy_data_generator is
    generic (
        -- General parameters
        reset_index              : integer;
        reset_width              : integer;
        int_data_width           : integer := 32;
        -- BRAM parameters
        int_bram_depth           : integer;
        int_bram_ctrl_addr_width : integer;  --clogb2(int_bram_depth * (int_data_width/8))
        int_bram_addr_offset     : integer;  --clogb2(int_data_width/8)
        int_bram_addr_width      : integer := 32;
        -- AXI slave interface parameters
        s_axi_data_width         : integer := 32;
        s_axi_addr_width         : integer := 6;
        -- AXIS master interface parameters
        m_axis_tdata_width       : integer := 32
        );
    port (
        -- reset:
        aclk                : in  std_logic;
        rstn                : in  std_logic_vector(reset_width - 1 downto 0);
        s_axi_aresetn       : in  std_logic;
        -- AXI slave register ports
        s_axi_regs_awaddr   : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_regs_awprot   : in  std_logic_vector(2 downto 0);
        s_axi_regs_awvalid  : in  std_logic;
        s_axi_regs_awready  : out std_logic;
        s_axi_regs_wdata    : in  std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_regs_wstrb    : in  std_logic_vector((s_axi_data_width/8) - 1 downto 0);
        s_axi_regs_wvalid   : in  std_logic;
        s_axi_regs_wready   : out std_logic;
        s_axi_regs_bresp    : out std_logic_vector(1 downto 0);
        s_axi_regs_bvalid   : out std_logic;
        s_axi_regs_bready   : in  std_logic;
        s_axi_regs_araddr   : in  std_logic_vector(s_axi_addr_width - 1 downto 0);
        s_axi_regs_arprot   : in  std_logic_vector(2 downto 0);
        s_axi_regs_arvalid  : in  std_logic;
        s_axi_regs_arready  : out std_logic;
        s_axi_regs_rdata    : out std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_regs_rresp    : out std_logic_vector(1 downto 0);
        s_axi_regs_rvalid   : out std_logic;
        s_axi_regs_rready   : in  std_logic;
        -- AXI BRAM controller ports
        s_axi_bram_awaddr   : in  std_logic_vector(int_bram_ctrl_addr_width - 1 downto 0);
        s_axi_bram_awprot   : in  std_logic_vector(2 downto 0);
        s_axi_bram_awvalid  : in  std_logic;
        s_axi_bram_awready  : out std_logic;
        s_axi_bram_wdata    : in  std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_bram_wstrb    : in  std_logic_vector((s_axi_data_width/8) - 1 downto 0);
        s_axi_bram_wvalid   : in  std_logic;
        s_axi_bram_wready   : out std_logic;
        s_axi_bram_bresp    : out std_logic_vector(1 downto 0);
        s_axi_bram_bvalid   : out std_logic;
        s_axi_bram_bready   : in  std_logic;
        s_axi_bram_araddr   : in  std_logic_vector(int_bram_ctrl_addr_width - 1 downto 0);
        s_axi_bram_arprot   : in  std_logic_vector(2 downto 0);
        s_axi_bram_arvalid  : in  std_logic;
        s_axi_bram_arready  : out std_logic;
        s_axi_bram_rdata    : out std_logic_vector(s_axi_data_width - 1 downto 0);
        s_axi_bram_rresp    : out std_logic_vector(1 downto 0);
        s_axi_bram_rvalid   : out std_logic;
        s_axi_bram_rready   : in  std_logic;
        -- Ports of Axi Master Bus Interface
        m_axis_tvalid       : out std_logic;
        m_axis_tdata        : out std_logic_vector(m_axis_tdata_width - 1 downto 0);
        m_axis_tready       : in  std_logic;
        -- Debug ports of Axi Master Bus Interface
        debug_m_axis_tvalid : out std_logic;
        debug_m_axis_tdata  : out std_logic_vector(m_axis_tdata_width - 1 downto 0);
        debug_m_axis_tready : in  std_logic
        );
end axis_dummy_data_generator;

architecture behavioral of axis_dummy_data_generator is

    -- Signals connected to Axi slave register module
    signal bram_mode             : std_logic;
    signal continuous_mode       : std_logic;
    signal debug_mode            : std_logic;
    signal sample_delay          : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal cnt_max_value         : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal max_samples           : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal transaction_done      : std_logic;
    -- Calculate bit size of BRAM address register
    constant bram_max_addr_width : integer := int_bram_ctrl_addr_width - int_bram_addr_offset;  -- clogb2(int_bram_depth)
    signal bram_max_addr         : std_logic_vector(bram_max_addr_width - 1 downto 0);
    signal bram_max_addr_val     : integer;

    -- Signals for data generation
    signal data               : unsigned(int_data_width - 1 downto 0) := (others => '0');
    signal data_out           : std_logic_vector(data'range)          := (others => '0');
    signal data_valid         : std_logic                             := '0';
    signal sample_cnt         : unsigned(int_data_width - 1 downto 0) := (others => '0');
    signal next_sample_delay  : unsigned(int_data_width - 1 downto 0);
    constant sample_delay_min : unsigned(int_data_width - 1 downto 0) := to_unsigned(1, int_data_width);

    -- Internal control signals: BRAM controller <-> BRAM
    -- No initial value, since BRAM controller will drive these signals
    signal int_bram_addr_a   : std_logic_vector(int_bram_ctrl_addr_width -1 downto 0);
    signal bram_addr_a_pad   : std_logic_vector(int_bram_addr_width - 1 downto 0);
    signal int_bram_clk_a    : std_logic;
    signal int_bram_wrdata_a : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal int_bram_rddata_a : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal int_bram_en_a     : std_logic;
    signal int_bram_rst_a    : std_logic;
    signal int_bram_we_a     : std_logic_vector(3 downto 0);

    -- Internal control signals: internal IP logic <-> BRAM
    constant bram_base_addr : integer                                           := 0;
    signal bram_addr_b      : std_logic_vector(int_bram_addr_width -1 downto 0) := (others => '0');
    signal bram_addr_b_int  : integer                                           := bram_base_addr;
    signal bram_wrdata_b    : std_logic_vector(s_axi_data_width - 1 downto 0)   := (others => '0');
    signal bram_rddata_b    : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal bram_en_b        : std_logic                                         := '0';
    signal bram_en_b_int    : std_logic                                         := '0';
    signal bram_rst_b       : std_logic                                         := '0';
    signal bram_we_b        : std_logic_vector(3 downto 0)                      := (others => '0');

    -- type for state machine
    type t_state is (wait_next_sample, write_data, done);
    signal state : t_state := wait_next_sample;

    -- return value for counter either '0' or '1'
    constant cnt_return_value : std_logic := '0';

begin
    ----------------------------------------------------------------------------
    -- Instantiation of modules
    ----------------------------------------------------------------------------
    -- AXI slave registers
    AXI_SLAVE_REGS : entity work.axis_dummy_data_generator_slave(regs)
        generic map(
            c_s_axi_data_width  => s_axi_data_width,
            c_s_axi_addr_width  => s_axi_addr_width,
            bram_max_addr_width => bram_max_addr_width
            )
        port map(
            -- AXI slave registers:
            bram_mode        => bram_mode,
            continuous_mode  => continuous_mode,
            debug_mode       => debug_mode,
            sample_delay     => sample_delay,
            cnt_max_value    => cnt_max_value,
            max_samples      => max_samples,
            transaction_done => transaction_done,
            bram_max_addr    => bram_max_addr,
            -- AXI slave port
            s_axi_aclk       => aclk,
            s_axi_aresetn    => s_axi_aresetn,
            s_axi_awaddr     => s_axi_regs_awaddr,
            s_axi_awprot     => s_axi_regs_awprot,
            s_axi_awvalid    => s_axi_regs_awvalid,
            s_axi_awready    => s_axi_regs_awready,
            s_axi_wdata      => s_axi_regs_wdata,
            s_axi_wstrb      => s_axi_regs_wstrb,
            s_axi_wvalid     => s_axi_regs_wvalid,
            s_axi_wready     => s_axi_regs_wready,
            s_axi_bresp      => s_axi_regs_bresp,
            s_axi_bvalid     => s_axi_regs_bvalid,
            s_axi_bready     => s_axi_regs_bready,
            s_axi_araddr     => s_axi_regs_araddr,
            s_axi_arprot     => s_axi_regs_arprot,
            s_axi_arvalid    => s_axi_regs_arvalid,
            s_axi_arready    => s_axi_regs_arready,
            s_axi_rdata      => s_axi_regs_rdata,
            s_axi_rresp      => s_axi_regs_rresp,
            s_axi_rvalid     => s_axi_regs_rvalid,
            s_axi_rready     => s_axi_regs_rready
            );

    -- BRAM connected to BRAM controller
    -- Module declaration in core_ext.tcl
    BRAM : entity work.blk_mem_gen_0
        port map(
            -- Port A, connected to BRAM controller
            addra => bram_addr_a_pad,
            clka  => int_bram_clk_a,
            dina  => int_bram_wrdata_a,
            douta => int_bram_rddata_a,
            ena   => int_bram_en_a,
            rsta  => int_bram_rst_a,
            wea   => int_bram_we_a,
            -- Port B, connected to internal IP logic
            addrb => bram_addr_b,
            clkb  => aclk,
            dinb  => bram_wrdata_b,
            doutb => bram_rddata_b,
            enb   => bram_en_b,
            web   => bram_we_b
            );

    -- BRAM controller connected to BRAM and PS
    -- Module declaration in core_ext.tcl
    BRAM_CTRL : entity work.axi_bram_ctrl_0
        port map(
            -- BRAM Interface (BRAM CTRL <-> BRAM Port A)
            bram_addr_a   => int_bram_addr_a,
            bram_clk_a    => int_bram_clk_a,
            bram_wrdata_a => int_bram_wrdata_a,
            bram_rddata_a => int_bram_rddata_a,
            bram_en_a     => int_bram_en_a,
            bram_rst_a    => int_bram_rst_a,
            bram_we_a     => int_bram_we_a,
            -- AXI Lite Interface (PS <-> BRAM CTRL)
            s_axi_aclk    => aclk,
            s_axi_aresetn => s_axi_aresetn,
            s_axi_awaddr  => s_axi_bram_awaddr,
            s_axi_awprot  => s_axi_bram_awprot,
            s_axi_awvalid => s_axi_bram_awvalid,
            s_axi_awready => s_axi_bram_awready,
            s_axi_wdata   => s_axi_bram_wdata,
            s_axi_wstrb   => s_axi_bram_wstrb,
            s_axi_wvalid  => s_axi_bram_wvalid,
            s_axi_wready  => s_axi_bram_wready,
            s_axi_bresp   => s_axi_bram_bresp,
            s_axi_bvalid  => s_axi_bram_bvalid,
            s_axi_bready  => s_axi_bram_bready,
            s_axi_araddr  => s_axi_bram_araddr,
            s_axi_arprot  => s_axi_bram_arprot,
            s_axi_arvalid => s_axi_bram_arvalid,
            s_axi_arready => s_axi_bram_arready,
            s_axi_rdata   => s_axi_bram_rdata,
            s_axi_rresp   => s_axi_bram_rresp,
            s_axi_rvalid  => s_axi_bram_rvalid,
            s_axi_rready  => s_axi_bram_rready
            );
    ----------------------------------------------------------------------------
    -- IP's internal logic section
    ----------------------------------------------------------------------------
    GENERATE_DATA : process (aclk)
    begin

        if rising_edge(aclk) then

            if (rstn(RESET_INDEX) = '0') then
                state             <= wait_next_sample;
                data              <= (0      => cnt_return_value, others => '0');
                next_sample_delay <= unsigned(sample_delay);
                transaction_done  <= '0';
                data_valid        <= '0';
                sample_cnt        <= (others => '0');
                bram_en_b_int     <= '1';
                bram_addr_b_int   <= bram_base_addr;
            else
                -- decrease counter until next sample and reset if counter reaches zero
                if (next_sample_delay = sample_delay_min) then
                    next_sample_delay <= unsigned(sample_delay);
                else
                    next_sample_delay <= next_sample_delay - 1;
                end if;

                ----------------------------------------------------------------
                -- FSM for data generation
                ----------------------------------------------------------------
                case state is

                    when wait_next_sample =>
                        -- Default assignment for data_valid
                        data_valid <= '0';

                        -- Idling state, wait until next_sample_delay decreases to zero
                        -- -> assert data_valid and go to write_data state
                        if (next_sample_delay = sample_delay_min) then
                            -- For non BRAM mode, data_valid is asserted here
                            if (bram_mode = '0') then
                                data_valid <= '1';
                            end if;
                            state <= write_data;
                        end if;

                        -- Disable BRAM port B
                        bram_en_b_int <= '0';

                    when write_data =>
                        -- Increment address and read data from BRAM
                        if (bram_mode = '1') then
                            if (bram_addr_b_int = bram_max_addr_val - 1) then
                                bram_addr_b_int <= bram_base_addr;
                            else
                                bram_addr_b_int <= bram_addr_b_int + 1;
                            end if;

                            -- Enable BRAM port B and assert valid
                            bram_en_b_int <= '1';
                            data_valid    <= '1';
                        end if;

                        -- Assign data value (non BRAM mode)
                        if (m_axis_tready = '1' and data_valid = '1') then
                            if (data = (unsigned(cnt_max_value))) then
                                data <= (0 => cnt_return_value, others => '0');
                            else
                                data <= data + 1;
                            end if;
                        end if;

                        -- If in counter mode, increase sample_cnt
                        if (continuous_mode = '0') then
                            sample_cnt <= sample_cnt + 1;
                        end if;

                        -- If sample_cnt reaches zero -> go to done state,
                        if (sample_cnt = unsigned(max_samples) - 1) then
                            if (bram_mode = '0') then
                                data_valid <= '0';
                            end if;
                            state <= done;
                        else
                            if (unsigned(sample_delay) <= sample_delay_min) then
                            -- If sample_delay is lower than minimum value, then remain in current state
                            else
                                -- Else go to wait_next_sample state
                                if (bram_mode = '0') then
                                    data_valid <= '0';
                                end if;
                                state <= wait_next_sample;
                            end if;
                        end if;

                    when done =>
                        bram_en_b_int    <= '0';
                        data_valid       <= '0';
                        transaction_done <= '1';

                    when others =>
                        state <= done;

                end case;
                ----------------------------------------------------------------
                -- FSM section end
                ----------------------------------------------------------------

            end if;  --else

        end if;  --rising_edge(aclk)

    end process GENERATE_DATA;

    ----------------------------------------------------------------------------
    -- Assign internal signals
    ----------------------------------------------------------------------------
    -- Pad BRAM address to full width of BRAM
    bram_addr_a_pad   <= (int_bram_addr_width-1 downto int_bram_ctrl_addr_width => '0') & int_bram_addr_a;
    -- Convert bram_max_addr from std_logic_vector to integer
    bram_max_addr_val <= to_integer(unsigned(bram_max_addr));
    -- Convert BRAM address counter (integer) to std_logic_vector
    bram_addr_b       <= std_logic_vector(shift_left(to_unsigned(bram_addr_b_int, bram_addr_b'length), int_bram_addr_offset));
    -- Avoid BRAM read/write conflicts at same address on port A and B
    bram_en_b         <= bram_en_b_int and not(int_bram_en_a);

    ----------------------------------------------------------------------------
    -- Assign output ports
    ----------------------------------------------------------------------------
    -- tdata output register, exist onlyfor better readability
    data_out <= bram_rddata_b when (bram_mode = '1') else std_logic_vector(data);

    -- Assign AXI Stream output ports
    m_axis_tdata  <= data_out                       when (debug_mode = '0') else (others => '0');
    m_axis_tvalid <= (data_valid and m_axis_tready) when (debug_mode = '0') else '0';

    -- Assign debug AXI Stream output ports
    debug_m_axis_tdata  <= data_out                             when (debug_mode = '1') else (others => '0');
    debug_m_axis_tvalid <= (data_valid and debug_m_axis_tready) when (debug_mode = '1') else '0';

end behavioral;
