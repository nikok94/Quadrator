LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use IEEE.MATH_REAL.ALL;
use IEEE.Std_Logic_Arith.all;

ENTITY CRC32 IS
    GENERIC (
      c_init        : std_logic_vector(31 downto 0) := x"FFFFFFFF"
    );
    PORT (
      clk       : in std_logic;
      rst       : in std_logic;
      din       : in std_logic_vector(7 downto 0);
      wr_en     : in std_logic;
      wr_ack    : out std_logic;
      crc_out   : out std_logic_vector(31 downto 0);
      valid     : out std_logic
    );
END CRC32;


ARCHITECTURE SYN OF CRC32 IS
    type crc32table_type is array (255 downto 0) of std_logic_vector(31 downto 0);
    signal Crc32Table : crc32table_type := (000 => x"00000000", 001 => x"77073096", 002 => x"EE0E612C", 003 => x"990951BA", 004 => x"076DC419", 005 => x"706AF48F", 006 => x"E963A535", 007 => x"9E6495A3",
                                            008 => x"0EDB8832", 009 => x"79DCB8A4", 010 => x"E0D5E91E", 011 => x"97D2D988", 012 => x"09B64C2B", 013 => x"7EB17CBD", 014 => x"E7B82D07", 015 => x"90BF1D91",
                                            016 => x"1DB71064", 017 => x"6AB020F2", 018 => x"F3B97148", 019 => x"84BE41DE", 020 => x"1ADAD47D", 021 => x"6DDDE4EB", 022 => x"F4D4B551", 023 => x"83D385C7",
                                            024 => x"136C9856", 025 => x"646BA8C0", 026 => x"FD62F97A", 027 => x"8A65C9EC", 028 => x"14015C4F", 029 => x"63066CD9", 030 => x"FA0F3D63", 031 => x"8D080DF5",
                                            032 => x"3B6E20C8", 033 => x"4C69105E", 034 => x"D56041E4", 035 => x"A2677172", 036 => x"3C03E4D1", 037 => x"4B04D447", 038 => x"D20D85FD", 039 => x"A50AB56B",
                                            040 => x"35B5A8FA", 041 => x"42B2986C", 042 => x"DBBBC9D6", 043 => x"ACBCF940", 044 => x"32D86CE3", 045 => x"45DF5C75", 046 => x"DCD60DCF", 047 => x"ABD13D59",
                                            048 => x"26D930AC", 049 => x"51DE003A", 050 => x"C8D75180", 051 => x"BFD06116", 052 => x"21B4F4B5", 053 => x"56B3C423", 054 => x"CFBA9599", 055 => x"B8BDA50F",
                                            056 => x"2802B89E", 057 => x"5F058808", 058 => x"C60CD9B2", 059 => x"B10BE924", 060 => x"2F6F7C87", 061 => x"58684C11", 062 => x"C1611DAB", 063 => x"B6662D3D",
                                            064 => x"76DC4190", 065 => x"01DB7106", 066 => x"98D220BC", 067 => x"EFD5102A", 068 => x"71B18589", 069 => x"06B6B51F", 070 => x"9FBFE4A5", 071 => x"E8B8D433",
                                            072 => x"7807C9A2", 073 => x"0F00F934", 074 => x"9609A88E", 075 => x"E10E9818", 076 => x"7F6A0DBB", 077 => x"086D3D2D", 078 => x"91646C97", 079 => x"E6635C01",
                                            080 => x"6B6B51F4", 081 => x"1C6C6162", 082 => x"856530D8", 083 => x"F262004E", 084 => x"6C0695ED", 085 => x"1B01A57B", 086 => x"8208F4C1", 087 => x"F50FC457",
                                            088 => x"65B0D9C6", 089 => x"12B7E950", 090 => x"8BBEB8EA", 091 => x"FCB9887C", 092 => x"62DD1DDF", 093 => x"15DA2D49", 094 => x"8CD37CF3", 095 => x"FBD44C65",
                                            096 => x"4DB26158", 097 => x"3AB551CE", 098 => x"A3BC0074", 099 => x"D4BB30E2", 100 => x"4ADFA541", 101 => x"3DD895D7", 102 => x"A4D1C46D", 103 => x"D3D6F4FB",
                                            104 => x"4369E96A", 105 => x"346ED9FC", 106 => x"AD678846", 107 => x"DA60B8D0", 108 => x"44042D73", 109 => x"33031DE5", 110 => x"AA0A4C5F", 111 => x"DD0D7CC9",
                                            112 => x"5005713C", 113 => x"270241AA", 114 => x"BE0B1010", 115 => x"C90C2086", 116 => x"5768B525", 117 => x"206F85B3", 118 => x"B966D409", 119 => x"CE61E49F",
                                            120 => x"5EDEF90E", 121 => x"29D9C998", 122 => x"B0D09822", 123 => x"C7D7A8B4", 124 => x"59B33D17", 125 => x"2EB40D81", 126 => x"B7BD5C3B", 127 => x"C0BA6CAD",
                                            128 => x"EDB88320", 129 => x"9ABFB3B6", 130 => x"03B6E20C", 131 => x"74B1D29A", 132 => x"EAD54739", 133 => x"9DD277AF", 134 => x"04DB2615", 135 => x"73DC1683",
                                            136 => x"E3630B12", 137 => x"94643B84", 138 => x"0D6D6A3E", 139 => x"7A6A5AA8", 140 => x"E40ECF0B", 141 => x"9309FF9D", 142 => x"0A00AE27", 143 => x"7D079EB1",
                                            144 => x"F00F9344", 145 => x"8708A3D2", 146 => x"1E01F268", 147 => x"6906C2FE", 148 => x"F762575D", 149 => x"806567CB", 150 => x"196C3671", 151 => x"6E6B06E7",
                                            152 => x"FED41B76", 153 => x"89D32BE0", 154 => x"10DA7A5A", 155 => x"67DD4ACC", 156 => x"F9B9DF6F", 157 => x"8EBEEFF9", 158 => x"17B7BE43", 159 => x"60B08ED5",
                                            160 => x"D6D6A3E8", 161 => x"A1D1937E", 162 => x"38D8C2C4", 163 => x"4FDFF252", 164 => x"D1BB67F1", 165 => x"A6BC5767", 166 => x"3FB506DD", 167 => x"48B2364B",
                                            168 => x"D80D2BDA", 169 => x"AF0A1B4C", 170 => x"36034AF6", 171 => x"41047A60", 172 => x"DF60EFC3", 173 => x"A867DF55", 174 => x"316E8EEF", 175 => x"4669BE79",
                                            176 => x"CB61B38C", 177 => x"BC66831A", 178 => x"256FD2A0", 179 => x"5268E236", 180 => x"CC0C7795", 181 => x"BB0B4703", 182 => x"220216B9", 183 => x"5505262F",
                                            184 => x"C5BA3BBE", 185 => x"B2BD0B28", 186 => x"2BB45A92", 187 => x"5CB36A04", 188 => x"C2D7FFA7", 189 => x"B5D0CF31", 190 => x"2CD99E8B", 191 => x"5BDEAE1D",
                                            192 => x"9B64C2B0", 193 => x"EC63F226", 194 => x"756AA39C", 195 => x"026D930A", 196 => x"9C0906A9", 197 => x"EB0E363F", 198 => x"72076785", 199 => x"05005713",
                                            200 => x"95BF4A82", 201 => x"E2B87A14", 202 => x"7BB12BAE", 203 => x"0CB61B38", 204 => x"92D28E9B", 205 => x"E5D5BE0D", 206 => x"7CDCEFB7", 207 => x"0BDBDF21",
                                            208 => x"86D3D2D4", 209 => x"F1D4E242", 210 => x"68DDB3F8", 211 => x"1FDA836E", 212 => x"81BE16CD", 213 => x"F6B9265B", 214 => x"6FB077E1", 215 => x"18B74777",
                                            216 => x"88085AE6", 217 => x"FF0F6A70", 218 => x"66063BCA", 219 => x"11010B5C", 220 => x"8F659EFF", 221 => x"F862AE69", 222 => x"616BFFD3", 223 => x"166CCF45",
                                            224 => x"A00AE278", 225 => x"D70DD2EE", 226 => x"4E048354", 227 => x"3903B3C2", 228 => x"A7672661", 229 => x"D06016F7", 230 => x"4969474D", 231 => x"3E6E77DB",
                                            232 => x"AED16A4A", 233 => x"D9D65ADC", 234 => x"40DF0B66", 235 => x"37D83BF0", 236 => x"A9BCAE53", 237 => x"DEBB9EC5", 238 => x"47B2CF7F", 239 => x"30B5FFE9",
                                            240 => x"BDBDF21C", 241 => x"CABAC28A", 242 => x"53B39330", 243 => x"24B4A3A6", 244 => x"BAD03605", 245 => x"CDD70693", 246 => x"54DE5729", 247 => x"23D967BF",
                                            248 => x"B3667A2E", 249 => x"C4614AB8", 250 => x"5D681B02", 251 => x"2A6F2B94", 252 => x"B40BBE37", 253 => x"C30C8EA1", 254 => x"5A05DF1B", 255 => x"2D02EF8D"
                                                );
    signal ulCRC                    : std_logic_vector(31 downto 0):= x"FFFFFFFF";
    signal TableValue               : std_logic_vector(31 downto 0);
    signal ack                      : std_logic;
    signal state                    : integer;

BEGIN

wr_ack <= ack;

main_process :
  process(clk, rst)
  begin
    if (rst = '1') then
      ulCRC <= x"FFFFFFFF";
      state <= 0;
      ack <= '0';
    elsif rising_edge(clk) then
      case (state) is
        when 0 =>
          valid <= '0';
          if (wr_en = '1') then
            ack <= '1';
            TableValue <= Crc32Table(conv_integer(ulCRC(7 downto 0) xor din));
            state <= 1;
          else
            ack <= '0'; 
          end if;
        when 1 =>
          ack <= '0';
          ulCRC <= (x"00" & ulCRC(31 downto 8)) xor TableValue;
          state <= 2;
        when 2 =>
          valid <= '1';
          crc_out <= ulCRC;
          state <= 0;
        when others =>
          valid <= '0';
          ack <= '0';
          state <= 0;
      end case;
    end if;
  end process;


END SYN;
