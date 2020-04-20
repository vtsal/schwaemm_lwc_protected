--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
--! @brief      Implementation of the dummy_lwc cipher and hash.
--!
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology     
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             —unrestricted)                                                  
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;


entity CryptoCore is
    Port (
        clk             : in   STD_LOGIC;
        rst             : in   STD_LOGIC;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key_a           : in   STD_LOGIC_VECTOR (CCSW      -1 downto 0);
        key_b           : in   STD_LOGIC_VECTOR (CCSW      -1 downto 0);
        key_c           : in   STD_LOGIC_VECTOR (CCSW      -1 downto 0);
        key_valid       : in   STD_LOGIC;
        key_ready       : out  STD_LOGIC;
        ----!Data----------------------------------------------------
        bdi_a           : in   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdi_b           : in   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdi_c           : in   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdi_valid       : in   STD_LOGIC;
        bdi_ready       : out  STD_LOGIC;
        --bdi_partial     : in   STD_LOGIC;
        bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
        bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
        bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
        bdi_eot         : in   STD_LOGIC;
        bdi_eoi         : in   STD_LOGIC;
        bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
        decrypt_in      : in   STD_LOGIC;
        hash_in         : in   STD_LOGIC;
        key_update      : in   STD_LOGIC;
        --!Post Processor=========================================
        bdo_a           : out   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdo_b           : out   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdo_c           : out   STD_LOGIC_VECTOR (CCW       -1 downto 0);
        bdo_valid       : out  STD_LOGIC;
        bdo_ready       : in   STD_LOGIC;
        bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
        bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
        end_of_block    : out  STD_LOGIC;
        msg_auth        : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in  std_logic;
        --!Random=================================================
        rdi_data        : in std_logic_vector(RW - 1 downto 0)
    );
end CryptoCore;

architecture behavioral of CryptoCore is
begin

    crypto_core_controller : entity work.controller(behavioral)
	port map (
        clk => clk,
        rst => rst,
        
        m_val => rdi_data,
    
        key_a => key_a,
        key_b => key_b,
        key_c => key_c,
        key_valid => key_valid,
        key_ready => key_ready,
        
        bdi_a => bdi_a,
        bdi_b => bdi_b,
        bdi_c => bdi_c,
        bdi_valid => bdi_valid,
        bdi_ready => bdi_ready,
        bdi_pad_loc => bdi_pad_loc,
        bdi_valid_bytes => bdi_valid_bytes,
        
        bdi_size => bdi_size,
        bdi_eot => bdi_eot,
        bdi_eoi => bdi_eoi,
        bdi_type => bdi_type,
        decrypt => decrypt_in,
        key_update => key_update,
        
        bdo_a => bdo_a,
        bdo_b => bdo_b,
        bdo_c => bdo_c,
        bdo_valid => bdo_valid,
        bdo_ready => bdo_ready,
        end_of_block => end_of_block, 
        bdo_valid_bytes => bdo_valid_bytes,
        bdo_type => bdo_type,
        
        msg_auth => msg_auth, 
        msg_auth_valid => msg_auth_valid, 
        msg_auth_ready => msg_auth_ready
        );

end behavioral;
