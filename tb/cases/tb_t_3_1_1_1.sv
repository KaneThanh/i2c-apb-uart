module tb_t_3_1_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [11:0] BAD [9] = '{'h01c,'h020,'hffc,'h001,'h002,'h003,'h00d,'h015,'h005};
  initial begin
    env.reset(); env.wr('h008, 3); env.wr('h000, 'h41); env.send_rx('h5a, 3);
    foreach (BAD[i]) begin
      env.rd(BAD[i], 0, 1); env.wr(BAD[i], '1, 15, 1);
      env.rd('h010, 3);
    end
    env.rd('h000, 'h41); env.rd('h008, 3); env.rd('h00c, 0); env.rd('h010, 3);
    env.rd('h014, 'h900d); env.rd('h018, 0); env.rd('h004, 'h5a);
    $display("PASS T-3.1.1.1");
    $finish;
  end
endmodule
