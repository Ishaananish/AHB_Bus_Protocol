`timescale 1ns / 1ps


interface ahb_if;
  
  logic clk;
  logic [31:0] hwdata;
  logic [31:0] haddr;
  logic [2:0] hsize;
  logic [2:0] hburst;
  logic hresetn, hsel, hwrite;
  logic [1:0] htrans;
  logic [1:0] hresp;
  logic hready;
  logic [31:0] hrdata;
  logic [31:0] next_addr;
  
endinterface

class transaction;
  
  rand bit [4:0] ulen;
  rand bit [31:0] hwdata;
  rand bit [31:0] haddr;
  rand bit [2:0]  hsize; 
  rand bit [2:0]  hburst;
  bit hresetn;
  rand bit hwrite;
  bit [1:0] htrans;
  bit [1:0] hresp;
  bit hready;
  bit [31:0] hrdata;
  
  constraint write_c {
    hwrite dist {1 :/ 1, 0:/ 1};
  }
  constraint ulen_c {
    ulen == 5;
  }
  constraint burst_c {
  hburst == 6;
  }
  constraint addr_c {
  haddr == 5;
  }
  
  function transaction copy();
    
    copy = new();
    copy.hwdata = this.hwdata;
    copy.haddr  = this.haddr;
    copy.hsize  = this.hsize;
    copy.hburst = this.hburst;
    copy.hwrite = this.hwrite;
    copy.htrans = this.htrans;
    copy.hresp  = this.hresp;
    copy.hready = this.hready;
    copy.hrdata = this.hrdata;
    copy.ulen   = this.ulen;
    
  endfunction

endclass

class generator;
  
  transaction tr;
  mailbox #(transaction) mbxgd;
  mailbox #(bit [4:0]) mbxgm;
  
  event done; 
  event drvnext; 
  event sconext;
  
  int count = 0;
  
  function new( mailbox #(transaction) mbxgd,
               mailbox #(bit[4:0]) mbxgm);
    this.mbxgd = mbxgd; 
    this.mbxgm = mbxgm;  
    tr =new();
  endfunction
  
  task run();
    
    repeat(count) begin
      assert(tr.randomize) else $error("Randomization Failed"); 
      $display("[GEN] : DATA SENT TO DRV");
      mbxgd.put(tr.copy);
      mbxgm.put(tr.ulen);
      @(drvnext);
      @(sconext);
    end
    
    ->done;
  endtask
endclass

class driver;
  
  virtual ahb_if vif;
  transaction tr;
  event drvnext;
  mailbox #(transaction) mbxgd;
 
  function new( mailbox #(transaction) mbxgd );
    this.mbxgd = mbxgd; 
  endfunction
  
  task reset();
    vif.hresetn <= 1'b0;
    vif.hwdata  <= 0;
    vif.haddr   <= 0; 
    vif.hsize   <= 0;
    vif.hwrite  <= 0;
    vif.hsel    <= 0;
    vif.htrans  <= 0;
    repeat(10) @(posedge vif.clk);
    vif.hresetn <= 1'b1;
    $display("[DRV] : RESET DONE");
  endtask
  
  task single_tr_wr();
    
   @(posedge vif.clk);
    vif.hresetn <= 1'b1;
    vif.hburst <= 3'b000;
    vif.hwrite <= 1'b1;
    vif.hsel   <= 1'b1;
    vif.hwdata <= $urandom_range(1,50);
    vif.haddr  <= tr.haddr;
    vif.hsize  <= 3'b010;
    vif.htrans <= 2'b00;
   
   @(posedge vif.hready);
   @(posedge vif.clk);
   ->drvnext; 
   $display("[DRV] : SINGLE TRANSFER WRITE ADDR : %0d DATA : %0d", tr.haddr, vif.hwdata); 
    
  endtask
  
  task single_tr_rd();
    
   @(posedge vif.clk);
    vif.hresetn <= 1'b1;
    vif.hburst <= 3'b000;
    vif.hwrite <= 1'b0;
    vif.hsel   <= 1'b1;
    vif.hwdata <= 0;
    vif.haddr  <= tr.haddr;
    vif.hsize  <= 3'b010;
    vif.htrans <= 2'b00;
   
   @(posedge vif.hready);
   @(posedge vif.clk);
   ->drvnext; 
   $display("[DRV] : SINGLE READ TRANSFER ADDR : %0d DATA : %0d", tr.haddr, vif.hwdata); 
   
  endtask
  
  task unspec_len_wr();
    @(posedge vif.clk);
   
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b001;
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
    
   
  
   @(posedge vif.hready);
   @(posedge vif.clk); 
    $display("[DRV] : UNSPEC LEN TRANSFER DATA : %0d ADDR : %0d", vif.hwdata, vif.haddr);
    
    repeat(tr.ulen - 1) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01;  
    @(posedge vif.hready);
    @(posedge vif.clk); 
    $display("[DRV] : UNSPEC LEN TRANSFER  ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);  
    end
 
   ->drvnext;
  endtask

    task unspec_len_rd();
    @(posedge vif.clk);
   
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b001;
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00; 
    
   
  
   @(posedge vif.hready);
   @(posedge vif.clk); 
    $display("[DRV] : UNSPEC LEN TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
   
    repeat(tr.ulen - 1) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01;  
    
    @(posedge vif.hready);
    @(posedge vif.clk);
    $display("[DRV] : UNSPEC LEN TRANSFER  ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
    end
 
   ->drvnext;
  endtask
  
  task incr4_wr ();
   $display("[DRV] : INCR4 WRITE");
   @(posedge vif.clk);
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b011; 
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00;
   
   @(posedge vif.hready);
   @(posedge vif.clk);
   
    repeat(3) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01;
 
    @(posedge vif.hready);
    @(posedge vif.clk); 
    end
    
   ->drvnext;
  endtask
  
    task incr4_rd ();
   $display("[DRV] : INCR4 READ");
   @(posedge vif.clk);
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b011; 
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00;

   @(posedge vif.hready);
   @(posedge vif.clk);
   
    repeat(3) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01;

    @(posedge vif.hready);
    @(posedge vif.clk); 
    end
   ->drvnext;
  endtask
  
  
    task incr8_wr();
    @(posedge vif.clk);  
      
   vif.hresetn <= 1'b1;
      
   vif.hburst <= 3'b101;
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00;
        
   @(posedge vif.hready);
   @(posedge vif.clk);
    $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
 
   
    repeat(7) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01; 
    $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
    @(posedge vif.hready);
    @(posedge vif.clk); 
    end
  ->drvnext;
  endtask
  
   task incr8_rd ();
    @(posedge vif.clk);  
      
   vif.hresetn <= 1'b1;
      
   vif.hburst <= 3'b101;
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
   $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
      
   @(posedge vif.hready);
   @(posedge vif.clk);
   
    repeat(7) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01; 
     @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : INCR8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
  
    end
  ->drvnext;
  endtask
  
   task incr16_wr();
    
   @(posedge vif.clk);
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b111;
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
   @(posedge vif.hready);
   @(posedge vif.clk);
      $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
    repeat(15) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01; 
      @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
 
    end
  ->drvnext;
  endtask
  

  task incr16_rd();
    
   @(posedge vif.clk);
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b111;
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
   @(posedge vif.hready);
   @(posedge vif.clk);
      $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
   
     repeat(15) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01; 
    @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : INCR16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
   
    end
  ->drvnext;
  endtask
  
  task wrap4_wr();
   @(posedge vif.clk); 
    
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b010;
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
   
    @(posedge vif.hready);
   @(posedge vif.clk);
    $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr); 
  
    repeat(3) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01;
      @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
 
    end
   ->drvnext;  
  endtask
  
    task wrap4_rd();
   @(posedge vif.clk); 
    
   vif.hresetn <= 1'b1;
    
   vif.hburst <= 3'b010;
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00;
    @(posedge vif.hready);
   @(posedge vif.clk);
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr); 
 
   
    repeat(3) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01;
     @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : WRAP4 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
    end
   ->drvnext;  
  endtask
  
   task wrap8_wr();
     @(posedge vif.clk);  
     
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b100;  
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
    @(posedge vif.hready);
   @(posedge vif.clk);
     $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
    repeat(7) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01;
     @(posedge vif.hready);
    @(posedge vif.clk); 
       $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);  
  
    end
  ->drvnext;
  endtask
  
     task wrap8_rd();
     @(posedge vif.clk);  
     
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b100;  
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010; 
   
   vif.htrans <= 2'b00;
   @(posedge vif.hready);
   @(posedge vif.clk);
      $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
    repeat(7) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01;
      @(posedge vif.hready);
    @(posedge vif.clk); 
      $display("[DRV] : WRAP8 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);  
  
    end
  ->drvnext;
  endtask
  
   task wrap16_wr();
     @(posedge vif.clk);
     
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b110;     
   
   vif.hwrite <= 1'b1;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= $urandom_range(1,50);
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
    @(posedge vif.hready);
   @(posedge vif.clk);
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
  
     repeat(15) begin
    vif.hwdata <= $urandom_range(1,50);  
    vif.htrans  <= 2'b01;  
    @(posedge vif.hready);
    @(posedge vif.clk); 
      $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
  
    end
  ->drvnext;
  endtask
  
     task wrap16_rd();
     
     @(posedge vif.clk);
     
   vif.hresetn <= 1'b1;
     
   vif.hburst <= 3'b110;     
   
   vif.hwrite <= 1'b0;
   vif.hsel   <= 1'b1;
    
   vif.hwdata <= 0;
   vif.haddr  <= tr.haddr;
   vif.hsize  <= 3'b010;
   
   vif.htrans <= 2'b00;
   @(posedge vif.hready);
   @(posedge vif.clk);
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);
   
    repeat(15) begin
    vif.hwdata <= 0;  
    vif.htrans  <= 2'b01;  
    @(posedge vif.hready);
    @(posedge vif.clk); 
     $display("[DRV] : WRAP16 TRANSFER ADDR : %0d DATA : %0d", vif.hwdata, vif.haddr);   
   
    end
  ->drvnext;
  endtask
 
  task run();
    forever begin
    mbxgd.get(tr);
    
    if(tr.hwrite == 1'b1) begin
    case(tr.hburst)
      3'b000: single_tr_wr();
      3'b001: unspec_len_wr();
      3'b010: wrap4_wr();
      3'b011: incr4_wr();
      3'b100: wrap8_wr();
      3'b101: incr8_wr();
      3'b110: wrap16_wr();
      3'b111: incr16_wr();
    endcase   
    end
   else begin
      case(tr.hburst)
      3'b000: single_tr_rd();
      3'b001: unspec_len_rd();
      3'b010: wrap4_rd();
      3'b011: incr4_rd();
      3'b100: wrap8_rd();
      3'b101: incr8_rd();
      3'b110: wrap16_rd();
      3'b111: incr16_rd();
    endcase 
   end 
      
  end  
  endtask
  
  
endclass
 
class monitor;
    
  virtual ahb_if vif; 
  transaction tr;
 
  int len = 0;
  bit [4:0] temp;
  
  mailbox #(transaction) mbxms;
  mailbox #(bit[4:0]) mbxgm;
 
  function new( mailbox #(transaction) mbxms, mailbox #(bit[4:0]) mbxgm);
    this.mbxms = mbxms;
    this.mbxgm = mbxgm;
  endfunction
  
  task single_tr_wr();
  @(posedge vif.hready);
  @(posedge vif.clk);
  tr.haddr  = vif.haddr;
  tr.hwdata = vif.hwdata;
  tr.hwrite = 1; 
  mbxms.put(tr);
  $display("[MON]: SINGLE TRANSFER WRITE addr : %0d data : %0d", tr.haddr, tr.hwdata);
  @(posedge vif.clk);
  endtask
  
  task single_tr_rd();
  @(posedge vif.hready);
  @(posedge vif.clk);
  tr.haddr  = vif.haddr;
  tr.hwrite = 0; 
  tr.hrdata = vif.hrdata;
  mbxms.put(tr);
 $display("[MON]: SINGLE TRANSFER READ addr : %0d data : %0d", tr.haddr, tr.hrdata);
 @(posedge vif.clk);
  endtask
  
  task unspec_tr_wr();
    mbxgm.get(temp);
    repeat(temp) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: UNSPECWR addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
  
    task unspec_tr_rd();
    mbxgm.get(temp);
    repeat(temp) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: UNSPECRD addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
  
   $display("[MON] : INCR4 DATA WRITE");
    repeat(4) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask

    task incr4_rd();
    $display("[MON] : INCR4 DATA READ");
    repeat(4) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
  
 task wrap4_wr();
   $display("[MON] : WRAP4 DATA WRITE");
    repeat(4) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
 
   task wrap4_rd();
    $display("[MON] : WRAP4 DATA READ");
    repeat(4) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
  
   task incr8_wr();
   $display("[MON] : INCR8 DATA WRITE");
    repeat(8) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
 
    task incr8_rd();
    $display("[MON] : INCR8 DATA READ");
    repeat(8) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
  
 task wrap8_wr();
   $display("[MON] : WRAP8 DATA WRITE");
    repeat(8) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
  
   task wrap8_rd();
    $display("[MON] : WRAP8 DATA READ");
    repeat(8) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask

   task incr16_wr();
   $display("[MON] : INCR16 DATA WRITE");
    repeat(16) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
 
    task incr16_rd();
    $display("[MON] : INCR16 DATA READ");
    repeat(16) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
 
 task wrap16_wr();
   $display("[MON] : WRAP16 DATA WRITE");
    repeat(16) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwdata = vif.hwdata;
    tr.hwrite = 1; 
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hwdata);
    @(posedge vif.clk);
    end
 endtask
 
 
   task wrap16_rd();
    $display("[MON] : WRAP4 DATA READ");
    repeat(16) begin
    @(posedge vif.hready);
    @(posedge vif.clk); 
    tr.haddr  = vif.next_addr;
    tr.hwrite = 0; 
    tr.hrdata = vif.hrdata;
    mbxms.put(tr);
    $display("[MON]: addr : %0d data : %0d", tr.haddr, tr.hrdata);
    @(posedge vif.clk);
    end
 endtask
  
  task run();  
    tr = new();
    forever begin  
        @(posedge vif.clk);
        
        if(vif.hresetn && vif.hsel && vif.hwrite)
          begin  
          case(vif.hburst)
          3'b000: single_tr_wr();   
          3'b001: unspec_tr_wr();
          3'b010: wrap4_wr();
          3'b011: incr4_wr();
          3'b100: wrap8_wr();
          3'b101: incr8_wr();
          3'b110: wrap16_wr();
          3'b111: incr16_wr();
          endcase
          end
   
      
       if(vif.hresetn && vif.hsel && (vif.hwrite == 0))
          begin  
          case(vif.hburst)
          3'b000: single_tr_rd();   
          3'b001: unspec_tr_rd();
          3'b010: wrap4_rd();
          3'b011: incr4_rd();
          3'b100: wrap8_rd();
          3'b101: incr8_rd();
          3'b110: wrap16_rd();
          3'b111: incr16_rd();
          endcase
          end
 
      end
        
 
  endtask
 
endclass
 
class scoreboard;
  
  transaction tr;
  event sconext;
  
  mailbox #(transaction) mbxms; 
  
  bit [7:0] data[256] = '{default:12};
  
  int count = 0;
  int len   = 0;
  bit [31:0] rdata;
  
  
  function new( mailbox #(transaction) mbxms );
    this.mbxms = mbxms;
  endfunction
  
  
  task run();
    
    forever 
      begin  
        
      
      mbxms.get(tr);
        
         if(tr.hwrite == 1'b1) begin
           $display("[SCO] : DATA WRITE");
           data[tr.haddr] = tr.hwdata[7:0];
           data[tr.haddr + 1] = tr.hwdata[15:8];
           data[tr.haddr + 2] = tr.hwdata[23:16];
           data[tr.haddr + 3] = tr.hwdata[31:24];                               
           end
 
        if(tr.hwrite == 1'b0) begin
            rdata = {data[tr.haddr + 3], data[tr.haddr + 2], data[tr.haddr + 1], data[tr.haddr]};
             if(tr.hrdata == 32'h0c0c0c0c)    
             $display("[SCO] : EMPTY LOCATION READ");
             else if (tr.hrdata == rdata)
             $display("[SCO] : DATA MATCHED");
             else    
             $display("[SCO] : DATA MISMATCHED");
         end
         
         
         ->sconext;  
    end
  endtask
  
  
endclass

module tb;
   
  monitor mon; 
  generator gen;
  driver drv;
  scoreboard sco;
   
 
   
  event nextgd;
  event nextgs;
  event done;
  
   mailbox #(transaction) mbxgd, mbxms;
   mailbox #(bit[4:0]) mbxgm;
  
  ahb_if vif();
 
  ahb_slave dut (vif.clk, vif.hwdata, vif.haddr, vif.hsize, vif.hburst, vif.hresetn, vif.hsel, vif.hwrite, vif.htrans, vif.hresp, vif.hready, vif.hrdata); 
 
  initial begin
    vif.clk <= 0;
  end
  
  always #5 vif.clk <= ~vif.clk;
  
  initial begin
    mbxgd = new();
    mbxms = new();
    mbxgm = new();
    
    gen = new(mbxgd, mbxgm);
    drv = new(mbxgd);
    mon = new(mbxms, mbxgm);
    sco = new(mbxms);
    
    gen.count = 3;
    
    drv.vif = vif;
    mon.vif = vif;
    
    drv.drvnext = nextgd;
    gen.drvnext = nextgd;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
      
  end
  
  initial begin
    drv.reset();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_none  
    wait(gen.done.triggered);
    $finish();
  end
   
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;   
  end
 
assign vif.next_addr = dut.next_addr;
 
endmodule