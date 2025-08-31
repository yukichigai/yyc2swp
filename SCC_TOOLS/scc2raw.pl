# scc2raw.pl: Convert Scenarist Closed Caption format into binary file (for VCD or CCParser)
# Run file without arguments to see usage
#
# Version 2.8
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release
# 1.1 added $lastframe to read loop to check for out-of-order timecodes
# 1.2 made SCC files double-spaced to conform with specification,
#     fixed accuracy of frame function
# 2.0 flipped argument list around to match other programs (infile outfile
#      instead of outfile infile1 infile2 ...),
#     added binmode command after opening write handle,
#     added ability to handle SCC files with tab after timecode,
#     added logic to assume outfile name from infile,
#     added line number to out-of-order error message
# 2.1 finally figured out drop vs non-drop (changing frame functions)
#       and correctly parsing non-drop timecodes,
#     added -td and -tn parameters
# 2.2 added -d flag for DVD-format (input to CCParser)
# 2.6 corrected drop/non-drop calculations (again),
#     changed -s to -o to match other tools,
#     added ability to accept Field 2 files for DVD format output
# 2.7 fixed error in frame()
# 2.8 changed default output file extension from .dat to .bin (reflecting
#       the fact that the VCD CAPTnn.DAT format looks nothing like CC raw
#       format).
#     cosmetic: updated my e-mail address in the source code

sub usage;
sub frame;
sub printdata;

# initial variables
$rawmode = 0; # 0 is broadcast (BytePair), 1 is DVD (GOPPacket)
$starttime = "00:00:00:00";
$fps = 30000/1001; # NTSC framerate (non-drop)
$drop = 0; # assume non-drop
$insert = 1; # which field to insert (with 12 = both)
$input = "~"; # place-holder for no input file yet
$input2 = "~"; # 2nd input file for inserting both fields
$output = "~"; # place-holder for no output file yet
$anything = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (m/-d/) {
    $rawmode = 1;
    next;
  }
  if (m/-12/) {
    $insert = 12;
    next;
  }
  if (m/-1/) {
    $insert = 1;
    next;
  }
  if (m/-2/) {
    $insert = 2;
    next;
  }
  if (s/-o//) {
    $starttime = $_;
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
  if ($input =~ m/~/) {
    $input = $_;
    next;
  }
  if (($insert == 12) && ($input2 =~ m/~/)) {
    $input2 = $_;
    next;
  }
  $output = $_; 
}

# print ("\nRaw Mode: ", $rawmode ? "DVD" : "Broadcast");
# print ("\nInsert Field: ", $insert);
# print ("\nStart time: ", $starttime);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nInput: ", $input);
# print ("\nInput 2: ", $input2);
# print ("\nOutput: ", $output);

if ($anything eq "~") {
  usage();
  exit;
}

if ($input eq "~") {
  usage();
  die "No input file, stopped";
}

if (($insert == 12) && ($input2 eq "~")) {
  usage();
  die "Missing second input file, stopped";
}

if (($rawmode == 0) && ($insert == 12)) {
  usage();
  die "Broadcast format can't import 2 SCC files, stopped";
}

if ($output eq "~") {
  if ($input =~ m/(.*)(\.scc)$/i) {
    $output = $1.".bin";
  }
}
if ($output eq "~") {
  usage();
  die "Input file must have .scc extension to guess output file name, stopped";
}

if ($input eq $output) {
  die "Input and output files cannot be the same, stopped";
}

if (($fps < 15)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($starttime =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for start time, stopped";
}

open (WH, ">".$output) or die "Unable to write to file: $!";
binmode WH;

if ($rawmode == 0) {
  print WH "\xff\xff\xff\xff"; # broadcast binary file header
} # the DVD file header will be handled by the printdata function

if ($insert != 2) {
  open (RH1, $input) or die "Unable to read from $input: $!";
  $header = <RH1>;
  chomp $header;
  ($formattype, $formatversion) = split (/ /, $header);
  if ($formattype ne "Scenarist_SCC") {
    die "Not SCC format, stopped";
  }
}
if ($insert == 2) {
  open (RH2, $input) or die "Unable to read from $input: $!";
}
if ($insert == 12) {
  open (RH2, $input2) or die "Unable to read from $input2: $!";
}
if ($insert != 1) {
  $header = <RH2>;
  chomp $header;
  ($formattype, $formatversion) = split (/ /, $header);
  if ($formattype ne "Scenarist_SCC") {
    die "Not SCC format, stopped";
  }
}

# these are only used by DVD raw mode:
$loopcount = 1; # loop 1: 5 elements, loop 2: 8 elements, loop 3: 11 elements, rest: 15 elements
$datacount = 0; # counts within loop

$keepReading1 = 0; # flags to tell when to read each input file
$keepReading2 = 0;
if ($insert != 2) {
  $keepReading1 = 1;
}
if ($insert != 1) {
  $keepReading2 = 1;
}
$counter1 = -1; # counters to step through each input line
$counter2 = -1;
@bytePairs1 = (); # contents of each line
@bytePairs2 = ();
$readnextline1 = 1; # flag to tell when to read a line from each input file
$readnextline2 = 1;
$datatext1 = ""; # hex data read from each input file
$datatext2 = "";
$databytes1 = ""; # binary data to store for Field 1
$databytes2 = ""; # binary data to store for Field 2
$currentframe = frame($starttime) - 1;
$lastframe = $currentframe - 1;

READLOOP: while (($keepReading1) or ($keepReading2)) {
  $currentframe++;
  $counter1++;
  $counter2++;

  $datatext1 = "8080";
  # read next line for Field 1 if necessary
  if (($readnextline1) && ($keepReading1)) {
    if (!defined($_ = <RH1>)) {
      close RH1;
      $keepReading1 = 0;
    } else {
      #print $_."\n";
      chomp;
      if ($_ eq "") {
        if (!defined($_ = <RH1>)) {
          close RH1;
          $keepReading1 = 0;
        }
        #print $_."\n";

      }
    }
  }
  # parse next Field 1 line
  if (($readnextline1) && ($keepReading1)) {
    $readnextline1 = 0;
    m/(..:..:..[:;]..)(\s)(.+)/; # split into timecode and rest of line
    ($timecode, $skip, $line) = ($1, $2, $3);
    $nextframe = frame($timecode);
    if ($nextframe < $currentframe) {
      die "Timecode $timecode in $inputfile is out of order in line $., stopped";
    }
    # countdown to when data will line up with $currentframe
    $counter1 = - int($nextframe - $currentframe + 0.5);
    chomp $line;
    @bytePairs1 = split(' ', $line);
  }
  # step through Field 1 line
  if (($keepReading1) && ($counter1 > -1)) {
    $datatext1 = @bytePairs1[$counter1];
    if (($counter1 + 1) > $#bytePairs1) {
      $counter1 = -1;
      $readnextline1 = 1;
    }
  }
  # convert text to bytes
  $datatext1 =~ m/(..)(..)/;
  $hi = hex $1;
  $lo = hex $2;
  $databytes1 = chr($hi).chr($lo);

  $datatext2 = "8080";
  # read next line for Field 2 if necessary
  if (($readnextline2) && ($keepReading2)) {
    if (!defined($_ = <RH2>)) {
      close RH2;
      $keepReading2 = 0;
    } else {
      chomp;
      if ($_ eq "") {
        if (!defined($_ = <RH2>)) {
          close RH2;
          $keepReading2 = 0;
        }
      }
    }
  }
  # parse next Field 2 line
  if (($readnextline2) && ($keepReading2)) {
    $readnextline2 = 0;
    m/(..:..:..[:;]..)(\s)(.+)/; # split into timecode and rest of line
    ($timecode, $skip, $line) = ($1, $2, $3);
    $nextframe = frame($timecode);
    if ($nextframe < $currentframe) {
      die "Timecode $timecode in $inputfile is out of order in line $., stopped";
    }
    # countdown to when data will line up with $currentframe
    $counter2 = - int($nextframe - $currentframe + 0.5);
    chomp $line;
    @bytePairs2 = split(' ', $line);
  }
  # step through Field 2 line
  if (($keepReading2) && ($counter2 > -1)) {
    $datatext2 = @bytePairs2[$counter2];
    if (($counter2 + 1) > $#bytePairs2) {
      $counter2 = -1;
      $readnextline2 = 1;
    }
  }
  # convert text to bytes
  $datatext2 =~ m/(..)(..)/;
  $hi = hex $1;
  $lo = hex $2;
  $databytes2 = chr($hi).chr($lo);
  
  printdata $databytes1, $databytes2;
  next READLOOP;
}
if ($insert != 1) {
  close RH2;
}
if ($insert != 2) {
  close RH1;
}
close WH;
exit;

sub usage {
  print "\nSCC2RAW Version 2.8\n";
  print "  Converts Scenarist import format to NTSC Closed-Caption binary data.\n\n";
  print "  Syntax: SCC2RAW -d -12 -s01:00:00:00 -td infile.scc infile2.scc outfile.bin\n";
  print "    -d: Output raw captions in DVD format\n";
  print "         (DEFAULT is broadcast format)\n";
  print "    -1, -2, -12: (DVD format only) Which field to encode as,\n";
  print "       Field 1, Field 2, or both (DEFAULT is -1)\n";
  print "       (-12 requires a second input file to be provided)\n";
  print "    -o: Offset for first byte in file, in HH:MM:SS:FF format\n";
  print "         (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    outfile will be overwritten if it exists\n";
  print "    outfile argument is optional and is assumed to be infile.bin\n\n";
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
  ($hh, $mm, $ss, $ff) = split(m/[:;]/, $timecode, 4);
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

sub printdata {
  my $data1 = shift(@_);
  my $data2 = shift(@_);
  if ($rawmode == 0) {
    if ($insert = 1) {
      print WH $data1;
    } else {
      print WH $data2;
    }
    return;
  }
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

