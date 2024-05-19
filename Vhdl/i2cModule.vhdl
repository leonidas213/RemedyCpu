
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity i2cLogic is
  port (
    enable       : in  std_logic;
    clk          : in  STD_LOGIC;
    addr         : in  STD_LOGIC_VECTOR(7 downto 0);
    data         : in  STD_LOGIC_VECTOR(7 downto 0);
    rst          : in  STD_LOGIC;
    sdain        : in  STD_LOGIC;
    sclin        : in  STD_LOGIC;

    endCon       : in  std_logic;

    sdaout       : out STD_LOGIC;
    sclout       : out STD_LOGIC;
    dataOut      : out std_logic_vector(7 downto 0);
    ack          : out STD_LOGIC;
    busy         : out STD_LOGIC;
    done         : out STD_LOGIC;
    isWriting    : out std_logic;
    isReading    : out std_logic;
    isAdrWriting : out std_logic;
    isStandby    : out std_logic;
    statedebug   : out STD_LOGIC_VECTOR(3 downto 0));

end entity;

architecture Behavioral of i2cLogic is

  signal addrReg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); --addr store

  type states is (free, start, startclk, busAddr, recvAck, wr, rd, sendAck, stop);
  signal currentstate : states    := stop;    --currentState
  signal oldState     : states;
  signal datCounter   : unsigned(8 downto 0); --bitcounter
  signal clockOnState : STD_LOGIC := '0';
  signal wrRdFlag     : STD_LOGIC := '0';
  signal state_slv    : std_logic_vector(3 downto 0);

begin
  state_slv <= "0000" when currentstate = free else
               "0001" when currentstate = start else
               "0010" when currentstate = startclk else
               "0011" when currentstate = busAddr else
               "0100" when currentstate = recvAck else
               "0101" when currentstate = wr else
               "0110" when currentstate = rd else
               "0111" when currentstate = sendAck else
               "1000" when currentstate = stop else
               "1111";

  statedebug <= STD_LOGIC_VECTOR(state_slv);

  process (clk, rst)
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
      isWriting <= '0';
      isReading <= '0';
      isAdrWriting <= '0';
      isStandby <= '1';
    end if;

    if (rising_edge(clk) and enable = '1') then

      if (currentstate = free and (enable = '1')) then -- bus is free

        addrReg <= addr;
        busy <= '1';
        sdaout <= '1';
        sclout <= '1';
        oldState <= currentstate;
        currentstate <= start;
        wrRdFlag <= addr(0);
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
        isStandby <= '0';
        isAdrWriting <= '1';
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

        isAdrWriting <= '0';
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
              done <= '0';
              if (endCon = '1') then
                oldState <= currentstate;
                currentstate <= stop;
              else
                if (addr(0) = '0') then
                  oldState <= currentstate;
                  currentstate <= wr;
                else --else go to currentstate 6
                  oldState <= currentstate;
                  currentstate <= rd;

                end if;
              end if;

            end if;

          else
            sclout <= '1';
          end if;

        end if;

      elsif (currentstate = wr) then -- write 8 bit data
        --if (endCon = '1' and startedProcedure = '0') then
        --  currentstate <= stop;
        --end if;
        isAdrWriting <= '1';
        isWriting <= '1';
        if (clockOnState = '0') then

          clockOnState <= '1';

          if (datCounter < 8) then
            sdaout <= data(7 - to_integer(datCounter));
            datCounter <= datCounter + 1;

          else
            datCounter <= (others => '0');
            clockOnState <= '0';
            sclout <= '0';
            oldState <= currentstate;
            done <= '1';
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
        done <= '0';
        isAdrWriting <= '1';
        dataOut <= (others => '0');
        --startedProcedure <= '0';
        if (clockOnState = '0') then

          sdaout <= 'Z';
          clockOnState <= '1';
        else
          if (sclout = '1') then
            sclout <= '0';
            clockOnState <= '0';
            if (endCon = '0') then
              oldState <= currentstate;
              sdaout <= 'Z';
              currentstate <= rd;
            else
              oldState <= currentstate;
              currentstate <= stop;
            end if;

          else
            if (endCon = '0') then
              sdaout <= '1';
            else
              sdaout <= '0';
            end if;
            sclout <= '1';

          end if;
        end if;
      elsif (currentstate = rd) then --readState
        isWriting <= '0';
        isAdrWriting <= '0';
        isReading <= '1';
        if (clockOnState = '0') then
          clockOnState <= '1';
          if (datCounter < 8) then
            datCounter <= datCounter + 1;

          else
            datCounter <= (others => '0');
            clockOnState <= '0';
            sclout <= '0';
            oldState <= currentstate;
            done <= '1';
            currentstate <= sendAck; --sendAck

          end if;
        else
          if (sclout = '1') then
            dataOut(to_integer(8 - datCounter)) <= sdain;
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
        isWriting <= '0';
        isReading <= '0';
        isAdrWriting <= '0';

        isStandby <= '1';
      end if; --if (currentstate = free &(enable = '1')) then

    end if; --if (rising_edge(clk)) then

  end process;

end architecture;


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity I2CModule is
  port (
    clk      : in  std_logic;
    busAddr  : in  std_logic_vector(15 downto 0);
    dataBus  : in  std_logic_vector(15 downto 0);
    ioread   : in  std_logic;
    iowrite  : in  std_logic;

    isoutput : out std_logic;
    scl      : out std_logic;
    isAck    : out std_logic;
    isBusy   : out std_logic;
    isDone   : out std_logic
  );
end entity;

architecture behavioral of I2CModule is
  signal mainclk      : std_logic;
  signal i2caddrin    : std_logic;
  signal i2cdatain    : std_logic;
  signal i2crst       : std_logic;
  signal i2csdain     : std_logic;
  signal i2csdaout    : std_logic;
  signal i2cenable    : std_logic;
  signal i2cwrFlag    : std_logic;
  signal endCon       : std_logic;
  signal statedebug   : std_logic_vector(3 downto 0);
  signal dataOut      : std_logic_vector(7 downto 0);
  signal isWriting    : std_logic;
  signal isReading    : std_logic;
  signal isAdrWriting : std_logic;
  signal isStandby    : std_logic;
  ---------------------------------------------
  signal i2cAddrReg  : std_logic_vector(7 downto 0);
  signal i2cdataReg  : std_logic_vector(7 downto 0);
  signal writelenReg : std_logic_vector(15 downto 0);
begin
  i2cLogic_inst: entity i2cLogic
    port map (
      clk          => clk,
      addr         => i2cAddrReg,
      data         => i2cdataReg,
      rst          => i2crst,
      sdain        => i2csdain,
      sclin        => '0',
      enable       => i2cenable,
      endCon       => endCon,
      sdaout       => i2csdaout,
      sclout       => scl,
      dataOut      => dataOut,
      ack          => isAck,
      busy         => isBusy,
      done         => isDone,
      isWriting    => isWriting,
      isReading    => isReading,
      isAdrWriting => isAdrWriting,
      isStandby    => isStandby,
      statedebug   => statedebug
    );

  process (iowrite, clk)
  begin
    if (rising_edge(clk) and (busAddr = x"A") and iowrite='1') then
      writelenReg <= dataBus;

    end if;
  end process;
end architecture;

