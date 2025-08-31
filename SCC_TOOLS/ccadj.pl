# ccadj.pl: Adjust timecodes on Scenarist Closed Caption and Closed Caption
#  Disassembly formats
# Run file without arguments to see usage
#
use strict;
my $Version = "2.8";
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release
# 1.1 fixed timecodeof function to properly round frames to never be above framerate,
#     added $lastframe and $frames to read loop to check for out-of-order timecodes
# 1.2 made SCC files double-spaced to conform with specification,
#     clarified usage note for negative timecodes,
#     simplified timecodeof function,
#     fixed frame function to handle negative timecodes
# 1.3 fixed frame function to handle negative timecodes (again)
# 2.0 add handling of CHANNEL changes in CCD file
# 2.1 finally figured out drop vs non-drop (changing frame and timecodeof functions)
#       and correctly parsing and outputting non-drop timecodes,
#     added -td and -tn parameters
# 2.6 corrected drop/non-drop calculations (again)
# 2.7 fixed errors in frame() and timecodeof()
# 2.7.1 fixed rounding error in timecodeof
# 2.7.2 cosmetic: updated my e-mail address in the source code
# 2.8 added ability to speed up or slow down captions

sub usage;
sub frame;
sub timecodeof;

# initial variables
my $offsettimecode = "00:00:00:00";
my $fps = 30000/1001; # NTSC framerate
my $mult = 1; # assume no speed change
my $drop = 0; # assume non-drop
my $input = "~"; # place-holder for no input file yet
my $output = "~"; # place-holder for no output file yet
my $anything = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (s/-m//) {
    $mult = $_;
    next;
  }
  if (s/-o//) {
    $offsettimecode = $_;
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
  if ($input =~ m\~\) {
    $input = $_;
    next;
  }
  $output = $_; 
}

# print ("\nInput: ", $input);
# print ("\nOutput: ", $output);
# print ("\nOffset: ", $offsettimecode);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# peinr ("\nMultiplier: ", $mult);

if ($anything eq "~") {
  usage();
  exit;
}

if ($input eq "~") {
  usage();
  die "No output file, stopped";
}
if ($output eq "~") {
  usage();
  die "No output file, stopped";
}

if (($fps < 15)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if ($mult <= 0) {
  usage();
  die "Multiplier can't be less than or equal to 0, stopped";
}

if (($offsettimecode =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

my $offset = frame($offsettimecode);
# print ("\nOffset frames: ",$offset);

# Need to determine type of first input file
my $outputheader = "~"; # placeholder for unknown file type
open (RH, $input) or die "Unable to read from file: $!";
my $header = <RH>;
chomp $header;
(my $formattype, my $formatversion) = split (/ /, $header);
if ($formattype eq "Scenarist_SCC") {
  $outputheader = $header."\n";
}
if ($formattype eq "SCC_disassembly") {
  my $channel = -1; # can be 1 or 2
  my $channelline = <RH>; # read in CHANNEL line
  chomp $channelline;
  (my $channelcommand, $channel) = split(/\s/, $channelline);
  if (($channelcommand ne "FIELD") && ($channelcommand ne "CHANNEL")) {
    $channel = -1;
  }
  if (($channel != 1) and ($channel != 2)) {
    die "CHANNEL set incorrectly, stopped";
  }
  $outputheader = $header."\n".$channelline."\n";
}
if ($outputheader eq "~") {
  die "Unrecognized input format, stopped";
}

open (WH, ">".$output) or die "Unable to write to file: $!";
print WH $outputheader;

# read loop
my $lastframe = -1;
my $timecode = "";
my $skip = "";
my $line = "";
my $frames = 0;
my $timecode = "00:00:00:00";
LINELOOP: while (<RH>) {
  if ($_ eq "\n") {
    print WH "\n";
    next LINELOOP;
  }
  chomp;
  m/(\S+)(\s)(.+)/; # split into timecode and rest of line
  ($timecode, $skip, $line) = ($1, $2, $3);
  # nothing to adjust for a FIELD  or CHANNEL command
  if (($timecode eq "FIELD") or ($timecode eq "CHANNEL")) { 
    print WH $timecode."\t".$line."\n";
    next LINELOOP;
  }
  $frames = frame($timecode);
  if ($frames <= $lastframe) {
    die "Timecode $timecode is out of order, stopped";
  }
  $timecode = timecodeof($frames*$mult + $offset);
  print WH $timecode."\t".$line."\n";
  $lastframe = $frames;
  next LINELOOP;
}

close WH;
close RH;
exit;

sub usage {
  printf "\nCCADJ Version %s\n", $Version;
  print "  Adjust timecodes of Scenarist Closed Caption\n";
  print "    or Closed Caption Disassembly files.\n";
  print "  Syntax: CCADJ -m1.249 -o01:00:00:00 -td infile outfile\n";
  print "    -m (OPTIONAL): Multiplier to apply to all timecodes\n";
  print "         (1.249 will convert FILM to NTSC, 0.834 = NTSC to PAL)\n";
  print "    -o: Offset to apply (after multiplier), in HH:MM:SS:FF format\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    Outfile will be overwritten if it exists\n";
  print "  Note: To move timecodes backwards, use a line like this:\n\n";
  print "  CCADJ -o-00:00:03:15 captions.scc captions2.scc\n\n";
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
    die "Negative time code in line $. of $input, stopped";
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

