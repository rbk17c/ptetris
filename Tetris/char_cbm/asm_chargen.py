#!/usr/bin/python3

import sys

#; c64 screen codes ( Poke ) to ascii
outs=list()
for i in range(128):
    a=f"0x{i:02X}"
    q=-1
    if 0x00 == i:
        a="at"
    if 1 <= i <= 26:
       q=i+0x40
       a=f"{q:c}"
    if 27 == i:
        a="left_square_bracket"
    if 28 == i:
        a="pound"
    if 0x1D == i:
        a="right_square_bracket"
    if 0x1E == i:
        a="arrow_up"
    if 0x1F == i:
        a="arrow_left"
    if 0x20 == i:
        a="space"
    if 0x21 == i:
        a="exclamation"
    if 0x22 == i:
        a="quotation"
    if 0x23 == i:
        a="hash"
    if 0x24 == i:
        a="dollar"
    if 0x25 == i:
        a="percent"
    if 0x26 == i:
        a="ampersand"
    if 0x27 == i:
        a="apostrophe"
    if 0x28 == i:
        a="left_parenthesis"
    if 0x29 == i:
        a="right_parenthesis"
    if 0x2a == i:
        a="asterisk"
    if 0x2b == i:
        a="plus"
    if 0x2c == i:
        a="comma"
    if 0x2d == i:
        a="hyphen"
    if 0x2e == i:
        a="period"
    if 0x2f == i:
        a="slash"
    if 0x30 <= i <= 0x39:
       q=i
       a=f"{q:c}"
    if 0x3a == i:
        a="colon"
    if 0x3b == i:
        a="semicolon"
    if 0x3c == i:
        a="less"
    if 0x3d == i:
        a="equals"
    if 0x3e == i:
        a="greater"
    if 0x3f == i:
        a="question"
    #DEBUG: print(f"{i} = {a}  - {q:02x} ")
    outs.append(a)
        #:print(f"{i} undef ;-(")
#DEBUG: print ("len: ", len(outs))
#DEBUG: print ("out: ", "|".join(outs))
"""
        a="backslash"
^	94_	caret
_	95_	underscore
`	96_	grave_accent
{	123_	left_curly_brace
|	124_	vertical_bar
}	125_	right_curly_brace
~	126_	tilde
"""

readlen=int()
readlen=4096
readlen=2048
readlen=int(256)
with open ("chargen", 'rb') as rom_file:
   char_file=rom_file.read(readlen)

if len(char_file)!=readlen:
    print(f"that is a bit short- read: {len(char_file)} != wanted: {readlen}")
    exit(-2);

with open  ("abc.asm", 'w') as o:
#if 1:
#    o=sys.stdout
    o.write("; vim:syntax=pic18\n")
    o.write("; ----------------\n")
    o.write(";    dump of c64 charom/chargen\n")
    o.write("; ----------------\n")

    for (CharN,i) in enumerate (range(0,readlen,8)):
        CName=outs[CharN]
        if len (CName) > 5:
            NL="\n\t"
        else:
            NL=" "

        o.write(f"char_{CName}:{NL}de ")
        Arr=char_file[i:i+8]                                # slice the Arr into only the 8 bytes for this char
        Hex=[ f"0x{i:02X}"  for i in Arr ]                  # ( 2 line for readability ) - convert Arr (bytes?) to hex (str)
        o.write(", ".join(Hex))                             # and join on one line
        o.write("\n")
        for A in Arr:                                       # to print bin, f-string makes 00000110, and translate 
            o.write (f";\t|+{A:08b}+|\n".translate(str.maketrans("01", ".X")))   # makes 0=. and 1=X...
        o.write("\n")
