# dvr2scc.pl: Rip closed captions in Scenarist Closed Caption format from DVR-MS (MediaCenter) files
# Run file without arguments to see usage
#
# Version 1.2
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release
# 1.1 correction based on having two videos to look at
# 1.2 correction based on having three videos to look at

sub frame;
sub timecodeof;
sub printdata;
sub skipheader;

# initial variables
$rawmode = 0; # 0 is broadcast (BytePair), 1 is DVD (GOPPacket)
$offset = "00:00:00:00";
$fps = 30000/1001; # NTSC framerate (non-drop)
$drop = 0; # assume non-drop
$inputfile = "~";
$anything = "~";
$rawoutput = "";
$sccoutput = "";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (m/-d/) {
    $rawmode = 1;
    next;
  }
  if (s/-o//) {
    $offset = $_;
    next;
  }
  if (s/-f//) {
    $fps = $_;
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
  if ($inputfile eq "~") {
    $inputfile = $_;
    next;
  }
}

# print ("\nRaw Mode: ", $rawmode ? "DVD" : "Broadcast");
# print ("\nOffset: ", $offset);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nInput: ", $inputFile);

if ($anything eq "~") {
  usage();
  exit;
}

if ($inputfile eq "~") {
  usage();
  die "No input file, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($offset =~ m/\d\d:\d\d:\d\d:\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

$inputfile =~ m/(.+)\.(dvr\-ms)$/; # remove extension
($filebase, $skip) = ($1, $2);
if ($filebase eq "") {
  $filebase = $inputfile;
}
$rawoutput = $filebase.".bin";
print "Creating $rawoutput";
open (WH, ">".$rawoutput) or die "Unable to write to file $rawoutput: $!, stopped";
binmode WH;
# the DVD file header will be handled by the printdata function
if ($rawmode == 0) {
  print WH "\xff\xff\xff\xff"; # broadcast binary file header
}

sysopen(RH, $inputfile, O_RDONLY) or die "Unable to read from file: $!, stopped";
binmode RH;

$data = "";
$data1 = "\x80\x80"; # default to do nothing byte-pair
$data2 = "\x80\x80"; # default to do nothing byte-pair
$total = 0;
$hasCaptions = 0;
# these are only used by DVD raw mode:
$loopcount = 1; # loop 1: 5 elements, loop 2: 8 elements, loop 3: 11 elements, rest: 15 elements
$datacount = 0; # counts within loop
$capcount = 0; # DVD has multiple captions per packet
$header = "\xff\xff\xff\xff\xff";

READLOOP: while (sysread (RH, $byte, 1)) {
  $header = substr($header, 1).$byte;
  $total += 1;
  if ($total % 0x100000 == 0) {
    print ".";
  }
  
  # printf "%02x", ord $byte;
  if ($header ne "\x00\xff\xff\x00\x00") { # Video user data (?)
    next READLOOP;
  }
  sysread (RH, $data, 3); # these bytes are specific to each recording
  sysread (RH, $data, 13);
  $total += 16;
  if ($data ne "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00") {
    $header = "\xff\xff\xff\xff\xff";
    next READLOOP;
  }  
  $hasCaptions = 1;
  sysread (RH, $data1, 2);
  $total += 2;
  if ($data1 eq "\x15\xc3") {
    printf ("%06x", $total);
  }
  printdata $data1, $data2;
  $data1 = "\x80\x80";
  $header = "\xff\xff\xff\xff\xff";
  next READLOOP;
}
close RH;
if (! $hasCaptions) {
  print " has no captions.";
  exit;
}
close WH;
print "\n";

# Raw to SCC

$sccoutput = $filebase.".scc";
print "Creating $sccoutput...\n";
open (WH, ">".$sccoutput) or die "Unable to write to file $sccoutput: $!, stopped";
print WH "Scenarist_SCC V1.0";
# set up input raw file handle
$rawinput = $filebase.".bin";
sysopen(RH, $rawinput, 0) or die "Unable to read from file $rawinput: $!, stopped";
binmode RH;
sysread RH, $data, 4; # skip file header

$currentframe = frame($offset) - 1;
$inline = 0; # flag for when it's worth outputting (0 = skip nulls)
$endofline = 0; # signal that line ends when next null reached
$colcount = 0; # keeps track of line length
$crflag = 0; # flag that a roll-up/text carriage return has been received
$tabflag = 0; # makes sure tab follows timecode

skipheader;

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
  if (($evenword eq "0000") and ($endofline)) {
    $endofline = 0;
    $inline = 0;
  }
  # check for carriage return code (142d or 1c2d)
  if (($evenword ne "142d") and ($evenword ne "1c2d") and ($crflag)) {
    $endofline = 0;
    $inline = 0;
  }
  if (($evenword eq "0000") and not ($inline)) {
    skipheader $filenum;
    next READLOOP;
  }
  
  # end line at end of XDS sequence
  if ($hi eq "0f") {
    $endofline = 0;
    $inline = 0;
  }
  
  # start new line if switching modes (and haven't started a new line already):
  #  Pop-on: 1420 or 1c20
  #  Roll-up: 1425, 1426, 1427, or 1c25, 1c26, 1c27
  #  Paint-on: 1429 or 1c29
  #  Text: 142a, 142b, 1c2a, 1c2b
  #  XDS: 0xyy (x from 1 to e)
  if ((($evenword eq "1420") or ($evenword eq "1c20") or
      ($evenword eq "1425") or ($evenword eq "1c25") or
      ($evenword eq "1426") or ($evenword eq "1c26") or
      ($evenword eq "1427") or ($evenword eq "1c27") or
      ($evenword eq "1429") or ($evenword eq "1c29") or
      ($evenword eq "142a") or ($evenword eq "1c2a") or
      ($evenword eq "142b") or ($evenword eq "1c2b") or
      (($hi > 0) and ($hi < 15))) and
   ($colcount > 2)) {
    $inline = 0;
  }
  
  if (($evenword ne "0000") and not ($inline)) {
    $inline = 1;
    $colcount = 1;
    print WH "\n\n".timecodeof($currentframe);
    $tabflag = 1;
  }
  # go immediately to next line for roll-up/text carriage return codes:
  #  142d = carriage return channel 1
  #  1c2d = carriage return channel 2
  if (($evenword eq "142d") or ($evenword eq "1c2d")) {
    $crflag = 1;
  } else {
    $crflag = 0;
  }

  # check for the standard XDS and closed-caption end caption codes:
  #  0fxx = XDS checksum
  #  142c = clear screen channel 1
  #  142f = write caption to screen channel 1 (used by pop-on captions)
  #  1c2c = clear screen channel 2
  #  1c2f = write caption to screen channel 2
  if (($hi == 15) or ($evenword eq "142c") or ($evenword eq "142f")
      or ($evenword eq "1c2c") or ($evenword eq "1c2f")) {
    $endofline = 1;
  }
  if ($tabflag) {
    print WH "\t";
    $tabflag = 0;
  } else {
    print WH " ";
  }
  print WH $word;

  skipheader $filenum;

  next READLOOP;
}
print WH "\n\n";
close RH;
close WH;

exit;

sub usage {
  print "\nDVR2SCC Version 1.2\n";
  print "  Rips closed captions in raw and SCC formats from MediaCenter files.\n";
  print "  Syntax: DVR2SCC -d -o-01:00:00:00 -f24 infile.dvr-ms\n";
  print "    -d: Output raw captions in DVD format\n";
  print "         (DEFAULT is broadcast format)\n";
  print "    -o (OPTIONAL): Offset to apply to all timecodes, in HH:MM:SS:FF format\n";
  print "                    (can be positive or negative)\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    infile.dvr-ms: file to process\n";
  print "    2 outfiles will have base name of infile plus .BIN and .SCC\n\n";
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

sub printdata {
  my $data1 = shift(@_);
  my $data2 = shift(@_);
  if ($rawmode == 0) { # Broadcast format
    print WH $data1;
    # no Field 2 data in DVR-MS format
    return;
  }
  # DVD format
  if ($datacount == 0) {
    print WH "\x00\x00\x01\xb2\x43\x43\x01\xf8";
    if ($loopcount == 1) {
      print WH "\x8a";
    }
    if ($loopcount == 2) {
      print WH "\x8f";
    }
    if ($loopcount == 3) {
      print WH "\x16\xfe".$data2;
    }
    if ($loopcount > 3) {
      print WH "\x1e\xfe".$data2;
    }
  }
  ++$datacount;
  print WH "\xff".$data1;
  if ((($loopcount == 1) and ($datacount < 5)) or (($loopcount == 2) and ($datacount < 8)) or
      (($loopcount == 3) and ($datacount < 11)) or (($loopcount > 3) and ($datacount < 15))) {
    print WH "\xfe".$data2;
  } else {
    if ($loopcount == 1) {
      print WH "\xfe".$data2;
    }
    ++$loopcount;
    $datacount = 0;
  }
}

sub skipheader {
  my $match = "\xff";
  my $data = "";
# input loop, used to remove header information when raw mode is DVD
  if ($rawmode == 1) {
    INPUTLOOP: while ($data ne $match) {
      if ((sysread RH, $data, 1) != 1) {
        last INPUTLOOP;
      }
    }
  }
}
