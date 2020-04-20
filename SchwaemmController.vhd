----------------------------------------------------------------------------------
-- Code based on NIST LWC Schwaemm256128
-- 3/20/2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.utility_functions.ALL;
use work.NIST_LWAPI_pkg.ALL;

entity controller is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        
        m_val : in std_logic_vector(63 downto 0);
    
        key_a : in std_logic_vector(31 downto 0);
        key_b : in std_logic_vector(31 downto 0);
        key_c : in std_logic_vector(31 downto 0);
        key_valid : in std_logic;
        key_ready : out std_logic;
        
        bdi_a : in std_logic_vector(31 downto 0);
        bdi_b : in std_logic_vector(31 downto 0);
        bdi_c : in std_logic_vector(31 downto 0);
        bdi_valid : in std_logic;
        bdi_ready : out std_logic;
        bdi_pad_loc : in std_logic_vector(3 downto 0);
        bdi_valid_bytes : in std_logic_vector(3 downto 0);
        
        bdi_size : in std_logic_vector(2 downto 0);
        bdi_eot : in std_logic;
        bdi_eoi : in std_logic;
        bdi_type : in std_logic_vector(3 downto 0);
        decrypt : in std_logic;
        key_update : in std_logic;
        
        bdo_a : out std_logic_vector(31 downto 0);
        bdo_b : out std_logic_vector(31 downto 0);
        bdo_c : out std_logic_vector(31 downto 0);
        bdo_valid : out std_logic;
        bdo_ready : in std_logic;
        end_of_block : out std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0);
        bdo_type : out std_logic_vector(3 downto 0);
        
        msg_auth : out std_logic;
        msg_auth_valid : out std_logic;
        msg_auth_ready : in std_logic
    );
end controller;

architecture behavioral of controller is

    -- Controller states
    type controller_state is (IDLE, LOAD_KEY, LOAD_NPUB,
                              START_PERM, WAIT_PERM,
                              LOAD_BLK, LOAD_BLK_ZERO,
                              FINALIZE_DAT_OUT, OUTPUT_DAT_BLK, 
                              LOAD_TAG, OUTPUT_TAG, VERIFY_TAG,
                              START_PERM_INIT);
    signal current_state : controller_state;
    signal next_state : controller_state;
    
    -- Input/Output word counter
    signal word_cntr_en, word_cntr_init : std_logic;
    signal word_counter : integer := 0;
    
    -- Signals to handle manipulation and storage of input words
    signal bdi_reg_en, key_reg_en : std_logic;
    signal bdi_pad_en, zero_fill : std_logic;

    -- Partial registers for storage of each word
    signal key_0_s1, key_1_s1, key_2_s1, key_3_s1: std_logic_vector(31 downto 0);
    signal bdi_p_s1, bdi_z_s1 : std_logic_vector(31 downto 0);
    signal bdi_0_s1, bdi_1_s1, bdi_2_s1, bdi_3_s1, bdi_4_s1, bdi_5_s1, bdi_6_s1, bdi_7_s1 : std_logic_vector(31 downto 0);
    
    signal key_0_s2, key_1_s2, key_2_s2, key_3_s2: std_logic_vector(31 downto 0);
    signal bdi_p_s2, bdi_z_s2 : std_logic_vector(31 downto 0);
    signal bdi_0_s2, bdi_1_s2, bdi_2_s2, bdi_3_s2, bdi_4_s2, bdi_5_s2, bdi_6_s2, bdi_7_s2 : std_logic_vector(31 downto 0);
    
    signal key_0_s3, key_1_s3, key_2_s3, key_3_s3: std_logic_vector(31 downto 0);
    signal bdi_p_s3, bdi_z_s3 : std_logic_vector(31 downto 0);
    signal bdi_0_s3, bdi_1_s3, bdi_2_s3, bdi_3_s3, bdi_4_s3, bdi_5_s3, bdi_6_s3, bdi_7_s3 : std_logic_vector(31 downto 0);
    
    -- Complete data storage registers
    signal bdi_blk_s1, bdi_blk_s2, bdi_blk_s3 : std_logic_vector(255 downto 0);
    signal key_reg_s1, key_reg_s2, key_reg_s3 : std_logic_vector(127 downto 0);
    
    -- Signals to handle storage
    signal store_dec, dec_reg : std_logic;
    signal store_lblk, lblk_reg, eoi_reg : std_logic;
    signal bdi_valid_bytes_reg : std_logic_vector(3 downto 0);
    signal bdi_pad_reg, store_pad_en : std_logic;
    signal lword_index : integer;
    
    -- BDO output signals
    signal bdo_out_reg_s1 : std_logic_vector(255 downto 0);
    signal bdo_out_reg_s2 : std_logic_vector(255 downto 0);
    signal bdo_out_reg_s3 : std_logic_vector(255 downto 0);
    signal bdo_current_s1, bdo_current_trunc_s1  : std_logic_vector(31 downto 0);
    signal bdo_current_s2, bdo_current_trunc_s2 : std_logic_vector(31 downto 0);
    signal bdo_current_s3, bdo_current_trunc_s3 : std_logic_vector(31 downto 0);
    signal bdo_out_sel, valid_bytes_sel, bdo_en : std_logic;
    signal bdo_valid_bytes_buf  : std_logic_vector(3 downto 0);
    
    -- Datapath signals
    signal feistel_out_s1 : std_logic_vector(383 downto 0);                     -- Feistel unit
    signal feistel_out_s2 : std_logic_vector(383 downto 0);
    signal feistel_out_s3 : std_logic_vector(383 downto 0);
    signal rho_rate_in_s1 : std_logic_vector(255 downto 0);                     -- Rho 1
    signal rho_rate_in_s2 : std_logic_vector(255 downto 0); 
    signal rho_rate_in_s3 : std_logic_vector(255 downto 0); 
    signal rho_out_s1, inv_rho_out_s1 : std_logic_vector(383 downto 0);         -- Rho 1, Inv rho
    signal rho_out_s2, inv_rho_out_s2 : std_logic_vector(383 downto 0);
    signal rho_out_s3, inv_rho_out_s3 : std_logic_vector(383 downto 0);
    signal rho_ct_out_s1 : std_logic_vector(383 downto 0);                      -- Rho 2
    signal rho_ct_out_s2 : std_logic_vector(383 downto 0);
    signal rho_ct_out_s3 : std_logic_vector(383 downto 0);
    signal padded_zero_pt_s1 : std_logic_vector(255 downto 0);                  -- Padded plaintext
    signal padded_zero_pt_s2 : std_logic_vector(255 downto 0); 
    signal padded_zero_pt_s3 : std_logic_vector(255 downto 0); 
    signal pad_const : std_logic_vector(31 downto 0);                           -- Pad constant
    signal inj_const_in_s1, inj_const_out_s1 : std_logic_vector(383 downto 0);  -- Inject constant unit
    signal inj_const_in_s2, inj_const_out_s2 : std_logic_vector(383 downto 0);
    signal inj_const_in_s3, inj_const_out_s3 : std_logic_vector(383 downto 0);
    signal rate_whiten_in_s1 : std_logic_vector(383 downto 0);
    signal state_init_input_s1, rate_whiten_out_s1 : std_logic_vector(383 downto 0);
    signal state_init_input_s2, rate_whiten_out_s2 : std_logic_vector(383 downto 0);
    signal state_init_input_s3, rate_whiten_out_s3 : std_logic_vector(383 downto 0);
    signal tag_s1 : std_logic_vector(127 downto 0);
    signal tag_s2 : std_logic_vector(127 downto 0);
    signal tag_s3 : std_logic_vector(127 downto 0);
    
    -- Datapath signal selects
    signal rho_rate_in_sel, inj_const_in_sel : std_logic;
    signal pad_const_sel : std_logic_vector(1 downto 0);
    signal ad_flag_in, ad_flag, store_ad_flag : std_logic;
    signal comp_tag, comp_tag_done : std_logic;
    
    -- Sparkle Permutation control signals: 
    signal perm_en, perm_complete : std_logic;
    signal num_steps : integer;
    signal state_sparkle_in_s1, state_sparkle_out_s1 : std_logic_vector(383 downto 0);
    signal state_sparkle_in_s2, state_sparkle_out_s2 : std_logic_vector(383 downto 0);
    signal state_sparkle_in_s3, state_sparkle_out_s3 : std_logic_vector(383 downto 0);
    signal sparkle_in_sel : std_logic;
       
begin

    -- Registers:
        
    bdi_valid_reg_unit: entity work.regGen(behavioral)
    generic map (width => 4)
    port map(
        d => bdi_valid_bytes,
	    e => store_lblk,
	    clk => clk,
	    q => bdi_valid_bytes_reg
    );
        
    ad_flag_reg_unit: entity work.regOne(behavioral)
    port map(
        d => ad_flag_in,
	    e => store_ad_flag,
	    clk => clk,
	    q => ad_flag
    );
    
    dec_flag_reg_unit: entity work.regOne(behavioral)
    port map(
        d => decrypt,
	    e => store_dec,
	    clk => clk,
	    q => dec_reg
    );
    
    eoi_reg_unit: entity work.regOne(behavioral)
    port map(
        d => bdi_eoi,
	    e => store_lblk,
	    clk => clk,
	    q => eoi_reg
    );
    
    bdi_pad_reg_unit: entity work.regOne(behavioral)
    port map(
        d => bdi_pad_en,
	    e => store_pad_en,
	    clk => clk,
	    q => bdi_pad_reg
    );
    
    eot_reg_unit: entity work.regOne(behavioral)
    port map(
        d => bdi_eot,
	    e => store_lblk,
	    clk => clk,
	    q => lblk_reg
    );
    
    lw_num_reg_unit: entity work.regNum(behavioral)
    port map(
        d => word_counter,
	    e => store_lblk,
	    clk => clk,
	    q => lword_index
    );
    
    -- Datapath units: 

    fesitel_unit: entity work.feistel_swap(structural) 
    port map(
        state_in_s1 => state_sparkle_out_s1,
        state_in_s2 => state_sparkle_out_s2,
        state_in_s3 => state_sparkle_out_s3,
        state_out_s1 => feistel_out_s1,
        state_out_s2 => feistel_out_s2,
        state_out_s3 => feistel_out_s3
    ); 
    
    rho_state_unit: entity work.rho(structural)
    port map(
        state_in_s1 => feistel_out_s1,      
        state_in_s2 => feistel_out_s2,      
        state_in_s3 => feistel_out_s3,      
        input_rate_s1 => rho_rate_in_s1,
        input_rate_s2 => rho_rate_in_s2,
        input_rate_s3 => rho_rate_in_s3,
        state_out_s1 => rho_out_s1,
        state_out_s2 => rho_out_s2,
        state_out_s3 => rho_out_s3
    ); 
    
    rho_ct_unit: entity work.rho(structural)
    port map(
        state_in_s1 => state_sparkle_out_s1,      
        state_in_s2 => state_sparkle_out_s2,      
        state_in_s3 => state_sparkle_out_s3,      
        input_rate_s1 => bdi_blk_s1,
        input_rate_s2 => bdi_blk_s2,
        input_rate_s3 => bdi_blk_s3,
        state_out_s1 => rho_ct_out_s1,
        state_out_s2 => rho_ct_out_s2,
        state_out_s3 => rho_ct_out_s3
    );
    
    inv_rho_unit: entity work.inv_rho(structural)
    port map(
        state_in_pre_feistel_s1 => state_sparkle_out_s1(383 downto 128),      
        state_in_pre_feistel_s2 => state_sparkle_out_s2(383 downto 128),      
        state_in_pre_feistel_s3 => state_sparkle_out_s3(383 downto 128),      
        state_in_post_feistel_s1 => feistel_out_s1,      
        state_in_post_feistel_s2 => feistel_out_s2,      
        state_in_post_feistel_s3 => feistel_out_s3,      
        input_rate_s1 => bdi_blk_s1,
        input_rate_s2 => bdi_blk_s2,
        input_rate_s3 => bdi_blk_s3,
        state_out_s1 => inv_rho_out_s1,
        state_out_s2 => inv_rho_out_s2,
        state_out_s3 => inv_rho_out_s3
    );
    
    inject_const: entity work.inject_constant(structural)
    port map(
        state_in_s1 => inj_const_in_s1,
        state_in_s2 => inj_const_in_s2,
        state_in_s3 => inj_const_in_s3,
        constant_value => pad_const,
        state_out_s1 => inj_const_out_s1,
        state_out_s2 => inj_const_out_s2,
        state_out_s3 => inj_const_out_s3
    );
    
    rate_white_unit: entity work.rate_whitening(structural)
    port map(
        state_in_s1 => rate_whiten_in_s1,
        state_in_s2 => inj_const_in_s2,
        state_in_s3 => inj_const_in_s3,
        state_out_s1 => rate_whiten_out_s1,
        state_out_s2 => rate_whiten_out_s2,
        state_out_s3 => rate_whiten_out_s3
    ); 
    
    perm_fsm: entity work.sparkle_permutation_fsm(behavioral)
    port map (
        clk => clk,
        rst => rst,
        perm_start => perm_en,
        num_steps => num_steps,
        m_val => m_val,
        state_in_s1 => state_sparkle_in_s1,
        state_in_s2 => state_sparkle_in_s2,
        state_in_s3 => state_sparkle_in_s3,
        state_out_s1 => state_sparkle_out_s1,
        state_out_s2 => state_sparkle_out_s2,
        state_out_s3 => state_sparkle_out_s3,
        perm_complete => perm_complete
    );
    
    tag_comparison_unit: entity work.compare_tag_pro(behavioral)
    port map (
        tag_in_s1 => bdi_blk_s1(127 downto 0),
        tag_in_s2 => bdi_blk_s2(127 downto 0),
        tag_in_s3 => bdi_blk_s3(127 downto 0),
	    tag_in_comp_s1 => tag_s1,
	    tag_in_comp_s2 => tag_s2,
	    tag_in_comp_s3 => tag_s3,
	    random_in => m_val,
	    clk => clk,
	    start_tag_compare => comp_tag,
	    done => comp_tag_done,
	    tag_match => msg_auth
        );
      
-- Handle BDI
bdi_z_s1 <= ZERO_W when (zero_fill = '1') else bdi_a;                                    -- Zero fill bdi word if needed
bdi_p_s1 <= padWordLoc(bdi_z_s1, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s1;     -- Pad bdi word if needed

bdi_z_s2 <= ZERO_W when (zero_fill = '1') else bdi_b;                                    -- Zero fill bdi word if needed
bdi_p_s2 <= padWordLoc(bdi_z_s2, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s2;     -- Pad bdi word if needed

bdi_z_s3 <= ZERO_W when (zero_fill = '1') else bdi_c;                                    -- Zero fill bdi word if needed
bdi_p_s3 <= padWordLoc(bdi_z_s3, bdi_pad_loc) when (bdi_pad_en = '1') else bdi_z_s3;     -- Pad bdi word if needed

-- Assign input key, nonce, tag, ad, and dat registers
key_reg_s1 <= key_0_s1 & key_1_s1 & key_2_s1 & key_3_s1;
key_reg_s2 <= key_0_s2 & key_1_s2 & key_2_s2 & key_3_s2;
key_reg_s3 <= key_0_s3 & key_1_s3 & key_2_s3 & key_3_s3;
bdi_blk_s1 <= bdi_0_s1 & bdi_1_s1 & bdi_2_s1 & bdi_3_s1 & bdi_4_s1 & bdi_5_s1 & bdi_6_s1 & bdi_7_s1;
bdi_blk_s2 <= bdi_0_s2 & bdi_1_s2 & bdi_2_s2 & bdi_3_s2 & bdi_4_s2 & bdi_5_s2 & bdi_6_s2 & bdi_7_s2;
bdi_blk_s3 <= bdi_0_s3 & bdi_1_s3 & bdi_2_s3 & bdi_3_s3 & bdi_4_s3 & bdi_5_s3 & bdi_6_s3 & bdi_7_s3;

-- Assign the intialization state input
state_init_input_s1 <= bdi_blk_s1 & key_reg_s1;
state_init_input_s2 <= bdi_blk_s2 & key_reg_s2;
state_init_input_s3 <= bdi_blk_s3 & key_reg_s3;
                             
-- Pad the computed plaintext to feed back into rho
padded_zero_pt_s1 <= zeroFillPt(rho_ct_out_s1(383 downto 128), lword_index, bdi_valid_bytes_reg);
padded_zero_pt_s2 <= zeroFillPt(rho_ct_out_s2(383 downto 128), lword_index, bdi_valid_bytes_reg);
padded_zero_pt_s3 <= zeroFillPt(rho_ct_out_s3(383 downto 128), lword_index, bdi_valid_bytes_reg);

-- Calculate tag
tag_s1 <= state_sparkle_out_s1(127 downto 0) xor key_reg_s1;
tag_s2 <= state_sparkle_out_s2(127 downto 0) xor key_reg_s2;
tag_s3 <= state_sparkle_out_s3(127 downto 0) xor key_reg_s3;

-- Flag to determine whether AD or DAT blocks are being processed 
ad_flag_in <= '1' when (bdi_type = HDR_AD) else '0';

-- MUX for sparkle input
with sparkle_in_sel select
state_sparkle_in_s1 <= state_init_input_s1  when '0', 
                       rate_whiten_out_s1 when '1',
                       state_init_input_s1 when others;

with sparkle_in_sel select
state_sparkle_in_s2 <= state_init_input_s2  when '0', 
                       rate_whiten_out_s2 when '1',
                       state_init_input_s2 when others;

with sparkle_in_sel select
state_sparkle_in_s3 <= state_init_input_s3  when '0', 
                       rate_whiten_out_s3 when '1',
                       state_init_input_s3 when others;
                    
-- MUX for rho state input
with rho_rate_in_sel select
rho_rate_in_s1 <= bdi_blk_s1 when '0',
               padded_zero_pt_s1 when '1',
               bdi_blk_s1 when others;

with rho_rate_in_sel select
rho_rate_in_s2 <= bdi_blk_s2 when '0',
               padded_zero_pt_s2 when '1',
               bdi_blk_s2 when others;

with rho_rate_in_sel select
rho_rate_in_s3 <= bdi_blk_s3 when '0',
               padded_zero_pt_s3 when '1',
               bdi_blk_s3 when others;

-- MUX for inject constant input       
with inj_const_in_sel select
inj_const_in_s1 <= rho_out_s1 when '0',
                   inv_rho_out_s1 when '1',
                   rho_out_s1 when others;
                   
with inj_const_in_sel select
inj_const_in_s2 <= rho_out_s2 when '0',
                   inv_rho_out_s2 when '1',
                   rho_out_s2 when others;

with inj_const_in_sel select
inj_const_in_s3 <= rho_out_s3 when '0',
                   inv_rho_out_s3 when '1',
                   rho_out_s3 when others;

-- MUX for Sparkle number of steps
with lblk_reg select
num_steps <= STEPS_BIG when '1',
             STEPS_SMALL when '0',
             0 when others;

-- MUX for rate whiten input selection (only apply inject constant to one share)
with lblk_reg select
rate_whiten_in_s1 <= inj_const_in_s1 when '0', 
                     inj_const_out_s1 when '1', 
                     inj_const_in_s1 when others;

-- MUX for pad constant select
with pad_const_sel select
pad_const <= PAD_AD_CONST when b"00", 
             NO_PAD_AD_CONST when b"01", 
             PAD_PT_CONST when b"10", 
             NO_PAD_PT_CONST when b"11", 
             ZERO_W when others;

-- MUX for bdo output (dat or tag)
with bdo_out_sel select
bdo_out_reg_s1 <= rho_ct_out_s1(383 downto 128) when '0', 
                  (tag_s1 & x"00000000000000000000000000000000") when '1',
                  rho_ct_out_s1(383 downto 128) when others;

with bdo_out_sel select
bdo_out_reg_s2 <= rho_ct_out_s2(383 downto 128) when '0', 
                  (tag_s2 & x"00000000000000000000000000000000") when '1',
                  rho_ct_out_s2(383 downto 128) when others;

with bdo_out_sel select
bdo_out_reg_s3 <= rho_ct_out_s3(383 downto 128) when '0', 
                  (tag_s3 & x"00000000000000000000000000000000") when '1',
                  rho_ct_out_s3(383 downto 128) when others;


-- MUX for bdo output (which word)
with word_counter select
bdo_current_s1 <= bdo_out_reg_s1(255 downto 224) when 0, 
       bdo_out_reg_s1(223 downto 192) when 1,
       bdo_out_reg_s1(191 downto 160) when 2,
       bdo_out_reg_s1(159 downto 128) when 3,
       bdo_out_reg_s1(127 downto 96) when 4,
       bdo_out_reg_s1(95 downto 64) when 5,
       bdo_out_reg_s1(63 downto 32) when 6,
       bdo_out_reg_s1(31 downto 0) when 7,
       ZERO_W when others;
       
with word_counter select
bdo_current_s2 <= bdo_out_reg_s2(255 downto 224) when 0, 
       bdo_out_reg_s2(223 downto 192) when 1,
       bdo_out_reg_s2(191 downto 160) when 2,
       bdo_out_reg_s2(159 downto 128) when 3,
       bdo_out_reg_s2(127 downto 96) when 4,
       bdo_out_reg_s2(95 downto 64) when 5,
       bdo_out_reg_s2(63 downto 32) when 6,
       bdo_out_reg_s2(31 downto 0) when 7,
       ZERO_W when others;
       
with word_counter select
bdo_current_s3 <= bdo_out_reg_s3(255 downto 224) when 0, 
       bdo_out_reg_s3(223 downto 192) when 1,
       bdo_out_reg_s3(191 downto 160) when 2,
       bdo_out_reg_s3(159 downto 128) when 3,
       bdo_out_reg_s3(127 downto 96) when 4,
       bdo_out_reg_s3(95 downto 64) when 5,
       bdo_out_reg_s3(63 downto 32) when 6,
       bdo_out_reg_s3(31 downto 0) when 7,
       ZERO_W when others;
       
-- MUX for bdo output valid bytes (all valid or bdi valid reg)
with valid_bytes_sel select
bdo_valid_bytes_buf <= VALID_WORD when '0', 
                   bdi_valid_bytes_reg when '1',
                   VALID_WORD when others;

-- Set the BDO valid bytes
bdo_valid_bytes <= bdo_valid_bytes_buf;

-- Truncate output words
bdo_current_trunc_s1 <= truncOut(bdo_current_s1, bdo_valid_bytes_buf);
bdo_current_trunc_s2 <= truncOut(bdo_current_s2, bdo_valid_bytes_buf);
bdo_current_trunc_s3 <= truncOut(bdo_current_s3, bdo_valid_bytes_buf);

register_input: process(clk)
begin
	if (rising_edge(clk)) then
        bdo_valid <= '0';
        if (key_reg_en = '1') then
            key_3_s1 <= littleEndianWord(key_a);
            key_2_s1 <= key_3_s1;
            key_1_s1 <= key_2_s1;
            key_0_s1 <= key_1_s1;
            key_3_s2 <= littleEndianWord(key_b);
            key_2_s2 <= key_3_s2;
            key_1_s2 <= key_2_s2;
            key_0_s2 <= key_1_s2;
            key_3_s3 <= littleEndianWord(key_c);
            key_2_s3 <= key_3_s3;
            key_1_s3 <= key_2_s3;
            key_0_s3 <= key_1_s3;
        end if;
        if (bdi_reg_en = '1') then
            bdi_7_s1 <= littleEndianWord(bdi_p_s1);
            bdi_6_s1 <= bdi_7_s1;
            bdi_5_s1 <= bdi_6_s1;
            bdi_4_s1 <= bdi_5_s1;
            bdi_3_s1 <= bdi_4_s1;
            bdi_2_s1 <= bdi_3_s1;
            bdi_1_s1 <= bdi_2_s1;
            bdi_0_s1 <= bdi_1_s1;
            
            bdi_7_s2 <= littleEndianWord(bdi_p_s2);
            bdi_6_s2 <= bdi_7_s2;
            bdi_5_s2 <= bdi_6_s2;
            bdi_4_s2 <= bdi_5_s2;
            bdi_3_s2 <= bdi_4_s2;
            bdi_2_s2 <= bdi_3_s2;
            bdi_1_s2 <= bdi_2_s2;
            bdi_0_s2 <= bdi_1_s2;
            
            bdi_7_s3 <= littleEndianWord(bdi_p_s3);
            bdi_6_s3 <= bdi_7_s3;
            bdi_5_s3 <= bdi_6_s3;
            bdi_4_s3 <= bdi_5_s3;
            bdi_3_s3 <= bdi_4_s3;
            bdi_2_s3 <= bdi_3_s3;
            bdi_1_s3 <= bdi_2_s3;
            bdi_0_s3 <= bdi_1_s3;
        end if;
        if (bdo_en = '1') then
            bdo_valid <= '1';
            bdo_a <= littleEndianWord(bdo_current_trunc_s1);
            bdo_b <= littleEndianWord(bdo_current_trunc_s2);
            bdo_c <= littleEndianWord(bdo_current_trunc_s3);
        end if;
    end if;
end process;

--compare_tag: process(comp_tag)
--begin
----    msg_auth <= '0';                    -- Default
----    if (comp_tag = '1') then            -- Perform tag comparison
----        if (tag(127 downto 96) = bdi_blk(127 downto 96)) and (tag(95 downto 64) = bdi_blk(95 downto 64)) and
----           (tag(63 downto 32) = bdi_blk(63 downto 32)) and (tag(31 downto 0) = bdi_blk(31 downto 0)) then
--            msg_auth <= '1';
----        end if;
----	end if;
--end process;

counter_process: process(clk)
begin
    if (rising_edge(clk)) then
        if (word_cntr_en = '1') then
            if (word_cntr_init = '1') then
                word_counter <= 0;
            else
                word_counter <= word_counter + 1;
            end if;
		end if;
	end if;
end process;
	
sync_process: process(clk)
begin
    if (rising_edge(clk)) then
        if (rst = '1') then
           current_state <= IDLE;
        else
           current_state <= next_state;
        end if;
    end if;
end process;

fsm_process: process(current_state, key_update, key_valid, bdi_valid, perm_complete, word_counter, bdi_eot, bdi_type, bdo_ready, comp_tag_done)
begin
 
    -- DEFAULTS:
    next_state <= current_state;            -- Default return to current state 
    perm_en <= '0';                         -- Sparkle permutation start flag
    comp_tag <= '0';                        -- Signal to enable tag comparison
    
    bdo_en <= '0';                          -- Output to postprocessor
    msg_auth_valid <= '0';
    end_of_block <= '0';
    
    key_ready <= '0';                       -- Output to preprocessor
    bdi_ready <= '0';
    
    bdi_pad_en <= '0';                      -- BDI/SDI signals
    zero_fill <= '0';
    bdi_reg_en <= '0';
    key_reg_en <= '0';
    
    word_cntr_init <= '0';                  -- Word counter
    word_cntr_en <= '0';
    
    store_lblk <= '0';                      -- Signals to enable storage
    store_dec <= '0';
    store_ad_flag <= '0';
    store_pad_en <= '0';
    
    rho_rate_in_sel <= '0';                 -- MUX select signals
    inj_const_in_sel <= '0';
    pad_const_sel <= b"00";
    sparkle_in_sel <= '0';
    bdo_out_sel <= '0';
    valid_bytes_sel <= '0';
            
    case current_state is
                     
        when IDLE => 
            if (key_valid = '1') and (key_update = '1') then
                    next_state <= LOAD_KEY;
            elsif (bdi_valid = '1') then
                if (bdi_type = HDR_NPUB) then
                    next_state <= LOAD_NPUB;
                end if;
            end if;
        
        when LOAD_KEY => 
            key_ready <= '1';                           -- Set output key ready signal
            if (key_valid = '1') then
                key_reg_en <= '1';                      -- Enable storage of each word
                word_cntr_en <= '1';                    -- Keep word counter enabled while loading key
             
                if (word_counter = KEY_SIZE - 1) then
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    word_cntr_en <= '1';
                    next_state <= IDLE;                     -- Return to IDLE to wait for NPUB
                end if;
            end if;
        
        when LOAD_NPUB => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            if (bdi_valid = '1') then
                bdi_reg_en <= '1';                          -- Enable storage of each word
                word_cntr_en <= '1';                        -- Keep word counter enabled while loading NPUB
                store_lblk <= '1';                          -- Enable storage of last block
                
                if (word_counter = BLK_SIZE - 1) then
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    store_dec <= '1';                       -- Enable storage of decrypt flag
                    next_state <= START_PERM_INIT;
                end if;
            end if;
        
        when START_PERM_INIT =>                         -- Handle starting permutation for initialization
            perm_en <= '1';                             -- Start permutation
            next_state <= WAIT_PERM;                    -- Update state to wait for completion
            
        when WAIT_PERM => 
            if (perm_complete = '1') then               -- Wait for completion
                if (eoi_reg = '1') then                 -- If end of input, handle tag based on enc or dec
                    if (dec_reg = '1') then
                        next_state <= LOAD_TAG;         -- If dec, then load tag from input
                    else
                        next_state <= OUTPUT_TAG;       -- If enc, then transition to outputting calculated tag
                        bdo_out_sel <= '1';             -- Select TAG for BDO output
                        bdo_en <= '1';                  -- Enable bdo output
                    end if;
                else                                    -- If NOT end of input, transition to loading AD or DAT
                    if (bdi_valid = '1') then
                        next_state <= LOAD_BLK;
                        store_ad_flag <= '1';           -- Store whether input is AD or DAT
                        store_pad_en <= '1';            -- Reset padding
                    end if;
                end if;
            end if;
              
        when LOAD_BLK => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            if (bdi_valid = '1') then
                bdi_reg_en <= '1';                          -- Enable storage of each word
                word_cntr_en <= '1';                        -- Keep word counter enabled while loading blk
                store_lblk <= '1';                          -- Enable storage of last block
                
                -- Handle padding of current word
                if (bdi_valid_bytes /= VALID_WORD) then
                    bdi_pad_en <= '1';                      -- If the current block is not all valid, enable padding
                    store_pad_en <= '1';
                end if;
                
                -- Handle end of input block
                if (word_counter = BLK_SIZE - 1) then       -- Full block loaded
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    if (ad_flag = '1') then                     -- If handling AD, start permutation
                        next_state <= START_PERM;
                    else
                        next_state <= FINALIZE_DAT_OUT;         -- If handling DAT, finalize output
                    end if;
                elsif (bdi_eot = '1') then                  -- Block still loading, handle incomplete last input block
                    next_state <= LOAD_BLK_ZERO;            -- Update state to zero fill
                end if;
            end if;
        
        when LOAD_BLK_ZERO => 
            bdi_reg_en <= '1';                          -- Enable storage of each word
            word_cntr_en <= '1';                        -- Keep word counter enabled while loading ad
            zero_fill <= '1';                           -- Enable zero fill for the rest of block
            
            -- Check previous word validity
            if (bdi_valid_bytes = VALID_WORD) then
                bdi_pad_en <= '1';                      -- Enable padding of zero-filled word
                store_pad_en <= '1';                    -- Store the padding flag
            end if;

            if (word_counter = BLK_SIZE - 1) then       -- Full block loaded
                word_cntr_init <= '1';                  -- Reset counter value to 0
                if (ad_flag = '1') then                     -- If handling AD, start permutation
                    next_state <= START_PERM;
                else
                    next_state <= FINALIZE_DAT_OUT;         -- If handling DAT, finalize output
                end if;
            end if;
                    
        when START_PERM =>
            sparkle_in_sel <= '1';                      -- Select rate whitening output for state input
            perm_en <= '1';                             -- Start permutation
            next_state <= WAIT_PERM;                    -- Update state to wait for completion

            -- Select the correct pad constant
            if (ad_flag = '1') then
                if (bdi_pad_reg = '1') then
                    pad_const_sel <= b"00";             -- Update pad constant select: PAD AD
                else
                    pad_const_sel <= b"01";             -- Update pad constant select: NO PAD AD
                end if;
            else
                if (bdi_pad_reg = '1') then
                    pad_const_sel <= b"10";             -- Update pad constant select: PAD DAT
                else
                    pad_const_sel <= b"11";             -- Update pad constant select: NO PAD DAT
                end if;
            end if;
            
            -- If decrypting completely valid full block use inv rho, else use rho with padded PT input
            -- Must be handling DAT blocks
            if (dec_reg = '1') then
                if (ad_flag /= '1') then
                    if (bdi_pad_reg = '0') then
                        inj_const_in_sel <= '1';
                    else
                        rho_rate_in_sel <= '1';
                    end if;
                end if;
            end if;
            
        when FINALIZE_DAT_OUT => 
            bdo_en <= '1';                              -- Enable output
            next_state <= OUTPUT_DAT_BLK;
            
        when OUTPUT_DAT_BLK => 
            bdo_en <= '1';                              -- Enable output
            if (bdo_ready = '1') then
                word_cntr_en <= '1';                        -- Keep word counter enabled while outputting data
       
                if (word_counter = lword_index) then    -- End of block
                    bdo_en <= '0';                          -- Enable output
                    valid_bytes_sel <= '1';                 -- Select bdi valid bytes reg for last word 
                    end_of_block <= '1';                    -- Indicate end of output block
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    next_state <= START_PERM;
                end if;
            end if;
            
        when LOAD_TAG => 
            bdi_ready <= '1';                           -- Set output bdi ready signal
            if (bdi_valid = '1') then
                bdi_reg_en <= '1';                          -- Enable storage of each word
                word_cntr_en <= '1';                        -- Keep word counter enabled while loading tag
                
                if (word_counter = TAG_SIZE - 1) then
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    next_state <= VERIFY_TAG;
                end if;
            end if;
                      
        when OUTPUT_TAG =>            
            bdo_out_sel <= '1';                         -- Select TAG for BDO output
            bdo_en <= '1';                              -- Enable output
            if (bdo_ready = '1') then
                word_cntr_en <= '1';                        -- Keep word counter enabled while outputting data

                if (word_counter = TAG_SIZE - 1) then          
                    end_of_block <= '1';                    -- Indicate end of output tag block
                    word_cntr_init <= '1';                  -- Reset counter value to 0
                    next_state <= IDLE;
                end if;
            end if;
        
        when VERIFY_TAG => 
            comp_tag <= '1';                            -- Enable tag comparison
            if (comp_tag_done = '1') then
                next_state <= IDLE;                         -- Return to IDLE state
                msg_auth_valid <= '1';                      -- Indicate msg auth output is valid
                comp_tag <= '0';
            end if;
            
        when others =>
            next_state <= IDLE;
            
    end case; 

end process;
end behavioral;
