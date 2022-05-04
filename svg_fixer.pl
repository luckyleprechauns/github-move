#!/usr/bin/perl
################################################################################
# Author:   Noel Noel
# Date:     November 24, 2021
# Revision: 1.0.0
#
# Purpose:
#     The Tinkercad SVG export will have negative numbers for the locations in it. 
#     While some app's like Inkscape doesn't have a problem with this, the Paint.NET
#     does.  It would only show the bottom right corner, since it ignored anything
#     starting in the negative range.  
#
################################################################################
# Setup
################################################################################
$|=1;
use warnings;
use strict;

use List::Util qw(min max);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my $GP_debug       = 0;
my $GP_app_version = "1.0.0";
my $GP_app_name    = $0;
   $GP_app_name    =~ s#.*/##;
my %GP_cli_opts    = ();

my %GP_results        = ();
my @GP_cache          = ();

################################################################################
# Main
################################################################################
cli_process();

get_input_data();

build_summary();

fix_and_print();

exit(0);

################################################################################
#
################################################################################
sub get_input_data {
   my @tmp   = ();
   my @tmp_M = ();
   my @tmp_L = ();
   my $IN;

   if (defined($GP_cli_opts{'infile'})) {
      if (!-e $GP_cli_opts{'infile'} || -d $GP_cli_opts{'infile'} || !-s $GP_cli_opts{'infile'}) {
         die "ERROR:  Bad input file name.  Either it doesn't exist or has no size\n";
      }
      open ($IN, "<" . $GP_cli_opts{'infile'}) || die "ERROR: Unable to open file.  $!\n";
   } else {
      $IN = *STDIN;
   }

   while (<$IN>) {
      chomp;
      if (/^(<path\s+d=")([^"]+)(\s+[a-z]+\w*"\s+\w+.*)$/i) {
         my $prefix = $1;
         my $data   = $2;
         my $pstfix = $3;
         push(@GP_cache, $prefix);

         @tmp_M = split(/M/, $data);
         foreach my $M (@tmp_M) {
            @tmp_L = split(/L/, $M);
            my $L = 0;
            while ($L < scalar(@tmp_L)) {
               if ($L == 0) {
                  push(@GP_cache, "M " . $tmp_L[$L]);
               } else {
                  push(@GP_cache, "  L " . $tmp_L[$L]);
               }
               $L++;
            }
         }
         push(@GP_cache, $pstfix);
      } else {
         push(@GP_cache, $_);
      }
   }

   close($IN) if (defined($GP_cli_opts{'infile'}));
   print join("\n", @GP_cache) . "\n" if ($GP_debug > 8);
}

################################################################################
sub build_summary {
   my $decimal_pnts = 0;
   my $type;
   my $x;
   my $y;
   my $tmp;
   my $tmpx;
   my $tmpy;
   my $i = 0;
   while ($i < scalar(@GP_cache)) {
      if ($GP_cache[$i] =~ /^\s*([LM])\s+(-?\d+(?:\.\d+)?(?:e-?\d+)?)\s+(-?\d+(?:\.\d+)?(?:e-?\d+)?)\s*$/i) {
         $type = $1;
         $x    = $2;
         $y    = $3;

         if (defined($GP_cli_opts{'round'}) && $GP_cli_opts{'round'} >= 0) {
            $tmp = sprintf("%." . $GP_cli_opts{'round'} . "f", $x);
            $x   = $tmp;
            $tmp = sprintf("%." . $GP_cli_opts{'round'} . "f", $y);
            $y   = $tmp;
            $GP_cache[$i] = sprintf("%s $x $y", ($type eq "M" ? $type : "  $type") );
            print "DEBUG: $GP_cache[$i]\n" if ($GP_debug > 6);
         }
   
         $GP_results{$type}{'x'}{'mx'} = $x if (!defined($GP_results{$type}{'x'}{'mx'}) || $GP_results{$type}{'x'}{'mx'} < $x);
         $GP_results{$type}{'x'}{'mn'} = $x if (!defined($GP_results{$type}{'x'}{'mn'}) || $GP_results{$type}{'x'}{'mn'} > $x);
         $GP_results{$type}{'x'}{'delta'} = $GP_results{$type}{'x'}{'mx'} - $GP_results{$type}{'x'}{'mn'};
   
         $GP_results{$type}{'y'}{'mx'} = $y if (!defined($GP_results{$type}{'y'}{'mx'}) || $GP_results{$type}{'y'}{'mx'} < $y);
         $GP_results{$type}{'y'}{'mn'} = $y if (!defined($GP_results{$type}{'y'}{'mn'}) || $GP_results{$type}{'y'}{'mn'} > $y);
         $GP_results{$type}{'y'}{'delta'} = $GP_results{$type}{'y'}{'mx'} - $GP_results{$type}{'y'}{'mn'};

         if ($type eq "M") {
            $GP_results{'M_count'}++;
         } elsif ($type eq "L") {
            $GP_results{'L_count'}{ $GP_results{'M_count'} }++;
            $GP_results{'delta'}{'x'} = $GP_results{$type}{'x'}{'mn'};
            $GP_results{'delta'}{'y'} = $GP_results{$type}{'y'}{'mn'};
         }

         $tmpx = length( (split(/\./, $x, 2))[1] );
         $tmpy = length( (split(/\./, $x, 2))[1] );
         $decimal_pnts = max($tmpx ? $tmpx : 0, $tmpy ? $tmpy : 0);
         $GP_results{'max_decimal_pnts'} = $decimal_pnts if (!defined($GP_results{'max_decimal_pnts'}) || $GP_results{'max_decimal_pnts'} < $decimal_pnts);
      }

      $i++;
   }
   
   print Dumper(\%GP_results) if ($GP_debug);
   print join("\n", @GP_cache) . "\n" if ($GP_debug > 7);
}
   
################################################################################
sub fix_and_print {
   my $tmp;
   my $type;
   my $x;
   my $y;
   my $i = 0;
   while ($i < scalar(@GP_cache)) {
      if ($GP_cache[$i] =~ /^\s*([LM])\s+(-?\d+(?:\.\d+)?(?:e-?\d+)?)\s+(-?\d+(?:\.\d+)?(?:e-?\d+)?)\s*$/i) {
         print "LRN:  $GP_cache[$i] ;;;\n" if ($GP_debug > 10);
         $type = $1;
         $x    = $2;
         $y    = $3;
   
         printf("%s%s %." . $GP_results{'max_decimal_pnts'} . "f %." . $GP_results{'max_decimal_pnts'} . "f\n", 
            ($type eq "M" ? "" : "  "),
            $type,
            ($x - $GP_results{'L'}{'x'}{'mn'}),
            ($y - $GP_results{'L'}{'y'}{'mn'}) );
                             # <svg width=    " 122              mm" height=  "  91             mm" viewBox=  "  0                 0                 122               91             " xmlns="http://www.w3.org/2000/svg" version="1.1">
                             # $1               $2               $3              $4             %5               $6                $7                $8                $9             $10
      } elsif ($GP_cache[$i] =~ /^(\s*<svg\s+width=")(-*\d+(?:\.\d+)?)(mm"\s+height=")(-*\d+(?:\.\d+)?)(mm"\s+viewBox=")(-*\d+(?:\.\d+)?)\s+(-*\d+(?:\.\d+)?)\s+(-*\d+(?:\.\d+)?)\s+(-*\d+(?:\.\d+)?)(".*)$/i) {
         printf("%s%s%s%s%s%s %s %s %s%s\n",
            $1, 
            ($GP_results{'L'}{'x'}{'delta'} + 1),
            $3,
            ($GP_results{'L'}{'y'}{'delta'} + 1),
            $5,
            ($GP_results{'L'}{'x'}{'mn'} + abs($GP_results{'L'}{'x'}{'mn'}) - 1),
            ($GP_results{'L'}{'y'}{'mn'} + abs($GP_results{'L'}{'y'}{'mn'}) - 1),
            ($GP_results{'L'}{'x'}{'delta'} + 3),
            ($GP_results{'L'}{'y'}{'delta'} + 3),
            $10);
      } elsif ($GP_cache[$i] =~ /^(.*stroke-width=")(\d+\.\d+)(mm".*)$/i) {
         $tmp = $2;
         if ( defined($GP_cli_opts{'stroke_width'}) ) {
            $tmp = $GP_cli_opts{'stroke_width'};
         } elsif ( defined($GP_cli_opts{'stroke_width-minus'}) ) {
            $tmp -= $GP_cli_opts{'stroke_width-minus'};
         } elsif ( defined($GP_cli_opts{'stroke_width-plus'}) ) {
            $tmp += $GP_cli_opts{'stroke_width-plus'};
         }

         printf("%s%1.3f%s\n", $1, $tmp, $3);
      } else {
         print "$GP_cache[$i]\n";
      }
   
      $i++;
   }
}


################################################################################
# Process command line
################################################################################
sub cli_process {
   my $tmp;
   my $i = 0;
   my $op;
   my $sz;

   while ($i < scalar(@ARGV)) {
      if ($ARGV[$i] =~ /^-+debug$/i) {
         $GP_debug++;
      } elsif ($ARGV[$i] =~ /^-+debug=(\d+)$/i) {
         $GP_debug = $1;
      } elsif ($ARGV[$i] =~ /^-+help$/i) {
         print_help();
         exit(1);
      } elsif ($ARGV[$i] =~ /^-round$/i) {
         $GP_cli_opts{'round'} = 3;
      } elsif ($ARGV[$i] =~ /^-round=(\d+)$/i) {
         $GP_cli_opts{'round'} = $1;
      } elsif ($ARGV[$i] =~ /^-$/i) {              # <STDIN>
         if (defined($GP_cli_opts{'infile'})) {
            delete( $GP_cli_opts{'infile'} );
         }
      } elsif ($ARGV[$i] =~ /^[^-]/i && -s $ARGV[$i]) {
         $GP_cli_opts{'infile'} = $ARGV[$i];
      } elsif ($ARGV[$i] =~ /^-(?:input|infile|file)=(.*)$/i) {
         $GP_cli_opts{'infile'} = $1;
      } elsif ($ARGV[$i] =~ /^-(?:stroke-width|stroke|width)(=|-=|\+=)(\d*\.?\d+)$/i) {
         $op = $1;
         $sz = $2;
         if ($op eq "-=") {
            $GP_cli_opts{'stroke_width-minus'} = $sz;
         } elsif ($op eq "+=") {
            $GP_cli_opts{'stroke_width-plus'} = $sz;
         } else {
            $GP_cli_opts{'stroke_width'} = $sz;
         }
      }

      $i++;
   }
}

################################################################################
# Help
################################################################################
sub print_help {
   print <<EOC;
   
   $0
      This program will take a SVG file and shift the axis's.  The export to SVG
   on the Thinkercad website likes to have negative numbers, since it appears
   to split the X axis coordinates down the middle and the Y axis down near the 
   bottom.  

   As it walks through all of the data it finds the min/max for each X/Y.  Then
   it adds that offset to every number.  Now all of the numbers should be positive.
   If you don't do this Paint.NET will not display the image correctly.  Other apps
   like Inkscape handle this case without issues.
   
   Command line options:
   -help          Prints this message.
   -debug         Prints debug message/data.
   -              Reads from <STDIN>
   -file=         Specify the file name to read (or can be a bare file name w/o -file=.
   -round=        How many decimal of percision (-round w/o the = will default to 3).
   -width=        Override the stroke-width to custom value.
   -width+=       Add custom amount to existing value.
   -width-=       Subtract custom amount to existing value.


   Exp:  $GP_app_name -round -width=.005 foobar.svg
   
EOC

}
