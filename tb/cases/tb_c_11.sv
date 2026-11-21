module tb_c_11;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h1b);
    env.send_rx('ha5, 'h1b, 8680.0, 1);
    env.rd('h010, 7);
    for (int i = 0; i < 5; i++) begin
      case (i)
        0: env.wr('h018, 2);
        1: env.wr('h018, 4);
        2: env.wr('h018, 1);
        3: env.wr('h018, 0);
        4: env.wr('h018, 6);
      endcase
      #80ns;
      env.check(env.irq === (i != 3), "IER change with pending flags");
    end
    env.rd('h004, 'ha5);
    #80ns;
    env.check(env.irq === 0, "Read clears enabled flags");
    $display("PASS C-11");
    $finish;
  end
endmodule
