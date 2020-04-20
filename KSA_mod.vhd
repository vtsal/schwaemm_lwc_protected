-- KSA_mod (32 bit KSA with 3-share threshold implementation)

library ieee;
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all; 
use work.utility_functions.all;

entity reg32 is
port(
	d: in pg_row_type;
	e, clk: in std_logic;
	q: out pg_row_type
	);
end reg32;

architecture behavioral of reg32 is   
begin

    process(clk) begin
        if (rising_edge(clk)) then
            if (e = '1') then
                q <= d;
            end if;
        end if;
    end process;

end behavioral;

library ieee;
use ieee.std_logic_1164.ALL;

entity and_3TI_a is
    port (
	xa, xb, ya, yb, m  : in  std_logic;
	o		: out std_logic
	);

end entity and_3TI_a;

architecture dataflow of and_3TI_a is
begin
	o <= (xb and ya) xor (xa and yb) xor (xa and ya) xor (xb and m) xor (m and yb) xor m;
end dataflow;

-- and_3TI_b

library ieee;
use ieee.std_logic_1164.ALL;

entity and_3TI_b is
    port (
	xa, xb, ya, yb, m  : in  std_logic;
	o		: out std_logic
	);

end entity and_3TI_b;

architecture dataflow of and_3TI_b is
begin
	o <= (xb and ya) xor (xa and yb) xor (xa and ya) xor (xa and m) xor (m and ya);
end dataflow;

-- and_3TI_c

library ieee;
use ieee.std_logic_1164.ALL;

entity and_3TI_c is
    port (
	xa, xb, ya, yb, m  : in  std_logic;
	o		: out std_logic
	);

end entity and_3TI_c;

architecture dataflow of and_3TI_c is
begin
	o <= (xa and ya) xor (xb and ya) xor (xa and yb) xor m;
end dataflow;

-- and_3TI

library ieee;
use ieee.std_logic_1164.ALL;

entity and_3TI is
    port (
	xa, xb, xc, ya, yb, yc, m  : in  std_logic;
	o1, o2, o3		: out std_logic
	);

end entity and_3TI;

architecture structural of and_3TI is
begin
	
anda: entity work.and_3TI_a(dataflow)
	port map(
	xa => xb,
	xb => xc,
	m => m,
	ya => yb, 
	yb => yc,
	o  => o1
	);

andb: entity work.and_3TI_b(dataflow)
	port map(
	xa => xc,
	xb => xa,
	m => m,
	ya => yc, 
	yb => ya,
	o  => o2
	);

andc: entity work.and_3TI_c(dataflow)
	port map(
	xa => xa,
	xb => xb,
	m => m,
	ya => ya, 
	yb => yb,
	o  => o3
	);

end structural;

library ieee;
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all; 
use work.utility_functions.all;

entity KSA_mod is
generic (n : integer:=32);
port(
	a_s1, a_s2, a_s3: in std_logic_vector(n-1 downto 0);
	b_s1, b_s2, b_s3: in std_logic_vector(n-1 downto 0);
	m_val : in std_logic_vector(63 downto 0);
	clk, start: in std_logic;
	s_s1, s_s2, s_s3: out std_logic_vector(n-1 downto 0);
	done: out std_logic
	);

end KSA_mod;

architecture behavioral of KSA_mod is

    constant log2_ceil_result : integer := 5;       -- For 32 bit KSA

    signal p_s1, g_s1 : pg_array_type;
    signal p_s2, g_s2 : pg_array_type;
    signal p_s3, g_s3 : pg_array_type;
    
    signal pReg_s1, gReg_s1 : pg_array_type;
    signal pReg_s2, gReg_s2 : pg_array_type;
    signal pReg_s3, gReg_s3 : pg_array_type;
    
    signal tmp_s1, tmp_s2, tmp_s3 : pg_array_type;
    
    signal stage_0_en, stage_1_en, stage_2_en, stage_3_en, stage_4_en, stage_5_en : std_logic;
    
    type ksa_state is (IDLE, STAGE_1, STAGE_2, STAGE_3, STAGE_4, STAGE_5);
        signal current_state : ksa_state;
        signal next_state : ksa_state;
    
begin

    public : process(start, current_state) begin
        
        -- Defaults:
        stage_0_en <= '0';
        stage_1_en <= '0';
        stage_2_en <= '0';
        stage_3_en <= '0';
        stage_4_en <= '0';
        stage_5_en <= '0';
        
        case current_state is
        when IDLE =>
            next_state <= IDLE;
            if (start = '1') then
                stage_0_en <= '1';
                next_state <= STAGE_1;
            end if;
            
        when STAGE_1 =>
            stage_1_en <= '1';
            next_state <= STAGE_2;
            
        when STAGE_2 =>
            stage_2_en <= '1';
            next_state <= STAGE_3;
            
        when STAGE_3 =>
            stage_3_en <= '1';
            next_state <= STAGE_4;
            
        when STAGE_4 =>
            stage_4_en <= '1';
            next_state <= STAGE_5;
            
        when STAGE_5 =>
            stage_5_en <= '1';
            next_state <= IDLE;
        
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
    
    done_process: process(clk)
    begin
    if (rising_edge(clk)) then
        done <= '0';
        if (stage_5_en = '1') then
            done <= '1';
        end if;
    end if;    
    end process;
    
    -- REGISTERS
    
    reg_0g_s1 : entity work.reg32(behavioral)
    port map(
        d => g_s1(0),
        e => stage_0_en,
        clk => clk,
        q => gReg_s1(0)
    );

    reg_0p_s1 : entity work.reg32(behavioral)
    port map(
        d => p_s1(0),
        e => stage_0_en,
        clk => clk,
        q => pReg_s1(0)
    );
    
    reg_0g_s2 : entity work.reg32(behavioral)
    port map(
        d => g_s2(0),
        e => stage_0_en,
        clk => clk,
        q => gReg_s2(0)
    );

    reg_0p_s2 : entity work.reg32(behavioral)
    port map(
        d => p_s2(0),
        e => stage_0_en,
        clk => clk,
        q => pReg_s2(0)
    );
    
    reg_0g_s3 : entity work.reg32(behavioral)
    port map(
        d => g_s3(0),
        e => stage_0_en,
        clk => clk,
        q => gReg_s3(0)
    );

    reg_0p_s3 : entity work.reg32(behavioral)
    port map(
        d => p_s3(0),
        e => stage_0_en,
        clk => clk,
        q => pReg_s3(0)
    );
    
    reg_1g_s1 : entity work.reg32(behavioral)
    port map(
        d => g_s1(1),
        e => stage_1_en,
        clk => clk,
        q => gReg_s1(1)
    );

    reg_1p_s1 : entity work.reg32(behavioral)
    port map(
        d => p_s1(1),
        e => stage_1_en,
        clk => clk,
        q => pReg_s1(1)
    );
    
    reg_1g_s2 : entity work.reg32(behavioral)
    port map(
        d => g_s2(1),
        e => stage_1_en,
        clk => clk,
        q => gReg_s2(1)
    );

    reg_1p_s2 : entity work.reg32(behavioral)
    port map(
        d => p_s2(1),
        e => stage_1_en,
        clk => clk,
        q => pReg_s2(1)
    );
    
    reg_1g_s3 : entity work.reg32(behavioral)
    port map(
        d => g_s3(1),
        e => stage_1_en,
        clk => clk,
        q => gReg_s3(1)
    );

    reg_1p_s3 : entity work.reg32(behavioral)
    port map(
        d => p_s3(1),
        e => stage_1_en,
        clk => clk,
        q => pReg_s3(1)
    );
    
    reg_2g_s1 : entity work.reg32(behavioral)
    port map(
        d => g_s1(2),
        e => stage_2_en,
        clk => clk,
        q => gReg_s1(2)
    );

    reg_2p_s1 : entity work.reg32(behavioral)
    port map(
        d => p_s1(2),
        e => stage_2_en,
        clk => clk,
        q => pReg_s1(2)
    );
    
    reg_2g_s2 : entity work.reg32(behavioral)
    port map(
        d => g_s2(2),
        e => stage_2_en,
        clk => clk,
        q => gReg_s2(2)
    );

    reg_2p_s2 : entity work.reg32(behavioral)
    port map(
        d => p_s2(2),
        e => stage_2_en,
        clk => clk,
        q => pReg_s2(2)
    );
    
    reg_2g_s3 : entity work.reg32(behavioral)
    port map(
        d => g_s3(2),
        e => stage_2_en,
        clk => clk,
        q => gReg_s3(2)
    );

    reg_2p_s3 : entity work.reg32(behavioral)
    port map(
        d => p_s3(2),
        e => stage_2_en,
        clk => clk,
        q => pReg_s3(2)
    );
    
    reg_3g_s1 : entity work.reg32(behavioral)
    port map(
        d => g_s1(3),
        e => stage_3_en,
        clk => clk,
        q => gReg_s1(3)
    );

    reg_3p_s1 : entity work.reg32(behavioral)
    port map(
        d => p_s1(3),
        e => stage_3_en,
        clk => clk,
        q => pReg_s1(3)
    );
    
    reg_3g_s2 : entity work.reg32(behavioral)
    port map(
        d => g_s2(3),
        e => stage_3_en,
        clk => clk,
        q => gReg_s2(3)
    );

    reg_3p_s2 : entity work.reg32(behavioral)
    port map(
        d => p_s2(3),
        e => stage_3_en,
        clk => clk,
        q => pReg_s2(3)
    );
    
    reg_3g_s3 : entity work.reg32(behavioral)
    port map(
        d => g_s3(3),
        e => stage_3_en,
        clk => clk,
        q => gReg_s3(3)
    );

    reg_3p_s3 : entity work.reg32(behavioral)
    port map(
        d => p_s3(3),
        e => stage_3_en,
        clk => clk,
        q => pReg_s3(3)
    );
    
    reg_4g_s1 : entity work.reg32(behavioral)
    port map(
        d => g_s1(4),
        e => stage_4_en,
        clk => clk,
        q => gReg_s1(4)
    );

    reg_4p_s1 : entity work.reg32(behavioral)
    port map(
        d => p_s1(4),
        e => stage_4_en,
        clk => clk,
        q => pReg_s1(4)
    );
    
    reg_4g_s2 : entity work.reg32(behavioral)
    port map(
        d => g_s2(4),
        e => stage_4_en,
        clk => clk,
        q => gReg_s2(4)
    );

    reg_4p_s2 : entity work.reg32(behavioral)
    port map(
        d => p_s2(4),
        e => stage_4_en,
        clk => clk,
        q => pReg_s2(4)
    );
    
    reg_4g_s3 : entity work.reg32(behavioral)
    port map(
        d => g_s3(4),
        e => stage_4_en,
        clk => clk,
        q => gReg_s3(4)
    );

    reg_4p_s3 : entity work.reg32(behavioral)
    port map(
        d => p_s3(4),
        e => stage_4_en,
        clk => clk,
        q => pReg_s3(4)
    );

    reg_5p_s1 : entity work.reg32(behavioral)
	port map(
        d => p_s1(5),
        e => stage_5_en,
        clk => clk,
        q => pReg_s1(5)
	);
	
	reg_5g_s1 : entity work.reg32(behavioral)
	port map(
        d => g_s1(5),
        e => stage_5_en,
        clk => clk,
        q => gReg_s1(5)
	);
	
	reg_5p_s2 : entity work.reg32(behavioral)
	port map(
        d => p_s2(5),
        e => stage_5_en,
        clk => clk,
        q => pReg_s2(5)
	);
	
	reg_5g_s2 : entity work.reg32(behavioral)
	port map(
        d => g_s2(5),
        e => stage_5_en,
        clk => clk,
        q => gReg_s2(5)
	);
	
	reg_5p_s3 : entity work.reg32(behavioral)
	port map(
        d => p_s3(5),
        e => stage_5_en,
        clk => clk,
        q => pReg_s3(5)
	);
	
	reg_5g_s3 : entity work.reg32(behavioral)
	port map(
        d => g_s3(5),
        e => stage_5_en,
        clk => clk,
        q => gReg_s3(5)
	);

    
    -- Stage 0: Preprocessing (carry generation and propagation with mask refresh)
    
    pg: for j in 0 to n-1 generate

        p_s1(0)(j) <= a_s1(j) xor b_s1(j);      -- Share 1
        p_s2(0)(j) <= a_s2(j) xor b_s2(j);      -- Share 2
        p_s3(0)(j) <= a_s3(j) xor b_s3(j);      -- Share 3

        and_3TI_preprocess : entity work.and_3TI(structural)
        port map(
            xa => a_s1(j),
            xb => a_s2(j),
            xc => a_s3(j),
            ya => b_s1(j),
            yb => b_s2(j),
            yc => b_s3(j),
            m => m_val(j),
            o1 => g_s1(0)(j),
            o2 => g_s2(0)(j),
            o3 => g_s3(0)(j)
        );
    
    end generate pg;
    
    -- Stage 1: Calculate row 1 

    g_s1(1)(0) <= gReg_s1(0)(0);        -- Share 1
    p_s1(1)(0) <= pReg_s1(0)(0);
    
    g_s2(1)(0) <= gReg_s2(0)(0);        -- Share 2
    p_s2(1)(0) <= pReg_s2(0)(0);
        
    g_s3(1)(0) <= gReg_s3(0)(0);        -- Share 3
    p_s3(1)(0) <= pReg_s3(0)(0);

    s1_j: for j in 1 to n-1 generate
    
        and_3TI_stage_1_1 : entity work.and_3TI(structural)
        port map(
            xa => gReg_s1(0)(j-1),
            xb => gReg_s2(0)(j-1),
            xc => gReg_s3(0)(j-1),
            ya => pReg_s1(0)(j),
            yb => pReg_s2(0)(j),
            yc => pReg_s3(0)(j),
            m => m_val(j),
            o1 => tmp_s1(1)(j),
            o2 => tmp_s2(1)(j),
            o3 => tmp_s3(1)(j)
        );
        
        and_3TI_stage_1_2 : entity work.and_3TI(structural)
        port map(
            xa => pReg_s1(0)(j),
            xb => pReg_s2(0)(j),
            xc => pReg_s3(0)(j),
            ya => pReg_s1(0)(j-1),
            yb => pReg_s2(0)(j-1),
            yc => pReg_s3(0)(j-1),
            m => m_val(j+32),
            o1 => p_s1(1)(j),
            o2 => p_s2(1)(j),
            o3 => p_s3(1)(j)
        );
    
        g_s1(1)(j) <= gReg_s1(0)(j) xor tmp_s1(1)(j);
        g_s2(1)(j) <= gReg_s2(0)(j) xor tmp_s2(1)(j);
        g_s3(1)(j) <= gReg_s3(0)(j) xor tmp_s3(1)(j);

    end generate s1_j;

    -- Stages 2 to log2(n): Calculate rows 2-log2(n)

    si: for i in 2 to log2_ceil_result generate

        si_k: for k in 0 to 2**(i-1)-1 generate
            g_s1(i)(k) <= gReg_s1(i-1)(k);
            g_s2(i)(k) <= gReg_s2(i-1)(k);
            g_s3(i)(k) <= gReg_s3(i-1)(k);
            
            p_s1(i)(k) <= pReg_s1(i-1)(k);
            p_s2(i)(k) <= pReg_s2(i-1)(k);
            p_s3(i)(k) <= pReg_s3(i-1)(k);
        end generate si_k;

        si_j: for j in 2**(i-1) to n-1 generate

            and_3TI_stage_x_1 : entity work.and_3TI(structural)
            port map(
                xa => gReg_s1(i-1)(j-2**(i-1)),
                xb => gReg_s2(i-1)(j-2**(i-1)),
                xc => gReg_s3(i-1)(j-2**(i-1)),
                ya => pReg_s1(i-1)(j),
                yb => pReg_s2(i-1)(j),
                yc => pReg_s3(i-1)(j),
                m => m_val(j),
                o1 => tmp_s1(i)(j),
                o2 => tmp_s2(i)(j),
                o3 => tmp_s3(i)(j)
            ); 
            
            and_3TI_stage_x_2 : entity work.and_3TI(structural)
            port map(
                xa => pReg_s1(i-1)(j),
                xb => pReg_s2(i-1)(j),
                xc => pReg_s3(i-1)(j),
                ya => pReg_s1(i-1)(j-2**(i-1)),
                yb => pReg_s2(i-1)(j-2**(i-1)),
                yc => pReg_s3(i-1)(j-2**(i-1)),
                m => m_val(j+32),
                o1 => p_s1(i)(j),
                o2 => p_s2(i)(j),
                o3 => p_s3(i)(j)
            ); 
            
            g_s1(i)(j) <= gReg_s1(i-1)(j) xor tmp_s1(i)(j); 
            g_s2(i)(j) <= gReg_s2(i-1)(j) xor tmp_s2(i)(j); 
            g_s3(i)(j) <= gReg_s3(i-1)(j) xor tmp_s3(i)(j);
                    
        end generate si_j;

    end generate si;

    -- Addition stage: 

    s_s1(0) <= a_s1(0) xor b_s1(0);
    s_s2(0) <= a_s2(0) xor b_s2(0);
    s_s3(0) <= a_s3(0) xor b_s3(0);
    
    m1: for i in 1 to n-1 generate
        s_s1(i) <= a_s1(i) xor b_s1(i) xor gReg_s1(log2_ceil_result)(i-1); 
        s_s2(i) <= a_s2(i) xor b_s2(i) xor gReg_s2(log2_ceil_result)(i-1); 
        s_s3(i) <= a_s3(i) xor b_s3(i) xor gReg_s3(log2_ceil_result)(i-1); 
    end generate m1;

end behavioral;
