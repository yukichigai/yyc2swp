# cc_mux.pl: Add closed captions in raw or Scenarist Closed Caption format to MPG files
#  (in DVD or DVB formats)
# Run file without arguments to see usage
#
# Version 1.0
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release

sub frame;
sub findpacket;

# global variables
$buffer = ""; # MPEG-to-MPEG copy buffer
$total = 0; # running byte count

# initial variables
my @CCFileFormat = (0, 0);  # 1 is raw broadcast (BytePair), 2 is raw DVD (GOPPacket), 3 is SCC;
my $CCformat = 1; # 1 is DVD (per-GOP), 11 is ReplayTV 4000, 12 is ReplayTV 5000 (both per-frame)
my $formatcode = "~";
my $captionstart = "00:00:00:00";
my $videostart = "00:00:00:00";
my $offset = 0;
my $fps = 30000/1001; # NTSC framerate (non-drop)
my $drop = 0; # assume non-drop
my $insert = ""; # "1" = Field 1, "2" = Field 2, "12" = both fields
my $inputMPEGfile = "~";
my @inputCCfile = ("~", "~");
my $anything = "~";
my $MPEGoutput = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (s/-c//) {
    $formatcode = $_;
    next;
  }
  if (s/-12//) {
    $insert = "12";
    $inputCCfile[0] = $_;
    $inputCCfile[1] = $_;
    next;
  }
  if (s/-1//) {
    $insert = "1".$insert;
    $inputCCfile[0] = $_;
    next;
  }
  if (s/-2//) {
    $insert = $insert."2";
    $inputCCfile[1] = $_;
    next;
  }
  if (s/-o//) {
    $captionstart = $_;
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
  if ($inputMPEGfile eq "~") {
    $inputMPEGfile = $_;
    next;
  }
  $MPEGoutput = $_;
}

# print ("\nFormat Code: ", $formatcode);
# print ("\nInsert: ", $insert);
# print ("\nCC File 1: ", $inputCCfile[0]);
# print ("\nCC File 2: ", $inputCCfile[1]);
# print ("\nStart Time: ", $captionstart);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nMPEG Input: ", $inputMPEGfile);
# print ("\nMPEG Output: ", $MPEGoutput);

if ($anything eq "~") {
  usage();
  exit;
}

if ($formatcode ne "~") {
  $CCformat = 0;
}
if ($formatcode eq "DVD") {
  $CCformat = 1;
}
if ($formatcode eq "RTV4") {
  $CCformat = 11;
}
if ($formatcode eq "RTV5") {
  $CCformat = 12;
}
if ($CCformat == 0) {
  die "Unknown caption format, stopped";
}

if ($inputMPEGfile eq "~") {
  usage();
  die "No input MPEG file, stopped";
}

if ($insert eq "") {
  usage();
  die "Need at least one CC file, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($captionstart =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for start offset, stopped";
}

my $filebase;
my $extension;
if ($MPEGoutput eq "~") {
  $inputMPEGfile =~ m/(.+)\.(\w+)$/; # remove extension
  ($filebase, $extension) = ($1, $2);
  if ($filebase eq "") {
    $filebase = $inputMPEGfile;
  }
  $MPEGoutput = $filebase."_out.".$extension;
}

# If CC files are in SCC or DVD raw formats, convert to broadcast raw
my $data;
my $i;
my $keepReading;
for ($i = substr($insert, 0, 1)-1; $i <= (substr($insert, -1, 1)-1); $i++) {
  my $filename = $inputCCfile[$i];
  sysopen (RH, $filename, O_RDONLY) or die "Unable to read from $filename: $!, stopped";
  binmode RH;
  sysread (RH, $data, 4);
  if ($data eq "\xff\xff\xff\xff") {  # already in broadcast raw format
    $CCFileFormat[$i] = 1;
  }
  if ($data eq "\x43\x43\x01\xf8") {  # DVD raw format, potentially with both fields
    $CCFileFormat[$i] = 2;
    $filename =~ m/(.+)\.(\w+)$/; # remove extension
    ($filebase, $extension) = ($1, $2);
    if ($filebase eq "") {
      $filebase = $filename;
    }
    $outfilename = $filebase."_b".$i.".".$extension;
    open (WH, ">".$outfilename) or die "Unable to create temp file $outfilename: $!, stopped";
    binmode WH;
    my $match;
    if ($i == 1) {
      $match = "\xff";
    } else {
      $match = "\xfe";
    }
    $keepReading = 1;  # flag for end of file
    READLOOP1: while ($keepReading) {
      $data = "";
      # skip past header and data for other field
      while ($data ne $match) {
        if ((sysread RH, $data, 1) != 1) {
          $keepReading = 0;
          last READLOOP1;
        }
      }
      # copy out data
      if (sysread RH, $data, 2) {
        print WH $data;
      } else {
        $keepReading = 0;
        last READLOOP1;
      }
    }
    close WH;
    $inputCCfile[$i] = $outfilename;
  }
  if ($data eq "Scen") { # SCC format (taken from scc2raw code)
    $CCFileFormat[$i] = 3;
    close RH; # need to close as binary and re-open as text
    open (RH, $filename) or die "Unable to read from $filename: $!, stopped";
    my $header = <RH>;
    chomp $header;
    (my $formattype, my $formatversion) = split (/ /, $header);
    if ($formattype ne "Scenarist_SCC") {
      usage();
      die "$filename is not in raw or SCC format, stopped";
    }
    $filename =~ m/(.+)\.(\w+)$/; # remove extension
    ($filebase, $extension) = ($1, $2);
    if ($filebase eq "") {
      $filebase = $filename;
    }
    $outfilename = $filebase."_b".$i.".bin";
    open (WH, ">".$outfilename) or die "Unable to create temp file $outfilename: $!, stopped";
    binmode WH;
    print WH "\xff\xff\xff\xff";  # broadcast raw file header
    $keepReading = 1;  # flag to tell when file is finished
    my $counter = -1;     # counter to step through each input line
    my @bytePairs = ();   # contents of each line
    my $readnextline = 1; # flag to tell when to read next line of SCC file
    my $datatext = "";    # hex data read from each line
    my $databytes = "";   # binary data to output
    my $currentframe = -1;
    my $lastframe = $currentframe - 1;
    READLOOP2: while ($keepReading) {
      $currentframe++;
      $counter++;

      $datatext = "8080";
      # read next line if necessary
      if (($readnextline) && ($keepReading)) {
        if (!defined($_ = <RH>)) {
          close RH;
          $keepReading = 0;
        } else {
          #print $_."\n";
          chomp;
          if ($_ eq "") {
            if (!defined($_ = <RH>)) {
              close RH;
              $keepReading = 0;
            }
            #print $_."\n";

          }
        }
      }
      # parse next line
      if (($readnextline) && ($keepReading)) {
        $readnextline = 0;
        m/(..:..:..[:;]..)(\s)(.+)/; # split into timecode and rest of line
        (my $timecode, my $skip, my $line) = ($1, $2, $3);
        my $nextframe = frame($timecode);
        if ($nextframe < $currentframe) {
          die "Timecode $timecode in $filename is out of order in line $., stopped";
        }
        # countdown to when data will line up with $currentframe
        $counter = - int($nextframe - $currentframe + 0.5);
        chomp $line;
        @bytePairs = split(' ', $line);
      }
      # step through line
      if (($keepReading) && ($counter > -1)) {
        $datatext = @bytePairs[$counter];
        if (($counter + 1) > $#bytePairs) {
          $counter = -1;
          $readnextline = 1;
        }
      }
      
      # convert text to bytes
      $datatext =~ m/(..)(..)/;
      $hi = hex $1;
      $lo = hex $2;
      $databytes = chr($hi).chr($lo);
      # output converted bytes
      print WH $databytes;
    }
    close WH;
    $inputCCfile[$i] = $outfilename;
  }
  close RH;
  if ($CCFileFormat[$i] == 0) {
    usage();
    die "Closed captions must be in raw or SCC format, stopped";
  }
}

sysopen (RHM, $inputMPEGfile, O_RDONLY) or die "Unable to read from $inputMPEGfile: $!, stopped";
binmode RHM;
open (WHM, ">".$MPEGoutput) or die "Unable to write to file $MPEGoutput: $!, stopped";
binmode WHM;
# flags for both when files are open and not EOF
my $readField1 = 0;
my $readField2 = 0;
if ($insert =~ /1/) {
  sysopen (RH1, $inputCCfile[0], O_RDONLY) or die "Unable to read from $inputCCfile[0]: $!, stopped";
  binmode RH1;
  sysread RH1, $data, 4;  # skip header
  $readField1 = 1;
}
if ($insert =~ /2/) {
  sysopen (RH2, $inputCCfile[1], O_RDONLY) or die "Unable to read from $inputCCfile[1]: $!, stopped";
  binmode RH2;
  sysread RH2, $data, 4;  # skip header
  $readField2 = 1;
}

# try to get frame rate from Sequence Header
$buffer = "";
if (findpacket("b3") == -1) {
  $buffer = "";
  $total = 0;
  sysseek RHM, 0, SEEK_SET;
} else {
  $buffer = "";
  sysread RHM, $data, 3; # skip horizontal and vertical size
  sysread RHM, $data, 1; # aspect ratio and frame rate
  my $fpsCode = $data % 0x10;
  if ($fpsCode == 1) { $fps = 24000 / 1001; }
  if ($fpsCode == 2) { $fps = 24; }
  if ($fpsCode == 3) { $fps = 25; }
  if ($fpsCode == 4) { $fps = 30000 / 1001; }
  if ($fpsCode == 5) { $fps = 30; }
  if ($fpsCode == 6) { $fps = 50; }
  if ($fpsCode == 7) { $fps = 60000 / 1001; }
  if ($fpsCode == 8) { $fps = 60; }
}

# first GOP header to get start timecode
if (findpacket("b8") == -1) {
  $buffer = "";
  if ($insert =~ /2/) {
    close RH2;
  }
  if ($insert =~ /1/) {
    close RH1;
  }
  close WHM;
  close RHM;
  exit;
}
my $GOPheaderPosition = $total;
$buffer = "";
sysread RHM, $data, 4;
my $hh, $mm, $ss, ff;
$data =~ m/(.)(.)(.)(.)/;
my @bytes = (ord $1, ord $2, ord $3, ord $4);
if ($bytes[0] > 0x7f) {
  $drop = 1;
  $bytes[0] -= 0x80;
}
$hh = int($bytes[0] / 0x04);
$mm = ($bytes[0] % 0x04) * 0x10 + int($bytes[1] / 0x10);
# there's a marker bit in here being skipped
$ss = ($bytes[1] % 0x08) * 0x08 + int($bytes[2] / 0x20);
$ff = ($bytes[2] % 0x20) * 0x02 + int($bytes[3] / 0x80);
# $bytes[3] also contains Closed GOP and Broken GOP flags
my $frameDivider = ":";
if ($drop) {
  $frameDivider = ";";
}
$videostart = sprintf("%02d:%02d:%02d%s%02d", $hh, $mm, $ss, $frameDivider, $ff);

# reset to start of video file
$buffer = "";
$total = 0;
sysseek RHM, 0, SEEK_SET;

my $captionstartframe = frame($captionstart);
my $videostartframe = frame($videostart);
$offset = $captionstartframe - $videostartframe;
#print $offset;
# if there are frames before the first GOP header, adjust $videostart
while ($total < $GOPheaderPosition) {
  if (findpacket("00") == -1) {
    $buffer = "";
    if ($insert =~ /2/) {
      close RH2;
    }
    if ($insert =~ /1/) {
      close RH1;
    }
    close WHM;
    close RHM;
    exit;
  }
  if ($total < $GOPheaderPosition) {
    $offset += 1;
  }
}

# reset to start of video file (again)
$buffer = "";
$total = 0;
sysseek RHM, 0, SEEK_SET;

#print $offset;
# a negative offset means to skip part of the caption files
if ($offset < 0) {
  for ($i = $offset; $i < 0; $i++) {
    if ($readField1) {
      if (sysread(RH1, $data, 2) == 0) {
        $readField1 = 0;
      }
    }
    if ($readField2) {
      if (sysread(RH2, $data, 2) == 0) {
        $readField2 = 0;
      }
    }
  }
}

$keepReading = 1; # flag for end of file
# GOP-based formats
if ($CCformat < 10) {
  my $framecount = 0;
  GOPLOOP: while ($keepReading) {
    # closed caption packet goes right here
    # count how many frames are in GOP
    $framecount = findpacket("b8");
    if ($framecount == -1) {
      print WHM $buffer;
      last GOPLOOP;
    }
    if ($framecount == 0) {
      next GOPLOOP;
    }
    # a positive offset means to skip part of the video file
    if ($offset > 0) {
      $offset -= $framecount;
    } else {
      # User Data header
      print WHM "\x00\x00\x01\xb2";
      if ($CCformat == 1) { # DVD format
        # DVD Closed Caption header
        print WHM "\x43\x43\x01\xf8";
        # DVD Closed Caption attribute
        my $attributeCode = ($framecount * 2) + 0x80;
        print WHM chr($attributeCode);
        # DVD Closed Caption packets
        for ($i = 0; $i < $framecount; $i++) {
          if ($insert =~ /1/) {
            if ($readField1) {
              if (sysread(RH1, $data, 2) == 0) {
                $readField1 = 0;
                $data = "\x80\x80";
              }
            } else {
              $data = "\x80\x80";
            }
          } else {
            $data = "\x00\x00";
          }
          print WHM "\xff".$data;
          if ($insert =~ /2/) {
            if ($readField2) {
              if (sysread(RH2, $data, 2) == 0) {
                $readField2 = 0;
                $data = "\x80\x80";
              }
            } else {
              $data = "\x80\x80";
            }
          } else {
            $data = "\x00\x00";
          }
          print WHM "\xfe".$data;
        }
      }
    }
    # buffer ends with \x00\x00\x01\xb8, which needs to be after the
    #  CC packet
    print WHM substr($buffer, 0, -4);
    $buffer = "\x00\x00\x01\xb8";
  }

# frame-based formats
} else {
  FRAMELOOP: while ($keepReading) {
    if (findpacket("00") == -1) {
      print WHM $buffer;
      last FRAMELOOP;
    }
    # a positive offset means to skip part of the video file
    if ($offset > 0) {
      $offset -= 1;
      # buffer ends with \x00\x00\x01\x00, which needs to be after the
      #  CC packet
      print WHM substr($buffer, 0, -4);
      $buffer = "\x00\x00\x01\x00";
    } else {
      if ($CCformat == 11) { # ReplayTV 4000 series
        # packet goes between picture (00) and 1st slice (01)
        print WHM $buffer;
        $buffer = "";
        if (findpacket("01") == -1) {
          print WHM $buffer;
          last FRAMELOOP;
        }
        # buffer ends with \x00\x00\x01\x01, which needs to be after the
        #  CC packet
        print WHM substr($buffer, 0, -4);
        $buffer = "\x00\x00\x01\x01";
        # User Data header
        print WHM "\x00\x00\x01\xb2";
        print WHM "\xbb\x02";
        if ($insert =~ /2/) {
          if ($readField2) {
            if (sysread(RH2, $data, 2) == 0) {
              $readField2 = 0;
              $data = "\x80\x80";
            }
          } else {
            $data = "\x80\x80";
          }
        } else {
          $data = "\x00\x00";
        }
        print WHM $data;
        print WHM "\xcc\x02";
        if ($insert =~ /1/) {
          if ($readField1) {
            if (sysread(RH1, $data, 2) == 0) {
              $readField1 = 0;
              $data = "\x80\x80";
            }
          } else {
            $data = "\x80\x80";
          }
        } else {
          $data = "\x00\x00";
        }
        print WHM $data;
        # buffer needs to be dumped
        print WHM $buffer;
        $buffer = "";
      }
      if ($CCformat == 12) { # ReplayTV 5000 series
        # packet goes between picture (00) and 1st slice (01)
        print WHM $buffer;
        $buffer = "";
        if (findpacket("01") == -1) {
          print WHM $buffer;
          last FRAMELOOP;
        }
        # buffer ends with \x00\x00\x01\x01, which needs to be after the
        #  CC packet
        print WHM substr($buffer, 0, -4);
        $buffer = "\x00\x00\x01\x01";
        # User Data header
        print WHM "\x00\x00\x01\xb2";
        print WHM "\x99\x02";
        if ($insert =~ /1/) {
          if ($readField1) {
            if (sysread(RH1, $data, 2) == 0) {
              $readField1 = 0;
              $data = "\x80\x80";
            }
          } else {
            $data = "\x80\x80";
          }
        } else {
          $data = "\x00\x00";
        }
        print WHM $data;
        print WHM "\xaa\x02";
        if ($insert =~ /2/) {
          if ($readField2) {
            if (sysread(RH2, $data, 2) == 0) {
              $readField2 = 0;
              $data = "\x80\x80";
            }
          } else {
            $data = "\x80\x80";
          }
        } else {
          $data = "\x00\x00";
        }
        print WHM $data;
        print WHM "\x00\x00";
        # buffer needs to be dumped
        print WHM $buffer;
        $buffer = "";
      }
    }
  }
}

if ($insert =~ /2/) {
  close RH2;
}
if ($insert =~ /1/) {
  close RH1;
}
close WHM;
close RHM;
exit;

sub usage {
  print "\nCC_MUX Version 1.0\n";
  print "  Muxes closed captions in raw or SCC formats into DVD and DVB MPEG files.\n";
  print "    (For DVB, ReplayTV 4000 and 5000 are supported.)\n\n";
  print "  Syntax: CC_MUX -cDVD -1fld1.scc -2fld2.bin -o-00:00:01:00 -f24 infile.m2v\n";
  print "    -c: Mux caption format: DVD (DEFAULT), RTV4 (ReplayTV 4000 series)\n";
  print "         or RTV5 (ReplayTV 5000 series)\n";
  print "    -1, -2, -12: Input file(s) containing Field 1 (Closed Caption) data, \n";
  print "         Field 2 (XDS) data, or both\n";
  print "    -o (OPTIONAL): Offset to apply to captions relative to video,\n";
  print "         in HH:MM:SS:FF format (DEFAULT: 00:00:00:00)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT from MPEG if available; else 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT from MPEG if available; else n)\n";
  print "    infile.m2v: video elementary stream MPEG file to mux captions into\n";
  print "    outfile.m2v (OPTIONAL): name of muxed VES MPEG file to create\n";
  print "      (assumed to be basename of infile plus _out. and infile's extension)\n\n";
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

sub findpacket {
  my $startcode = shift(@_);
  # uses global variables $buffer, $total
  $startcode = hex $startcode;
  $startcode = chr($startcode);
  $startcode = "\x00\x00\x01".$startcode;
  #print $startcode;
  my $picturecode = "\x00\x00\x01\x00";
  my $picturecount = 0;
  my $header = "\xff\xff\xff\xff";
  my $data = "";
  FINDSTART: while (sysread RHM, $data, 1) {
    $buffer = $buffer.$data;
    $header = substr($header, 1, 3).$data;
    $total++;
    if ($total % 0x100000 == 0) {
      print ".";
    }
  
    # printf "%02x.", ord $data;
    if ($header eq $picturecode) {
      $picturecounter++;
    }
    if ($header eq $startcode) {
      return picturecounter;
    }
    next FINDSTART;
  }
  return -1;
}
