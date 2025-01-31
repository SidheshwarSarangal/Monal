#!/usr/bin/env python3
import re

# Function to generate the NSMakeRange output from the table of code points
def generate_ns_make_range(code_points):
    for entry in code_points:
        # If the entry is a range (tuple), generate the range NSMakeRange
        if isinstance(entry, tuple):
            start, end = entry
            print(f'[unassignedCodePointsCharacterSet addCharactersInRange:NSMakeRange(0x{start:04X}, 0x{end-start+1:X})];  // U+{start:04X} to U+{end:04X}')
        else:
            # Otherwise, it's a single code point, so generate the single character NSMakeRange
            print(f'[unassignedCodePointsCharacterSet addCharactersInRange:NSMakeRange(0x{entry:04X}, 1)];  // U+{entry:04X}')

# Parse the input Unicode code points and ranges
def parse_input(input_str):
    # Regular expression to match single code points or ranges in the form "start-end"
    pattern = r'([0-9A-Fa-f]+(?:-[0-9A-Fa-f]+)?)'
    
    # Find all matches in the input string
    matches = re.findall(pattern, input_str)
    
    # Convert matches to a list of integers or tuples for ranges
    code_points = []
    
    for match in matches:
        if '-' in match:
            # It's a range (start-end), split and convert to integers
            start, end = match.split('-')
            code_points.append((int(start, 16), int(end, 16)))
        else:
            # It's a single code point
            code_points.append(int(match, 16))
    
    return code_points
    
input_str = """
   0221
   0234-024F
   02AE-02AF
   02EF-02FF
   0350-035F
   0370-0373
   0376-0379
   037B-037D
   037F-0383
   038B
   038D
   03A2
   03CF
   03F7-03FF
   0487
   04CF
   04F6-04F7
   04FA-04FF
   0510-0530
   0557-0558
   0560
   0588
   058B-0590
   05A2
   05BA
   05C5-05CF
   05EB-05EF
   05F5-060B
   060D-061A
   061C-061E
   0620
   063B-063F
   0656-065F
   06EE-06EF
   06FF
   070E
   072D-072F
   074B-077F
   07B2-0900


   0904
   093A-093B
   094E-094F
   0955-0957
   0971-0980
   0984
   098D-098E
   0991-0992
   09A9
   09B1
   09B3-09B5
   09BA-09BB
   09BD
   09C5-09C6
   09C9-09CA
   09CE-09D6
   09D8-09DB
   09DE
   09E4-09E5
   09FB-0A01
   0A03-0A04
   0A0B-0A0E
   0A11-0A12
   0A29
   0A31
   0A34
   0A37
   0A3A-0A3B
   0A3D
   0A43-0A46
   0A49-0A4A
   0A4E-0A58
   0A5D
   0A5F-0A65
   0A75-0A80
   0A84
   0A8C
   0A8E
   0A92
   0AA9
   0AB1
   0AB4
   0ABA-0ABB
   0AC6
   0ACA
   0ACE-0ACF
   0AD1-0ADF
   0AE1-0AE5


   0AF0-0B00
   0B04
   0B0D-0B0E
   0B11-0B12
   0B29
   0B31
   0B34-0B35
   0B3A-0B3B
   0B44-0B46
   0B49-0B4A
   0B4E-0B55
   0B58-0B5B
   0B5E
   0B62-0B65
   0B71-0B81
   0B84
   0B8B-0B8D
   0B91
   0B96-0B98
   0B9B
   0B9D
   0BA0-0BA2
   0BA5-0BA7
   0BAB-0BAD
   0BB6
   0BBA-0BBD
   0BC3-0BC5
   0BC9
   0BCE-0BD6
   0BD8-0BE6
   0BF3-0C00
   0C04
   0C0D
   0C11
   0C29
   0C34
   0C3A-0C3D
   0C45
   0C49
   0C4E-0C54
   0C57-0C5F
   0C62-0C65
   0C70-0C81
   0C84
   0C8D
   0C91
   0CA9
   0CB4

   0CBA-0CBD
   0CC5
   0CC9
   0CCE-0CD4
   0CD7-0CDD
   0CDF
   0CE2-0CE5
   0CF0-0D01
   0D04
   0D0D
   0D11
   0D29
   0D3A-0D3D
   0D44-0D45
   0D49
   0D4E-0D56
   0D58-0D5F
   0D62-0D65
   0D70-0D81
   0D84
   0D97-0D99
   0DB2
   0DBC
   0DBE-0DBF
   0DC7-0DC9
   0DCB-0DCE
   0DD5
   0DD7
   0DE0-0DF1
   0DF5-0E00
   0E3B-0E3E
   0E5C-0E80
   0E83
   0E85-0E86
   0E89
   0E8B-0E8C
   0E8E-0E93
   0E98
   0EA0
   0EA4
   0EA6
   0EA8-0EA9
   0EAC
   0EBA
   0EBE-0EBF
   0EC5
   0EC7
   0ECE-0ECF
   
   0EDA-0EDB
   0EDE-0EFF
   0F48
   0F6B-0F70
   0F8C-0F8F
   0F98
   0FBD
   0FCD-0FCE
   0FD0-0FFF
   1022
   1028
   102B
   1033-1035
   103A-103F
   105A-109F
   10C6-10CF
   10F9-10FA
   10FC-10FF
   115A-115E
   11A3-11A7
   11FA-11FF
   1207
   1247
   1249
   124E-124F
   1257
   1259
   125E-125F
   1287
   1289
   128E-128F
   12AF
   12B1
   12B6-12B7
   12BF
   12C1
   12C6-12C7
   12CF
   12D7
   12EF
   130F
   1311
   1316-1317
   131F
   1347
   135B-1360
   137D-139F
   13F5-1400

   1677-167F
   169D-169F
   16F1-16FF
   170D
   1715-171F
   1737-173F
   1754-175F
   176D
   1771
   1774-177F
   17DD-17DF
   17EA-17FF
   180F
   181A-181F
   1878-187F
   18AA-1DFF
   1E9C-1E9F
   1EFA-1EFF
   1F16-1F17
   1F1E-1F1F
   1F46-1F47
   1F4E-1F4F
   1F58
   1F5A
   1F5C
   1F5E
   1F7E-1F7F
   1FB5
   1FC5
   1FD4-1FD5
   1FDC
   1FF0-1FF1
   1FF5
   1FFF
   2053-2056
   2058-205E
   2064-2069
   2072-2073
   208F-209F
   20B2-20CF
   20EB-20FF
   213B-213C
   214C-2152
   2184-218F
   23CF-23FF
   2427-243F
   244B-245F
   24FF

   2614-2615
   2618
   267E-267F
   268A-2700
   2705
   270A-270B
   2728
   274C
   274E
   2753-2755
   2757
   275F-2760
   2795-2797
   27B0
   27BF-27CF
   27EC-27EF
   2B00-2E7F
   2E9A
   2EF4-2EFF
   2FD6-2FEF
   2FFC-2FFF
   3040
   3097-3098
   3100-3104
   312D-3130
   318F
   31B8-31EF
   321D-321F
   3244-3250
   327C-327E
   32CC-32CF
   32FF
   3377-337A
   33DE-33DF
   33FF
   4DB6-4DFF
   9FA6-9FFF
   A48D-A48F
   A4C7-ABFF
   D7A4-D7FF
   FA2E-FA2F
   FA6B-FAFF
   FB07-FB12
   FB18-FB1C
   FB37
   FB3D
   FB3F
   FB42

   FB45
   FBB2-FBD2
   FD40-FD4F
   FD90-FD91
   FDC8-FDCF
   FDFD-FDFF
   FE10-FE1F
   FE24-FE2F
   FE47-FE48
   FE53
   FE67
   FE6C-FE6F
   FE75
   FEFD-FEFE
   FF00
   FFBF-FFC1
   FFC8-FFC9
   FFD0-FFD1
   FFD8-FFD9
   FFDD-FFDF
   FFE7
   FFEF-FFF8
   10000-102FF
   1031F
   10324-1032F
   1034B-103FF
   10426-10427
   1044E-1CFFF
   1D0F6-1D0FF
   1D127-1D129
   1D1DE-1D3FF
   1D455
   1D49D
   1D4A0-1D4A1
   1D4A3-1D4A4
   1D4A7-1D4A8
   1D4AD
   1D4BA
   1D4BC
   1D4C1
   1D4C4
   1D506
   1D50B-1D50C
   1D515
   1D51D
   1D53A
   1D53F
   1D545

   1D547-1D549
   1D551
   1D6A4-1D6A7
   1D7CA-1D7CD
   1D800-1FFFD
   2A6D7-2F7FF
   2FA1E-2FFFD
   30000-3FFFD
   40000-4FFFD
   50000-5FFFD
   60000-6FFFD
   70000-7FFFD
   80000-8FFFD
   90000-9FFFD
   A0000-AFFFD
   B0000-BFFFD
   C0000-CFFFD
   D0000-DFFFD
   E0000
   E0002-E001F
   E0080-EFFFD
"""

code_points = parse_input(input_str)
generate_ns_make_range(code_points)

