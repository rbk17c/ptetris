#!/usr/bin/perl


open ($FD,"<chargen") or die "open chargen $!"; 

$len=sysread($FD,$buf,65536);
@bin=split (//, $buf);

print unpack ("H*", $bin[0]) . "\n";
$q=unpack("N", $bin[0]);

$q++;

printf "%2.2x\n", $q;

printf ("bin0 %2.2x\n", $bin[0]);


#print unpack ("H*", $bin[1]) . "\n";

