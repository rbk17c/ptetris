#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: hdl.pl
#
#        USAGE: ./hdl.pl  
#
#  DESCRIPTION: Hardware describtion to pic ASM
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 2016-02-21 09:21:57
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use feature ":5.10";

my (@name, @port, @pin, %input, @key, %tris, %PortName);
my ($fd, $tname, $tport, $tpin, $tinput, $len, $i, $inp);
my $max = 0;
my $ina = 0;
my $idx = 0;
my $pic="";
my $end=0;
my $store='';
my %r;

#
# ----------------------------------- PIC_18_28 -------------------------------
#
sub PIC_18_28 {
  my @left_pins = qw/
A0 A1 A2 A3 A4 A5 A6 A7
C0 C1 C2 C3 Vs MR /;
  my @right_pins = qw/
B0 B1 B2 B3 B4 B5 B6 B7 VS
C4 C5 C6 C7 /;

  my $type="Pic18F25K50";
  if ( m/^;#pic.*PIC_18_28\s*(\w*)/i) {
    $type=$1;
  }

  $r{MR}='MCLR ';
  $r{Vs}='GND Vss';
  $r{VS}='Vss GND';
  $r{Vd}='Vdd 5v';
  $r{A6}='OSC';
  $r{A7}='OSC';
  if ( $type=~m/pic.*[jk]50/i) {
  	$r{C3}='VUSB';
  	$r{C4}='USB D+';
  	$r{C5}='USB D-';
  }

  foreach (@left_pins) {
    $r{$_}=sprintf("%9.9s", $r{$_}//'    free -');
  }
  foreach (@right_pins) {
    $r{$_}=$r{$_}//'free';
  }

  
  $pic.="
;		$type
;        $r{MR} 1+.--+28 RB7 - $r{B7}
; $r{A0} - RA0  2|   |27 RB6 - $r{B6}
; $r{A1} - RA1  3|   |26 RB5 - $r{B5}
; $r{A2} - RA2  4|   |25 RB4 - $r{B4}
; $r{A3} - RA3  5|   |25 RB3 - $r{B3}
; $r{A4} - RA4  6|   |25 RB2 - $r{B2}
; $r{A5} - RA5  7|   |22 RB1 - $r{B1}
;       $r{Vs}  8|   |21 RB0 - $r{B0}
; $r{A7} - RA7  9|   |20  $r{Vd}
; $r{A6} - RA6 10|   |19  $r{VS}
; $r{C0} - RC0 11|   |18 RC7 - $r{C7}
; $r{C1} - RC1 12|   |17 RC6 - $r{C6}
; $r{C2} - RC2 13|   |16 RC5 - $r{C5}
; $r{C3} - RC3 14+---+15 RC4 - $r{C4}

";
  return;
}

#
# ----------------------------------- PIC_18_44 -------------------------------
#
sub PIC_18_44 {
  my @left_pins = qw/
C7 D4 D5 D6 D7 B0 B1 B2 B3 NC NC B4 B5 B6 B7 MR A0 A1 A2 A3 Vs Vd
/;
#A0 A1 A2 A3 A4 A5 A6 A7
#C0 C1 C2 C3 Vs MR
  my @right_pins = qw/
VDDcore A5 E0 E1 E2 vd vs A6 A7 C0   Nc Nc C1 C2 Vusb D0 D1 D2 D3 C4 C5 C6
/;
#B0 B1 B2 B3 B4 B5 B6 B7 VS
#C4 C5 C6 C7

  $r{MR}='MCLR';
  $r{Vs}='GND Vss';
  $r{vs}='Vss GND';
  $r{Vd}='3.3v Vdd';
  $r{vd}='Vdd 3.3v';
  $r{NC}='n.c.';
  $r{Nc}='n.c.';
  $r{VDDcore}='10uF cap';
  $r{Vusb}='VUSB';
  foreach (@left_pins, @right_pins) {
    $r{$_}=$r{$_}//'free';
  }

  foreach (@left_pins) {
    $r{$_}=sprintf("%9.9s", $r{$_});
  }
  foreach (@right_pins) {
    $r{$_}=sprintf("%-9.9s", $r{$_});
  }
  $r{00}=sprintf("%-9.9s", " ");

  my $type="Pic18F4x-xx";
  if ( m/^;#pic.*PIC_18_44\s*(\w*)/i) {
    $type=$1;
  }

  my $lt=length($type)/2;
  $r{type}=sprintf("%*s%*s", (10+$lt), $type, (11-$lt), " " );

  $pic.="
;
; $r{D1} - RD1 39 ------------. 
; $r{D2} - RD2 40 ----------. | .---------- 38 RD0 - $r{D0}
; $r{D3} - RD3 41 --------. | | | .-------- 37 r{Vusb} 
; $r{C4} - RC4 42 ------. | | | | | .------ 36 RC2 - $r{C2}
; $r{C5} - RC5 43 ----. | | | | | | | .---- 35 RC1 - $r{C1}
; $r{C6} - RC6 44 --. | | | | | | | | | .-- 34 $r{Nc}
; $r{00}            | | | | | | | | | | |
; $r{00}           +---------------------+
; $r{C7} - RC7  1 -|                     |- 33 $r{Nc}
; $r{D4} - RD4  2 -| $r{    type        }|- 32 RC0 - $r{C0}
; $r{D5} - RD5  3 -|                     |- 31 RA6 - $r{A6}
; $r{D6} - RD6  4 -|                     |- 30 RA7 - $r{A7}
; $r{D7} - RD7  5 -|                     |- 29 $r{vs}
;       $r{Vs}  6 -|                     |- 28 $r{vd}
;       $r{Vd}  7 -|                     |- 27 RE2 - $r{E2}
; $r{B0} - RB0  8 -|                     |- 26 RE1 - $r{E1}
; $r{B1} - RB1  9 -|                     |- 25 RE0 - $r{E0}
; $r{B2} - RB2 10 -|                     |- 24 RA5 - $r{A5}
; $r{B3} - RB3 11 -|                     |- 23 VDDcore - $r{VDDcore}       
; $r{00}           +---------------------+
;       $r{NC} 12 --. | | | | | | | | | .-- 22 RA3 $r{A3}
;       $r{NC} 13 ----. | | | | | | | .---- 21 RA2 $r{A2}
; $r{B4} - RB4 14 ------. | | | | | .------ 20 RA1 $r{A1}
; $r{B5} - RB5 15 --------. | | | .-------- 19 RA0 $r{A0}
; $r{B6} - RB6 16 ----------. | .---------- 18 RE3 $r{MR}
; $r{B7} - RB7 17 ------------. 
;
";

  return;
}

;#pic PIC_18_28
;#pin Mouse_Xb, I, B1
;#pin KEY_CLK, C7, o
;#pin KEY_DAT, C6, o
;#pin USB_DM, C4, i
;#pin USB_DP, C5, i
;
;#pin LED_GREEN, B6, o
;#pin LED_RED,   B5, o
;
;#pin Mouse_Xa,   B0, o
;#pin Mouse_Xb,   B1, o
;#pin Mouse_Ya,   B2, o
;#pin Mouse_Yb,   B3, o
;#pin Mouse_left, B4, o
;#pin Mouse_right,B7, o
;#pin Mouse_ght,C5, o

#open $fd, '<', "hardware.hdl" or (say "no hardware.hdl exists" ; exit 0);
#if (! open ($fd, '<', "hdl.pl") ) {
#	say "no hardware.hdl exists" ;
#	exit 0;
#}

while (<>) {
  if ( m/^;#pic.*PIC_18_28.*/i) {
     PIC_18_28(); 
     if ( m/^;#pic.*PIC_18_28_i2c.*/i) {
  	$r{C4}='C4 i2c';
  	$r{C5}='C5 i2c';
     }
  } elsif ( m/^;#pic.*PIC_18_44.*/i) {
     PIC_18_44(); 
  } elsif ( m/^;#pin\s*(\w*)\s*,\s*([a-q,A-Q])(\d)\s*,\s*(\w*)/ ) {
	  $tname  = $1;
	  $tport  = $2;
	  $tpin   = $3;
	  $tinput = $4;

	  $i=$tport . $tpin;
	  $len = length ($tname);
	  $max = $len if $len > $max;

	  $tris{$tport}//= 0;
	  $input{$i}     = 0;
	  if ($tinput =~m/^I/i ) {
		$input{$i} = 1;
	  }
	  if ($tinput eq "1" ) {
		$input{$i} = 1;
	  }
	  $name[$ina]   = $tname;
	  $PortName{$i} = $tname;
	  $r{$i} = $tname;
	  $port[$ina]   = $tport;
	  $pin[$ina]    = $tpin;
	  $key[$ina]    = $ina;
	  $ina++;
  } elsif ( m/^;#end/ ) {
      $end=1;
  } elsif ( m/^;#/ ) {
      next;
  } elsif ($end == 1) {
      $store.=$_;
  } else {
      print;
  }
}
#close $fd;

  print $pic;
  $max++;
  #say "maxlen $max";
  #say "lin $ina";

  @key = (sort { $name[$a] cmp $name[$b] } @key);
  foreach $idx (@key) {
    printf ("#define %-*s LAT%s, %d, LAT%s, PORT%s, TRIS%s\n", $max, $name[$idx],  $port[$idx], $pin[$idx], $port[$idx], $port[$idx], $port[$idx] );
  }

  my $IO;
  foreach $tport (sort keys %tris) {
    say "";
    $inp='';
    foreach my $tpin (0..7) {
      $i=$tport.$tpin;
      $inp.=$input{$i}//'0';
      if ($input{$i}//'0' == '1' ) {
	  $IO='input ';
      } else {
	  $IO='output';
      }
      printf("; port R%s - %s - pin ( %s )\n", $i, $IO, $PortName{ $i }//"NC" );
    }
    $i=reverse($inp);
    printf "TRIS2_FOR_$tport=b'$i'\n";
  }
  print $store;

exit 0;
