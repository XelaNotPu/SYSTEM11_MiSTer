-- ZNMCU - ZN arcade input MCU emulation
-- The ZN board has a NEC uPD78081 MCU that handles coin/DSW/analog over SIO0.
-- It communicates through the PSX SIO0 serial interface alongside the CAT702 chips.
-- The BIOS selects the ZNMCU via znsecsel[1:0]=3; when selected, this device
-- responds with DSW bytes, frame counter, and coin/service status.
--
-- Protocol observed in MAME znmcu.cpp:
--   The host writes 0x00 (DSW poll) or 0x01 (analog/trackball poll) via SIO0.
--   MCU responds with: frame_count, dsw_byte, service/coin byte.
--
-- For ZN-1 Visco games we only need DSW + coin inputs; analog is unused.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity znmcu is
   port (
      clk         : in  std_logic;
      reset       : in  std_logic;
      -- SIO0 interface; selected when znsecsel=3 (both select lines low in ZN logic)
      selected    : in  std_logic;   -- active high: ZNMCU is the active device
      sio_clk     : in  std_logic;
      sio_datain  : in  std_logic;   -- byte from host, received LSB first
      sio_dataout : out std_logic;   -- byte to host, sent LSB first
      sio_ack     : out std_logic;   -- ack after each byte received
      -- Inputs
      dsw         : in  std_logic_vector(7 downto 0);  -- dip switches (active low)
      coin1       : in  std_logic;   -- active high
      coin2       : in  std_logic;
      service     : in  std_logic;
      -- Frame counter tick (pulse once per video frame for MCU internal counter)
      frame_tick  : in  std_logic
   );
end entity;

architecture arch of znmcu is

   -- SIO0 shift register: 8 bits, LSB first
   signal rx_shift   : std_logic_vector(7 downto 0) := (others => '0');
   signal tx_shift   : std_logic_vector(7 downto 0) := (others => '1');
   signal bit_cnt    : unsigned(3 downto 0) := (others => '0');
   signal prev_clk   : std_logic := '1';
   signal prev_sel   : std_logic := '0';

   signal frame_cnt  : unsigned(7 downto 0) := (others => '0');
   signal byte_idx   : unsigned(1 downto 0) := (others => '0');  -- which response byte
   signal ack_r      : std_logic := '0';

   -- Build the service/coin byte: bit7=service, bit6..5=coin2, bit4..3=coin1, rest=1
   function coin_byte(svc : std_logic; c1 : std_logic; c2 : std_logic)
      return std_logic_vector is
   begin
      return (not svc) & (not c2) & (not c2) & (not c1) & (not c1) & "111";
   end function;

begin

   sio_dataout <= tx_shift(0);
   sio_ack     <= ack_r;

   process(clk)
   begin
      if rising_edge(clk) then
         if reset = '1' then
            rx_shift <= (others => '0');
            tx_shift <= (others => '1');
            bit_cnt  <= (others => '0');
            byte_idx <= (others => '0');
            ack_r    <= '0';
            frame_cnt<= (others => '0');
         else
            ack_r <= '0';

            if frame_tick = '1' then
               frame_cnt <= frame_cnt + 1;
            end if;

            prev_clk <= sio_clk;
            prev_sel <= selected;

            -- De-selected: reset byte position
            if prev_sel = '1' and selected = '0' then
               byte_idx <= (others => '0');
               tx_shift <= (others => '1');
               bit_cnt  <= (others => '0');
            end if;

            if selected = '1' then

               -- Falling clock: shift out next TX bit
               if prev_clk = '1' and sio_clk = '0' then
                  tx_shift <= '1' & tx_shift(7 downto 1);
               end if;

               -- Rising clock: sample RX bit, advance counter
               if prev_clk = '0' and sio_clk = '1' then
                  rx_shift <= sio_datain & rx_shift(7 downto 1);
                  bit_cnt  <= bit_cnt + 1;

                  if bit_cnt = 7 then
                     -- Full byte received; prepare response for next byte
                     ack_r <= '1';
                     bit_cnt <= (others => '0');

                     case byte_idx is
                        when "00" =>
                           -- First response: frame counter
                           tx_shift <= std_logic_vector(frame_cnt);
                        when "01" =>
                           -- Second response: DSW
                           tx_shift <= dsw;
                        when "10" =>
                           -- Third response: coin/service byte
                           tx_shift <= coin_byte(service, coin1, coin2);
                        when others =>
                           tx_shift <= x"FF";
                     end case;

                     if byte_idx /= "11" then
                        byte_idx <= byte_idx + 1;
                     end if;
                  end if;
               end if;

            end if;
         end if;
      end if;
   end process;

end architecture;
