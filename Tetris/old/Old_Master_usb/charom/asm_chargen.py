#!/usr/bin/python3

import re

with open ("chargen", 'rb') as rom_file:
   c=rom_file.read(8192)



b=([ (bin(int(i)+256))[3:] for i in c])


for (n,i) in enumerate(b):
    if not n%8:
       print(f"; --- {int(n/8):02x} ---")
    d=re.sub("0", " ",i)
    d=re.sub("1", "X",d)
    print(f"; {n:03d} is: |+{d}+|")



# $len=sysread($FD,$buf,65536);
# @bin=split (//, $buf);
# 
# print unpack ("H*", $bin[0]) . "\n";
# $q=unpack("N", $bin[0]);
# 
# $q++;
# 
# printf "%2.2x\n", $q;
# 
# printf ("bin0 %2.2x\n", $bin[0]);
# 
# 
# #print unpack ("H*", $bin[1]) . "\n";

