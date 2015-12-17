--
-- vid_debayer.vhd
--
-- Video - Simple bilinear debayering
--
--
-- Copyright (C) 2015  Sylvain Munaut <tnt@246tNt.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- vim: ts=4 sw=4
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.utils_pkg.all;


entity vid_debayer is
	port (
		-- Input
		in_data		: in  std_logic_vector(9 downto 0);
		in_last		: in  std_logic;
		in_sof		: in  std_logic;
		in_valid	: in  std_logic;

		-- Output
		out_red		: out std_logic_vector(7 downto 0);
		out_green	: out std_logic_vector(7 downto 0);
		out_blue	: out std_logic_vector(7 downto 0);
		out_last	: out std_logic;
		out_sof		: out std_logic;
		out_valid	: out std_logic;

		-- Polarity config
		pol_col		: in  std_logic;
		pol_line	: in  std_logic;

		-- Clock / Reset
		clk			: in  std_logic;
		rst			: in  std_logic
	);
end vid_debayer;


architecture rtl of vid_debayer is

    COMPONENT tdp_3072x18_bram IS
        PORT (
            clka    : IN STD_LOGIC;
            wea     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra   : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            dina    : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
            douta   : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
            clkb    : IN STD_LOGIC;
            web     : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addrb   : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            dinb    : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
            doutb   : OUT STD_LOGIC_VECTOR(17 DOWNTO 0)
        );
    END COMPONENT tdp_3072x18_bram;

	-- Flags
	signal valid_x		: std_logic_vector(0 to 4);
	signal last_x		: std_logic_vector(0 to 4);
	signal sof_x		: std_logic_vector(0 to 4);

	signal sel_col_3	: std_logic;
	signal sel_line_3	: std_logic;

	-- Line buffer
	signal lbuf_raddr_1	: std_logic_vector(11 downto 0);
	signal lbuf_waddr_3	: std_logic_vector(11 downto 0);
	signal lbuf_rdata_3	: std_logic_vector(17 downto 0);
	signal lbuf_wdata_3 : std_logic_vector(17 downto 0);
	signal lbuf_wen_3	: std_logic_vector(0  downto 0);

	-- Column buffer
	signal pix_l0c0_3	: std_logic_vector(8 downto 0);
	signal pix_l0c1_3	: std_logic_vector(8 downto 0);
	signal pix_l0c2_3	: std_logic_vector(8 downto 0);
	signal pix_l1c0_3	: std_logic_vector(8 downto 0);
	signal pix_l1c1_3	: std_logic_vector(8 downto 0);
	signal pix_l1c2_3	: std_logic_vector(8 downto 0);
	signal pix_l2c0_3	: std_logic_vector(8 downto 0);
	signal pix_l2c1_3	: std_logic_vector(8 downto 0);
	signal pix_l2c2_3	: std_logic_vector(8 downto 0);

	signal pix_l1c02_3	: std_logic_vector(9 downto 0);
	signal pix_l02c0_3	: std_logic_vector(9 downto 0);
	signal pix_l02c1_3	: std_logic_vector(9 downto 0);
	signal pix_l02c2_3	: std_logic_vector(9 downto 0);

	-- Interpolated pixels
	signal pix_red_4	: std_logic_vector(10 downto 0);
	signal pix_green_4	: std_logic_vector(10 downto 0);
	signal pix_blue_4	: std_logic_vector(10 downto 0);

begin

	-- Control
	------------

	-- Valid / Flags propagation
	valid_x(0) <= in_valid;
	last_x(0)  <= in_last;
	sof_x(0)   <= in_sof;

	process (clk)
	begin
		if rising_edge(clk) then
			valid_x(1 to 4) <= valid_x(0 to 3);
			last_x(1 to 4)  <= last_x(0 to 3);
			sof_x(1 to 4)   <= sof_x(0 to 3);
		end if;
	end process;

	-- Column / Line selection tracking
	process (clk)
	begin
		if rising_edge(clk) then
			if (valid_x(2) = '1' and sof_x(2) = '1') then
				sel_col_3  <= pol_col;
				sel_line_3 <= pol_line;
			elsif valid_x(3) = '1' then
				sel_col_3  <= (pol_col and last_x(3)) or (not sel_col_3 and not last_x(3));
				sel_line_3 <= sel_line_3 xor last_x(3);
			end if;
		end if;
	end process;


	-- Line buffer
	----------------

    line_buf_I : tdp_3072x18_bram
    port map (
      clka   =>  clk,
      wea    =>  lbuf_wen_3,
      addra  =>  lbuf_waddr_3,
      dina   =>  lbuf_wdata_3,
      douta  =>  open,        
      clkb   =>  clk,         
      web    =>  (others => '0'),
      addrb  =>  lbuf_raddr_1, 
      dinb   =>  (others => '0'),
      doutb  =>  lbuf_rdata_3
    );

	-- Control
	lbuf_wen_3(0) <= valid_x(3);

	-- Address generation
	process (clk)
	begin
		if rising_edge(clk) then
			if (sof_x(0) = '1'  and valid_x(0) = '1') or
			   (last_x(1) = '1' and valid_x(1) = '1') then
				lbuf_raddr_1 <= (others => '0');
			elsif valid_x(1) = '1' then
				lbuf_raddr_1 <= lbuf_raddr_1 + 1;
			end if;
		end if;
	end process;

	addr_dly_I: delay_bus
		generic map (
			DELAY => 2,
			WIDTH => 12
		)
		port map (
			d   => lbuf_raddr_1,
			q   => lbuf_waddr_3,
			qp  => open,
			clk => clk
		);

	-- Data
	data_dly_I: delay_bus
		generic map (
			DELAY => 3,
			WIDTH => 9
		)
		port map (
			d   => in_data(9 downto 1),
			q	=> lbuf_wdata_3(8 downto 0),
			qp  => open,
			clk => clk
		);

	lbuf_wdata_3(17 downto 9) <= lbuf_rdata_3(8 downto 0);

	pix_l0c2_3 <= lbuf_rdata_3(17 downto 9);
	pix_l1c2_3 <= lbuf_rdata_3( 8 downto 0);
	pix_l2c2_3 <= lbuf_wdata_3( 8 downto 0);


	-- Column buffer
	------------------

	process (clk)
	begin
		if rising_edge(clk) then
			if valid_x(3) = '1' then
				pix_l0c0_3 <= pix_l0c1_3;
				pix_l0c1_3 <= pix_l0c2_3;
				pix_l1c0_3 <= pix_l1c1_3;
				pix_l1c1_3 <= pix_l1c2_3;
				pix_l2c0_3 <= pix_l2c1_3;
				pix_l2c1_3 <= pix_l2c2_3;
			end if;
		end if;
	end process;


	-- Color interpolation
	------------------------

	-- Prepare some sums
	pix_l1c02_3 <= ('0' & pix_l1c0_3) + ('0' & pix_l1c2_3);
	pix_l02c2_3 <= ('0' & pix_l0c2_3) + ('0' & pix_l2c2_3);

	process (clk)
	begin
		if rising_edge(clk) then
			if valid_x(3) = '1' then
				pix_l02c0_3 <= pix_l02c1_3;
				pix_l02c1_3 <= pix_l02c2_3;
			end if;
		end if;
	end process;

	-- Green
	process (clk)
	begin
		if rising_edge(clk) then
			if (sel_col_3 xor sel_line_3) = '1' then
				pix_green_4 <= pix_l1c1_3 & "00";
			else
				pix_green_4 <= ('0' & (('0' & pix_l1c0_3) + ('0' & pix_l1c2_3))) + ('0' & pix_l02c1_3);
			end if;
		end if;
	end process;

	-- Red
	process (clk)
	begin
		if rising_edge(clk) then
			if (sel_col_3 = '0') and (sel_line_3 = '0') then
				pix_red_4 <= pix_l1c1_3 & "00";
			elsif (sel_col_3 = '1') and (sel_line_3 = '0') then
				pix_red_4 <= (('0' & pix_l1c0_3) + ('0' & pix_l1c2_3)) & '0';
			elsif (sel_col_3 = '0') and (sel_line_3 = '1') then
				pix_red_4 <= pix_l02c1_3 & '0';
			else -- (sel_col_3 = '1') and (sel_line_3 = '1')
				pix_red_4 <= ('0' & pix_l02c0_3) + ('0' & pix_l02c2_3);
			end if;
		end if;
	end process;

	-- Blue
	process (clk)
	begin
		if rising_edge(clk) then
			if (sel_col_3 = '0') and (sel_line_3 = '0') then
				pix_blue_4 <= ('0' & pix_l02c0_3) + ('0' & pix_l02c2_3);
			elsif (sel_col_3 = '1') and (sel_line_3 = '0') then
				pix_blue_4 <= pix_l02c1_3 & '0';
			elsif (sel_col_3 = '0') and (sel_line_3 = '1') then
				pix_blue_4 <= (('0' & pix_l1c0_3) + ('0' & pix_l1c2_3)) & '0';
			else -- (sel_col_3 = '1') and (sel_line_3 = '1')
				pix_blue_4 <= pix_l1c1_3 & "00";
			end if;
		end if;
	end process;


	-- Output
	-----------

	out_red   <= pix_red_4(10 downto 3);
	out_green <= pix_green_4(10 downto 3);
	out_blue  <= pix_blue_4(10 downto 3);
	out_last  <= last_x(4);
	out_sof   <= sof_x(4);
	out_valid <= valid_x(4);

end rtl;
