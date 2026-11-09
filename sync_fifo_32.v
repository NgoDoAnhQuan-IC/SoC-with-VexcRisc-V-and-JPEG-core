/*2. Nguyên lý hoạt động
Ghi vào (Write): Khi tín hiệu write_enable bật lên, dữ liệu từ write_data sẽ được đẩy vào trong ống.
Đọc ra (Read): Khi tín hiệu read_req (yêu cầu đọc) bật lên, dữ liệu cũ nhất đang nằm trong ống sẽ trôi ra cổng read_data. 
FIFO có nghĩa là cái nào vào trước thì ra trước.

Báo trạng thái:
fifo_empty: Báo hiệu ống đang rỗng, không có gì để đọc.
rdata_valid: Báo hiệu dữ liệu đang ở cổng read_data là hợp lệ (có nghĩa là lệnh đọc trước đó đã thành công).

3. Tại sao cần module này trong hệ thống JPEG?
Đây là thành phần cực kỳ quan trọng để chống "tắc nghẽn" hoặc "mất dữ liệu":
Vấn đề: Module nén Huffman (y_huff) hoạt động không đều. Có lúc ảnh phức tạp, nó tính toán lâu mới ra được 32-bit. 
Có lúc ảnh đơn giản (nhiều màu giống nhau), nó "bắn" ra dữ liệu 32-bit liên tục rất nhanh.

Giải pháp: FIFO đứng ở giữa hứng dữ liệu.
Khi Huffman tạo ra dữ liệu, nó ném ngay vào FIFO (miễn là FIFO chưa đầy) rồi quay lại làm việc tiếp, không cần chờ ai nhận.
Bên phía đầu ra (Output), mạch điều khiển sẽ thong thả lấy dữ liệu từ FIFO ra để ghi vào RAM hoặc gửi đi.*/
`timescale 1ns / 100ps

module sync_fifo_32 (clk, rst, read_req, write_data, write_enable, 
read_data, fifo_empty, rdata_valid);
input	clk;
input	rst;
input	read_req;
input [31:0] write_data;
input write_enable;
output [31:0] read_data;  
output  fifo_empty; 
output	rdata_valid;
   
reg [4:0] read_ptr;
reg [4:0] write_ptr;
reg [31:0] mem [0:15];
reg [31:0] read_data;
reg rdata_valid;
wire [3:0] write_addr = write_ptr[3:0];
wire [3:0] read_addr = read_ptr[3:0];	
wire read_enable = read_req && (~fifo_empty);
assign fifo_empty = (read_ptr == write_ptr);


always @(posedge clk)
  begin
   if (rst)
      write_ptr <= {(5){1'b0}};
   else if (write_enable)
      write_ptr <= write_ptr + {{4{1'b0}},1'b1};
  end

always @(posedge clk)
begin
   if (rst)
      rdata_valid <= 1'b0;
   else if (read_enable)
      rdata_valid <= 1'b1;
   else
   	  rdata_valid <= 1'b0;  
end
  
always @(posedge clk)
 begin
   if (rst)
      read_ptr <= {(5){1'b0}};
   else if (read_enable)
      read_ptr <= read_ptr + {{4{1'b0}},1'b1};
end

// Mem write
always @(posedge clk)
  begin
   if (write_enable)
     mem[write_addr] <= write_data;
  end
// Mem Read
always @(posedge clk)
  begin
   if (read_enable)
      read_data <= mem[read_addr];
  end
  
endmodule 

/* `timescale 1ns / 100ps

module sync_fifo_32 (
    clk, 
    rst, 
    read_req, 
    write_data, 
    write_enable, 
    read_data, 
    fifo_empty, 
    rdata_valid
);
input         clk;
input         rst;
input         read_req;
input  [31:0] write_data;
input         write_enable;
output [31:0] read_data;  
output        fifo_empty; 
output        rdata_valid;
    
// Con trỏ 8-bit cho dung lượng 128 ô
reg [7:0] read_ptr;
reg [7:0] write_ptr;

// Bộ nhớ 128 ô 32-bit
reg [31:0] mem [0:127]; 
reg [31:0] read_data;
reg        rdata_valid;

// Lấy 7 bit thấp [6:0] làm địa chỉ (2^7 = 128)
wire [6:0] write_addr = write_ptr[6:0];
wire [6:0] read_addr  = read_ptr[6:0]; 

wire read_enable = read_req && (~fifo_empty);
assign fifo_empty = (read_ptr == write_ptr);

always @(posedge clk) begin
   if (rst)
      write_ptr <= 8'b0;
   else if (write_enable)
      write_ptr <= write_ptr + 8'b1;
end

always @(posedge clk) begin
   if (rst)
      rdata_valid <= 1'b0;
   else if (read_enable)
      rdata_valid <= 1'b1;
   else
      rdata_valid <= 1'b0;  
end
  
always @(posedge clk) begin
   if (rst)
      read_ptr <= 8'b0;
   else if (read_enable)
      read_ptr <= read_ptr + 8'b1;
end

// Mem write
always @(posedge clk) begin
   if (write_enable)
      mem[write_addr] <= write_data;
end

// Mem Read
always @(posedge clk) begin
   if (read_enable)
      read_data <= mem[read_addr];
end
  
endmodule */


