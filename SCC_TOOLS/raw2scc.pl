# raw2scc.pl: Convert raw Closed Captions binary file into Scenarist Closed Caption format
# Run file without arguments to see usage
#
use strict;
my $Version = "2.10";
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release
# 1.1 fixed timecode function to properly round frames to never be above framerate
# 1.2 made SCC file double-spaced to conform to specifications, 
#     removed max line width,
#     simplified timecodeof function,
#     fixed frame function to handle negative timecodes [shouldn't happen in this program]
# 2.0 set up default output name,
#     added binmode command after opening read handle, so program won't terminate on
#       the EOF character 0x1a (used in extended characters for Channel 2),
#     added newline if switching modes (for example, pop-on captions to text captions),
#     added detection of XDS checksum to list of when to set $endofline,
#     corrected all field references to channel references (invisible to user)
# 2.1 finally figured out drop vs non-drop (changing frame and timecodeof functions)
#       and correctly parsing and outputting non-drop timecodes,
#     added -td and -tn parameters
# 2.6 able to extract from Field 1 or 2 of DVD-formatted raw files,
#     corrected drop/non-drop calculations (again),
#     put each XDS sequence on its own line in the SCC file
# 2.7 fixed errors in frame() and timecodeof()
# 2.7.1 fixed rounding errors in timecodeof()
# 2.7.2 cosmetic: updated my e-mail address in the source code
# 2.8 added in Channel 3 & 4 codes for line-splitting
# 2.9 trimmed 8080 (null) codes off of end of lines,
#     break line anytime more than 2 nulls in a row are found
#      (user can adjust this with -l parameter)
# 2.10 use channel change to force new line

sub usage;
sub frame;
sub timecodeof;
sub skipheader;
sub trim;

# initial variables
my $offset = "00:00:00:00";
my $fps = 30000/1001; # NTSC framerate
my $drop = 0; # assume non-drop
my $extract = 1; # assume extract Field 1 only
my $nulllimit = 2; # break line if more than this many nulls are found inline
my $input = "~"; # place-holder for no input file yet
my $output = "~"; # place-holder for no output file yet
my $anything = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (m/-12/) {
    $extract = 12;
    next;
  }
  if (m/-1/) {
    $extract = 1;
    next;
  }
  if (m/-2/) {
    $extract = 2;
    next;
  }
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
  if ($input =~ m\~\) {
    $input = $_;
    next;
  }
  $output = $_; 
}

# print ("Offset: ", $offset);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nInput: ", $input);
# print ("\nOutput: ", $output);

if ($anything eq "~") {
  usage();
  exit;
}

if ($nulllimit =~ /\D/) {
  usage();
  die "-l null limit must be a number, stopped";
}

if ($input eq "~") {
  usage();
  die "No input file, stopped";
}

if ($output eq "~") {
  if (($input =~ m/(.*)(\.bin)$/i)) {
    $output = $1.".scc";
  }
  if (($input =~ m/(.*)(\.dat)$/i)) {
    $output = $1.".scc";
  }
}
if ($output eq "~") {
  usage();
  die "Input file must have .bin or .dat extension for default output to work, stopped";
}

if ($input eq $output) {
  die "Input and output files cannot be the same, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($offset =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

my $currentframe;
my $filetype = 0; # flag for type of file: 1 = Line 21 Byte Pair, 2 = Line 21 GOP Packet
my $data;

for (my $filenum = 1; $filenum < 3; $filenum++) { # loop through 2 possible raw files
  # skip unwanted scenarios (reading raw2 when user only wanted raw1, and vice-versa)
  if (($filenum==1) && ($extract==2)) {
    next;
  }
  if (($filenum==2) && ($extract==1)) {
    next;
  }
  if ($extract == 12) {
    if (($input =~ m/(.*)(\.bin)$/i)) {
      $output = $1."_$filenum.scc";
    }
    if (($input =~ m/(.*)(\.dat)$/i)) {
      $output = $1."_$filenum.scc";
    }
  }

  $currentframe = frame($offset) - 1;
  open (WH, ">".$output) or die "Unable to write to file: $!";

  print WH "Scenarist_SCC V1.0";

  sysopen(RH, $input, 0) or die "Unable to read from file: $!, stopped";
  binmode RH;
  sysread RH, $data, 4; # grab file header
  $filetype = 0; # flag for type of file: 1 = Line 21 Byte Pair, 2 = Line 21 GOP Packet
  if ($data eq "\xff\xff\xff\xff") {
    $filetype = 1;
  }
  if ($data eq "\x00\x00\x01\xb2") {
    $filetype = 2;
  }
  if ($filetype == 0) {
    die "File type of $! not recognized, stopped";
  }

  my $line = ""; # line to output
  my $inline = 0; # flag for when it's worth outputting (0 = skip nulls)
  my $endofline = 0; # signal that line ends when next null reached
  my $nullcount = 0;
  my $colcount = 0; # keeps track of line length
  my $crflag = 0; # flag that a roll-up/text carriage return has been received
  my $tabflag = 0; # makes sure tab follows timecode
  my $channel = 3; # current channel (default to XDS Channel 3)

  skipheader $filenum;

  # read loop
  READLOOP: while (sysread RH, $data, 2) {
    if ($inline) {++$colcount};
    ++$currentframe;
    $data =~ m/(.)(.)/;
    my $hi = ord $1;
    my $lo = ord $2;
    my $word = sprintf "%02x%02x", $hi, $lo;
    # remove any odd parity for testing
    if ($hi > 127) {$hi -= 128;}
    if ($lo > 127) {$lo -= 128;}
    my $evenword = sprintf ("%02x%02x", $hi, $lo);
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
      skipheader $filenum;
      next READLOOP;
    }
    # start new line if switching modes (and haven't started a new line already):
    #  High byte = 14, 1c, 15 or 1d for Channel 1 - 4
    #  Pop-on: low byte 20
    #  Roll-up: low bytes 25, 26, 27
    #  Paint-on: low byte 29
    #  Text: low byte 2a, 2b
    #  XDS (always Channel 3): high byte 01 - 0e, any low byte
    if (((($hi == 0x14) or ($hi == 0x1c) or ($hi == 0x15) or ($hi == 0x1d))
        and (($lo == 0x20) or ($lo == 0x25) or ($lo == 0x26) or ($lo == 0x27)
          or ($lo == 0x29) or ($lo == 0x2a) or ($lo == 0x2b)))
        or (($hi > 0) and ($hi < 15))) {
      if ($colcount > 1) {
        if (($hi == 0x14) and ($channel != 1)) { $inline = 0; }
        if (($hi == 0x1c) and ($channel != 2)) { $inline = 0; }
        if ((($hi == 0x15) or ($hi < 15)) and ($channel != 3)) {
          $inline = 0;
        }
        if (($hi == 0x1d) and ($channel != 4)) { $inline = 0; }
      }
      if ($colcount > 2) { $inline = 0; }
      if ($hi == 0x14) { $channel = 1; }
      if ($hi == 28) { $channel = 2; }
      if (($hi == 0x15) or ($hi < 15)) { $channel = 3; }
      if ($hi == 0x1d) { $channel = 4; }
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

    skipheader $filenum;

    next READLOOP;
  }  
  print WH trim($line)."\n\n";
  close RH;
  close WH;
}
exit;

sub usage {
  printf "\nRAW2SCC Version %s\n", $Version;
  print "  Converts NTSC Closed-Caption binary data to Scenarist import format.\n\n";
  print "  Syntax: RAW2SCC -2 -o01:00:00:00 -td -l2 infile.bin outfile.scc\n";
  print "    -1, -2, -12: Output Field 1 data, Field 2 data, or both\n";
  print "         (only applies to DVD-formatted input; DEFAULT is -1)\n";
  print "      (for -12, output will be infile_1.scc and infile_2.scc)\n";
  print "    -o (OPTIONAL): Offset for first byte in file, in HH:MM:SS:FF format\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    -l: Set how many null codes it takes to trigger a new SCC line\n";
  print "         (DEFAULT: 2)\n";
  print "    Outfile argument is optional and is assumed to be infile.scc\n";
  print "      (input file in this case must have .bin or .dat extension)\n";
  print "    Outfile will be overwritten if it exists\n\n";
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

sub skipheader {
  my $field = shift(@_);
  my $match = "";
  my $data = "";
  if ($field == 1) {
    $match = "\xff";
  } else {
    $match = "\xfe";
  }
# input loop, used to remove header information when raw mode is DVD
  if ($filetype == 2) {
    INPUTLOOP: while ($data ne $match) {
      if ((sysread RH, $data, 1) != 1) {
        last INPUTLOOP;
      }
    }
  }
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
