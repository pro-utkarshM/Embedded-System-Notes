// risc-v multicycle controller testbench
// Josh Brake
// jbrake@hmc.edu
// 4/15/2020

module testbench();
  logic        clk;
  logic        reset;
  
  logic [6:0]  op;
  logic [2:0]  funct3;
  logic        funct7b5;
  logic        Zero;
  logic [1:0]  ImmSrc;
  logic [1:0]  ALUSrcA, ALUSrcB;
  logic [1:0]  ResultSrc;
  logic        AdrSrc;
  logic [2:0]  ALUControl;
  logic        IRWrite, PCWrite;
  logic        RegWrite, MemWrite;
  
  logic [31:0] vectornum, errors;
  logic [39:0] testvectors[10000:0];
  
  logic [15:0] actual, expected;


  // instantiate device to be tested
  controller dut(clk, reset, op, funct3, funct7b5, Zero,
                 ImmSrc, ALUSrcA, ALUSrcB, ResultSrc, AdrSrc, ALUControl, IRWrite, PCWrite, RegWrite, MemWrite);
  
  // generate clock
  always 
    begin
      clk = 1; #5; clk = 0; #5;
    end

  // at start of test, load vectors
  // and pulse reset
  initial
    begin
      $readmemb("controller.tv", testvectors);
      vectornum = 0; errors = 0;
      reset = 1; #22; reset = 0;
    end
	 
  // apply test vectors on rising edge of clk
  always @(posedge clk)
    begin
      #1; {op, funct3, funct7b5, Zero, expected} = testvectors[vectornum];
    end

  // check results on falling edge of clk
  always @(negedge clk)
    if (~reset) begin // skip cycles during reset
      actual = {ImmSrc, ALUSrcA, ALUSrcB, ResultSrc, AdrSrc, ALUControl, IRWrite, PCWrite, RegWrite, MemWrite};
      
      if (actual !== expected) begin  // check result
        $display("Error on vector %d: inputs: op = %h funct3 = %h funct7b5 = %h; outputs = %h (%h expected)", 
			  vectornum, op, funct3, funct7b5, actual, expected); 
  	    // provide some detailed errors to help debug
  	     if (expected[15:14] !== 2'bx)
          if (ImmSrc !== expected[15:14])   $display("   ImmSrc = %b.  Expected %b", ImmSrc, expected[15:14]);
        if (ALUSrcA !== expected[13:12])    $display("   ALUSrcA = %b.  Expected %b", ALUSrcA, expected[13:12]);
        if (ALUSrcB !== expected[11:10])    $display("   ALUSrcB = %b.  Expected %b", ALUSrcB, expected[11:10]);
        if (ResultSrc !== expected[9:8])     $display("   ResultSrc = %b.  Expected %b", ResultSrc, expected[9:8]);
        if (AdrSrc !== expected[7])      $display("   AdrSrc = %b.  Expected %b", AdrSrc, expected[7]);
        if (ALUControl !== expected[6:4])    $display("   ALUControl = %b.  Expected %b", ALUControl, expected[6:4]);
        if (IRWrite !== expected[3])      $display("   IRWrite = %b.  Expected %b", IRWrite, expected[3]);
        if (PCWrite !== expected[2])    $display("   PCWrite = %b.  Expected %b", PCWrite, expected[2]);
        if (RegWrite !== expected[1])  $display("   RegWrite = %b.  Expected %b", RegWrite, expected[1]);
        if (MemWrite !== expected[0])     $display("   MemWrite = %b.  Expected %b", MemWrite, expected[0]);		
	      errors = errors + 1;
      end

      vectornum = vectornum + 1;

      if (testvectors[vectornum] === 'bx) begin 
        $display("%d tests completed with %d errors", 
	         vectornum, errors);
        $stop;
      end
    end

endmodule