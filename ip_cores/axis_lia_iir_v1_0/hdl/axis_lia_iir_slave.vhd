library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_lia_iir_slave is
    generic (
        c_s_axi_data_width : integer := 32;
        c_s_axi_addr_width : integer := 8
        );
    port (
        -- Register input and output
        sos_mux : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        -- Filter coefficients
        b0_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b0_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b0_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a0_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a0_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b1_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b1_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b1_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a1_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a1_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b2_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b2_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b2_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a2_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a2_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b3_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b3_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b3_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a3_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a3_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b4_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b4_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b4_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a4_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a4_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b5_0    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b5_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        b5_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a5_1    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        a5_2    : out std_logic_vector(c_s_axi_data_width - 1 downto 0);

        -- AXI Lite signals
        s_axi_aclk    : in  std_logic;
        s_axi_aresetn : in  std_logic;
        s_axi_awaddr  : in  std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_wstrb   : in  std_logic_vector((c_s_axi_data_width/8) - 1 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
        );
end axis_lia_iir_slave;

architecture regs of axis_lia_iir_slave is
    -- AXI4LITE signals
    signal axi_awaddr  : std_logic_vector(c_s_axi_addr_width - 1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(c_s_axi_addr_width - 1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;

    -- Example-specific design signals
    -- local parameter for addressing 32 bit / 64 bit c_s_axi_data_width
    -- ADDR_LSB is used for addressing 32/64 bit registers/memories
    -- ADDR_LSB = 2 for 32 bits (n downto 2)
    -- ADDR_LSB = 3 for 64 bits (n downto 3)
    constant ADDR_LSB          : integer := (c_s_axi_data_width/32) + 1;
    constant OPT_MEM_ADDR_BITS : integer := 5;

    ------------------------------------------------
    ---- Signals for user logic register space example
    --------------------------------------------------
    signal slv_reg0     : std_logic_vector(c_s_axi_data_width - 1 downto 0) := (0 => '1', others => '0');  -- Default sos stage are 1
    signal slv_reg1     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg2     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg3     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg4     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg5     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg6     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg7     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg8     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg9     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg10    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg11    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg12    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg13    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg14    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg15    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg16    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg17    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg18    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg19    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg20    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg21    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg22    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg23    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg24    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg25    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg26    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg27    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg28    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg29    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg30    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg31    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg_rden : std_logic;
    signal slv_reg_wren : std_logic;
    signal reg_data_out : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal byte_index   : integer;
    signal aw_en        : std_logic;

begin

    -- I/O Connections assignments
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bresp   <= axi_bresp;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_arready <= axi_arready;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= axi_rresp;
    s_axi_rvalid  <= axi_rvalid;

    ----------------------------------------------------------------------------
    -- User Slave Register:
    ----------------------------------------------------------------------------
    sos_mux <= slv_reg0;                -- 0x00
    -- 1st second order section
    b0_0    <= slv_reg1;                -- 0x04
    b0_1    <= slv_reg2;                -- 0x08
    b0_2    <= slv_reg3;                -- 0x0C
    a0_1    <= slv_reg4;                -- 0x10
    a0_2    <= slv_reg5;                -- 0x14
    -- 2nd second order section
    b1_0    <= slv_reg6;                -- 0x18
    b1_1    <= slv_reg7;                -- 0x1C
    b1_2    <= slv_reg8;                -- 0x20
    a1_1    <= slv_reg9;                -- 0x24
    a1_2    <= slv_reg10;               -- 0x28
    -- 3rd second order section
    b2_0    <= slv_reg11;               -- 0x2C
    b2_1    <= slv_reg12;               -- 0x30
    b2_2    <= slv_reg13;               -- 0x34
    a2_1    <= slv_reg14;               -- 0x38
    a2_2    <= slv_reg15;               -- 0x3C
    -- 4th second order section
    b3_0    <= slv_reg16;               -- 0x40
    b3_1    <= slv_reg17;               -- 0x44
    b3_2    <= slv_reg18;               -- 0x48
    a3_1    <= slv_reg19;               -- 0x4C
    a3_2    <= slv_reg20;               -- 0x50
    -- 5th second order section
    b4_0    <= slv_reg21;               -- 0x54
    b4_1    <= slv_reg22;               -- 0x58
    b4_2    <= slv_reg23;               -- 0x5C
    a4_1    <= slv_reg24;               -- 0x60
    a4_2    <= slv_reg25;               -- 0x64
    -- 6th second order section
    b5_0    <= slv_reg26;               -- 0x68
    b5_1    <= slv_reg27;               -- 0x6C
    b5_2    <= slv_reg28;               -- 0x70
    a5_1    <= slv_reg29;               -- 0x74
    a5_2    <= slv_reg30;               -- 0x78


    -- Implement axi_awready generation
    -- axi_awready is asserted for one s_axi_aclk clock cycle when both
    -- s_axi_awvalid and s_axi_wvalid are asserted. axi_awready is
    -- de-asserted when reset is low.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
                aw_en       <= '1';
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                                        -- slave is ready to accept write address when
                                        -- there is a valid write address and write data
                                        -- on the write address and data bus. This design
                                        -- expects no outstanding transactions.
                    axi_awready <= '1';
                    aw_en       <= '0';
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then
                    aw_en       <= '1';
                    axi_awready <= '0';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_awaddr latching
    -- This process is used to latch the address when both
    -- s_axi_awvalid and s_axi_wvalid are valid.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awaddr <= (others => '0');
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                                        -- Write Address latching
                    axi_awaddr <= s_axi_awaddr;
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_wready generation
    -- axi_wready is asserted for one s_axi_aclk clock cycle when both
    -- s_axi_awvalid and s_axi_wvalid are asserted. axi_wready is
    -- de-asserted when reset is low.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_wready <= '0';
            else
                if (axi_wready = '0' and s_axi_wvalid = '1' and s_axi_awvalid = '1' and aw_en = '1') then
                                        -- slave is ready to accept write data when
                                        -- there is a valid write address and write data
                                        -- on the write address and data bus. This design
                                        -- expects no outstanding transactions.
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement memory mapped register select and write logic generation
    -- The write data is accepted and written to memory mapped registers when
    -- axi_awready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted. Write strobes are used to
    -- select byte enables of slave registers while writing.
    -- These registers are cleared when reset (active low) is applied.
    -- Slave register write enable is asserted when valid address and data are available
    -- and the slave is ready to accept the write address and write data.
    slv_reg_wren <= axi_wready and s_axi_wvalid and axi_awready and s_axi_awvalid;

    process (s_axi_aclk)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                slv_reg0  <= (0      => '1', others => '0');  -- Default sos stages are 1
                slv_reg1  <= (others => '0');
                slv_reg2  <= (others => '0');
                slv_reg3  <= (others => '0');
                slv_reg4  <= (others => '0');
                slv_reg5  <= (others => '0');
                slv_reg6  <= (others => '0');
                slv_reg7  <= (others => '0');
                slv_reg8  <= (others => '0');
                slv_reg9  <= (others => '0');
                slv_reg10 <= (others => '0');
                slv_reg11 <= (others => '0');
                slv_reg12 <= (others => '0');
                slv_reg13 <= (others => '0');
                slv_reg14 <= (others => '0');
                slv_reg15 <= (others => '0');
                slv_reg16 <= (others => '0');
                slv_reg17 <= (others => '0');
                slv_reg18 <= (others => '0');
                slv_reg19 <= (others => '0');
                slv_reg20 <= (others => '0');
                slv_reg21 <= (others => '0');
                slv_reg22 <= (others => '0');
                slv_reg23 <= (others => '0');
                slv_reg24 <= (others => '0');
                slv_reg25 <= (others => '0');
                slv_reg26 <= (others => '0');
                slv_reg27 <= (others => '0');
                slv_reg28 <= (others => '0');
                slv_reg29 <= (others => '0');
                slv_reg30 <= (others => '0');
                slv_reg31 <= (others => '0');
            else
                loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
                if (slv_reg_wren = '1') then
                    case loc_addr is
                        when b"000000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg0(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg1(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000010" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg2(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg3(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg4(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg5(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg6(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"000111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg7(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg8(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg9(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001010" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg10(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg11(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg12(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg13(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg14(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"001111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg15(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg16(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg17(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010010" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg18(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg19(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg20(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg21(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg22(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"010111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg23(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg24(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg25(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011010" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg26(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg27(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg28(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg29(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg30(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"011111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                    slv_reg31(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;

                        when others =>
                            slv_reg0  <= slv_reg0;
                            slv_reg1  <= slv_reg1;
                            slv_reg2  <= slv_reg2;
                            slv_reg3  <= slv_reg3;
                            slv_reg4  <= slv_reg4;
                            slv_reg5  <= slv_reg5;
                            slv_reg6  <= slv_reg6;
                            slv_reg7  <= slv_reg7;
                            slv_reg8  <= slv_reg8;
                            slv_reg9  <= slv_reg9;
                            slv_reg10 <= slv_reg10;
                            slv_reg11 <= slv_reg11;
                            slv_reg12 <= slv_reg12;
                            slv_reg13 <= slv_reg13;
                            slv_reg14 <= slv_reg14;
                            slv_reg15 <= slv_reg15;
                            slv_reg16 <= slv_reg16;
                            slv_reg17 <= slv_reg17;
                            slv_reg18 <= slv_reg18;
                            slv_reg19 <= slv_reg19;
                            slv_reg20 <= slv_reg20;
                            slv_reg21 <= slv_reg21;
                            slv_reg22 <= slv_reg22;
                            slv_reg23 <= slv_reg23;
                            slv_reg24 <= slv_reg24;
                            slv_reg25 <= slv_reg25;
                            slv_reg26 <= slv_reg26;
                            slv_reg27 <= slv_reg27;
                            slv_reg28 <= slv_reg28;
                            slv_reg29 <= slv_reg29;
                            slv_reg30 <= slv_reg30;
                            slv_reg31 <= slv_reg31;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- Implement write response logic generation
    -- The write response and response valid signals are asserted by the slave
    -- when axi_wready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted.
    -- This marks the acceptance of address and indicates the status of
    -- write transaction.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";     --need to work more on the responses
            else
                if (axi_awready = '1' and s_axi_awvalid = '1' and axi_wready = '1' and s_axi_wvalid = '1' and axi_bvalid = '0') then
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then  --check if bready is asserted while bvalid is high)
                    axi_bvalid <= '0';  -- (there is a possibility that bready is always asserted high)
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_arready generation
    -- axi_arready is asserted for one s_axi_aclk clock cycle when
    -- s_axi_arvalid is asserted. axi_awready is
    -- de-asserted when reset (active low) is asserted.
    -- The read address is also latched when s_axi_arvalid is
    -- asserted. axi_araddr is reset to zero on reset assertion.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_arready <= '0';
                axi_araddr  <= (others => '1');
            else
                if (axi_arready = '0' and s_axi_arvalid = '1') then
                                        -- indicates that the slave has acceped the valid read address
                    axi_arready <= '1';
                                        -- Read Address latching
                    axi_araddr  <= s_axi_araddr;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_arvalid generation
    -- axi_rvalid is asserted for one s_axi_aclk clock cycle when both
    -- s_axi_arvalid and axi_arready are asserted. The slave registers
    -- data are available on the axi_rdata bus at this instance. The
    -- assertion of axi_rvalid marks the validity of read data on the
    -- bus and axi_rresp indicates the status of read transaction.axi_rvalid
    -- is deasserted on reset (active low). axi_rresp and axi_rdata are
    -- cleared to zero on reset (active low).
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";
            else
                if (axi_arready = '1' and s_axi_arvalid = '1' and axi_rvalid = '0') then
                                         -- Valid read data is available at the read data bus
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";  -- 'OKAY' response
                elsif (axi_rvalid = '1' and s_axi_rready = '1') then
                                         -- Read data is accepted by the master
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement memory mapped register select and read logic generation
    -- Slave register read enable is asserted when valid address is available
    -- and the slave is ready to accept the read address.
    slv_reg_rden <= axi_arready and s_axi_arvalid and (not axi_rvalid);

    process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8, slv_reg9, slv_reg10, slv_reg11, slv_reg12, slv_reg13, slv_reg14, slv_reg15, slv_reg16, slv_reg17, slv_reg18, slv_reg19, slv_reg20, slv_reg21, slv_reg22, slv_reg23, slv_reg24, slv_reg25, slv_reg26, slv_reg27, slv_reg28, slv_reg29, slv_reg30, slv_reg31, axi_araddr, s_axi_aresetn, slv_reg_rden)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        -- Address decoding for reading registers
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        case loc_addr is
            when b"000000" =>
                reg_data_out <= slv_reg0;
            when b"000001" =>
                reg_data_out <= slv_reg1;
            when b"000010" =>
                reg_data_out <= slv_reg2;
            when b"000011" =>
                reg_data_out <= slv_reg3;
            when b"000100" =>
                reg_data_out <= slv_reg4;
            when b"000101" =>
                reg_data_out <= slv_reg5;
            when b"000110" =>
                reg_data_out <= slv_reg6;
            when b"000111" =>
                reg_data_out <= slv_reg7;
            when b"001000" =>
                reg_data_out <= slv_reg8;
            when b"001001" =>
                reg_data_out <= slv_reg9;
            when b"001010" =>
                reg_data_out <= slv_reg10;
            when b"001011" =>
                reg_data_out <= slv_reg11;
            when b"001100" =>
                reg_data_out <= slv_reg12;
            when b"001101" =>
                reg_data_out <= slv_reg13;
            when b"001110" =>
                reg_data_out <= slv_reg14;
            when b"001111" =>
                reg_data_out <= slv_reg15;
            when b"010000" =>
                reg_data_out <= slv_reg16;
            when b"010001" =>
                reg_data_out <= slv_reg17;
            when b"010010" =>
                reg_data_out <= slv_reg18;
            when b"010011" =>
                reg_data_out <= slv_reg19;
            when b"010100" =>
                reg_data_out <= slv_reg20;
            when b"010101" =>
                reg_data_out <= slv_reg21;
            when b"010110" =>
                reg_data_out <= slv_reg22;
            when b"010111" =>
                reg_data_out <= slv_reg23;
            when b"011000" =>
                reg_data_out <= slv_reg24;
            when b"011001" =>
                reg_data_out <= slv_reg25;
            when b"011010" =>
                reg_data_out <= slv_reg26;
            when b"011011" =>
                reg_data_out <= slv_reg27;
            when b"011100" =>
                reg_data_out <= slv_reg28;
            when b"011101" =>
                reg_data_out <= slv_reg29;
            when b"011110" =>
                reg_data_out <= slv_reg30;
            when b"011111" =>
                reg_data_out <= slv_reg31;
            when others =>
                reg_data_out <= (others => '0');
        end case;
    end process;

    -- Output register or memory read data
    process (s_axi_aclk) is
    begin
        if (rising_edge (s_axi_aclk)) then
            if (s_axi_aresetn = '0') then
                axi_rdata <= (others => '0');
            else
                if (slv_reg_rden = '1') then
                                                -- When there is a valid read address (s_axi_arvalid) with
                                                -- acceptance of read address by the slave (axi_arready),
                                                -- output the read dada
                                                -- Read address mux
                    axi_rdata <= reg_data_out;  -- register read data
                end if;
            end if;
        end if;
    end process;
    -- Add user logic here

    -- User logic ends

end regs;
