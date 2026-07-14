-- SIO0 (JOY port) register stub: "controller port present, nothing attached".
--
-- WHY: the lean System 11 core removed joypad.vhd (inputs come from the C76),
-- but SIO0 lives inside the CXD8530 CPU chip on real hardware, so its registers
-- always respond. Namco's runtime library runs stock PSX pad init at boot on
-- several titles (dunkmnia, souledge, primglex, pocketrc): it writes JOY_CTRL
-- and polls JOY_STAT bit0 (TX Ready 1) before anything else - with the bus
-- tied to zero that poll never terminates and the game black-screens with a
-- healthy C76 (found 2026-07-13 via live-PC probe + MAME loop disassembly).
--
-- Register semantics mirror the removed joypad.vhd (upstream PSX_MiSTer);
-- the line model is a dumb terminal: a transfer completes after a fixed
-- delay, shifts in 0xFF (idle-high line), never raises /ACK, never IRQs.
-- Pad detection therefore times out exactly like a real cabinet.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sio0_stub is
   port (
      clk1x         : in  std_logic;
      ce            : in  std_logic;
      reset         : in  std_logic;
      bus_addr      : in  unsigned(3 downto 0);
      bus_dataWrite : in  std_logic_vector(31 downto 0);
      bus_read      : in  std_logic;
      bus_write     : in  std_logic;
      bus_writeMask : in  std_logic_vector(3 downto 0);
      bus_dataRead  : out std_logic_vector(31 downto 0) := (others => '0')
   );
end entity;

architecture arch of sio0_stub is

   signal JOY_MODE       : std_logic_vector(15 downto 0) := (others => '0');
   signal JOY_CTRL       : std_logic_vector(15 downto 0) := (others => '0');
   signal JOY_BAUD       : std_logic_vector(15 downto 0) := (others => '0');
   signal JOY_STAT       : std_logic_vector(31 downto 0);

   signal transmitFilled : std_logic := '0';
   signal receiveFilled  : std_logic := '0';
   signal receiveBuffer  : std_logic_vector(7 downto 0) := x"FF";
   -- 8 bits at the slowest sane baud is well under this; exact timing is
   -- irrelevant with nothing attached, it only needs to be nonzero so
   -- polling code sees a busy->ready transition like real silicon.
   signal shiftCnt       : unsigned(8 downto 0) := (others => '0');

begin

   JOY_STAT( 0) <= not transmitFilled;                     -- TX Ready 1 (buffer free)
   JOY_STAT( 1) <= receiveFilled;                          -- RX FIFO not empty
   JOY_STAT( 2) <= '1' when (transmitFilled = '0' and shiftCnt = 0) else '0'; -- TX Ready 2 (all sent)
   JOY_STAT( 7) <= '0';                                    -- /ACK level: never asserted
   JOY_STAT( 9) <= '0';                                    -- IRQ: never raised
   JOY_STAT( 6 downto 3) <= (others => '0');
   JOY_STAT( 8) <= '0';
   JOY_STAT(31 downto 10) <= (others => '0');              -- baud timer not modelled

   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (reset = '1') then
            JOY_MODE       <= (others => '0');
            JOY_CTRL       <= (others => '0');
            JOY_BAUD       <= (others => '0');
            transmitFilled <= '0';
            receiveFilled  <= '0';
            receiveBuffer  <= x"FF";
            shiftCnt       <= (others => '0');
            bus_dataRead   <= (others => '0');
         elsif (ce = '1') then

            bus_dataRead <= (others => '0');

            -- line model: byte clocks out, 0xFF clocks in, no /ACK
            if (shiftCnt /= 0) then
               shiftCnt <= shiftCnt - 1;
               if (shiftCnt = 1) then
                  receiveBuffer <= x"FF";
                  receiveFilled <= '1';
               end if;
            end if;

            if (bus_read = '1') then
               case (bus_addr(3 downto 1) & '0') is
                  when x"0" =>
                     if (receiveFilled = '1') then
                        receiveFilled <= '0';
                        bus_dataRead  <= receiveBuffer & receiveBuffer & receiveBuffer & receiveBuffer;
                     else
                        bus_dataRead  <= (others => '1');
                     end if;
                  when x"4" => bus_dataRead <= JOY_STAT;
                  when x"8" => bus_dataRead <= JOY_CTRL & JOY_MODE;
                  when x"A" => bus_dataRead <= x"0000" & JOY_CTRL;
                  when x"E" => bus_dataRead <= x"0000" & JOY_BAUD;
                  when others => bus_dataRead <= x"0000CBAD";
               end case;
            end if;

            if (bus_write = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"0" =>
                     transmitFilled <= '1';
                     if (JOY_CTRL(1 downto 0) = "11" and shiftCnt = 0) then
                        transmitFilled <= '0';        -- byte accepted into shifter
                        shiftCnt       <= to_unsigned(300, 9);
                     end if;
                  when x"8" =>
                     if (bus_writeMask(1 downto 0) /= "00") then
                        JOY_MODE <= "0000000" & bus_dataWrite(8) & "00" & bus_dataWrite(5 downto 0);
                     elsif (bus_writeMask(3 downto 2) /= "00") then
                        JOY_CTRL <= "00" & bus_dataWrite(29 downto 23) & "0" & bus_dataWrite(21) & "0" & bus_dataWrite(19 downto 16);
                        if (bus_dataWrite(22) = '1') then          -- reset bit
                           transmitFilled <= '0';
                           receiveFilled  <= '0';
                           shiftCnt       <= (others => '0');
                           JOY_CTRL       <= (others => '0');
                           JOY_MODE       <= (others => '0');
                        elsif (bus_dataWrite(17 downto 16) = "11" and transmitFilled = '1' and shiftCnt = 0) then
                           transmitFilled <= '0';     -- select+TXEN with a byte pending
                           shiftCnt       <= to_unsigned(300, 9);
                        end if;
                     end if;
                  when x"C" =>
                     if (bus_writeMask(3 downto 2) /= "00") then
                        JOY_BAUD <= bus_dataWrite(31 downto 16);
                     end if;
                  when others => null;
               end case;
            end if;

         end if;
      end if;
   end process;

end architecture;
