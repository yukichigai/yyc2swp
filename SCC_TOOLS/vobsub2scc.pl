# vobsub2scc.pl: Convert VOBSub's (sub.)cc.raw file into broadcast binary file and
#  Scenarist Closed Caption formats
# Run file without arguments to see usage; full documentation at
#  http://www.geocities.com/mcpoodle43/SCCTOOLS/DOC/SCC_TOOLS.HTML
#
use strict;
my $Version = "3.1";
# McPoodle (mcpoodle@sonic.net)
#
# Version History
# 2.0 initial release (incorporated the default output filename change and line-splitting
#       changes I put into version 2.0 of raw2scc)
# 2.1 finally figured out drop vs non-drop (changing frame and timecodeof functions)
#       and correctly parsing and outputting non-drop timecodes,
#     added -td and -tn parameters,
#     made sure character SCC timecode is a tab character
# 2.2 check to see if file is empty (all 8080 byte-pairs)
# 2.3 Gabest changed his output to .cc.raw, so I change to match
# 2.6 corrected drop/non-drop calculations (again),
#     put each XDS sequence on its own line in the SCC file
# 2.7 fixed errors in frame() and timecodeof()
# 2.7.1 fixed rounding error in timecodeof()
# 2.7.2 cosmetic: updated my e-mail & web addresses in the source code
# 2.8 added -d1 & -d2 flags to remove duplicate captions
# 2.9 added in Channel 3 & 4 codes for line-splitting,
#     trimmed 8080 (null) codes off of end of lines,
#     break line anytime more than 2 nulls in a row are found,
#     changed -d1 & -d2 flags to -1 & -2 (for consistency with
#      SCC_RIP)
# 3.0 complete re-write of parsing algorithm to handle duplicate
#      captions (method used in 2.8 was wrong),
#     dropped -1 and -2 parameters (no longer needed),
#     fixed file naming for .sub.cc.raw
# 3.1 now keep track of last packet used to control next packet

sub usage;
sub frame;
sub timecodeof;
sub trim;

# initial variables
my $offset = "00:00:00:00";
my $fps = 30000/1001; # NTSC framerate (non-drop)
my $drop = 0; # assume non-drop
my $nulllimit = 2; # break line if more than this many nulls are found inline
my $rawoutput = "~"; # place-holder for no raw-type output file yet
my $sccoutput = "~"; # place-holder for no SCC output file yet
my $inputfile = "~"; # place-holder for no input file yet
my $anything = "~"; # place-holder for any arguments

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = '';
  if (s/-o//) {
    $offset = $_;
    next;
  }
  if (s/-f//) {
    $fps = $_;
    $drop = 0;
    next;
  }
  if (s/-t//) {
    if (m/d/) { # NTSC drop frame
      $fps = 30;
      $drop = 1;
    }
    if (m/n/) { # NTSC non-drop frame
      $fps = 30000/1000;
      $drop = 0;
    }
    next;
  }
  if (s/-l//) {
    $nulllimit = $_;
    next;
  }
  $inputfile = $_;
}

# print ("Offset: ", $offset);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nInput: ", $inputfile);
# print ("\nNull Limit: ", $nulllimit);

if ($anything eq "~") {
  usage();
  exit;
}

if ($nulllimit =~ /\D/) {
  usage();
  die "-l null limit must be a number, stopped";
}

if ($inputfile eq "~") {
  usage();
  die "No input file, stopped";
}

if (($inputfile =~ m/(.*)(\.cc\.raw)$/) == 1) {
  $rawoutput = $1.".bin";
  $sccoutput = $1.".scc";
}
if (($inputfile =~ m/(.*)(\.sub\.cc\.raw)$/) == 1) {
  $rawoutput = $1.".bin";
  $sccoutput = $1.".scc";
}
if ($rawoutput eq "~") {
  usage();
  die "Input file is not a VobSub .cc.raw file, stopped";
}

# print ("\nRaw Output: ", $rawoutput);
# print ("\nSCC Output: ", $sccoutput);

if ($rawoutput eq ".bin") {
  usage();
  exit;
}

if (($fps < 15)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($offset =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

print "Creating $rawoutput...\n";

open (WH, ">".$rawoutput) or die "Unable to write to file $rawoutput: $!";

print WH "\xff\xff\xff\xff"; # binary file begins with four ff bytes

open (RH, $inputfile) or die "Unable to read from file $inputfile: $!";

my $hasCaptions = 0;
my $lastTimecode = "~";
my $lastIndex = 0;
my @lines;
my $lineIndex = 0;
my $i;
my @codes;
my $code;
my $nonNullIndex = -1;
my $byte;
# read loop
LINELOOP: while (<RH>) {
  if ($_ eq "\n") {
    next LINELOOP;
  }
  chomp;
  if (m/:/) {
    if (($_ ne $lastTimecode) && ($lastTimecode ne "~")) {
      for ($i = 0; $i <= $lineIndex; $i++) {
        (@codes) = split(/ /, $lines[$i]);
        foreach $code (@codes) {
          if ($code ne "80") {
            $hasCaptions = 1;
            $nonNullIndex = $i;
          }        
        }
      }
      if ($nonNullIndex == -1) {
        $nonNullIndex = $lastIndex;
      }
      (@codes) = split(/ /, $lines[$nonNullIndex]);
      foreach $code (@codes) {
        $byte = hex $code;
        print WH chr($byte);
      }
      for ($i = 0; $i <= $lineIndex; $i++) {
        $lines[$i] = "";
      }
      $lastIndex = $nonNullIndex;
      $nonNullIndex = -1;
      $lineIndex = 0;
    }
    if ($_ eq $lastTimecode) {
      $lineIndex++;
    }
    $lastTimecode = $_;
    next LINELOOP;
  }
  chomp;
  $lines[$lineIndex] .= $_;
  next LINELOOP;
}
close RH;
close WH;

if (! $hasCaptions) {
  print "\nNo captions were found!  Aborting.";
  exit;
}

# Raw to SCC

print "Creating $sccoutput...\n";

my $currentframe = frame($offset) - 1;
open (WH, ">".$sccoutput) or die "Unable to write to file $sccoutput: $!";

print WH "Scenarist_SCC V1.0";

sysopen(RH, $rawoutput, 0) or die "Unable to read from file $rawoutput: $!, stopped";
my $data;
sysread RH, $data, 4; # skip file header

my $line = ""; # line to output
my $inline = 0; # flag for when it's worth outputting (0 = skip nulls)
my $endofline = 0; # signal that line ends when next null reached
my $nullcount = 0;
my $colcount = 0; # keeps track of line length
my $crflag = 0; # flag that a roll-up/text carriage return has been received
my $tabflag = 0; # makes sure tab follows timecode
my $hi;
my $lo;
my $word;
my $evenword;

# read loop
READLOOP: while (sysread RH, $data, 2) {
  if ($inline) {++$colcount};
  ++$currentframe;
  $data =~ m/(.)(.)/;
  $hi = ord $1;
  $lo = ord $2;
  $word = sprintf "%02x%02x", $hi, $lo;
  # remove any odd parity for testing
  if ($hi > 127) {$hi -= 128;}
  if ($lo > 127) {$lo -= 128;}
  $evenword = sprintf ("%02x%02x", $hi, $lo);
  if ($evenword ne "0000") {
    $nullcount = 0;
  }
  if (($evenword eq "0000") && ($inline)) {
    $nullcount++;
  }
  if ($nullcount > $nulllimit) {
    $endofline = 1;
    $nullcount = 0;
  }
  if (($evenword eq "0000") && ($endofline)) {
    $endofline = 0;
    $inline = 0;
  }
  # check for carriage return code (142d, 1c2d, 152d or 1c2d)
  if (($evenword ne "142d") and ($evenword ne "1c2d") and
     ($evenword ne "152d") and ($evenword ne "1d2d") and ($crflag)) {
    $endofline = 0;
    $inline = 0;
  }
  if (($evenword eq "0000") and not ($inline)) {
    next READLOOP;
  }
  
  # start new line if switching modes (and haven't started a new line already):
  #  High byte = 14, 1c, 15 or 1d for Channel 1 - 4
  #  Pop-on: low byte 20
  #  Roll-up: low bytes 25, 26, 27
  #  Paint-on: low byte 29
  #  Text: low byte 2a, 2b
  #  XDS: high byte 01 - 0e, any low byte
  if ((((($hi == 0x14) or ($hi == 0x1c) or ($hi == 0x15) or ($hi == 0x1d))
        and (($lo == 0x20) or ($lo == 0x25) or ($lo == 0x26) or ($lo == 0x27)
             or ($lo == 0x29) or ($lo == 0x2a) or ($lo == 0x2b)))
       or (($hi > 0) and ($hi < 15)))
      and ($colcount > 2)) {
    $inline = 0;
  }
  
  if (($evenword ne "0000") and not ($inline)) {
    $inline = 1;
    $colcount = 1;
    print WH trim($line)."\n\n";
    $line = timecodeof($currentframe);
    $tabflag = 1;
  }
  # go immediately to next line for roll-up/text carriage return codes:
  #  142d = carriage return channel 1
  #  1c2d = carriage return channel 2
  #  152d = carriage return channel 3
  #  1d2d = carriage return channel 4
  if (($evenword eq "142d") or ($evenword eq "1c2d") or
      ($evenword eq "152d") or ($evenword eq "1d2d")) {
    $crflag = 1;
  } else {
    $crflag = 0;
  }

  # check for the standard XDS and closed-caption end caption codes:
  #  0fxx = XDS checksum
  #  High byte = 14, 1c, 15 or 1d for Channel 1 - 4
  #  Clear Screen = low byte 2c
  #  Write Caption (for pop-on captions): low byte 2f
  if (($hi == 15) or
      ((($hi == 0x14) or ($hi == 0x1c) or ($hi == 0x15) or ($hi == 0x1d))
       and (($lo == 0x2c) or ($lo == 0x2f)))) {
    $endofline = 1;
  }
  if ($tabflag) {
    $line = $line."\t";
    $tabflag = 0;
  } else {
    $line = $line." ";
  }
  $line = $line.$word;

  next READLOOP;
}
print WH trim($line)."\n\n";
close RH;
close WH;
exit;

sub usage {
  printf "\nVOBSUB2SCC Version %s\n", $Version;
  print "  Converts VOBSub's raw CC format to Scenarist import format.\n\n";
  print "  Syntax: VOBSUB2SCC -o01:00:00:00 -td -l2 filename.cc.raw\n";
  print "    -o: Offset to apply to SCC file, in HH:MM:SS:FF format\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    -l: Set how many null codes it takes to trigger a new SCC line\n";
  print "         (DEFAULT: 2)\n";
  print "    Creates files filename.bin (raw broadcast data) & filename.scc (Scenarist).\n";
  print "    Output files will be overwritten if they exist.\n\n";
}

sub frame {
  my $timecode = shift(@_);
  my $signmultiplier = +1;
  if (substr($timecode, 0, 1) eq '-') {
    $signmultiplier = -1;
    $timecode = substr $timecode, 1, 11;
  }
  if (substr($timecode, 8, 1) eq ';') {
    $drop = 1;
  }
  (my $hh, my $mm, my $ss, my $ff) = split(m/[:;]/, $timecode, 4);
  # drop/non-drop requires that minutes be split into 10-minute intervals
  my $dm = int($mm/10); # "deci-minutes"
  my $sm = $mm % 10; # single minutes
  # hours
  my $multiplier = 3600 * $fps;
  if ($drop) {
    $multiplier -= 108; # number of frames dropped every hour
  }
  my $framecount = $hh * $multiplier;
  # deci-minutes
  $multiplier = 600 * $fps;
  if ($drop) {
    $multiplier -= 18; # number of frames dropped every 10 minutes
  }
  $framecount += $dm * $multiplier;
  # single minutes
  $multiplier = 60 * $fps;
  if ($drop) {
    $multiplier -= 2; # number of frames dropped every minute (except the 10th)
  }
  $framecount += $sm * $multiplier;
  # seconds
  $framecount += $ss * $fps;
  # frames
  $framecount += $ff;
  $framecount *= $signmultiplier;
  return int($framecount + 0.5);
}

sub timecodeof {
  my $frames = shift(@_);
  if ($frames < 0) {
    die "Negative time code in line $. of $inputfile, stopped";
  }
  # hours
  my $divisor = 3600 * $fps;
  if ($drop) {
    $divisor -= 108; # number of frames dropped every hour
  }
  my $hh = int($frames / $divisor);
  my $remainder = $frames - ($hh * $divisor);
  # tens of minutes (required by drop-frame)
  $divisor = 600 * $fps;
  if ($drop) {
    $divisor -= 18; # number of frames dropped every 10 minutes
  }
  my $dm = int($remainder / $divisor);
  $remainder = $remainder - ($dm * $divisor);
  # single minutes
  $divisor = 60 * $fps;
  if ($drop) {
    $divisor -= 2; # number of frames dropped every minute except the 10th
  }
  my $sm = int($remainder / $divisor);
  my $mm = $dm * 10 + $sm;
  $remainder = $remainder - ($sm * $divisor);
  # seconds
  my $ss = int($remainder / $fps);
  # frames
  $remainder -= ($ss * $fps);
  my $ff = int($remainder + 0.5);
  
  # correct for calculation errors that would produce illegal timecodes
  if ($ff > int($fps)) { $ff = 0; $ss++;}
  # drop base means that first two frames of 9 out of 10 minutes don't exist
  # i.e. 00:10:00;01 is legal but 00:11:00;01 is not
  if (($drop) && ($ff < 2) && ($sm > 0)) {
    $ff = 2;
  }
  if ($ss > 59) { $ss = 0; $mm++; }
  if ($mm > 59) { $mm = 0; $hh++; }

  my $frameDivider = ":";
  if ($drop) {
    $frameDivider = ";";
  }
  return sprintf ("%02d:%02d:%02d%s%02d", $hh, $mm, $ss, $frameDivider, $ff);
}

sub trim {
  my $line = shift(@_);
  my $outline = "";
  my @bytepair = split(/ /, $line);
  my $linesize = $#bytepair;
  my $lineoutsize = $linesize;
  # truncate line to remove all training "8080" bytepairs
  while ($bytepair[$lineoutsize] eq "8080") {
    $lineoutsize--;
  }
  for (my $i = 0; $i <= $lineoutsize; $i++) {
    $outline = $outline.$bytepair[$i]." ";
  }
  # remove final space
  $outline = substr($outline, 0, length($outline)-1);
  return $outline;
}
