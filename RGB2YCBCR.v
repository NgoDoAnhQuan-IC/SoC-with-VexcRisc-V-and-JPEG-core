/* Mô-đun này chuyển đổi dữ liệu pixel 8-bit Đỏ, Xanh lục và Xanh lam đầu vào
thành các giá trị 8-bit Y, Cb và Cr. Các giá trị đầu ra sẽ là số không dấu
trong phạm vi từ 0 đến 255.
data_in chứa giá trị pixel Đỏ ở bit [7:0], Xanh lục ở bit [15:8],
và Xanh lam ở bit [23:16].
data_out chứa giá trị Y ở bit [7:0], giá trị Cb ở bit [15:8],
và giá trị Cr ở bit [23:16].*/

`timescale 1ns / 100ps

module RGB2YCBCR(clk, rst, enable, data_in, data_out,
enable_out);
input		clk;
input		rst;
input		enable;
input	[23:0]	data_in;				//{B,G,R}
output	[23:0]	data_out;		//{CR,CB,Y}
output	enable_out;

/* Y=0.299R+0.587G+0.114B
	Cb=-0.169R-0.331G+0.500B+128
	Cr=0.500R-0.419G-0.081B+128 */

//Scale ×16384 (2^14) de dung so nguyen 
wire [13:0] Y1 = 14'd4899;			//0.299
wire [13:0] Y2 = 14'd9617;			//0.587
wire [13:0] Y3 = 14'd1868;			//0.114
wire [13:0] CB1 = 14'd2764;		//0.1687
wire [13:0] CB2 = 14'd5428;		//0.3313
wire [13:0] CB3 = 14'd8192;		//0.5
wire [13:0] CR1 = 14'd8192;		//0.5
wire [13:0] CR2 = 14'd6860;		//0.4187
wire [13:0] CR3 = 14'd1332;		//0.0813
reg [21:0] Y_temp, CB_temp, CR_temp;
reg [21:0] Y1_product, Y2_product, Y3_product;
reg [21:0] CB1_product, CB2_product, CB3_product;
reg [21:0] CR1_product, CR2_product, CR3_product;
reg [7:0] Y, CB, CR;
reg	enable_1, enable_2, enable_out;
wire [23:0] data_out = {CR, CB, Y};

always @(posedge clk)
begin
	if (rst) begin
		Y1_product <= 0;	
		Y2_product <= 0;
		Y3_product <= 0;   
		CB1_product <= 0;	
		CB2_product <= 0;
		CB3_product <= 0;
		CR1_product <= 0;	
		CR2_product <= 0;
		CR3_product <= 0;
		Y_temp <= 0;
		CB_temp <= 0;
		CR_temp <= 0;
		end
	else if (enable) begin
		Y1_product <= Y1 * data_in[7:0];			//0.299*R
		Y2_product <= Y2 * data_in[15:8];		//0.587*G
		Y3_product <= Y3 * data_in[23:16];   	//0.114*B
		CB1_product <= CB1 * data_in[7:0];		//0.1687*R
		CB2_product <= CB2 * data_in[15:8];		//0.3313*G
		CB3_product <= CB3 * data_in[23:16];	//0.5*B
		CR1_product <= CR1 * data_in[7:0];		//0.5*R
		CR2_product <= CR2 * data_in[15:8];		//0.4187*G
		CR3_product <= CR3 * data_in[23:16];	//0.0813*B
		Y_temp <= Y1_product + Y2_product + Y3_product;									//Y=0.299R+0.587G+0.114B	
		CB_temp <= 22'd2097152 - CB1_product - CB2_product + CB3_product;			//Cb=-0.169R-0.331G+0.500B+128
		CR_temp <= 22'd2097152 + CR1_product - CR2_product - CR3_product;  		//Cr=0.500R-0.419G-0.081B+128
		end
end 
 
/* Làm tròn Y, CB, CR yêu cầu kiểm tra bit 13. Nếu có '1' ở bit 13,
thì giá trị trong các bit [21:14] cần được làm tròn lên bằng cách cộng thêm 1 vào giá trị
trong các bit đó */

always @(posedge clk)
begin
	if (rst) begin
		Y <= 0;
		CB <= 0;
		CR <= 0;   
		end
	else if (enable) begin
		Y <= Y_temp[13] ? Y_temp[21:14] + 1: Y_temp[21:14];
		CB <= CB_temp[13] & (CB_temp[21:14] != 8'd255) ? CB_temp[21:14] + 1: CB_temp[21:14];
		CR <= CR_temp[13] & (CR_temp[21:14] != 8'd255) ? CR_temp[21:14] + 1: CR_temp[21:14]; 
		// Cần tránh làm tròn nếu giá trị ở 8 bit cao nhất là 255, nếu không thì
		// giá trị sẽ tràn từ 255 xuống 0
		end
end


always @(posedge clk)
begin
	if (rst) begin
		enable_1 <= 0;
		enable_2 <= 0;
		enable_out <= 0;   
		end
	else begin
		enable_1 <= enable;
		enable_2 <= enable_1;
		enable_out <= enable_2;
		end
end
endmodule