`include "parameter.v"
module image_read
#(
  parameter WIDTH 	= 768,
			HEIGHT 	= 512,
			INFILE  = "kodim23.hex",
			INFILE1="mask.hex", 	// image file
			INFILE2="bg_hex.hex",
			VALUE= 100,								// value for Brightness operation
			THRESHOLD= 90,							// Threshold value for Threshold operation
			SIGN=1
)
(
	input HCLK,										// clock					
	input HRESETn,
	output reg data_write,
    output reg [7:0]  DATA_R0,				// 8 bit Red data (even)
    output reg [7:0]  DATA_G0,				// 8 bit Green data (even)
    output reg [7:0]  DATA_B0,				// 8 bit Blue data (even)
    output reg [7:0]  DATA_R1,				// 8 bit Red  data (odd)
    output reg [7:0]  DATA_G1,				// 8 bit Green data (odd)
    output reg [7:0]  DATA_B1,				// 8 bit Blue data (odd)
	output			  ctrl_done				// Done flag
);
localparam		ST_IDLE 	= 1'b0,
				ST_DATA		= 1'b1;
reg cstate;
reg nstate;
reg HRESETn_d;
reg start;
reg [7 : 0]   total_memory [0 : WIDTH*HEIGHT*3-1];
reg [7 : 0]   total_memory1 [0 : WIDTH*HEIGHT-1];	
reg [7 : 0]   total_memory2 [0 : WIDTH*HEIGHT*3-1];
integer temp_BMP   [0 : WIDTH*HEIGHT*3 - 1];	
integer temp_BMP1 [0 : WIDTH*HEIGHT - 1];
integer temp_BMP2   [0 : WIDTH*HEIGHT*3 - 1];			
integer org_R  [0 : WIDTH*HEIGHT - 1];
integer org_G  [0 : WIDTH*HEIGHT - 1];
integer org_B  [0 : WIDTH*HEIGHT - 1];
integer org_M  [0 : WIDTH*HEIGHT - 1]; 
integer org_RB [0 : WIDTH*HEIGHT - 1]; 	// temporary storage for R component
integer org_GB [0 : WIDTH*HEIGHT - 1];	// temporary storage for G component
integer org_BB  [0 : WIDTH*HEIGHT - 1];
integer org_A   [0:31*31-1];	// temporary storage for B component
integer i, j,k;
integer value,value1,value2,value4;
integer tempR0,tempR1,tempG0,tempG1,tempB0,tempB1; // temporary variables in contrast and brightness operation
reg [ 8:0] row;
reg [9:0] col;
reg [17:0] data_count;
//CONTRAST
real alpha = 2;
reg signed [15:0]adjusted_valueR0;
reg signed [15:0]adjusted_valueG0;
reg signed [15:0]adjusted_valueB0;
reg signed [15:0]adjusted_valueR1;
reg signed [15:0]adjusted_valueG1;
reg signed [15:0]adjusted_valueB1;
reg [7:0]clamped_valueR0;
reg [7:0]clamped_valueG0;
reg [7:0]clamped_valueB0;
reg [7:0]clamped_valueR1;
reg [7:0]clamped_valueG1;
reg [7:0]clamped_valueB1;
reg [7:0] avg0;
reg [7:0] avg1;
initial begin
    $readmemh(INFILE,total_memory,0,WIDTH*HEIGHT*3-1);
end
initial begin
    $readmemh(INFILE1,total_memory1,0,WIDTH*HEIGHT-1); // read file from INFILE
end
initial begin
    $readmemh(INFILE2,total_memory2,0,WIDTH*HEIGHT*3-1); // read file from INFILE
end
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP[i] = total_memory[i+0][7:0]; 
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_R[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+0]; // save Red component
                org_G[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+1];// save Green component
                org_B[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+2];// save Blue component
            end
        end
    end
end

//--------------------------------------------------------------------------------------------------------//
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT; i=i+1) begin
            temp_BMP1[i] = total_memory1[i+0][7:0]; 
        end
        
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_M[WIDTH*i+j] = temp_BMP1[WIDTH*(i)+j]; // save mask component
            end
        end
    end
end
//----------------------------------------------------------------------------------------------------------------------
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP2[i] = total_memory2[i+0][7:0]; 
        end
        
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_RB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+0]; // save Red component
                org_GB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+1];// save Green component
                org_BB[WIDTH*i+j] = temp_BMP2[WIDTH*3*(i)+3*j+2];// save Blue component
            end
        end
//for 31x31
/*
 org_A[0]=4;  org_A[1]=5;  org_A[2]=5;  org_A[3]=5;  org_A[4]=6;  org_A[5]=6;  org_A[6]=6;  org_A[7]=7;  org_A[8]=7;  org_A[9]=7;  org_A[10]=7;  org_A[11]=7;  org_A[12]=8;  org_A[13]=8;  org_A[14]=8;  org_A[15]=8;  org_A[16]=8;  org_A[17]=8;  org_A[18]=8;  org_A[19]=8;  org_A[20]=7;  org_A[21]=7;  org_A[22]=7;  org_A[23]=7;  org_A[24]=7;  org_A[25]=6;  org_A[26]=6;  org_A[27]=6;  org_A[28]=5;  org_A[29]=5;  org_A[30]=5; 
 org_A[31]=5;  org_A[32]=5;  org_A[33]=5;  org_A[34]=6;  org_A[35]=6;  org_A[36]=6;  org_A[37]=7;  org_A[38]=7;  org_A[39]=7;  org_A[40]=8;  org_A[41]=8;  org_A[42]=8;  org_A[43]=8;  org_A[44]=8;  org_A[45]=8;  org_A[46]=8;  org_A[47]=8;  org_A[48]=8;  org_A[49]=8;  org_A[50]=8;  org_A[51]=8;  org_A[52]=8;  org_A[53]=8;  org_A[54]=7;  org_A[55]=7;  org_A[56]=7;  org_A[57]=6;  org_A[58]=6;  org_A[59]=6;  org_A[60]=5;  org_A[61]=5; 
 org_A[62]=5;  org_A[63]=5;  org_A[64]=6;  org_A[65]=6;  org_A[66]=7;  org_A[67]=7;  org_A[68]=7;  org_A[69]=8;  org_A[70]=8;  org_A[71]=8;  org_A[72]=8;  org_A[73]=9;  org_A[74]=9;  org_A[75]=9;  org_A[76]=9;  org_A[77]=9;  org_A[78]=9;  org_A[79]=9;  org_A[80]=9;  org_A[81]=9;  org_A[82]=9;  org_A[83]=8;  org_A[84]=8;  org_A[85]=8;  org_A[86]=8;  org_A[87]=7;  org_A[88]=7;  org_A[89]=7;  org_A[90]=6;  org_A[91]=6;  org_A[92]=5; 
 org_A[93]=5;  org_A[94]=6;  org_A[95]=6;  org_A[96]=7;  org_A[97]=7;  org_A[98]=7;  org_A[99]=8;  org_A[100]=8;  org_A[101]=8;  org_A[102]=9;  org_A[103]=9;  org_A[104]=9;  org_A[105]=9;  org_A[106]=10;  org_A[107]=10;  org_A[108]=10;  org_A[109]=10;  org_A[110]=10;  org_A[111]=10;  org_A[112]=9;  org_A[113]=9;  org_A[114]=9;  org_A[115]=9;  org_A[116]=8;  org_A[117]=8;  org_A[118]=8;  org_A[119]=7;  org_A[120]=7;  org_A[121]=7;  org_A[122]=6;  org_A[123]=6; 
 org_A[124]=6;  org_A[125]=6;  org_A[126]=7;  org_A[127]=7;  org_A[128]=7;  org_A[129]=8;  org_A[130]=8;  org_A[131]=9;  org_A[132]=9;  org_A[133]=9;  org_A[134]=10;  org_A[135]=10;  org_A[136]=10;  org_A[137]=10;  org_A[138]=10;  org_A[139]=10;  org_A[140]=10;  org_A[141]=10;  org_A[142]=10;  org_A[143]=10;  org_A[144]=10;  org_A[145]=10;  org_A[146]=9;  org_A[147]=9;  org_A[148]=9;  org_A[149]=8;  org_A[150]=8;  org_A[151]=7;  org_A[152]=7;  org_A[153]=7;  org_A[154]=6; 
 org_A[155]=6;  org_A[156]=6;  org_A[157]=7;  org_A[158]=7;  org_A[159]=8;  org_A[160]=8;  org_A[161]=9;  org_A[162]=9;  org_A[163]=9;  org_A[164]=10;  org_A[165]=10;  org_A[166]=10;  org_A[167]=11;  org_A[168]=11;  org_A[169]=11;  org_A[170]=11;  org_A[171]=11;  org_A[172]=11;  org_A[173]=11;  org_A[174]=11;  org_A[175]=10;  org_A[176]=10;  org_A[177]=10;  org_A[178]=9;  org_A[179]=9;  org_A[180]=9;  org_A[181]=8;  org_A[182]=8;  org_A[183]=7;  org_A[184]=7;  org_A[185]=6; 
 org_A[186]=6;  org_A[187]=7;  org_A[188]=7;  org_A[189]=8;  org_A[190]=8;  org_A[191]=9;  org_A[192]=9;  org_A[193]=10;  org_A[194]=10;  org_A[195]=10;  org_A[196]=11;  org_A[197]=11;  org_A[198]=11;  org_A[199]=11;  org_A[200]=11;  org_A[201]=11;  org_A[202]=11;  org_A[203]=11;  org_A[204]=11;  org_A[205]=11;  org_A[206]=11;  org_A[207]=11;  org_A[208]=10;  org_A[209]=10;  org_A[210]=10;  org_A[211]=9;  org_A[212]=9;  org_A[213]=8;  org_A[214]=8;  org_A[215]=7;  org_A[216]=7; 
 org_A[217]=7;  org_A[218]=7;  org_A[219]=8;  org_A[220]=8;  org_A[221]=9;  org_A[222]=9;  org_A[223]=10;  org_A[224]=10;  org_A[225]=10;  org_A[226]=11;  org_A[227]=11;  org_A[228]=11;  org_A[229]=12;  org_A[230]=12;  org_A[231]=12;  org_A[232]=12;  org_A[233]=12;  org_A[234]=12;  org_A[235]=12;  org_A[236]=12;  org_A[237]=11;  org_A[238]=11;  org_A[239]=11;  org_A[240]=10;  org_A[241]=10;  org_A[242]=10;  org_A[243]=9;  org_A[244]=9;  org_A[245]=8;  org_A[246]=8;  org_A[247]=7; 
 org_A[248]=7;  org_A[249]=7;  org_A[250]=8;  org_A[251]=8;  org_A[252]=9;  org_A[253]=9;  org_A[254]=10;  org_A[255]=10;  org_A[256]=11;  org_A[257]=11;  org_A[258]=12;  org_A[259]=12;  org_A[260]=12;  org_A[261]=12;  org_A[262]=12;  org_A[263]=12;  org_A[264]=12;  org_A[265]=12;  org_A[266]=12;  org_A[267]=12;  org_A[268]=12;  org_A[269]=12;  org_A[270]=11;  org_A[271]=11;  org_A[272]=10;  org_A[273]=10;  org_A[274]=9;  org_A[275]=9;  org_A[276]=8;  org_A[277]=8;  org_A[278]=7; 
 org_A[279]=7;  org_A[280]=8;  org_A[281]=8;  org_A[282]=9;  org_A[283]=9;  org_A[284]=10;  org_A[285]=10;  org_A[286]=11;  org_A[287]=11;  org_A[288]=12;  org_A[289]=12;  org_A[290]=12;  org_A[291]=13;  org_A[292]=13;  org_A[293]=13;  org_A[294]=13;  org_A[295]=13;  org_A[296]=13;  org_A[297]=13;  org_A[298]=13;  org_A[299]=12;  org_A[300]=12;  org_A[301]=12;  org_A[302]=11;  org_A[303]=11;  org_A[304]=10;  org_A[305]=10;  org_A[306]=9;  org_A[307]=9;  org_A[308]=8;  org_A[309]=8; 
 org_A[310]=7;  org_A[311]=8;  org_A[312]=8;  org_A[313]=9;  org_A[314]=10;  org_A[315]=10;  org_A[316]=11;  org_A[317]=11;  org_A[318]=12;  org_A[319]=12;  org_A[320]=12;  org_A[321]=13;  org_A[322]=13;  org_A[323]=13;  org_A[324]=13;  org_A[325]=13;  org_A[326]=13;  org_A[327]=13;  org_A[328]=13;  org_A[329]=13;  org_A[330]=13;  org_A[331]=12;  org_A[332]=12;  org_A[333]=12;  org_A[334]=11;  org_A[335]=11;  org_A[336]=10;  org_A[337]=10;  org_A[338]=9;  org_A[339]=8;  org_A[340]=8; 
 org_A[341]=7;  org_A[342]=8;  org_A[343]=9;  org_A[344]=9;  org_A[345]=10;  org_A[346]=10;  org_A[347]=11;  org_A[348]=11;  org_A[349]=12;  org_A[350]=12;  org_A[351]=13;  org_A[352]=13;  org_A[353]=13;  org_A[354]=13;  org_A[355]=14;  org_A[356]=14;  org_A[357]=14;  org_A[358]=14;  org_A[359]=13;  org_A[360]=13;  org_A[361]=13;  org_A[362]=13;  org_A[363]=12;  org_A[364]=12;  org_A[365]=11;  org_A[366]=11;  org_A[367]=10;  org_A[368]=10;  org_A[369]=9;  org_A[370]=9;  org_A[371]=8; 
 org_A[372]=8;  org_A[373]=8;  org_A[374]=9;  org_A[375]=9;  org_A[376]=10;  org_A[377]=11;  org_A[378]=11;  org_A[379]=12;  org_A[380]=12;  org_A[381]=13;  org_A[382]=13;  org_A[383]=13;  org_A[384]=13;  org_A[385]=14;  org_A[386]=14;  org_A[387]=14;  org_A[388]=14;  org_A[389]=14;  org_A[390]=14;  org_A[391]=13;  org_A[392]=13;  org_A[393]=13;  org_A[394]=13;  org_A[395]=12;  org_A[396]=12;  org_A[397]=11;  org_A[398]=11;  org_A[399]=10;  org_A[400]=9;  org_A[401]=9;  org_A[402]=8; 
 org_A[403]=8;  org_A[404]=8;  org_A[405]=9;  org_A[406]=10;  org_A[407]=10;  org_A[408]=11;  org_A[409]=11;  org_A[410]=12;  org_A[411]=12;  org_A[412]=13;  org_A[413]=13;  org_A[414]=13;  org_A[415]=14;  org_A[416]=14;  org_A[417]=14;  org_A[418]=14;  org_A[419]=14;  org_A[420]=14;  org_A[421]=14;  org_A[422]=14;  org_A[423]=13;  org_A[424]=13;  org_A[425]=13;  org_A[426]=12;  org_A[427]=12;  org_A[428]=11;  org_A[429]=11;  org_A[430]=10;  org_A[431]=10;  org_A[432]=9;  org_A[433]=8; 
 org_A[434]=8;  org_A[435]=8;  org_A[436]=9;  org_A[437]=10;  org_A[438]=10;  org_A[439]=11;  org_A[440]=11;  org_A[441]=12;  org_A[442]=12;  org_A[443]=13;  org_A[444]=13;  org_A[445]=14;  org_A[446]=14;  org_A[447]=14;  org_A[448]=14;  org_A[449]=14;  org_A[450]=14;  org_A[451]=14;  org_A[452]=14;  org_A[453]=14;  org_A[454]=14;  org_A[455]=13;  org_A[456]=13;  org_A[457]=12;  org_A[458]=12;  org_A[459]=11;  org_A[460]=11;  org_A[461]=10;  org_A[462]=10;  org_A[463]=9;  org_A[464]=8; 
 org_A[465]=8;  org_A[466]=8;  org_A[467]=9;  org_A[468]=10;  org_A[469]=10;  org_A[470]=11;  org_A[471]=11;  org_A[472]=12;  org_A[473]=12;  org_A[474]=13;  org_A[475]=13;  org_A[476]=14;  org_A[477]=14;  org_A[478]=14;  org_A[479]=14;  org_A[480]=14;  org_A[481]=14;  org_A[482]=14;  org_A[483]=14;  org_A[484]=14;  org_A[485]=14;  org_A[486]=13;  org_A[487]=13;  org_A[488]=12;  org_A[489]=12;  org_A[490]=11;  org_A[491]=11;  org_A[492]=10;  org_A[493]=10;  org_A[494]=9;  org_A[495]=8; 
 org_A[496]=8;  org_A[497]=8;  org_A[498]=9;  org_A[499]=10;  org_A[500]=10;  org_A[501]=11;  org_A[502]=11;  org_A[503]=12;  org_A[504]=12;  org_A[505]=13;  org_A[506]=13;  org_A[507]=14;  org_A[508]=14;  org_A[509]=14;  org_A[510]=14;  org_A[511]=14;  org_A[512]=14;  org_A[513]=14;  org_A[514]=14;  org_A[515]=14;  org_A[516]=14;  org_A[517]=13;  org_A[518]=13;  org_A[519]=12;  org_A[520]=12;  org_A[521]=11;  org_A[522]=11;  org_A[523]=10;  org_A[524]=10;  org_A[525]=9;  org_A[526]=8; 
 org_A[527]=8;  org_A[528]=8;  org_A[529]=9;  org_A[530]=10;  org_A[531]=10;  org_A[532]=11;  org_A[533]=11;  org_A[534]=12;  org_A[535]=12;  org_A[536]=13;  org_A[537]=13;  org_A[538]=14;  org_A[539]=14;  org_A[540]=14;  org_A[541]=14;  org_A[542]=14;  org_A[543]=14;  org_A[544]=14;  org_A[545]=14;  org_A[546]=14;  org_A[547]=14;  org_A[548]=13;  org_A[549]=13;  org_A[550]=12;  org_A[551]=12;  org_A[552]=11;  org_A[553]=11;  org_A[554]=10;  org_A[555]=10;  org_A[556]=9;  org_A[557]=8; 
 org_A[558]=8;  org_A[559]=8;  org_A[560]=9;  org_A[561]=10;  org_A[562]=10;  org_A[563]=11;  org_A[564]=11;  org_A[565]=12;  org_A[566]=12;  org_A[567]=13;  org_A[568]=13;  org_A[569]=13;  org_A[570]=14;  org_A[571]=14;  org_A[572]=14;  org_A[573]=14;  org_A[574]=14;  org_A[575]=14;  org_A[576]=14;  org_A[577]=14;  org_A[578]=13;  org_A[579]=13;  org_A[580]=13;  org_A[581]=12;  org_A[582]=12;  org_A[583]=11;  org_A[584]=11;  org_A[585]=10;  org_A[586]=10;  org_A[587]=9;  org_A[588]=8; 
 org_A[589]=8;  org_A[590]=8;  org_A[591]=9;  org_A[592]=9;  org_A[593]=10;  org_A[594]=11;  org_A[595]=11;  org_A[596]=12;  org_A[597]=12;  org_A[598]=13;  org_A[599]=13;  org_A[600]=13;  org_A[601]=13;  org_A[602]=14;  org_A[603]=14;  org_A[604]=14;  org_A[605]=14;  org_A[606]=14;  org_A[607]=14;  org_A[608]=13;  org_A[609]=13;  org_A[610]=13;  org_A[611]=13;  org_A[612]=12;  org_A[613]=12;  org_A[614]=11;  org_A[615]=11;  org_A[616]=10;  org_A[617]=9;  org_A[618]=9;  org_A[619]=8; 
 org_A[620]=7;  org_A[621]=8;  org_A[622]=9;  org_A[623]=9;  org_A[624]=10;  org_A[625]=10;  org_A[626]=11;  org_A[627]=11;  org_A[628]=12;  org_A[629]=12;  org_A[630]=13;  org_A[631]=13;  org_A[632]=13;  org_A[633]=13;  org_A[634]=14;  org_A[635]=14;  org_A[636]=14;  org_A[637]=14;  org_A[638]=13;  org_A[639]=13;  org_A[640]=13;  org_A[641]=13;  org_A[642]=12;  org_A[643]=12;  org_A[644]=11;  org_A[645]=11;  org_A[646]=10;  org_A[647]=10;  org_A[648]=9;  org_A[649]=9;  org_A[650]=8; 
 org_A[651]=7;  org_A[652]=8;  org_A[653]=8;  org_A[654]=9;  org_A[655]=10;  org_A[656]=10;  org_A[657]=11;  org_A[658]=11;  org_A[659]=12;  org_A[660]=12;  org_A[661]=12;  org_A[662]=13;  org_A[663]=13;  org_A[664]=13;  org_A[665]=13;  org_A[666]=13;  org_A[667]=13;  org_A[668]=13;  org_A[669]=13;  org_A[670]=13;  org_A[671]=13;  org_A[672]=12;  org_A[673]=12;  org_A[674]=12;  org_A[675]=11;  org_A[676]=11;  org_A[677]=10;  org_A[678]=10;  org_A[679]=9;  org_A[680]=8;  org_A[681]=8; 
 org_A[682]=7;  org_A[683]=8;  org_A[684]=8;  org_A[685]=9;  org_A[686]=9;  org_A[687]=10;  org_A[688]=10;  org_A[689]=11;  org_A[690]=11;  org_A[691]=12;  org_A[692]=12;  org_A[693]=12;  org_A[694]=13;  org_A[695]=13;  org_A[696]=13;  org_A[697]=13;  org_A[698]=13;  org_A[699]=13;  org_A[700]=13;  org_A[701]=13;  org_A[702]=12;  org_A[703]=12;  org_A[704]=12;  org_A[705]=11;  org_A[706]=11;  org_A[707]=10;  org_A[708]=10;  org_A[709]=9;  org_A[710]=9;  org_A[711]=8;  org_A[712]=8; 
 org_A[713]=7;  org_A[714]=7;  org_A[715]=8;  org_A[716]=8;  org_A[717]=9;  org_A[718]=9;  org_A[719]=10;  org_A[720]=10;  org_A[721]=11;  org_A[722]=11;  org_A[723]=12;  org_A[724]=12;  org_A[725]=12;  org_A[726]=12;  org_A[727]=12;  org_A[728]=12;  org_A[729]=12;  org_A[730]=12;  org_A[731]=12;  org_A[732]=12;  org_A[733]=12;  org_A[734]=12;  org_A[735]=11;  org_A[736]=11;  org_A[737]=10;  org_A[738]=10;  org_A[739]=9;  org_A[740]=9;  org_A[741]=8;  org_A[742]=8;  org_A[743]=7; 
 org_A[744]=7;  org_A[745]=7;  org_A[746]=8;  org_A[747]=8;  org_A[748]=9;  org_A[749]=9;  org_A[750]=10;  org_A[751]=10;  org_A[752]=10;  org_A[753]=11;  org_A[754]=11;  org_A[755]=11;  org_A[756]=12;  org_A[757]=12;  org_A[758]=12;  org_A[759]=12;  org_A[760]=12;  org_A[761]=12;  org_A[762]=12;  org_A[763]=12;  org_A[764]=11;  org_A[765]=11;  org_A[766]=11;  org_A[767]=10;  org_A[768]=10;  org_A[769]=10;  org_A[770]=9;  org_A[771]=9;  org_A[772]=8;  org_A[773]=8;  org_A[774]=7; 
 org_A[775]=6;  org_A[776]=7;  org_A[777]=7;  org_A[778]=8;  org_A[779]=8;  org_A[780]=9;  org_A[781]=9;  org_A[782]=10;  org_A[783]=10;  org_A[784]=10;  org_A[785]=11;  org_A[786]=11;  org_A[787]=11;  org_A[788]=11;  org_A[789]=11;  org_A[790]=11;  org_A[791]=11;  org_A[792]=11;  org_A[793]=11;  org_A[794]=11;  org_A[795]=11;  org_A[796]=11;  org_A[797]=10;  org_A[798]=10;  org_A[799]=10;  org_A[800]=9;  org_A[801]=9;  org_A[802]=8;  org_A[803]=8;  org_A[804]=7;  org_A[805]=7; 
 org_A[806]=6;  org_A[807]=6;  org_A[808]=7;  org_A[809]=7;  org_A[810]=8;  org_A[811]=8;  org_A[812]=9;  org_A[813]=9;  org_A[814]=9;  org_A[815]=10;  org_A[816]=10;  org_A[817]=10;  org_A[818]=11;  org_A[819]=11;  org_A[820]=11;  org_A[821]=11;  org_A[822]=11;  org_A[823]=11;  org_A[824]=11;  org_A[825]=11;  org_A[826]=10;  org_A[827]=10;  org_A[828]=10;  org_A[829]=9;  org_A[830]=9;  org_A[831]=9;  org_A[832]=8;  org_A[833]=8;  org_A[834]=7;  org_A[835]=7;  org_A[836]=6; 
 org_A[837]=6;  org_A[838]=6;  org_A[839]=7;  org_A[840]=7;  org_A[841]=7;  org_A[842]=8;  org_A[843]=8;  org_A[844]=9;  org_A[845]=9;  org_A[846]=9;  org_A[847]=10;  org_A[848]=10;  org_A[849]=10;  org_A[850]=10;  org_A[851]=10;  org_A[852]=10;  org_A[853]=10;  org_A[854]=10;  org_A[855]=10;  org_A[856]=10;  org_A[857]=10;  org_A[858]=10;  org_A[859]=9;  org_A[860]=9;  org_A[861]=9;  org_A[862]=8;  org_A[863]=8;  org_A[864]=7;  org_A[865]=7;  org_A[866]=7;  org_A[867]=6; 
 org_A[868]=5;  org_A[869]=6;  org_A[870]=6;  org_A[871]=7;  org_A[872]=7;  org_A[873]=7;  org_A[874]=8;  org_A[875]=8;  org_A[876]=8;  org_A[877]=9;  org_A[878]=9;  org_A[879]=9;  org_A[880]=9;  org_A[881]=10;  org_A[882]=10;  org_A[883]=10;  org_A[884]=10;  org_A[885]=10;  org_A[886]=10;  org_A[887]=9;  org_A[888]=9;  org_A[889]=9;  org_A[890]=9;  org_A[891]=8;  org_A[892]=8;  org_A[893]=8;  org_A[894]=7;  org_A[895]=7;  org_A[896]=7;  org_A[897]=6;  org_A[898]=6; 
 org_A[899]=5;  org_A[900]=5;  org_A[901]=6;  org_A[902]=6;  org_A[903]=7;  org_A[904]=7;  org_A[905]=7;  org_A[906]=8;  org_A[907]=8;  org_A[908]=8;  org_A[909]=8;  org_A[910]=9;  org_A[911]=9;  org_A[912]=9;  org_A[913]=9;  org_A[914]=9;  org_A[915]=9;  org_A[916]=9;  org_A[917]=9;  org_A[918]=9;  org_A[919]=9;  org_A[920]=8;  org_A[921]=8;  org_A[922]=8;  org_A[923]=8;  org_A[924]=7;  org_A[925]=7;  org_A[926]=7;  org_A[927]=6;  org_A[928]=6;  org_A[929]=5; 
 org_A[930]=5;  org_A[931]=5;  org_A[932]=5;  org_A[933]=6;  org_A[934]=6;  org_A[935]=6;  org_A[936]=7;  org_A[937]=7;  org_A[938]=7;  org_A[939]=8;  org_A[940]=8;  org_A[941]=8;  org_A[942]=8;  org_A[943]=8;  org_A[944]=8;  org_A[945]=8;  org_A[946]=8;  org_A[947]=8;  org_A[948]=8;  org_A[949]=8;  org_A[950]=8;  org_A[951]=8;  org_A[952]=8;  org_A[953]=7;  org_A[954]=7;  org_A[955]=7;  org_A[956]=6;  org_A[957]=6;  org_A[958]=6;  org_A[959]=5;  org_A[960]=5; 
   */
//for 15x15
org_A[0]=41;  org_A[1]=42;  org_A[2]=42;  org_A[3]=42;  org_A[4]=43;  org_A[5]=43;  org_A[6]=43;  org_A[7]=43;  org_A[8]=43;  org_A[9]=43;  org_A[10]=43;  org_A[11]=43;  org_A[12]=42;  org_A[13]=42;  org_A[14]=42; 
 org_A[15]=42;  org_A[16]=42;  org_A[17]=43;  org_A[18]=43;  org_A[19]=43;  org_A[20]=44;  org_A[21]=44;  org_A[22]=44;  org_A[23]=44;  org_A[24]=44;  org_A[25]=44;  org_A[26]=43;  org_A[27]=43;  org_A[28]=43;  org_A[29]=42; 
 org_A[30]=42;  org_A[31]=43;  org_A[32]=43;  org_A[33]=43;  org_A[34]=44;  org_A[35]=44;  org_A[36]=44;  org_A[37]=44;  org_A[38]=44;  org_A[39]=44;  org_A[40]=44;  org_A[41]=44;  org_A[42]=43;  org_A[43]=43;  org_A[44]=43; 
 org_A[45]=42;  org_A[46]=43;  org_A[47]=43;  org_A[48]=44;  org_A[49]=44;  org_A[50]=44;  org_A[51]=45;  org_A[52]=45;  org_A[53]=45;  org_A[54]=45;  org_A[55]=44;  org_A[56]=44;  org_A[57]=44;  org_A[58]=43;  org_A[59]=43; 
 org_A[60]=43;  org_A[61]=43;  org_A[62]=44;  org_A[63]=44;  org_A[64]=44;  org_A[65]=45;  org_A[66]=45;  org_A[67]=45;  org_A[68]=45;  org_A[69]=45;  org_A[70]=45;  org_A[71]=44;  org_A[72]=44;  org_A[73]=44;  org_A[74]=43; 
 org_A[75]=43;  org_A[76]=44;  org_A[77]=44;  org_A[78]=44;  org_A[79]=45;  org_A[80]=45;  org_A[81]=45;  org_A[82]=45;  org_A[83]=45;  org_A[84]=45;  org_A[85]=45;  org_A[86]=45;  org_A[87]=44;  org_A[88]=44;  org_A[89]=43; 
 org_A[90]=43;  org_A[91]=44;  org_A[92]=44;  org_A[93]=45;  org_A[94]=45;  org_A[95]=45;  org_A[96]=45;  org_A[97]=45;  org_A[98]=45;  org_A[99]=45;  org_A[100]=45;  org_A[101]=45;  org_A[102]=45;  org_A[103]=44;  org_A[104]=44; 
 org_A[105]=43;  org_A[106]=44;  org_A[107]=44;  org_A[108]=45;  org_A[109]=45;  org_A[110]=45;  org_A[111]=45;  org_A[112]=45;  org_A[113]=45;  org_A[114]=45;  org_A[115]=45;  org_A[116]=45;  org_A[117]=45;  org_A[118]=44;  org_A[119]=44; 
 org_A[120]=43;  org_A[121]=44;  org_A[122]=44;  org_A[123]=45;  org_A[124]=45;  org_A[125]=45;  org_A[126]=45;  org_A[127]=45;  org_A[128]=45;  org_A[129]=45;  org_A[130]=45;  org_A[131]=45;  org_A[132]=45;  org_A[133]=44;  org_A[134]=44; 
 org_A[135]=43;  org_A[136]=44;  org_A[137]=44;  org_A[138]=45;  org_A[139]=45;  org_A[140]=45;  org_A[141]=45;  org_A[142]=45;  org_A[143]=45;  org_A[144]=45;  org_A[145]=45;  org_A[146]=45;  org_A[147]=45;  org_A[148]=44;  org_A[149]=44; 
 org_A[150]=43;  org_A[151]=44;  org_A[152]=44;  org_A[153]=44;  org_A[154]=45;  org_A[155]=45;  org_A[156]=45;  org_A[157]=45;  org_A[158]=45;  org_A[159]=45;  org_A[160]=45;  org_A[161]=45;  org_A[162]=44;  org_A[163]=44;  org_A[164]=43; 
 org_A[165]=43;  org_A[166]=43;  org_A[167]=44;  org_A[168]=44;  org_A[169]=44;  org_A[170]=45;  org_A[171]=45;  org_A[172]=45;  org_A[173]=45;  org_A[174]=45;  org_A[175]=45;  org_A[176]=44;  org_A[177]=44;  org_A[178]=44;  org_A[179]=43; 
 org_A[180]=42;  org_A[181]=43;  org_A[182]=43;  org_A[183]=44;  org_A[184]=44;  org_A[185]=44;  org_A[186]=45;  org_A[187]=45;  org_A[188]=45;  org_A[189]=45;  org_A[190]=44;  org_A[191]=44;  org_A[192]=44;  org_A[193]=43;  org_A[194]=43; 
 org_A[195]=42;  org_A[196]=43;  org_A[197]=43;  org_A[198]=43;  org_A[199]=44;  org_A[200]=44;  org_A[201]=44;  org_A[202]=44;  org_A[203]=44;  org_A[204]=44;  org_A[205]=44;  org_A[206]=44;  org_A[207]=43;  org_A[208]=43;  org_A[209]=43; 
 org_A[210]=42;  org_A[211]=42;  org_A[212]=43;  org_A[213]=43;  org_A[214]=43;  org_A[215]=43;  org_A[216]=44;  org_A[217]=44;  org_A[218]=44;  org_A[219]=44;  org_A[220]=43;  org_A[221]=43;  org_A[222]=43;  org_A[223]=43;  org_A[224]=42;
    k=0;
    for(i=0;i<15*15;i=i+1)
    begin 
    k=k+org_A[i];
     end
    end
end

always@(posedge HCLK, negedge HRESETn)begin
    if(!HRESETn) begin
        start <= 0;
        HRESETn_d<=0;
    end
    else begin						//       	|		|
        HRESETn_d<=HRESETn;
		if(HRESETn==1'b1 && HRESETn_d==1'b0)
			start <= 1'b1;
		else
			start <= 1'b0;
    end
end
always@(posedge HCLK, negedge HRESETn)begin
    if(~HRESETn) begin
        cstate <= ST_IDLE;
    end
    else begin
        cstate <= nstate; // update next state 
    end
end
always @(*) begin
	case(cstate)
		ST_IDLE: begin
			if(start)
				nstate = ST_DATA;
			else
				nstate = ST_IDLE;
		end
		ST_DATA: begin
			if(ctrl_done)
				nstate = ST_IDLE;
		end
	endcase
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        row <= 0;
		col <= 0;
    end
	else begin
		if(cstate == ST_DATA) begin
			if(col == WIDTH - 2) begin
				row <= row + 1;
			end
			if(col == WIDTH - 2) 
				col <= 0;
			else 
				col <= col + 2; // reading 2 pixels in parallel
		end
	end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        data_count <= 0;
    end
    else begin
        if(cstate == ST_DATA)
			data_count <= data_count + 1;
    end
end
assign ctrl_done = (data_count == 196607)? 1'b1: 1'b0;
always @(*) begin
	data_write   = 1'b0;
	DATA_R0 = 0;
	DATA_G0 = 0;
	DATA_B0 = 0;                                       
	DATA_R1 = 0;
	DATA_G1 = 0;
	DATA_B1 = 0;
    tempR0 = 0;
	tempG0 = 0;
	tempB0 = 0;                                       
	tempR1 = 0;
	tempG1 = 0;
	tempB1 = 0;                                          
	if(cstate == ST_DATA) begin
		data_write   = 1'b1;
		`ifdef BRIGHTNESS_OPERATION	
		/**************************************/		
		/*		BRIGHTNESS ADDITION OPERATION */
		/**************************************/
		if(SIGN == 1) begin
		// R0
		if (org_R[WIDTH * row + col   ] + VALUE > 255)
			DATA_R0 = 255;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] + VALUE;
		// R1	
		if (org_R[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_R1 = 255;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] + VALUE;	
		// G0	
		if (org_G[WIDTH * row + col   ] + VALUE > 255)
			DATA_G0 = 255;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] + VALUE;
		if (org_G[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_G1 = 255;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] + VALUE;		
		// B0
		if (org_B[WIDTH * row + col   ] + VALUE > 255)
			DATA_B0 = 255;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] + VALUE;
		if (org_B[WIDTH * row + col+1   ] + VALUE > 255)
			DATA_B1 = 255;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] + VALUE;
	end
	else begin
	/**************************************/		
	/*	BRIGHTNESS SUBTRACTION OPERATION */
	/**************************************/
		// R0
		if (org_R[WIDTH * row + col   ] - VALUE < 0)
			DATA_R0 = 0;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] - VALUE;
		// R1	
		if (org_R[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_R1 = 0;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] - VALUE;	
		// G0	
		if (org_G[WIDTH * row + col   ] - VALUE < 0)
			DATA_G0 = 0;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] - VALUE;
		if (org_G[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_G1 = 0;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] - VALUE;		
		// B
		if (org_B[WIDTH * row + col   ] - VALUE < 0)
			DATA_B0 = 0;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] - VALUE;
		if (org_B[WIDTH * row + col+1   ] - VALUE < 0)
			DATA_B1 = 0;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] - VALUE;
	 end
		`endif
	
		/**************************************/		
		/*		INVERT_OPERATION  			  */
		/**************************************/
		`ifdef INVERT_OPERATION	
			value2 = (org_B[WIDTH * row + col  ] + org_R[WIDTH * row + col  ] +org_G[WIDTH * row + col  ])/3;
			DATA_R0=255-value2;
			DATA_G0=255-value2;
			DATA_B0=255-value2;
			value4 = (org_B[WIDTH * row + col+1  ] + org_R[WIDTH * row + col+1  ] +org_G[WIDTH * row + col+1  ])/3;
			DATA_R1=255-value4;
			DATA_G1=255-value4;
			DATA_B1=255-value4;		
		`endif
		/**************************************/		
		/********THRESHOLD OPERATION  *********/
		/**************************************/
		`ifdef THRESHOLD_OPERATION

		value = (org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
		if(value > THRESHOLD) begin
			DATA_R0=255;
			DATA_G0=255;
			DATA_B0=255;
		end
		else begin
			DATA_R0=0;
			DATA_G0=0;
			DATA_B0=0;
		end
		value1 = (org_R[WIDTH * row + col+1   ]+org_G[WIDTH * row + col+1   ]+org_B[WIDTH * row + col+1   ])/3;
		if(value1 > THRESHOLD) begin
			DATA_R1=255;
			DATA_G1=255;
			DATA_B1=255;
		end
		else begin
			DATA_R1=0;
			DATA_G1=0;
			DATA_B1=0;
		end		
		`endif
		`ifdef CONTRAST
		avg0=(org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
		avg1=(org_R[WIDTH * row + col   +1]+org_G[WIDTH * row + col   +1]+org_B[WIDTH * row + col   +1])/3;
		  adjusted_valueR0 = ((org_R[WIDTH * row + col   ] - 128) * alpha);
          adjusted_valueG0 = ((org_G[WIDTH * row + col   ] - 128) * alpha);
          adjusted_valueB0 = ((org_B[WIDTH * row + col   ] - 128) * alpha);
          adjusted_valueR1 = ((org_R[WIDTH * row + col   +1] - 128) * alpha);
          adjusted_valueG1 = ((org_G[WIDTH * row + col   +1] - 128) * alpha);
          adjusted_valueB1 = ((org_B[WIDTH * row + col   +1] - 128) * alpha);
          
    // Re-center and clamp to 0–255
          clamped_valueR0 = (adjusted_valueR0 + 128 < 0) ? 0 :
                           (adjusted_valueR0 + 128 > 255) ? 255 :
                           (adjusted_valueR0 + 128);
          clamped_valueG0 = (adjusted_valueG0 + 128 < 0) ? 0 :
                           (adjusted_valueG0 + 128 > 255) ? 255 :
                           (adjusted_valueG0 + 128);
          clamped_valueB0 = (adjusted_valueB0 + 128 < 0) ? 0 :
                           (adjusted_valueB0 + 128 > 255) ? 255 :
                           (adjusted_valueB0 + 128);
          clamped_valueR1 = (adjusted_valueR1 + 128 < 0) ? 0 :
                           (adjusted_valueR1 + 128 > 255) ? 255 :
                           (adjusted_valueR1 + 128);
          clamped_valueG1 = (adjusted_valueG1 + 128 < 0) ? 0 :
                           (adjusted_valueG1 + 128 > 255) ? 255 :
                           (adjusted_valueG1 + 128);
          clamped_valueB1 = (adjusted_valueB1 + 128 < 0) ? 0 :
                           (adjusted_valueB1 + 128 > 255) ? 255 :
                           (adjusted_valueB1 + 128);
          DATA_R0 = clamped_valueR0;
          DATA_G0 = clamped_valueG0;
          DATA_B0 = clamped_valueB0;
          DATA_R1 = clamped_valueR1;
          DATA_G1 = clamped_valueG1;
          DATA_B1 = clamped_valueB1;
		`endif
		
		`ifdef GAUSSIAN_BLUR
 if(org_M[WIDTH*row+col]==0 )
begin 
value=row<7?-row:-7;
value1=row<HEIGHT-7?7:HEIGHT-row;
value2=col<7?-col:-7;
value4=col<WIDTH-7?7:WIDTH-col;
for(i=value;i<value1;i=i+1)
begin 
for(j=value2;j<value4;j=j+1)
begin
    tempR0 = tempR0+org_R[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];
	tempG0 = tempG0+org_G[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];
	tempB0 = tempB0+org_B[WIDTH*(row+i)+col+j]*org_A[15*(7+i)+7+j];                                       
	tempR1 = tempR1+org_R[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];
	tempG1 = tempG1+org_G[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];
	tempB1 = tempB1+org_B[WIDTH*(row+i)+col+j+1]*org_A[15*(7+i)+7+j];     
end
end
     DATA_R0 = tempR0/k;
	DATA_G0 = tempG0/k;
	DATA_B0 = tempB0/k;                                       
	DATA_R1 = tempR1/k;
	DATA_G1 = tempG1/k;
	DATA_B1 = tempB1/k;    
end
else begin
	DATA_R0 = org_R[WIDTH*(row)+ (col)];
	DATA_G0 = org_G[WIDTH*(row)+ (col)];
	DATA_B0 = org_B[WIDTH*(row)+ (col)];                                       
	DATA_R1 = org_R[WIDTH*(row)+ (col+1)];
	DATA_G1 = org_G[WIDTH*(row)+ (col)+1];
	DATA_B1 = org_B[WIDTH*(row)+ (col)+1];    
		end
		`endif
`ifdef BACK_GROUND
		if(org_M[WIDTH*row+col]==0) 
		begin
			DATA_R0 = org_RB[WIDTH*(row)+ (col)];
	DATA_G0 = org_GB[WIDTH*(row)+ (col)];
	DATA_B0 = org_BB[WIDTH*(row)+ (col)];                                       
	DATA_R1 = org_RB[WIDTH*(row)+ (col+1)];
	DATA_G1 = org_GB[WIDTH*(row)+ (col)+1];
	DATA_B1 = org_BB[WIDTH*(row)+ (col)+1];  
	end
	 else begin 
	 DATA_R0 = org_R[WIDTH*(row)+ (col)];
	DATA_G0 = org_G[WIDTH*(row)+ (col)];
	DATA_B0 = org_B[WIDTH*(row)+ (col)];                                       
	DATA_R1 = org_R[WIDTH*(row)+ (col+1)];
	DATA_G1 = org_G[WIDTH*(row)+ (col)+1];
	DATA_B1 = org_B[WIDTH*(row)+ (col)+1];  
	end
		`endif
		
	end
end

endmodule
