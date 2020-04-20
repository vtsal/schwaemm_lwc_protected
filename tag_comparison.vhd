-- Protected tag comparison entity (128 bit tag)
-- tag_in_comp is computed tag
-- tag_in is input tag from test vector

library ieee;
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all; 

entity compare_tag_pro is
port(
	tag_in_s1, tag_in_s2, tag_in_s3: in std_logic_vector(127 downto 0);
	tag_in_comp_s1, tag_in_comp_s2, tag_in_comp_s3: in std_logic_vector(127 downto 0);
	random_in : in std_logic_vector(63 downto 0);
	clk, start_tag_compare : in std_logic;
	done, tag_match: out std_logic
	);

end compare_tag_pro;

architecture behavioral of compare_tag_pro is

    type tag_compare_state is (IDLE, RUN);
        signal current_state : tag_compare_state;
        signal next_state : tag_compare_state;
    
    signal tg_counter : integer := 0;
    signal counter_en, counter_init : std_logic;

    signal stage_0_en, stage_1_en, stage_2_en, stage_3_en, stage_4_en, stage_5_en, stage_6_en : std_logic;
    
    signal c_s1_a_in, c_s1_a_out, c_s1_b_in, c_s1_b_out : std_logic_vector(63 downto 0);
    signal c_s2_a_in, c_s2_a_out, c_s2_b_in, c_s2_b_out : std_logic_vector(63 downto 0);
    signal c_s3_a_in, c_s3_a_out, c_s3_b_in, c_s3_b_out : std_logic_vector(63 downto 0);
    
    signal d_1_a_in, d_1_a_out, d_1_b_in, d_1_b_out : std_logic_vector(63 downto 0);
    signal d_2_a_in, d_2_a_out, d_2_b_in, d_2_b_out : std_logic_vector(63 downto 0);
    
    signal r_a_out, r_b_out : std_logic_vector(63 downto 0);
    
begin

    public : process(tg_counter, start_tag_compare, current_state) begin
        
        -- Defaults:
        counter_en <= '0';
        done <= '0';
        counter_init <= '0';
        tag_match <= '0';
        
        case current_state is
        when IDLE =>
            if (start_tag_compare = '1') then
                next_state <= RUN;
                counter_en <= '1';
            else
                next_state <= IDLE;
            end if;
        when RUN =>
            counter_en <= '1';
            if (tg_counter = 6) then
                counter_init <= '1';
                done <= '1';
                if ((d_2_a_out xor d_2_b_out) = x"0000000000000000") then
                    tag_match <= '1';
                end if;
                next_state <= IDLE;
            else
                next_state <= RUN;
            end if;
        when others =>
            next_state <= IDLE;
        end case;
    end process;
    
    sync_process: process(clk)
    begin
    if (rising_edge(clk)) then
       current_state <= next_state;
    end if;
    end process;
    
    update_counter: process(clk) begin
    if (rising_edge(clk)) then
        if (counter_en = '1') then
            if (counter_init = '1') then
                tg_counter <= 0;
            else
                tg_counter <= tg_counter + 1;
            end if;
        end if;
    end if;
    end process;
    
    enable_regs: process(tg_counter, start_tag_compare) begin
        stage_0_en <= '0';
        stage_1_en <= '0';
        stage_2_en <= '0';
        stage_3_en <= '0';
        stage_4_en <= '0';
        stage_5_en <= '0';
        stage_6_en <= '0';
    
        if (tg_counter = 0) and (start_tag_compare = '1') then
            stage_0_en <= '1';
        elsif (tg_counter = 1) then
            stage_1_en <= '1';
        elsif (tg_counter = 2) then
            stage_2_en <= '1';
        elsif (tg_counter = 3) then
            stage_3_en <= '1';
        elsif (tg_counter = 4) then
            stage_4_en <= '1';
        elsif (tg_counter = 5) then
            stage_5_en <= '1';
        elsif (tg_counter = 6) then
            stage_6_en <= '1';
        end if;
    end process;
    
    -- REGISTERS
    
    reg_c1a : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s1_a_in,
        e => stage_0_en,
        clk => clk,
        q => c_s1_a_out
    );
    
    reg_c1b : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s1_b_in,
        e => stage_1_en,
        clk => clk,
        q => c_s1_b_out
    );
    
    reg_c2a : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s2_a_in,
        e => stage_1_en,
        clk => clk,
        q => c_s2_a_out
    );
    
    reg_c2b : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s2_b_in,
        e => stage_2_en,
        clk => clk,
        q => c_s2_b_out
    );

    reg_c3a : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s3_a_in,
        e => stage_2_en,
        clk => clk,
        q => c_s3_a_out
    );
    
    reg_c3b : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => c_s3_b_in,
        e => stage_3_en,
        clk => clk,
        q => c_s3_b_out
    );
    
    reg_d1a : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => d_1_a_in,
        e => stage_3_en,
        clk => clk,
        q => d_1_a_out
    );
    
    reg_d1b : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => d_1_b_in,
        e => stage_4_en,
        clk => clk,
        q => d_1_b_out
    );
    
    reg_d2a : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => d_2_a_in,
        e => stage_4_en,
        clk => clk,
        q => d_2_a_out
    );
    
    reg_d2b : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => d_2_b_in,
        e => stage_5_en,
        clk => clk,
        q => d_2_b_out
    );
    
    reg_ra : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => random_in,
        e => stage_2_en,
        clk => clk,
        q => r_a_out
    );
    
    reg_rb : entity work.regGen(behavioral)
    generic map(width => 64)
    port map(
        d => random_in,
        e => stage_3_en,
        clk => clk,
        q => r_b_out
    );
   
    -- ASSIGNMENTS
    c_s1_a_in <= tag_in_s1(127 downto 64) xor tag_in_comp_s1(127 downto 64);
    
    c_s1_b_in <= tag_in_s1(63 downto 0) xor tag_in_comp_s1(63 downto 0);
    c_s2_a_in <= tag_in_s2(127 downto 64) xor tag_in_comp_s2(127 downto 64);
    
    c_s2_b_in <= tag_in_s2(63 downto 0) xor tag_in_comp_s2(63 downto 0);
    c_s3_a_in <= tag_in_s3(127 downto 64) xor tag_in_comp_s3(127 downto 64);
    
    c_s3_b_in <= tag_in_s3(63 downto 0) xor tag_in_comp_s3(63 downto 0);
    d_1_a_in <= c_s1_a_out xor c_s2_a_out xor r_a_out;
    
    d_1_b_in <= c_s1_b_out xor c_s2_b_out xor r_b_out;
    d_2_a_in <= d_1_a_out xor c_s3_a_out xor r_a_out;
    
    d_2_b_in <= c_s3_b_out xor d_1_b_out xor r_b_out;    

end behavioral;
