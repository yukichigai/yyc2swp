# pas2scc.pl: Convert CCWriter (DOS) into Scenarist Closed Caption format
# Run file without arguments to see usage
#
# Version 1.0
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 1.0 initial release
#
# Note that this program makes a few assumptions to determine caption
#   positioning.


sub processCaption;
sub usage;
sub CCWriterFrame;
sub SccFrame;
sub SccTimecode;
sub oddParity;

# global variables
# CCWriter Positioning codes:
#  mbc = bottom center (default)
#  mtc = top center
#  BL  = bottom left
#  BR  = bottom right
#  TL  = top left
#  TR  = top right
#  xmc = center of line x
#  xmy = line x, column y
$CCWriterPositioning = "mbc";
$channel = 1; # can be 1 or 2

# initial variables
my $offsettimecode = "00:00:00F00";
my $fps = 30000/1001; # NTSC framerate
my $drop = 0; # assume non-drop
my $input = "~"; # place-holder for no input file yet
my $output = "~"; # place-holder for no output file yet
my $anything = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
  if (s/-2//) {
    $channel = 2;
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

# print ("Offset: ", $offsettimecode);
# print ("\nFPS: ", $fps);
# print ("\nDrop: ", $drop);
# print ("\nInput: ", $input);
# print ("\nOutput: ", $output);

if ($anything eq "~") {
  usage();
  exit;
}

if ($input eq "~") {
  usage();
  die "No input file, stopped";
}

if ($output eq "~") {
  if (($input =~ m/(.*)(\.pas)$/i)) {
    $output = $1.".scc";
  }
}
if ($output eq "~") {
  usage();
  die "Input file must have .pas extension for default output to work, stopped";
}

if ($input eq $output) {
  die "Input and output files cannot be the same, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($offsettimecode =~ m/\d\d:\d\d:\d\d[Ff]\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

open (RH, $input) or die "Unable to read from file: $!";
open (WH, ">".$output) or die "Unable to write to file: $!";
print WH "Scenarist_SCC V1.0\n\n";
my $offset = CCWriterFrame($offsettimecode);

# read loop
# when screen should be cleared prior to caption
#  (same as endFrame of previous caption)
# offset + 2 because clear command is 2 frames long
my $clearFrame = $offset + 2;
my $startFrame = $offset;
my $endFrame = $offset;
my $lastFrame = $offset - 1; # last frame of last caption, to prevent overlap
my $CCWriterLineMode = 0; # this is 0 for a blank line, 1 - 7 for up to four lines of captions
                          #  with formatting in-between, or 10 for timecode line
                          #  (comments are skipped, so they don't get a value)
my $CCWriterLines = ''; # this will be an entire caption to convert, including positioning
                        #  and formatting, with newlines inserted
LINELOOP: while (<RH>) {
  if ($_ eq "\n") { # if line is blank, process caption (if any has been received)
    $CCWriterLineMode = 0;
    next LINELOOP;
  }
  chomp;
  if (/^;/) { # if line starts with a semicolon, it's a comment and can be ignored
    next LINELOOP;
  }
  if (/^\+/) { # if line starts with a plus, it's the start and end timecodes
    $CCWriterLineMode = 10;
    @elements = split(/\s+/, $_);
    $startFrame = CCWriterFrame($elements[1]) + $offset;
    if ($endFrame == -1) {
      $clearFrame = $startFrame + 2;
    } else {
      $clearFrame = $endFrame + 2;
    }
    if ($#elements > 1) {
      $endFrame = CCWriterFrame($elements[2]) + $offset;
    } else {
      $endFrame = -1;
    }
    #print "/".$startFrame."/".$endFrame."/";
    # process line when you have the timecodes
    if ($CCWriterLines ne '') {
      #print "\n".$CCWriterLines."\n";
      my $LineAndLastFrame = processCaption($CCWriterLines, $clearFrame,
                                            $startFrame, $lastFrame);
      # use "," character to separate two outputs
      (my $SccLines, $lastFrame) = split(/,/, $LineAndLastFrame);
      # print "\n".$SccLines;
      print WH $SccLines;
      $CCWriterLines = "";
    }
    next LINELOOP;
  }  
  if ($CCWriterLineMode < 10) { # we must be in caption: up to 8 lines allowed (caption + positioning)
    $CCWriterLineMode++;
    if ($CCWriterLineMode == 1) {
      $CCWriterLines = $_;
    } else {
      $CCWriterLines = $CCWriterLines."\n".$_; # insert newline between two lines
    }
    next LINELOOP;
  }
  die "CCWriter caption on line $. is more than 8 lines long, stopped";
}
# clear code for last caption
if ($clearFrame - $lastFrame > 2) {
  $SccLines = SccTimecode($clearFrame - 2);
} else {
  $SccLines = SccTimecode($lastFrame + 2);
}
if ($channel == 1) {
  $SccLines = $SccLines."\t942c 942c\n";
} else {
  $SccLines = $SccLines."\t1c2c 1c2c\n";
}
print WH $SccLines;
close WH;
close RH;
exit;


sub processCaption {
  # uses global variables $CCWriterPositioning and $channel
  my $CCWriterLines = shift(@_);
  my $clearFrame = shift(@_);
  my $startFrame = shift(@_);
  my $lastFrame = shift(@_);
  my $actualStartFrame = $clearFrame - 3;
  my $SccClearLine = '';
  my @SccList = ();
  my $SccLineMode = 1; # this is 1 for a line to be displayed or 0 for a clear screen line
  my $counter = 0; # used to step through various arrays
  
  my $i, $j;
  my @CCWLines = split(/\n/, $CCWriterLines);
  # horizontal alignment for each caption line
  #  ("L0"    = left-aligned to column 0,
  #   "R31"   = right-aligned to column 31,
  #   "C14.5" = center-aligned to column 14.5)
  my @HAlign = ("") x 4;
  # vertical alignment for each caption line
  #  ("T1"    = top-aligned to row 1,
  #   "B15"   = bottom-aligned to row 15,
  #   "M7"    = middle-aligned to row 7 [not used])
  my @VAlign = ("") x 4;
  my @PAC = ("") x 4;      # coordinates for start of each caption line
  my @SccText = ("") x 4;  # contents of each caption line
  my @SccWidth = (0) x 4;  # width of each caption line, in characters
  my $SccLine = -1;        # counter for each caption line
  
  LINE: for ($i = 0; $i <= $#CCWLines; $i++) {
    #print "\n".$i.$CCWLines[$i];
    $SccLine++;
    # evaluate positioning
    if (substr($CCWLines[$i], 0, 1) eq ",") {
      $SccLine--;
      $CCWriterPositioning = substr($CCWLines[$i], 1);
      next LINE;
    }
    if ($CCWriterPositioning =~ /m/) {
      my @elements = split(/m/, $CCWriterPositioning);
      if ($elements[0] eq "") {
        $elements[1] =~ /(.)(.)/;
        my @subelements = ($1, $2);
        if ($subelements[0] eq "t") { $VAlign[$SccLine] = "T1"; }
        if ($subelements[0] eq "b") { $VAlign[$SccLine] = "B15"; }
        if ($subelements[1] eq "c") { $HAlign[$SccLine] = "C14.5" }
      } else {
        $VAlign[$SccLine] = "T".$elements[0];
        if ($elements[1] eq "c") { $HAlign[$SccLine] = "C14.5" }
      }
    } else {
      if ($CCWriterPositioning eq "TL") { $HAlign[$SccLine] = "L0"; $VAlign[$SccLine] = "T1"; }
      if ($CCWriterPositioning eq "TR") { $HAlign[$SccLine] = "R31"; $VAlign[$SccLine] = "T1"; }
      if ($CCWriterPositioning eq "BL") { $HAlign[$SccLine] = "L0"; $VAlign[$SccLine] = "B15"; }
      if ($CCWriterPositioning eq "BR") { $HAlign[$SccLine] = "R31"; $VAlign[$SccLine] = "B15"; }
    }
    if ($HAlign[$SccLine] eq "") { $HAlign[$SccLine] = "C14.5"; }
    if ($VAlign[$SccLine] eq "") { $VAlign[$SccLine] = "B15"; }
    
    # evaluate line
    # clear screen code, ||
    if ($CCWLines[$i] eq "||") {
      next LINE;
    }
    my $italics = 0; # italics flag
    #print "\n".$SccLine;
    CHAR: for ($j = 0; $j < length($CCWLines[$i]); $j++) {
      my $character = substr($CCWLines[$i], $j, 1);
      #print $character;
      # italics code, \
      if ($character eq "\\") {
        $italics = 1 - $italics;
        my $italicsCode = "";
        if ($italics == 1) {
          $italicsCode = ($channel == 1) ? "\x11\x2e\x11\x2e" : "\x19\x2e\x19\x2e";
        } else { # use code for plain white text to turn off italics
          $italicsCode = ($channel == 1) ? "\x11\x20\x11\x20" : "\x19\x20\x19\x20";
        }
        $SccText[$SccLine] = $SccText[$SccLine].$italicsCode;
        next CHAR;
      }
      # musical note, *
      if ($character =~ /\*/) {
        $character = ($channel == 1) ? "\x11\x37\x11\x37" : "\x19\x37\x19\x37";
      }
      # this program currently skips extended characters; among others, the following characters
      #  are not handled: ^, _, `, {, }
      if ($character =~ /[\^\_\`\{\}]/) {
        print "\nIllegal character \'$character\' encountered on line $., skipping.";
        next CHAR;
      }
      # most characters map directly from ASCII to CC character set;
      #  the following handles the exceptions
      $_ = $character;
      SWITCH: {
        /á/ && do {$_ = "\x2a"; last SWITCH; };
        /é/ && do {$_ = "\x5c"; last SWITCH; };
        /í/ && do {$_ = "\x5e"; last SWITCH; };
        /ó/ && do {$_ = "\x5f"; last SWITCH; };
        /ú/ && do {$_ = "\x60"; last SWITCH; };
        /ç/ && do {$_ = "\x7b"; last SWITCH; };
        /÷/ && do {$_ = "\x7c"; last SWITCH; };
        /Ñ/ && do {$_ = "\x7d"; last SWITCH; };
        /ñ/ && do {$_ = "\x7e"; last SWITCH; };
        # no coverage for block character, \x7f
        # special characters
        /®/ && do {$_ = ($channel == 1) ? "\x11\x30\x11\x30" : "\x19\x30\x19\x30"; last SWITCH; };
        /°/ && do {$_ = ($channel == 1) ? "\x11\x31\x11\x31" : "\x19\x31\x19\x31"; last SWITCH; };
        /½/ && do {$_ = ($channel == 1) ? "\x11\x32\x11\x32" : "\x19\x32\x19\x32"; last SWITCH; };
        /¿/ && do {$_ = ($channel == 1) ? "\x11\x33\x11\x33" : "\x19\x33\x19\x33"; last SWITCH; };
        /™/ && do {$_ = ($channel == 1) ? "\x11\x34\x11\x34" : "\x19\x34\x19\x34"; last SWITCH; };
        /¢/ && do {$_ = ($channel == 1) ? "\x11\x35\x11\x35" : "\x19\x35\x19\x35"; last SWITCH; };
        /£/ && do {$_ = ($channel == 1) ? "\x11\x36\x11\x36" : "\x19\x36\x19\x36"; last SWITCH; };
        # musical note covered above
        /à/ && do {$_ = ($channel == 1) ? "\x11\x38\x11\x38" : "\x19\x38\x19\x38"; last SWITCH; };
        # no coverage for transparent space
        /è/ && do {$_ = ($channel == 1) ? "\x11\x3a\x11\x3a" : "\x19\x3a\x19\x3a"; last SWITCH; };
        /â/ && do {$_ = ($channel == 1) ? "\x11\x3b\x11\x3b" : "\x19\x3b\x19\x3b"; last SWITCH; };
        /ê/ && do {$_ = ($channel == 1) ? "\x11\x3c\x11\x3c" : "\x19\x3c\x19\x3c"; last SWITCH; };
        /î/ && do {$_ = ($channel == 1) ? "\x11\x3d\x11\x3d" : "\x19\x3d\x19\x3d"; last SWITCH; };
        /ô/ && do {$_ = ($channel == 1) ? "\x11\x3e\x11\x3e" : "\x19\x3e\x19\x3e"; last SWITCH; };
        /û/ && do {$_ = ($channel == 1) ? "\x11\x3f\x11\x3f" : "\x19\x3f\x19\x3f"; last SWITCH; };
      }
      if (($_ eq $character) && (ord($character) > 0x7f)) {
        print "\nIllegal character \'$character\' encountered on line $., skipping.";
        next CHAR;
      }
      $character = $_;
      #print $character;
      $SccText[$SccLine] = $SccText[$SccLine].$character;
      $SccWidth[$SccLine]++;
    }
  }
  if ($SccLine > 3) {
    print "\nCaption at line $. is over four lines long and will be truncated.";
    $SccLine = 3;
  }
  #print "\n".$SccText[0];
  # Preamble Access Code
  # caption columns are two part: multiple of 4, and what's left over
  my @rowCode = ();
  if ($channel == 1) {
    @rowCode = ("", "\x11", "\x11", "\x12", "\x12", "\x15", "\x15", "\x16", "\x16",
                    "\x17", "\x17", "\x10", "\x13", "\x13", "\x14", "\x14");
  } else {
    @rowCode = ("", "\x19", "\x19", "\x1a", "\x1a", "\x1d", "\x1d", "\x1e", "\x1e",
                    "\x1f", "\x1f", "\x18", "\x1b", "\x1b", "\x1c", "\x1c");
  }
  # there are two ways to turn column into bottom byte, based on row
  my @evenColumnCodeA = (0x40, 0x52, 0x54, 0x56, 0x58, 0x5a, 0x5c, 0x5e);
  my @evenColumnCodeB = (0x60, 0x72, 0x74, 0x76, 0x78, 0x7a, 0x7c, 0x7e);
  my @stateFactor = (0, 1, 14, 15); # what to add to bottom byte to get various states
                                    #  (plain, underline, italics, underlined italics)
  my @columnSelect = (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0);

  my $topByte = "";
  my $bottomByte = "";
  my @row = (-1) x $SccLine;
  my @col = (-1) x $SccLine;
  my $VLimit, $HLimit;
  my $lastVLimit = 0;

  # determine row for bottom alignment
  for ($i = $SccLine; $i >= 0; $i--) {
    if ($VAlign[$i] =~ /B/) {
      $lastVLimit = $VLimit;
      $VLimit = substr($VAlign[$i], 1);
      if ($VLimit == $lastVLimit) {
        $row[$i] = $row[$i-1] - 1;
      } else {
        $row[$i] = int($VLimit);
      }
    }
    if ($row[$i] < 1) { $row[$i] = 1; }
  }
  # determine row for top alignment (and column and codes for all)
  for ($i = 0; $i <= $SccLine; $i++) {
    if ($VAlign[$i] =~ /T/) {
      $lastVLimit = $VLimit;
      $VLimit = substr($VAlign[$i], 1);
      if ($VLimit == $lastVLimit) {
        $row[$i] = $row[$i-1] + 1;
      } else {
        $row[$i] = $VLimit;
      }
    }
    if ($row[$i] > 15) { $row[$i] = 15; }

    $HLimit = substr($HAlign[$i], 1);
    if ($HAlign[$i] =~ /L/) {
      if (int($HLimit + $SccWidth[$i]) > 31) {
        $col[$i] = int(31 - $SccWidth[$i]);
      } else {
        $col[$i] = $HLimit;
      }
    }
    if ($HAlign[$i] =~ /R/) {
      if (int($HLimit - $SccWidth[$i]) < 0) {
        $col[$i] = 0;
      } else {
        $col[$i] = $HLimit - $SccWidth[$i];
      }
    }
    if ($HAlign[$i] =~ /C/) {
      $col[$i] = -1;
      if (int($HLimit - ($SccWidth[$i] / 2)) < 0) {
        $col[$i] = int(($SccWidth[$i] / 2));
      }
      if (int($HLimit + ($SccWidth[$i] / 2)) > 31) {
        $col[$i] = int(31 - ($SccWidth[$i] / 2));
      }
      if ($col[$i] == -1) {
        $col[$i] = int($HLimit - ($SccWidth[$i] / 2));
      }
    }
    
    $topByte = $rowCode[$row[$i]];
    my $evenColumn = int($col[$i] / 4);
    #print "\n".$col[$i];
    my $state = 0; # was $underline
    # for column 0 only, you can merge the first italics formatting into the PAC
    if ($evenColumn == 0) {
      if (substr($SccText[$i], 0, 2) =~ /[\x11\x19]\x21/) {
        $state += 2;
        $SccText[$i] = substr($SccText[$i], 4);
      }
    }
    if ($columnSelect[$row[$i]]) {
      $bottomByte = chr($evenColumnCodeA[$evenColumn] + $stateFactor[$state]);
    } else {
      $bottomByte = chr($evenColumnCodeB[$evenColumn] + $stateFactor[$state]);
    }
    $PAC[$i] = $topByte.$bottomByte.$topByte.$bottomByte;
    # tab offset
    my $oddColumn = $col[$i] % 4;
    if ($oddColumn > 0) {
      $topByte = ($channel == 1) ? "\x17" : "\x1f";
      $bottomByte = chr(0x20 + $oddColumn);
      $PAC[$i] = $PAC[$i].$topByte.$bottomByte.$topByte.$bottomByte;
    }
  }
  #print $PAC[0];
  # if first caption is "||", then only a clear screen is wanted,
  #  so skip most of the following
  $counter = 0;
  if ($SccText[0] ne "") {
    # start building display caption line
    $SccList[0] = ($channel == 1)?0x14:0x1c; # command:
    $SccList[1] = 0x2e;                      # ENM (Erase Non-Displayed Memory)
    $SccList[2] = $SccList[0];               # (all commands are in pairs)
    $SccList[3] = $SccList[1];
    $SccList[4] = ($channel == 1)?0x14:0x1c; # command:
    $SccList[5] = 0x20;                      # RCL (Resume Caption Loading)
    $SccList[6] = $SccList[4];
    $SccList[7] = $SccList[5];
    $counter = 8;
    for ($i = 0; $i <= $SccLine; $i++) {
      # all codes (< 0x20) must start on a counter multiple of 2
      # copy @PAC
      for ($j = 0; $j < length($PAC[$i]); $j++) {
        $SccList[$counter++] = ord(substr($PAC[$i], $j, 1));
      }
      # copy @SccText
      for ($j = 0; $j < length($SccText[$i]); $j++) {
        my $code = ord(substr($SccText[$i], $j, 1));
        if (($code < 0x20) && (($counter % 2) == 1)) {
          $SccList[$counter++] = 0;
        }
        $SccList[$counter++] = $code;
      }
      if (($counter % 2) == 1) {
        $SccList[$counter++] = 0;
      }
    }
    $SccList[$counter++] = ($channel == 1)?0x14:0x1c; # command:
    $SccList[$counter++] = 0x2f;                      # EOC (End of Caption)
    $SccList[$counter++] = ($channel == 1)?0x14:0x1c;
    $SccList[$counter++] = 0x2f;
  } else {
    $counter = 0;
  }
  $actualStartFrame = $startFrame - int(($counter + 0.5) / 2);
  # print "$lastFrame, $actualStartFrame\n";
  if ($actualStartFrame < $lastFrame) {
    #print $actualStartFrame.",".$lastFrame.";".$counter;
    $actualStartFrame = $lastFrame + 1;
    print "(Forced to shorten start of caption at line $..)\n";
  }
  # build clear command for *previous* caption
  # The clear screen line is just {EDM}{EDM}, 2 frames long
  # test to see if clear command is outside caption
  if (($counter == 0) || ($actualStartFrame - $clearFrame > 2)) { 
    # "942c" is the odd-Parity version of EDM
    if ($channel == 1) {
      $SccClearLine = SccTimecode($clearFrame - 2)."\t942c 942c\n\n";
    } else {
      $SccClearLine = SccTimecode($clearFrame - 2)."\t1c2c 1c2c\n\n";
    }
  }
  #print $SccClearLine;
  my $displayStartFrame = $actualStartFrame + int(($counter / 2) + 0.5);
  #print SccTimecode($clearFrame).", ".SccTimecode($DisplayStartFrame)."\n";
  if (($clearFrame - $displayStartFrame < 2) &&
   (($clearFrame - $actualStartFrame) > 2)) { # clear command is inside caption
    #print "(Inserting in line $..)\n";
    $SccClearLine = "";
    my $insertPosition = ($clearFrame - $actualStartFrame - 2) * 2;
    my(@temp) = splice(@SccList, $insertPosition);
    $SccList[$insertPosition++] = ($channel == 1)?0x14:0x1c;
    $SccList[$insertPosition++] = 0x2c;                      # EDM (clear command)
    $SccList[$insertPosition++] = ($channel == 1)?0x14:0x1c;
    $SccList[$insertPosition++] = 0x2c;
    push(@SccList, @temp);
    $counter += 4;
    $actualStartFrame -= 2;
  }
  $SccDisplayLine = SccTimecode($actualStartFrame + 2);
  for (my $i = 0; $i < $counter; $i += 2) {
    #print chr($SccList[$i]).chr($SccList[$i+1]);
    $SccDisplayLine = $SccDisplayLine.sprintf(" %02x%02x",
                                oddParity($SccList[$i]), oddParity($SccList[$i+1]));
  }
  $SccDisplayLine =~ m/(..:..:..[:;]..)(\s)(.+)/;
  $SccDisplayLine = $SccClearLine.$1."\t".$3."\n\n";
  #print $SccDisplayLine;
  return $SccDisplayLine.",".$displayStartFrame;
}

sub usage {
  print "\nPAS2SCC Version 1.0\n";
  print "  Converts CCWriter (DOS) file to Scenarist inport format.\n\n";
  print "  Syntax: PAS2SCC -2 -o01:00:00F00 -td infile.pas outfile.scc\n";
  print "    -2 (OPTIONAL): Write as Channel 2 captions\n";
  print "         (DEFAULT is to write as Channel 1 captions)\n";
  print "    -o (OPTIONAL): Offset to apply to CCWriter timecodes, in hh:mm:ssFff format\n";
  print "         (DEFAULT: 00:00:00F00 - negative values are permitted)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    Outfile argument is optional and is assumed to be infile.scc\n";
  print "      (input file in this case must have .pas extension)\n";
  print "    Outfile will be overwritten if it exists\n\n";
}

sub CCWriterFrame {
  my $timecode = shift(@_);
  my $hh = 0;
  # drop/non-drop requires that minutes be split into 10-minute intervals
  my $dm = 0; # "deci-minutes"
  my $sm = 0; # single minutes
  my $ss = 0;
  my $ff = 0;
  my $signmultiplier = +1;
  if (substr($timecode, 0, 1) eq '-') {
    $signmultiplier = -1;
    $timecode = substr $timecode, 1, 12;
  }
  # CCWriter timecodes use "F" to separate seconds from frames
  $timecode =~ m/(\d\d):(\d)(\d):(\d\d)[Ff](\d\d)/;
  ($hh, $dm, $sm, $ss, $ff) = ($1, $2, $3, $4, $5);
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

sub SccFrame {
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

sub SccTimecode {
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

# subroutine to get odd-parity version of a number (individual bits add up to an odd number)
sub oddParity {
  my @odd = (0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 
             0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0);
  my $num = shift(@_);
  if (not $odd[$num]) {
    $num += 128;
  }
  return $num;
}
