
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.numeric_std_unsigned.all;

entity i2c_master is
  port (
    clk           : in  STD_LOGIC;
    addr          : in  STD_LOGIC_VECTOR(7 downto 0);
    data          : in  STD_LOGIC_VECTOR(7 downto 0);
    rst           : in  STD_LOGIC;
    sdain         : in  STD_LOGIC;
    sclin         : in  STD_LOGIC;

    wrRd          : in  STD_LOGIC;
    enable        : in  std_logic;
    setEnable     : in  std_logic;

    sdaout        : out STD_LOGIC;
    sclout        : out STD_LOGIC;
    ack           : out STD_LOGIC;
    busy          : out STD_LOGIC;
    done          : out STD_LOGIC;

    statedebug    : out STD_LOGIC_VECTOR(7 downto 0);
    writelendebug : out STD_LOGIC_VECTOR(3 downto 0);
    writeData     : out STD_LOGIC_VECTOR(7 downto 0);
    readlendebug  : out STD_LOGIC_VECTOR(3 downto 0);
    readData      : out STD_LOGIC_VECTOR(7 downto 0)

  );
end entity;

architecture Behavioral of i2c_master is
  type bufferType is array (0 to 16) of std_logic_vector(7 downto 0);
  signal readBuffer         : bufferType;
  signal readBufferCounter  : unsigned(3 downto 0);
  signal readLeft           : STD_LOGIC_VECTOR(3 downto 0);
  signal writeBuffer        : bufferType;
  signal writeBufferCounter : unsigned(3 downto 0);
  signal writeLeft          : integer range 0 to 16;
  signal addrReg            : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --addr store

  type states is (free, start, startclk, busAddr, recvAck, wr, rd, sendAck, stop);
  signal currentstate : states    := stop;    --currentState
  signal oldState     : states;
  signal datCounter   : unsigned(7 downto 0); --bitcounter
  signal clockOnState : STD_LOGIC := '0';
  signal wrRdFlag     : STD_LOGIC := '0';

  signal dataReg    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --data store
  signal debugstate : STD_LOGIC_VECTOR(7 downto 0);
  signal isEnabled  : std_logic;
begin
  statedebug <= debugstate;

  process (clk, rst, wrRd, setEnable)
  begin
    if (rst = '1') then
      sdaout <= '1';
      sclout <= '1';
      ack <= '0';
      done <= '0';
      busy <= '0';
      clockOnState <= '0';
      datCounter <= (others => '0');
      oldState <= currentstate;
      currentstate <= free;
      isEnabled <= '0';
    end if;
    if (rising_edge(clk) and isEnabled = '0' and setEnable = '1') then
      if (wrRd = '1') then --read count
        readLeft <= (data(3 downto 0));
        readBufferCounter <= unsigned(readLeft);
        readlendebug <= readLeft;
        readData <= readBuffer(to_integer(readLeft));
      else --write data
        writeBuffer((writeLeft)) <= data;
        writeLeft <= writeLeft + 1;
        writeBufferCounter <= to_unsigned(writeLeft, 4);
        writelendebug <= STD_LOGIC_VECTOR(writeBufferCounter);
        --writelendebug <= "0010";
        writeData <= writeBuffer(to_integer(writeBufferCounter));
      end if;
    end if;
    if (rising_edge(clk) and enable = '1') then

      writelendebug <= std_logic_vector(writeBufferCounter - to_unsigned(writeLeft, 4));
      writeData <= writeBuffer(to_integer(writeBufferCounter - to_unsigned(writeLeft, 4)));
      if (currentstate = free and (enable = '1')) then -- bus is free
        isEnabled <= '1';
        addrReg <= addr;
        busy <= '1';
        sdaout <= '1';
        sclout <= '1';
        oldState <= currentstate;
        currentstate <= start;
        wrRdFlag <= '1' when writeLeft > 0
      else
        '0';
      elsif (currentstate = start) then -- start condition

        sdaout <= '0';
        sclout <= '1';
        oldState <= currentstate;
        currentstate <= startclk;
      elsif (currentstate = startclk) then -- start clock

        sclout <= '0';
        oldState <= currentstate;
        currentstate <= busAddr;

      elsif (currentstate = busAddr) then -- write 7 bit address and w/r bit
        if (clockOnState = '0') then
          clockOnState <= '1';
          if (datCounter < 7) then
            sdaout <= addrReg(7 - to_integer(datCounter));
            datCounter <= datCounter + 1;
          elsif (datCounter = 7) then
            sdaout <= wrRdFlag;

            datCounter <= datCounter + 1;
          else
            datCounter <= (others => '0');
            clockOnState <= '0';
            oldState <= currentstate;
            currentstate <= recvAck;

          end if;
        else
          if (sclout = '1') then
            sclout <= '0';
            clockOnState <= '0';
          else
            sclout <= '1';
          end if;
        end if; --if (clockOnState = '0') then
      elsif (currentstate = recvAck) then -- read ack bit
        if (clockOnState = '0') then
          sdaout <= 'Z';
          clockOnState <= '1';
        else
          if (sclout = '1') then
            ack <= sdain;
            sclout <= '0';
            clockOnState <= '0';

            if (oldState = busAddr) then

              if (wrRdFlag = '0') then --if write go to currentstate 5
                oldState <= currentstate;
                currentstate <= wr;

              else --else go to currentstate 6
                oldState <= currentstate;
                currentstate <= rd;

              end if;

            else --oldstate = wr
              if (writeLeft /= 0) then
                oldState <= currentstate;
                currentstate <= wr;

              else
                oldState <= currentstate;
                currentstate <= stop;

              end if;

            end if;

          else
            sclout <= '1';
          end if;

        end if;

      elsif (currentstate = wr) then -- write 8 bit data
        if (writeLeft = 0) then
          currentstate <= stop;
        end if;
        if (clockOnState = '0') then

          clockOnState <= '1';

          if (datCounter < 7) then

            sdaout <= writeBuffer(to_integer(writeBufferCounter) - (writeLeft))(7 - to_integer(datCounter));
            datCounter <= datCounter + 1;

          elsif datCounter = 7 then
            sdaout <= wrRdFlag;
            datCounter <= datCounter + 1;

          else
            datCounter <= (others => '0');
            clockOnState <= '0';
            sclout <= '0';
            writeLeft <= writeLeft - 1;
            oldState <= currentstate;
            currentstate <= recvAck; --stop conditon

          end if;

        else
          if (sclout = '1') then
            sclout <= '0';
            clockOnState <= '0';

          else
            sclout <= '1';

          end if;

        end if;
      elsif (currentstate = sendAck) then
        if (clockOnState = '0') then
          sdaout <= 'Z';
          clockOnState <= '1';
        else
          if (sclout = '1') then
            sclout <= '0';
            clockOnState <= '0';
            if (readLeft /= 0) then
              oldState <= currentstate;
              currentstate <= rd;
            else
              oldState <= currentstate;
              currentstate <= stop;
            end if;

          else
            if (readLeft /= 0) then
              sdaout <= '1';
            else
              sdaout <= '0';
            end if;
            sclout <= '1';

          end if;
        end if;
      elsif (currentstate = rd) then --readState
        if (clockOnState = '0') then
          clockOnState <= '1';
          if (datCounter /= 7) then
            datCounter <= datCounter + 1;

          else
            datCounter <= (others => '0');
            clockOnState <= '0';
            sclout <= '1';
            readLeft <= readLeft - 1;
            oldState <= currentstate;
            currentstate <= sendAck; --sendAck

          end if;
        else
          if (sclout = '1') then
            readBuffer(to_integer(readBufferCounter) - to_integer(readLeft))(to_integer(7 - datCounter)) <= sdain;
            sclout <= '0';
            clockOnState <= '0';
          else
            sclout <= '1';
          end if;
        end if;
      elsif (currentstate = stop) then --stopState
        sdaout <= '1';
        sclout <= '1';
        done <= '1';
        busy <= '0';
        isEnabled <= '0';

      end if; --if (currentstate = free &(enable = '1')) then

    end if; --if (rising_edge(clk)) then

  end process;

end architecture;
