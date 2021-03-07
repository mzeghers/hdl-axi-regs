library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_regs is
    Generic(
        -- Must be >= 2 and <= 30
        ADDR_WIDTH : natural := 12 -- 4kB addressable space = 1024 32-bit registers
    );    
    Port(
        -- Slave AXI-Lite interface
        s_axi_aclk              : in std_logic := '0';
        s_axi_aresetn           : in std_logic := '0';
        s_axi_awaddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_awvalid           : in std_logic := '0';
        s_axi_awready           : out std_logic := '0';
        s_axi_wdata             : in std_logic_vector(31 downto 0) := (others => '0');
        s_axi_wvalid            : in std_logic := '0';
        s_axi_wready            : out std_logic := '0';
        s_axi_bresp             : out std_logic_vector(1 downto 0) := (others => '0');
        s_axi_bvalid            : out std_logic := '0';
        s_axi_bready            : in std_logic := '0';
        s_axi_araddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_arvalid           : in std_logic := '0';
        s_axi_arready           : out std_logic := '0';
        s_axi_rdata             : out std_logic_vector(31 downto 0) := (others => '0');
        s_axi_rvalid            : out std_logic := '0';
        s_axi_rready            : in std_logic := '0';
        s_axi_rresp             : out std_logic_vector(1 downto 0) := (others => '0');
        
        -- Read-Write register example
        my_rw_reg               : out std_logic_vector(23 downto 0) := (others => '0');
        
        -- Read-only register example
        my_ro_reg               : in std_logic_vector(15 downto 0) := (others => '0');
        
        -- Read-only (read to clear) example
        my_rorc_reg             : in std_logic_vector(7 downto 0) := (others => '0');
        my_rorc_reg_load        : in std_logic := '0';
        
        -- Read-only (write 0x1234 to clear) example
        my_rowc_reg             : in std_logic_vector(31 downto 0) := (others => '0');
        my_rowc_reg_load        : in std_logic := '0'
    );
end axi_regs;

architecture Behavioral of axi_regs is
    
    -- Number of registers
    constant NUM_REGS                   : natural := 2**(ADDR_WIDTH-2);
    
    -- Slave AXI-Lite state machine
    type S_AXI_STATES                   is (Wait_Addr, Read, Write);
    signal s_axi_state                  : S_AXI_STATES := Wait_Addr;
    signal s_axi_reg_nr                 : natural range 0 to NUM_REGS-1 := 0; 

    -- Registers array
    type REGS_ARRAY                     is array (0 to NUM_REGS-1) of std_logic_vector(31 downto 0);
    signal REGS                         : REGS_ARRAY := (others => (others => '0'));     
    
begin

-- Slave AXI-Lite state machine
process(s_axi_aclk, s_axi_aresetn) begin
    if(s_axi_aresetn = '0') then
        s_axi_state <= Wait_Addr;
        s_axi_reg_nr <= 0;
    elsif rising_edge(s_axi_aclk) then
        case s_axi_state is

            -- Wait for s_axi_awvalid or s_axi_arvalid      
            when Wait_Addr =>
                if(s_axi_awvalid = '1') then
                    s_axi_state <= Write;
                    s_axi_reg_nr <= to_integer(unsigned(s_axi_awaddr(ADDR_WIDTH-1 downto 2))); -- Divide by 4 to get the reg number from AXI addr
                elsif(s_axi_arvalid = '1') then
                    s_axi_state <= Read;
                    s_axi_reg_nr <= to_integer(unsigned(s_axi_araddr(ADDR_WIDTH-1 downto 2))); -- Divide by 4 to get the reg number from AXI addr
                end if;

            -- Do the read
            when Read =>
                if(s_axi_rready = '1') then
                    s_axi_state <= Wait_Addr;
                end if;

            -- Do the write
            when Write =>
                if(s_axi_wvalid = '1') then
                    s_axi_state <= Wait_Addr;
                end if;

        end case;
    end if;
end process;

-- Slave AXI-Lite outputs
s_axi_awready 	<= '1' when (s_axi_state = Wait_Addr) else '0';
s_axi_wready 	<= '1' when (s_axi_state = Write) else '0';
s_axi_arready 	<= '1' when ((s_axi_state = Wait_Addr) and (s_axi_awvalid = '0')) else '0'; -- Prioritize write access
s_axi_rvalid 	<= '1' when (s_axi_state = Read) else '0';
s_axi_rdata 	<=  REGS(s_axi_reg_nr);
s_axi_bresp     <= (others => '0');
s_axi_bvalid    <= '1';
s_axi_rresp     <= (others => '0');




-- Example Read-Write register REGS(0) @ 0x000
process(s_axi_aclk, s_axi_aresetn) begin
    if(s_axi_aresetn = '0') then
        REGS(0)(23 downto 0) <= x"123456"; -- Reset value
    elsif rising_edge(s_axi_aclk) then
        if((s_axi_state = Write) and (s_axi_wvalid = '1') and (s_axi_reg_nr = 0)) then
            REGS(0)(23 downto 0) <= s_axi_wdata(23 downto 0);
        end if;
    end if;
end process;
my_rw_reg <= REGS(0)(23 downto 0);

-- Example Read-Only register REGS(1) @ 0x004
process(s_axi_aclk) begin
    if rising_edge(s_axi_aclk) then
        REGS(1)(15 downto 0) <= my_ro_reg;
    end if;
end process;

-- Example Read-Only (read to clear) register REGS(2) @ 0x008
process(s_axi_aclk) begin
    if rising_edge(s_axi_aclk) then
        if((s_axi_state = Read) and (s_axi_rready = '1') and (s_axi_reg_nr = 2)) then
            REGS(2)(7 downto 0) <= (others => '0');
        end if;
        if(my_rorc_reg_load = '1') then
            REGS(2)(7 downto 0) <= my_rorc_reg;
        end if;
    end if;
end process;

-- Example Read-Only (write 0x1234 to clear) register REGS(14) @ 0x038
process(s_axi_aclk) begin
    if rising_edge(s_axi_aclk) then
        if((s_axi_state = Write) and (s_axi_wvalid = '1') and (s_axi_reg_nr = 14)) then
            if(s_axi_wdata = x"00001234") then
                REGS(14)(31 downto 0) <= (others => '0');
            end if;            
        end if;
        if(my_rowc_reg_load = '1') then
            REGS(14)(31 downto 0) <= my_rowc_reg;
        end if;
    end if;
end process;



end Behavioral;
