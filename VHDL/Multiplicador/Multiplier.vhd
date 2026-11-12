LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY Multiplier IS
    GENERIC(N: INTEGER := 5);
    PORT (
          A           : IN  STD_LOGIC_VECTOR(N-1             DOWNTO 0);
          B           : IN  STD_LOGIC_VECTOR(N-1             DOWNTO 0);
          -- Full signed product: N-bit operands need 2*N result bits.
          Res         : OUT STD_LOGIC_VECTOR(2*N-1           DOWNTO 0)
    );
END ENTITY Multiplier;

ARCHITECTURE MultiplierArch OF Multiplier IS

     SIGNAL part_Prod : STD_LOGIC_VECTOR((N * N) - 1         DOWNTO 0);
     SIGNAL part_Sum  : STD_LOGIC_VECTOR((N * (N+1)) - 1     DOWNTO 0);
     SIGNAL row_Mode  : STD_LOGIC_VECTOR(N-2 DOWNTO 0);

BEGIN

     ASSERT N >= 2
         REPORT "Multiplier requires N >= 2"
         SEVERITY FAILURE;


     part: FOR i IN 0 TO N-1 GENERATE

          part2: FOR j IN 0 TO N-1 GENERATE

               part_Prod(i*N + j) <= A(i) AND B(j);

        END GENERATE;

    END GENERATE;

     -- Row i is B AND (A(i) replicated N times). Extend B's sign.
     part_Sum(N DOWNTO 0) <= part_Prod(N-1) & part_Prod(N-1  DOWNTO 0);

     Ripples: FOR i IN 0 TO N-2 GENERATE

          -- A(N-1) has weight -2**(N-1), so subtract the final row.
          -- RippleCAdder already sign-extends both N-bit inputs.
          row_Mode(i) <= '1' WHEN i = N-2 ELSE '0';

          Adder: ENTITY WORK.RippleCAdder
                 GENERIC MAP 
                 (
                    N => N
                 )
                 PORT MAP 
                 (
                    Mode => row_Mode(i),
                    A => part_Sum ( (N)   + (N + 1) * (i)    DOWNTO ( (N + 1)*(i) ) + 1 ),
                    B => part_Prod( (N-1) +  N *(i+1)        DOWNTO  N*(i+1)            ),
                    S => part_Sum ( (N)   + (N + 1)*(i+1)    DOWNTO (N + 1) * (i+1)     ) 
                 );
          -- Keep each discarded LSB; the upper slice is an arithmetic shift.
          Res(i) <= part_Sum((N + 1)*i);

     END GENERATE;
     -- Preserve all N+1 bits of the final sum, including its sign.
     Res(2*N-1 DOWNTO N-1) <= part_Sum(N + (N+1)*(N-1) DOWNTO (N+1)*(N-1));


END MultiplierArch;

