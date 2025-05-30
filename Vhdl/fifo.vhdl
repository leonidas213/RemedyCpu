library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Fifo is
  port
  (
    clk  : in std_logic; --clock pini
    data : in std_logic_vector(7 downto 0);--datanın giriş pinleri

    rst     : in std_logic;--fifo resetleme pini
    writeEn : in std_logic;--yazma aktifleştirme pini
    readEn  : in std_logic;--okuma aktifleştirme pini

    FIFOEmpty : out std_logic;--fifonun içi boş mu eğer boş ise 1 data var ise 0

    FIFOFull  : out std_logic;

    FIFOCount : out std_logic_vector(4 downto 0);

    readData : out std_logic_vector(7 downto 0) --fifonun içindeki datanın çıkış pinleri

  );
end entity;

architecture Behavioral of Fifo is
  --verilerimizi tuttuğumuz 16 x 8 bitlik buffer

  type bufferType is array (0 to 16) of std_logic_vector(7 downto 0);
  signal FifoBuffer : bufferType;
  --fifonun içindeki data sayısını tuttuğumuz counter
  signal fifoCounter : unsigned(4 downto 0) := (others => '0');
  --fifonun içi boş mu dolu mu kontrolü
  signal isEmpty : std_logic := '1';
  signal isFull : std_logic := '0';

begin
  --fifonun içi boş ise fifoempty 1 olacak dolu ise 0 olacak
  FIFOEmpty <= isEmpty;
  FIFOFull <= isFull;
  FIFOCount <= std_logic_vector(fifoCounter);

  process (clk) --her clock cycle da çalışacak process
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        --resetleme durumunda fifo içindeki tüm verileri sıfırlıyoruz
        for i in 0 to 15 loop
          FifoBuffer(i) <= (others => '0');
        end loop;
        --fifo counterı sıfırlıyoruz
        fifoCounter <= (others => '0');
        --fifo boş olduğu için isEmpty 1 olacak
        isEmpty <= '1';
        isFull <= '0';
      end if;
      if ((writeEn = '1') and (fifoCounter /= 16)) then
        --fifo counter 16 dan küçük ise ve yazma aktif ise fifo içine data yazıyoruz
        FifoBuffer(to_integer(fifoCounter)) <= data;
        --fifo counterı bir arttırıyoruz
        fifoCounter <= fifoCounter + 1;
        --fifo boş olmadığı için isEmpty 0 olacak
        isEmpty <= '0';
        if (fifoCounter = 15) then
          --fifo counter 16 ise fifo dolu olduğu için isFull 1 olacak
          isFull <= '1';
        end if;
      end if;
      if ((readEn = '1') and (fifoCounter > 0)) then
        --fifo counter 0 dan büyük ise ve okuma aktif ise fifo içinden data okuyoruz
        readData <= FifoBuffer(0);
        isfull <= '0';
        for i in 0 to 15 loop
          --fifo içindeki verileri bir bir kaydırıyoruz
          FifoBuffer(i) <= FifoBuffer(i + 1);
        end loop;
        --fifo counterı bir azaltıyoruz
        fifoCounter <= fifoCounter - 1;
        if (fifoCounter = 1) then
          --fifo counter 1 ise fifo boş olduğu için isEmpty 1 olacak
          isEmpty <= '1';
        end if;
      end if;

    end if;

  end process;

end architecture;