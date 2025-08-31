# scc_rip.pl: Rip closed captions in Scenarist Closed Caption format from MPG files
#  (ripped from DVD or DVB)
# Run file without arguments to see usage
#
# Version 3.0
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 2.0 initial release as dvb2scc (incorporated the default output filename change and
#       line-splitting changes I put into version 2.0 of raw2scc)
# 2.1 added -d flag to output DVD-style raw file
#     (and subroutines printdata and skipheader to support it)
# 2.2 added logic for DishTV captions (previous logic was for ReplayTV only)
# 2.3 fixed DishTV logic: captions were in GOP order, not chronological order,
#     fixed DishTV logic: repeat code should only apply to commands, not character pairs
# 2.4 added more binmode statements where needed, in case they were causing the file read
#       operation to terminate before the entire file has been processed
# 2.5 added DVD logic, converting this tool from dvb2scc to scc_rip,
#     fixed DVD file creation logic, so it will work with CCParser,
#     added -t flag for drop/non-drop timecodes,
#     exit without creating SCC file if no captions are found
# 2.6 added ability to strip Field 2 from those formats that support it,
#     put each XDS sequence on its own line in the SCC file,
#     corrected drop/non-drop calculations (again)
# 2.7 splits ReplayTV into 4000 and 5000 lines (which use different formats),
#     fixed errors in frame() and timecodeof()
# 2.7.1 fixed rounding problem in timecodeof()
# 2.7.2 cosmetic: updated my e-mail address in the source code
# 2.8 deals with DVD MPEGs that use ff ff instead of ff fe pattern.
#     fixed major bug with DVD format that would lead to empty output
# 2.8.1 fixed open file handle for DVD output,
#       swapped documentation for ReplayTV 4000 & 5000 models
#        (no visible change)
# 3.0 improved DVD ff ff algorithm in case pattern is not 0x80
#      (thanks to Keith Hui)
#     added in Channel 3 & 4 codes for line-splitting

sub frame;
sub timecodeof;
sub printdata;
sub skipheader;

# initial variables
$rawmode = 0; # 0 is broadcast (BytePair), 1 is DVD (GOPPacket)
$offset = "00:00:00:00";
$fps = 30000/1001; # NTSC framerate (non-drop)
$drop = 0; # assume non-drop
$extract = 1; # assume extract Field 1 only
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
# print ("\nExtract: ", $extract);
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

$inputfile =~ m/(.+)\.(\w+)$/; # remove extension
($filebase, $skip) = ($1, $2);
if ($filebase eq "") {
  $filebase = $inputfile;
}
# DVD format uses one raw file for both fields, while Broadcast requires 2
if ($rawmode == 1) {
  $rawoutput = $filebase.".bin";
  print "Creating $rawoutput";
  open (WH, ">".$rawoutput) or die "Unable to write to file $rawoutput: $!, stopped";
  binmode WH;
  # the DVD file header will be handled by the printdata function
} else {
  print "Creating ";
  if ($extract != 2) {
    $rawoutput1 = $filebase."_1.bin";
    print "$rawoutput1";

    open (WH1, ">".$rawoutput1) or die "Unable to write to file $rawoutput1: $!, stopped";
    binmode WH1;

    print WH1 "\xff\xff\xff\xff"; # broadcast binary file header
  }
  if ($extract == 12) {
    print " and ";
  }
  if ($extract != 1) {
    $rawoutput2 = $filebase."_2.bin";
    print "$rawoutput2";

    open (WH2, ">".$rawoutput2) or die "Unable to write to file $rawoutput2: $!, stopped";
    binmode WH2;

    print WH2 "\xff\xff\xff\xff"; # broadcast binary file header
  }
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
$type = ""; # a few DVB types have sub-types
$P_caption = ""; # some DVB types ties captions to GOP frames; Predictive frame captions
                 #  must be held until after the Bi-directionals
$header = "\xff\xff\xff\xff";

READLOOP: while (sysread (RH, $byte, 1)) {
  $header = substr($header, 1, 3).$byte;
  $total += 1;
  if ($total % 0x100000 == 0) {
    print ".";
  }
  
  # printf "%02x", ord $byte;
  if ($header ne "\x00\x00\x01\xb2") { # user data header
    next READLOOP;
  }  
  sysread (RH, $header, 2);
  $total += 2;
  if ($header eq "\x43\x43") { # DVD closed caption header
    # DVDs can have multiple captions per segment
    $hasCaptions = 1;
    sysread (RH, $data, 2); # ship 2 bytes (\x01, \xf8)
    sysread (RH, $data, 1);
    # pattern of 0x00 means Field 2 then Field 1,
    #  while pattern of 0x80 means Field 1 then Field 2
    my $pattern = ord $data & 0x80;
    my $field1packet = 0; # expect Field 1 first
    if ($pattern == 0x00) {
      $field1packet = 1; # expect Field 1 second
    }
    $capcount = ord $data & 0x1e;
    $capcount = int ($capcount / 2);
    $total += 3;
    for (my $i = 0; $i < $capcount; $i++) {
      for (my $j = 0; $j < 2; $j++) {
        sysread (RH, $data, 3);
        $total += 3;
        # Field 1 and 2 data can be in either order,
        #  with marker bytes of \xff and \xfe
        # Since markers can be repeated, use pattern as well
        if ((substr($data, 0, 1) eq "\xff") && (j == $field1packet)) {
          $data1 = substr($data, 1, 2);
        } else { # \xfe or other \xff in case of repetition
          $data2 = substr($date, 1, 2);
        }
      }
      printdata $data1, $data2;
      $data1 = "\x80\x80";
      $data2 = "\x80\x80";
    }
    $header = "\xff\xff\xff\xff";
    next READLOOP;
  }
  if ($header eq "\xbb\x02") { # DVB closed caption header for ReplayTV 4000 series
    $hasCaptions = 1;
    # print ".";
    sysread (RH, $data2, 2); # read Field 2 data
    sysread (RH, $data, 2); # skip 2 bytes (\xcc\x02)
    sysread (RH, $data1, 2); # read Field 1 data
    $total += 6;
    printdata $data1, $data2;
    $data = "";
    $data1 = "\x80\x80";
    $data2 = "\x80\x80";
    $header = "\xff\xff\xff\xff";
    next READLOOP;
  }
  if ($header eq "\x99\x02") { # DVB closed caption header for ReplayTV 5000 series
    $hasCaptions = 1;
    # print ".";
    sysread (RH, $data2, 2); # read Field 2 data
    sysread (RH, $data, 2); # skip 2 bytes (\xaa\x02)
    sysread (RH, $data1, 2); # read Field 1 data
    $total += 6;
    printdata $data1, $data2;
    $data = "";
    $data1 = "\x80\x80";
    $data2 = "\x80\x80";
    $header = "\xff\xff\xff\xff";
    next READLOOP;
  }
  if ($header eq "\x05\x02") { # DVB closed caption header for Dish Network (Field 1 only)
    # Dish Network can have 2 or 4 bytes of captions per segment, with the possibility
    #  of a 2-byte code with the command to repeat it
    # Making things even trickier, each type 5 pattern needs to be held until just
    #  before the next type 5 pattern before being sent.
    # Finally, the repeats should only be performed for repeatable pairs
    #  (byte 1 in: 10-1f or 80-9f)
    $hasCaptions = 1;
    sysread (RH, $data, 5); # skip 5 bytes (\x04, a 2 byte counter, and 2 varied bytes)
    sysread (RH, $type, 1); # pattern type (\x02, \x04 or \x05)
    $total += 6;
    if ($type eq "\x02") { # 2-byte caption, can be repeated
      sysread (RH, $data, 1); # skip 1 byte (\x09)
      sysread (RH, $data1, 2); # caption bytes
      sysread (RH, $type, 1); # repeater (\x02 or \x04)
      printdata $data1, "\x80\x80";
      my $hi = ord substr($data1, 0, 1);
      if ($hi > 127) {$hi -= 128;}
      if ($type eq "\x04" and $hi < 32) { # repeat (only for non-character pairs)
        printdata $data1, "\x80\x80";
      }
      sysread (RH, $data, 3); # skip 3 bytes (\x0a and 2-byte checksum?)
      $total += 6;
      $data1 = "\x80\x80";
      $header = "\xff\xff\xff\xff";
      next READLOOP;
    }
    if ($type eq "\x04") { # 4-byte caption, not repeated
      sysread (RH, $data, 1); # skip 1 byte (\x09)
      sysread (RH, $data1, 2); # caption bytes
      printdata $data1, "\x80\x80";
      sysread (RH, $data1, 2); # more caption bytes
      printdata $data1, "\x80\x80";
      sysread (RH, $data, 4); # skip 4 bytes (\x020a, followed by 2-byte checksum?)
      $total += 9;
      $data1 = "\x80\x80";
      $header = "\xff\xff\xff\xff";
      next READLOOP;
    }
    # type 5 is used by P (Predictive) frames, so we have to hold each one until the next
    #  P frame is received
    if ($type eq "\x05") { # 2 or 4-byte caption (2-byte can be repeated)
      if ($P_caption ne "") { # play the previous P-caption first
        for (my $i = 0; $i < (length $P_caption); $i += 2) {
          printdata substr($P_caption, $i, 2);
        }
        $P_caption = "";
      }
      sysread (RH, $data, 6); # skip 6 bytes (\x04, followed by 5 bytes from last 0x05 pattern)
      sysread (RH, $type, 1); # number of caption bytes (\x02 or \x04)
      sysread (RH, $data, 1); # skip 1 byte (\x09)
      sysread (RH, $data1, 2); # caption bytes--hold until next type-5 caption
      $P_caption = $data1;
      if ($type eq "\x02") {
        sysread (RH, $type, 1); # repeater (\x02 or \x04)
        my $hi = ord substr($data1, 0, 1);
        if ($hi > 127) {$hi -= 128;}
        if ($type eq "\x04" and $hi < 32) {
          $P_caption = $P_caption.$data1;
        }
      } else {
        sysread (RH, $data1, 2); # more caption bytes
        $P_caption = $P_caption.$data1;
        sysread (RH, $data, 1); # repeater (always \x02)
        $total += 2;
      }
      sysread (RH, $data, 3); # skip 3 bytes (\x0a, followed by 2-byte checksum?)
      $total += 11;
      $data1 = "\x80\x80";
      $header = "\xff\xff\xff\xff";
      next READLOOP;
    }
      
    $header = "\xff\xff\xff\xff";
    $data = "";
    next READLOOP;
  }
  # does not match any known closed caption header
  $header = "\xff\xff\xff\xff";
  next READLOOP;
}
close RH;
if ($rawmode == 1) {
  close WH;
}
if ($extract != 2) {
  close WH1;
}
if ($extract != 1) {
  close WH2;
}
if (! $hasCaptions) {
  print " has no captions.";
  exit;
}
print "\n";

# Raw to SCC

for (my $filenum = 1; $filenum < 3; $filenum++) { # loop through 2 possible raw files
  # skip unwanted scenarios (reading raw2 when user only wanted raw1, and vice-versa)
  if (($filenum==1) && ($extract==2)) {
    next;
  }
  if (($filenum==2) && ($extract==1)) {
    next;
  }
  # set up output SCC file handle
  $sccoutput = $filebase."_$filenum.scc";
  print "Creating $sccoutput...\n";
  open (WH, ">".$sccoutput) or die "Unable to write to file $sccoutput: $!, stopped";
  print WH "Scenarist_SCC V1.0";
  # set up input raw file handle
  if ($rawmode == 1) { # DVD-style raw files contain both fields
    $rawinput = $filebase.".bin";
  } else { # broadcast-style raw files only contain a single field
    $rawinput = $filebase."_$filenum.bin";
  }
  sysopen(RH, $rawinput, 0) or die "Unable to read from file $rawinput: $!, stopped";
  binmode RH;
  sysread RH, $data, 4; # skip file header

  $currentframe = frame($offset) - 1;
  $inline = 0; # flag for when it's worth outputting (0 = skip nulls)
  $endofline = 0; # signal that line ends when next null reached
  $colcount = 0; # keeps track of line length
  $crflag = 0; # flag that a roll-up/text carriage return has been received
  $tabflag = 0; # makes sure tab follows timecode

  skipheader $filenum;

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
    
    # end line at end of XDS sequence
    if ($hi eq "0f") {
      $endofline = 0;
      $inline = 0;
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
      print WH "\n\n".timecodeof($currentframe);
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
}

exit;

sub usage {
  print "\nSCC_RIP Version 3.0\n";
  print "  Rips closed captions in raw and SCC formats from DVD and DVB MPG files.\n";
  print "    (For DVB, ReplayTV 4000 and 5000, and Dish Network formats are supported.)\n\n";
  print "  Syntax: SCC_RIP -d -12 -o-01:00:00:00 -f24 infile.mpg\n";
  print "    -d: Output raw captions in DVD format\n";
  print "         (DEFAULT is broadcast format)\n";
  print "    -1, -2, -12: Output Field 1 data, Field 2 data, or both\n";
  print "         (DEFAULT is -1)\n";
  print "    -o (OPTIONAL): Offset to apply to all timecodes, in HH:MM:SS:FF format\n";
  print "                    (can be positive or negative)\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    infile.mpg: file to process\n";
  print "    2 (or 4) outfiles will have base name of infile plus _1.BIN and _1.SCC\n";
  print "      (for Field 1) and/or _2.BIN and _2.SCC (for Field 2)\n\n";
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
    if ($extract != 2) {
      print WH1 $data1;
    }
    if ($extract != 1) {
      print WH2 $data2;
    }
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
  my $field = shift(@_);
  my $match = "";
  my $data = "";
  if ($field == 1) {
    $match = "\xff";
  } else {
    $match = "\xfe";
  }
# input loop, used to remove header information when raw mode is DVD
  if ($rawmode == 1) {
    INPUTLOOP: while ($data ne $match) {
      if ((sysread RH, $data, 1) != 1) {
        last INPUTLOOP;
      }
    }
  }
}
