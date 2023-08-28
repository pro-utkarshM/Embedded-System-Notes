-- riscvsingle.sv

-- RISC-V single-cycle processor
-- From Section 7.6 of Digital Design & Computer Architecture
-- 27 April 2020
-- David_Harris@hmc.edu 
-- Sarah.Harris@unlv.edu

-- run 210
-- Expect simulator to print "Simulation succeeded"
-- when the value 25 (0x19) is written to address 100 (0x64)

-- Single-cycle implementation of RISC-V (RV32I)
-- User-level Instruction Set Architecture V2.2 (May 7, 2017)
-- Implements a subset of the base integer instructions:
--    lw, sw
--    add, sub, and, or, slt, 
--    addi, andi, ori, slti
--    beq
--    jal
-- Exceptions, traps, and interrupts not implemented
-- little-endian memory

-- 31 32-bit registers x1-x31, x0 hardwired to 0
-- R-Type instructions
--   add, sub, and, or, slt
--   INSTR rd, rs1, rs2
--   Instr[31:25] = funct7 (funct7b5 & opb5 = 1 for sub, 0 for others)
--   Instr[24:20] = rs2
--   Instr[19:15] = rs1
--   Instr[14:12] = funct3
--   Instr[11:7]  = rd
--   Instr[6:0]   = opcode
-- I-Type Instructions
--   lw, I-type ALU (addi, andi, ori, slti)
--   lw:         INSTR rd, imm(rs1)
--   I-type ALU: INSTR rd, rs1, imm (12-bit signed)
--   Instr[31:20] = imm[11:0]
--   Instr[24:20] = rs2
--   Instr[19:15] = rs1
--   Instr[14:12] = funct3
--   Instr[11:7]  = rd
--   Instr[6:0]   = opcode
-- S-Type Instruction
--   sw rs2, imm(rs1) (store rs2 into address specified by rs1 + immm)
--   Instr[31:25] = imm[11:5] (offset[11:5])
--   Instr[24:20] = rs2 (src)
--   Instr[19:15] = rs1 (base)
--   Instr[14:12] = funct3
--   Instr[11:7]  = imm[4:0]  (offset[4:0])
--   Instr[6:0]   = opcode
-- B-Type Instruction
--   beq rs1, rs2, imm (PCTarget = PC + (signed imm x 2))
--   Instr[31:25] = imm[12], imm[10:5]
--   Instr[24:20] = rs2
--   Instr[19:15] = rs1
--   Instr[14:12] = funct3
--   Instr[11:7]  = imm[4:1], imm[11]
--   Instr[6:0]   = opcode
-- J-Type Instruction
--   jal rd, imm  (signed imm is multiplied by 2 and added to PC, rd = PC+4)
--   Instr[31:12] = imm[20], imm[10:1], imm[11], imm[19:12]
--   Instr[11:7]  = rd
--   Instr[6:0]   = opcode

--   Instruction  opcode    funct3    funct7
--   add          0110011   000       0000000
--   sub          0110011   000       0100000
--   and          0110011   111       0000000
--   or           0110011   110       0000000
--   slt          0110011   010       0000000
--   addi         0010011   000       immediate
--   andi         0010011   111       immediate
--   ori          0010011   110       immediate
--   slti         0010011   010       immediate
--   beq          1100011   000       immediate
--   lw           0000011   010       immediate
--   sw           0100011   010       immediate
--   jal          1101111   immediate immediate


library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity riscvsingle is -- single cycle RISC-V processor
  port(clk, reset:           in  STD_LOGIC;
       PC:                   out STD_LOGIC_VECTOR(31 downto 0);
       Instr:                in  STD_LOGIC_VECTOR(31 downto 0);
       MemWrite:             out STD_LOGIC;
       ALUResult, WriteData: out STD_LOGIC_VECTOR(31 downto 0);
       ReadData:             in  STD_LOGIC_VECTOR(31 downto 0));
end;

architecture struct of riscvsingle is
  component controller
    port(op:             in  STD_LOGIC_VECTOR(6 downto 0);
         funct3:         in  STD_LOGIC_VECTOR(2 downto 0);
         funct7b5, Zero: in  STD_LOGIC;
         ResultSrc:      out STD_LOGIC_VECTOR(1 downto 0);
         MemWrite:       out STD_LOGIC;
         PCSrc, ALUSrc:  out STD_LOGIC;
         RegWrite, Jump: out STD_LOGIC;
         ImmSrc:         out STD_LOGIC_VECTOR(1 downto 0);
         ALUControl:     out STD_LOGIC_VECTOR(2 downto 0));
  end component;
  component datapath
    port(clk, reset:           in  STD_LOGIC;
         ResultSrc:            in  STD_LOGIC_VECTOR(1  downto 0);
         PCSrc, ALUSrc:        in  STD_LOGIC;
         RegWrite:             in  STD_LOGIC;
         ImmSrc:               in  STD_LOGIC_VECTOR(1  downto 0);
         ALUControl:           in  STD_LOGIC_VECTOR(2  downto 0);
         Zero:                 out STD_LOGIC;
         PC:                   out STD_LOGIC_VECTOR(31 downto 0);
         Instr:                in  STD_LOGIC_VECTOR(31 downto 0);
         ALUResult, WriteData: out STD_LOGIC_VECTOR(31 downto 0);
         ReadData:             in  STD_LOGIC_VECTOR(31 downto 0));
  end component;
    
  signal ALUSrc, RegWrite, Jump, Zero, PCSrc: STD_LOGIC;
  signal ResultSrc, ImmSrc: STD_LOGIC_VECTOR(1 downto 0);
  signal ALUControl: STD_LOGIC_VECTOR(2 downto 0);
begin
  c: controller port map(Instr(6 downto 0), Instr(14 downto 12),
                         Instr(30), Zero, ResultSrc, MemWrite,
                         PCSrc, ALUSrc, RegWrite, Jump,
                         ImmSrc, ALUControl);
  dp: datapath port map(clk, reset, ResultSrc, PCSrc, ALUSrc, 
                        RegWrite, ImmSrc, ALUControl, Zero, 
                        PC, Instr, ALUResult,  WriteData, 
                        ReadData);
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity controller is -- single-cycle controller
  port(op:             in     STD_LOGIC_VECTOR(6 downto 0);
       funct3:         in     STD_LOGIC_VECTOR(2 downto 0);
       funct7b5, Zero: in     STD_LOGIC;
       ResultSrc:      out    STD_LOGIC_VECTOR(1 downto 0);
       MemWrite:       out    STD_LOGIC;
       PCSrc, ALUSrc:  out    STD_LOGIC;
       RegWrite:       out    STD_LOGIC;
       Jump:           buffer STD_LOGIC;
       ImmSrc:         out    STD_LOGIC_VECTOR(1 downto 0);
       ALUControl:     out    STD_LOGIC_VECTOR(2 downto 0));
end;

architecture struct of controller is
  component maindec
    port(op:             in  STD_LOGIC_VECTOR(6 downto 0);
         ResultSrc:      out STD_LOGIC_VECTOR(1 downto 0);
         MemWrite:       out STD_LOGIC;
         Branch, ALUSrc: out STD_LOGIC;
         RegWrite, Jump: out STD_LOGIC;
         ImmSrc:         out STD_LOGIC_VECTOR(1 downto 0);
         ALUOp:          out STD_LOGIC_VECTOR(1 downto 0));
  end component;
  component aludec
    port(opb5:       in  STD_LOGIC;
         funct3:     in  STD_LOGIC_VECTOR(2 downto 0);
         funct7b5:   in  STD_LOGIC;
         ALUOp:      in  STD_LOGIC_VECTOR(1 downto 0);
         ALUControl: out STD_LOGIC_VECTOR(2 downto 0));
  end component;
  
  signal ALUOp:  STD_LOGIC_VECTOR(1 downto 0);
  signal Branch: STD_LOGIC;
begin
  md: maindec port map(op, ResultSrc, MemWrite, Branch,
                       ALUSrc, RegWrite, Jump, ImmSrc, ALUOp);
  ad: aludec port map(op(5), funct3, funct7b5, ALUOp, ALUControl);
  
  PCSrc <= (Branch and Zero) or Jump;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity maindec is -- main control decoder
  port(op:             in  STD_LOGIC_VECTOR(6 downto 0);
       ResultSrc:      out STD_LOGIC_VECTOR(1 downto 0);
       MemWrite:       out STD_LOGIC;
       Branch, ALUSrc: out STD_LOGIC;
       RegWrite, Jump: out STD_LOGIC;
       ImmSrc:         out STD_LOGIC_VECTOR(1 downto 0);
       ALUOp:          out STD_LOGIC_VECTOR(1 downto 0));
end;

architecture behave of maindec is
  signal controls: STD_LOGIC_VECTOR(10 downto 0);
begin
  process(op) begin
    case op is
      when "0000011" => controls <= "10010010000"; -- lw
      when "0100011" => controls <= "00111000000"; -- sw
      when "0110011" => controls <= "1--00000100"; -- R-type
      when "1100011" => controls <= "01000001010"; -- beq
      when "0010011" => controls <= "10010000100"; -- I-type ALU
      when "1101111" => controls <= "11100100001"; -- jal
      when others    => controls <= "-----------"; -- not valid
    end case;
  end process;

  (RegWrite, ImmSrc(1), ImmSrc(0), ALUSrc, MemWrite,
   ResultSrc(1), ResultSrc(0), Branch, ALUOp(1), ALUOp(0), Jump) <= controls;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity aludec is -- ALU control decoder
  port(opb5:       in  STD_LOGIC;
       funct3:     in  STD_LOGIC_VECTOR(2 downto 0);
       funct7b5:   in  STD_LOGIC;
       ALUOp:      in  STD_LOGIC_VECTOR(1 downto 0);
       ALUControl: out STD_LOGIC_VECTOR(2 downto 0));
end;

architecture behave of aludec is
  signal RtypeSub: STD_LOGIC;
begin
  RtypeSub <= funct7b5 and opb5; -- TRUE for R-type subtract
  process(opb5, funct3, funct7b5, ALUOp, RtypeSub) begin
    case ALUOp is
      when "00" =>                     ALUControl <= "000"; -- addition
      when "01" =>                     ALUControl <= "001"; -- subtraction
      when others => case funct3 is           -- R-type or I-type ALU
                       when "000" => if RtypeSub = '1' then
                                       ALUControl <= "001"; -- sub
                                     else
                                       ALUControl <= "000"; -- add, addi
                                     end if;
                       when "010" =>   ALUControl <= "101"; -- slt, slti
                       when "110" =>   ALUControl <= "011"; -- or, ori
                       when "111" =>   ALUControl <= "010"; -- and, andi
                       when others =>  ALUControl <= "---"; -- unknown
                     end case;
    end case;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

entity datapath is -- RISC-V datapath
  port(clk, reset:           in     STD_LOGIC;
       ResultSrc:            in     STD_LOGIC_VECTOR(1  downto 0);
       PCSrc, ALUSrc:        in     STD_LOGIC;
       RegWrite:             in     STD_LOGIC;
       ImmSrc:               in     STD_LOGIC_VECTOR(1  downto 0);
       ALUControl:           in     STD_LOGIC_VECTOR(2  downto 0);
       Zero:                 out    STD_LOGIC;
       PC:                   buffer STD_LOGIC_VECTOR(31 downto 0);
       Instr:                in     STD_LOGIC_VECTOR(31 downto 0);
       ALUResult, WriteData: buffer STD_LOGIC_VECTOR(31 downto 0);
       ReadData:             in     STD_LOGIC_VECTOR(31 downto 0));
end;

architecture struct of datapath is
  component flopr generic(width: integer);
    port(clk, reset: in  STD_LOGIC;
         d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
         q:          out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  component adder
    port(a, b: in  STD_LOGIC_VECTOR(31 downto 0);
         y:    out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component mux2 generic(width: integer);
    port(d0, d1: in  STD_LOGIC_VECTOR(width-1 downto 0);
         s:      in  STD_LOGIC;
         y:      out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  component mux3 generic(width: integer);
    port(d0, d1, d2: in  STD_LOGIC_VECTOR(width-1 downto 0);
         s:          in  STD_LOGIC_VECTOR(1 downto 0);
         y:          out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  component regfile
    port(clk:        in  STD_LOGIC;
         we3:        in  STD_LOGIC;
         a1, a2, a3: in  STD_LOGIC_VECTOR(4  downto 0);
         wd3:        in  STD_LOGIC_VECTOR(31 downto 0);
         rd1, rd2:   out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component extend
    port(instr:  in  STD_LOGIC_VECTOR(31 downto 7);
         immsrc: in  STD_LOGIC_VECTOR(1  downto 0);
         immext: out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component alu
    port(a, b:       in     STD_LOGIC_VECTOR(31 downto 0);
         ALUControl: in     STD_LOGIC_VECTOR(2  downto 0);
         ALUResult:  buffer STD_LOGIC_VECTOR(31 downto 0);
         Zero:       out    STD_LOGIC);
  end component;
    
  signal PCNext, PCPlus4, PCTarget: STD_LOGIC_VECTOR(31 downto 0);
  signal ImmExt:                    STD_LOGIC_VECTOR(31 downto 0);
  signal SrcA, SrcB:                STD_LOGIC_VECTOR(31 downto 0);
  signal Result:                    STD_LOGIC_VECTOR(31 downto 0);
begin
  -- next PC logic
  pcreg: flopr generic map(32) port map(clk, reset, PCNext, PC);
  pcadd4: adder port map(PC, X"00000004", PCPlus4);
  pcaddbranch: adder port map(PC, ImmExt, PCTarget);
  pcmux: mux2 generic map(32) port map(PCPlus4, PCTarget, PCSrc, PCNext);
    
  -- register file logic
  rf: regfile port map(clk, RegWrite, Instr(19 downto 15), Instr(24 downto 20),
                         Instr(11 downto 7), Result, SrcA, WriteData);
  ext: extend port map(Instr(31 downto 7), ImmSrc, ImmExt);
    
  -- ALU logic
  srcbmux: mux2 generic map(32) port map(WriteData, ImmExt, ALUSrc, SrcB);
  mainalu: alu port map(SrcA, SrcB, ALUControl, ALUResult, Zero);
  resultmux: mux3 generic map(32) port map(ALUResult, ReadData, PCPlus4, ResultSrc,
                                           Result);
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity regfile is -- three-port register file
  port(clk:        in  STD_LOGIC;
       we3:        in  STD_LOGIC;
       a1, a2, a3: in  STD_LOGIC_VECTOR(4  downto 0);
       wd3:        in  STD_LOGIC_VECTOR(31 downto 0);
       rd1, rd2:   out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of regfile is
  type ramtype is array (31 downto 0) of STD_LOGIC_VECTOR(31 downto 0);
  signal mem: ramtype;
begin
  -- three ported register file
  -- read two ports combinationally (A1/RD1, A2/RD2)
  -- write third port on rising edge of clock (A3/WD3/WE3)
  -- register 0 hardwired to 0
  process(clk) begin
    if rising_edge(clk) then
      if we3='1' then mem(to_integer(a3)) <= wd3;
      end if;
    end if;
  end process;
  process(a1, a2) begin
    if (to_integer(a1)=0) then rd1 <= X"00000000";
    else rd1 <= mem(to_integer(a1));
    end if;
    if (to_integer(a2)=0) then rd2 <= X"00000000";
    else rd2 <= mem(to_integer(a2));
    end if;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity adder is -- adder
  port(a, b: in  STD_LOGIC_VECTOR(31 downto 0);
       y:    out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of adder is
begin
  y <= a + b;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity extend is -- extend unit
  port(instr:  in  STD_LOGIC_VECTOR(31 downto 7);
    immsrc: in  STD_LOGIC_VECTOR(1  downto 0);
    immext: out STD_LOGIC_VECTOR(31 downto 0));
end;
    
architecture behave of extend is
begin
  process(instr, immsrc) begin
    case immsrc is
      -- I-type
      when "00" =>
        immext <= (31 downto 12 => instr(31)) & instr(31 downto 20);
      -- S-types (stores)
      when "01" =>
        immext <= (31 downto 12 => instr(31)) & instr(31 downto 25) & instr(11 downto 7);
      -- B-type (branches)
      when "10" =>
        immext <= (31 downto 12 => instr(31)) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
      -- J-type (jal)
      when "11" =>
        immext <= (31 downto 20 => instr(31)) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
      when others =>
        immext <= (31 downto 0 => '-');
    end case;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

entity flopr is -- flip-flop with synchronous reset
  generic(width: integer);
  port(clk, reset: in  STD_LOGIC;
       d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
       q:          out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture asynchronous of flopr is
begin
  process(clk, reset) begin
    if reset='1' then           q <= (others => '0');
    elsif rising_edge(clk) then q <= d;
    end if;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

entity flopenr is
  generic(width: integer); -- flip-flop with synchronous reset and enable
  port(clk, reset, en: in  STD_LOGIC;
       d:              in  STD_LOGIC_VECTOR(width-1 downto 0);
       q:              out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture asynchronous of flopenr is
begin
  process(clk, reset, en) begin
    if reset='1' then                      q <= (others => '0');
    elsif rising_edge(clk) and en='1' then q <= d;
    end if;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity mux2 is -- two-input multiplexer
  generic(width: integer :=8);
  port(d0, d1: in  STD_LOGIC_VECTOR(width-1 downto 0);
       s:      in  STD_LOGIC;
       y:      out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture behave of mux2 is
begin
  y <= d1 when s='1' else d0;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity mux3 is -- three-input multiplexer
  generic(width: integer :=8);
  port(d0, d1, d2: in  STD_LOGIC_VECTOR(width-1 downto 0);
       s:          in  STD_LOGIC_VECTOR(1 downto 0);
       y:          out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture behave of mux3 is
begin
  process(d0, d1, d2, s) begin
    if    (s = "00") then y <= d0;
    elsif (s = "01") then y <= d1;
    elsif (s = "10") then y <= d2;
    end if;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity testbench is -- RISC-V testbench
end;

architecture test of testbench is
  component top
    port(clk, reset:         in STD_LOGIC;
         WriteData, DataAdr: out STD_LOGIC_VECTOR(31 downto 0);
         MemWrite:           out STD_LOGIC);
    
  end component;
  signal WriteData, DataAdr:   STD_LOGIC_VECTOR(31 downto 0);
  signal clk, reset, MemWrite: STD_LOGIC;
begin
  -- instantiate device to be tested
  dut: top port map(clk, reset, WriteData, DataAdr, MemWrite);
    
  -- Generate clock with 10 ns period
  process begin
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  -- Generate reset for first two clock cycles
  process begin
    reset <= '1';
    wait for 22 ns;
    reset <= '0';
    wait;
  end process;

  -- check that 25 gets written to address 100 at end of program
  process(clk) begin
    if(clk'event and clk = '0' and MemWrite = '1') then
      if(to_integer(DataAdr) = 100 and to_integer(writedata) = 25) then
        report "NO ERRORS: Simulation succeeded" severity failure;
      elsif (DataAdr /= 96) then
        report "Simulation failed" severity failure;
      end if;
    end if;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity top is -- top-level design for testing
  port(clk, reset:         in     STD_LOGIC;
       WriteData, DataAdr: buffer STD_LOGIC_VECTOR(31 downto 0);
       MemWrite:           buffer STD_LOGIC);
end;

architecture test of top is
  component riscvsingle
    port(clk, reset:           in  STD_LOGIC;
         PC:                   out STD_LOGIC_VECTOR(31 downto 0);
         Instr:                in  STD_LOGIC_VECTOR(31 downto 0);
         MemWrite:             out STD_LOGIC;
         ALUResult, WriteData: out STD_LOGIC_VECTOR(31 downto 0);
         ReadData:             in  STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component imem
    port(a:  in  STD_LOGIC_VECTOR(31 downto 0);
         rd: out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component dmem
    port(clk, we: in  STD_LOGIC;
         a, wd:   in  STD_LOGIC_VECTOR(31 downto 0);
         rd:      out STD_LOGIC_VECTOR(31 downto 0));
  end component;
    
  signal PC, Instr, ReadData: STD_LOGIC_VECTOR(31 downto 0);
begin
  -- instantiate processor and memories
  rvsingle: riscvsingle port map(clk, reset, PC, Instr, MemWrite, DataAdr,
                                   WriteData, ReadData);
  imem1: imem port map(PC, Instr);
  dmem1: dmem port map(clk, MemWrite, DataAdr, WriteData, ReadData);
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use STD.TEXTIO.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;
use ieee.std_logic_textio.all;

entity imem is -- instruction memory
  port(a:  in  STD_LOGIC_VECTOR(31 downto 0);
       rd: out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of imem is
  type ramtype is array(63 downto 0) of STD_LOGIC_VECTOR(31 downto 0);

  -- initialize memory from file
  impure function init_ram_hex return ramtype is
    file text_file : text open read_mode is "riscvtest.txt";
    variable text_line : line;
    variable ram_content : ramtype;
    variable i : integer := 0;
  begin
    for i in 0 to 63 loop -- set all contents low
      ram_content(i) := (others => '0');
    end loop;
    while not endfile(text_file) loop -- set contents from file
      readline(text_file, text_line);
      hread(text_line, ram_content(i));
      i := i+1;
    end loop;
     
    return ram_content;
  end function;
    
  signal mem : ramtype := init_ram_hex;
    
  begin
  -- read memory
  process(a) begin
    rd <= mem(to_integer(a(31 downto 2)));
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use STD.TEXTIO.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity dmem is -- data memory
  port(clk, we: in  STD_LOGIC;
       a, wd:   in  STD_LOGIC_VECTOR(31 downto 0);
       rd:      out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of dmem is
begin
  process is
    type ramtype is array (63 downto 0) of STD_LOGIC_VECTOR(31 downto 0);
    variable mem: ramtype;
  begin
    -- read or write memory
    loop
      if rising_edge(clk) then
        if (we='1') then mem(to_integer(a(7 downto 2))) := wd;
        end if;
      end if;
      rd <= mem(to_integer(a(7 downto 2)));
      wait on clk, a;
    end loop;
  end process;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity alu is
  port(a, b:       in     STD_LOGIC_VECTOR(31 downto 0);
       ALUControl: in     STD_LOGIC_VECTOR(2  downto 0);
       ALUResult:  buffer STD_LOGIC_VECTOR(31 downto 0);
       Zero:       out    STD_LOGIC);
end;

architecture behave of alu is
  signal condinvb, sum: STD_LOGIC_VECTOR(31 downto 0);
  signal v, isAddSub: STD_LOGIC;
begin
  condinvb <= not b when Alucontrol(0)='1' else b;
  sum <= a + condinvb + Alucontrol(0);
  isAddSub = not ALUControl(2) and not ALUControl(1) or
             not ALUControl(1) and     ALUControl(0);
             
  process(a,b,ALUControl,sum) begin
    case Alucontrol is
      when "000"  => ALUResult <= sum;
      when "001"  => ALUResult <= sum;
      when "010"  => ALUResult <= a and b;
      when "011"  => ALUResult <= a or b;         
      when "101"  => ALUResult <= (0 => (sum(31) xor v), others => '0');
      when others => ALUResult <= (others => 'X');
    end case;
  end process;
  
  Zero <= '1' when ALUResult = X"00000000" else '0';
  v <= not(ALUControl(0) xor a(31) xor b(31)) and (a(31) xor sum(31)) and isAddSub;
end;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;

entity alu is
  port(a, b:       in     STD_LOGIC_VECTOR(31 downto 0);
       ALUControl: in     STD_LOGIC_VECTOR(2  downto 0);
       ALUResult:  buffer STD_LOGIC_VECTOR(31 downto 0);
       Zero:       out    STD_LOGIC);
end;

architecture behave of alu is
  signal condinvb, sum: STD_LOGIC_VECTOR(31 downto 0);
begin
  condinvb <= not b when Alucontrol(0)='1' else b;
  sum <= a + condinvb + Alucontrol(0);
  process(a,b,ALUControl,sum) begin
    case Alucontrol is
      when "000" =>  ALUResult <= sum;
      when "001" =>  ALUResult <= sum;
      when "010" =>  ALUResult <= a and b;
      when "011" =>  ALUResult <= a or b;         
      when "101" =>  ALUResult <= (0 => sum(31), others => '0');
      when others => ALUResult <= (others => 'X');
    end case;
  end process;
  Zero <= '1' when ALUResult = X"00000000" else '0';
end;


