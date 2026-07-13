-- CAT702 ZN security chip implementation
-- Serial magic latch, bit-banged over PSX SIO0 lines.
-- Protocol: assert select low, clock 8 bits LSB-first; on falling edge output
-- the state bit then on rising edge apply the sbox if datain=0.
-- The chip transform is derived from an 8-byte key region (per-game).
-- Visco COH-1002V key "kn02": 0x01 0x18 0xE2 0xFE 0x3C 0x30 0x70 0x80
-- Two instances sit on the same SIO0 lines; znsecsel[1:0] picks which responds.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cat702 is
   port (
      clk         : in  std_logic;
      reset       : in  std_logic;
      -- per-game 8-byte transform key loaded at startup
      key         : in  std_logic_vector(63 downto 0);
      -- SIO0 interface (active-low select mirrors PSX JOY_CTRL logic)
      sio_select  : in  std_logic;   -- active low
      sio_clk     : in  std_logic;
      sio_datain  : in  std_logic;
      sio_dataout : out std_logic
   );
end entity;

architecture arch of cat702 is

   -- 8-bit internal state, initialised to 0xFC on select assertion
   signal state      : std_logic_vector(7 downto 0) := (others => '0');
   signal bit_cnt    : unsigned(2 downto 0) := (others => '0');
   signal prev_clk   : std_logic := '1';
   signal prev_sel   : std_logic := '1';
   signal init_done  : std_logic := '0';
   signal dataout_r  : std_logic := '1';
   -- NOTE (2026-06-08): this file is NOT in files.qip/psx.qip — it's dead code.
   -- The live CAT702 implementation is the `cat702_byte` procedure in zn_sio.vhd,
   -- which already applies TF2 every byte (correctly matching MAME).

   -- TF2 initial sbox (fixed, same for all CAT702 chips)
   type t_sbox8 is array(0 to 7) of std_logic_vector(7 downto 0);
   constant INITIAL_SBOX : t_sbox8 := (
      x"FF", x"FE", x"FC", x"F8", x"F0", x"E0", x"C0", x"7F"
   );

   -- Extract per-bit coefficient from the 8-byte key
   function key_byte(k : std_logic_vector(63 downto 0); idx : integer)
      return std_logic_vector is
   begin
      return k(idx*8+7 downto idx*8);
   end function;

   -- Compute c[sel][bit] using the recursive Shift derivation from MAME.
   -- c[0][b] = key[b]; c[n][b] = Shift(c[n-1][(b-1)&7]) with correction at b=7.
   function compute_coef(k : std_logic_vector(63 downto 0); sel : integer; bit_in : integer)
      return std_logic_vector is
      variable r   : std_logic_vector(7 downto 0);
      variable r0  : std_logic_vector(7 downto 0);
   begin
      if sel = 0 then
         return key_byte(k, bit_in);
      else
         -- r = Shift(c[sel-1][(bit_in-1)&7])
         r := compute_coef(k, sel-1, (bit_in-1) mod 8);
         r := r(6 downto 0) & (r(7) xor r(6));  -- Shift
         if bit_in /= 7 then
            return r;
         else
            -- xor with c[sel][0]
            r0 := compute_coef(k, sel, 0);
            return r xor r0;
         end if;
      end if;
   end function;

   -- Apply one sbox to the state given the 8 coefficient bytes for that bit position
   function apply_sbox_with_coefs(s : std_logic_vector(7 downto 0);
                                   coefs : t_sbox8)
      return std_logic_vector is
      variable r : std_logic_vector(7 downto 0) := (others => '0');
   begin
      for i in 0 to 7 loop
         if s(i) = '1' then
            r := r xor coefs(i);
         end if;
      end loop;
      return r;
   end function;

   -- Apply TF2 (initial fixed sbox) to state
   function apply_tf2(s : std_logic_vector(7 downto 0)) return std_logic_vector is
      variable r : std_logic_vector(7 downto 0) := (others => '0');
   begin
      for i in 0 to 7 loop
         if s(i) = '1' then
            r := r xor INITIAL_SBOX(i);
         end if;
      end loop;
      return r;
   end function;

   -- Build the 8 coefficient bytes for a given bit-position sbox from the key
   function get_coefs(k : std_logic_vector(63 downto 0); sel : integer)
      return t_sbox8 is
      variable c : t_sbox8;
   begin
      for i in 0 to 7 loop
         c(i) := compute_coef(k, sel, i);
      end loop;
      return c;
   end function;

begin

   sio_dataout <= dataout_r;

   process(clk)
      variable new_state : std_logic_vector(7 downto 0);
      variable coefs     : t_sbox8;
      variable b         : integer range 0 to 7;
   begin
      if rising_edge(clk) then
         if reset = '1' then
            state      <= (others => '0');
            bit_cnt    <= (others => '0');
            prev_clk   <= '1';
            prev_sel   <= '1';
            init_done  <= '0';
            dataout_r  <= '1';
         else
            prev_clk <= sio_clk;
            prev_sel <= sio_select;

            -- Falling edge of select: initialise state to 0xFC, bit counter to 0
            if prev_sel = '1' and sio_select = '0' then
               state     <= x"FC";
               bit_cnt   <= (others => '0');
               init_done <= '0';
               dataout_r <= '1';
            end if;

            -- Rising edge of select: deassert output
            if prev_sel = '0' and sio_select = '1' then
               dataout_r <= '1';
            end if;

            if sio_select = '0' then
               b := to_integer(bit_cnt);

               -- Falling clock edge: apply TF2 on first bit, then output state bit
               if prev_clk = '1' and sio_clk = '0' then
                  new_state := state;
                  if init_done = '0' then
                     new_state := apply_tf2(new_state);
                     init_done <= '1';
                  end if;
                  state     <= new_state;
                  dataout_r <= new_state(b);
               end if;

               -- Rising clock edge: conditionally apply TF1 if datain was 0, advance bit
               if prev_clk = '0' and sio_clk = '1' then
                  if sio_datain = '0' then
                     coefs := get_coefs(key, b);
                     state <= apply_sbox_with_coefs(state, coefs);
                  end if;
                  bit_cnt <= bit_cnt + 1;
               end if;
            end if;
         end if;
      end if;
   end process;

end architecture;
