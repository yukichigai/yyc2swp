# subrip2scc.pl: Convert Subrip subtitle format to Scenarist Closed Caption format
# Run file without arguments to see usage
#
# Version 2.9
# McPoodle (mcpoodle43@yahoo.com)
#
# Version History
# 2.0 initial release (to keep in sync with other parts of SCC_TOOLS package)
# 2.1 finally figured out drop vs non-drop (changing frame and timecodeof functions)
#       and correctly parsing and outputting non-drop timecodes,
#     added -td and -tn parameters
# 2.2 fixed line numbering (was 1 row too high for bottom rows),
#     fixed line break when space at position 32,
#     made error message for 3-line subtitle clearer
# 2.3 removed 2-line rule for SubRip subtitles (made it a 4-line rule)
# 2.6 corrected drop/non-drop calculations (again)
# 2.7 fixed errors in SccFrame() and SccTimecode()
# 2.7.1 fixed rounding problem in SccTimecode()
# 2.8 correct handling for subtitles with no gap between them
# 2.8.1 cosmetic: updated my e-mail address in the source code
# 2.9 added logic to convert "*" to note character and -k option to not do it
#     moved display line timecodes up by 2 frames,
#     fixed logic for positioning of clear code in middle of display line
#
# Note that this program makes all kinds of assumptions to determine caption
#   positioning.

sub processSubtitle;
sub usage;
sub SubripFrame;
sub SccFrame;
sub SccTimecode;
sub oddParity;
sub nearestColorCode;

# initial variables
$offsettimecode = "00:00:00,000";
$fps = 30000/1001; # NTSC framerate (non-drop)
$drop = 0; # assume non-drop
$channel = 1; # can be 1 or 2
$uppercase = 0; # apply standard caption capitalization rules:
                # uppercase everything where the line doesn't start with "[" or "("
$convertAsterisk = 1; # convert all "*" characters into note characters
$input = "~"; # place-holder for no input file yet
$output = "~"; # place-holder for no output file yet
$anything = "~";

# process command line arguments
while ($_ = shift) {
#  print ($_, "\n");
  $anything = "";
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
  if (m/-2/) {
    $channel = 2;
    next;
  }
  if (m/-u/) {
    $uppercase = 1;
    next;
  }
  if (m/-k/) {
    $convertAsterisk = 0;
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

if ($anything eq "~") {
  usage();
  exit;
}

if ($input eq "~") {
  usage();
  die "No input file, stopped";
}

if ($output eq "~") {
  if ($input =~ m/(.*)(\.srt)$/i) {
    $output = $1.".scc";
  }
}
if ($output eq "~") {
  usage();
  die "Input file must have .srt extension if output is not supplied, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second out of range, stopped";
}

if (($offsettimecode =~ m/\d\d:\d\d:\d\d\,\d\d\d/) != 1) {
  if (($offsettimecode =~ m/\d\d:\d\d:\d\d\.\d\d\d/) != 1) {
    usage();
    die "Wrong format for offset, stopped";
  }
}

if ($input eq $output) {
  die "Input and output files cannot be the same, stopped";
}
open (RH, $input) or die "Unable to read from file: $!";
open (WH, ">".$output) or die "Unable to write to file: $!";
print WH "Scenarist_SCC V1.0\n\n";
$offset = SubripFrame($offsettimecode);

# read loop
$clearFrame = 2; # when screen should be cleared prior to subtitle/caption
                 #  (same as endFrame of previous subtitle/caption)
                 # value 2 because clear command is 2 frames long
$startFrame = 0;
$endFrame = 0;
$lastFrame = -1; # last frame of last caption, to prevent overlap
$SubripLineMode = 0; # this is 0 for index line, 1 for timecodes line,
                     #  and 2 - 5 for up to four lines of subtitle
$SubripLines = ''; # this will be an entire subtitle, with the following special
                   #  characters inserted:
                   # 13: newline
                   # 19: color off
                   # 20: italics on
                   # 21: italics off
                   # 22: underline on
                   # 23: underline off
                   # 24: white
                   # 25: green
                   # 26: blue
                   # 27: cyan
                   # 28: red
                   # 29: yellow
                   # 30: magenta
                   # 31: black
                   # Note that Subrip's bold characteristic cannot be applied to captions
$SubripIndex = 0; # from index line of Subrip file
LINELOOP: while (<RH>) {
  if ($_ eq "\n") { # if line is blank, process subtitle (if any has been received)
    if ($SubripLines ne '') {
      my $LineAndLastFrame = processSubtitle($SubripLines, $clearFrame, $startFrame, $lastFrame,
                                             $SubripIndex);
      # use "," character to separate two outputs
      (my $SccLines, $lastFrame) = split(/,/, $LineAndLastFrame);
      # print $SubripIndex.$SccLines;
      print WH $SccLines;
      $clearFrame = $endFrame + 2;
      $SubripLines = '';
    next LINELOOP;
    }
  }
  chomp;
  if (/^\d+$/) { # if line consists of nothing but digits, this is the Subrip index
    $SubripLineMode = 0;
    $SubripIndex = $_;
    next LINELOOP;
  }
  if (/-->/) { # timecodes line; may optionally start with index
    $SubripLineMode = 1;
    @elements = split(/ /, $_);
    $start = 0;
    if ($elements[2] eq '-->') { # if divider is in position 2, position 0 must be index
      $SubripIndex = $elements[0];
      $start = 1;
    }
    $startFrame = SubripFrame($elements[$start]) + $offset;
    $endFrame = SubripFrame($elements[$start + 2]) + $offset;
    next LINELOOP;
  }
  if ($SubripLineMode =~ /[1234]/) { # we must be in subtitle: up to 4 lines allowed
    $SubripLineMode++;
    if ($SubripLineMode == 2) {
      $SubripLines = $_;
    } else {
      $SubripLines = $SubripLines.chr(13).$_; # insert newline between two lines
    }
    next LINELOOP;
  }
  die "Subrip subtitle $SubripIndex is more than 4 lines long, stopped";
}
# clear for last caption
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

sub processSubtitle {
  my $SubripLines = shift(@_);
  my $clearFrame = shift(@_);
  my $startFrame = shift(@_);
  my $lastFrame = shift(@_);
  my $SubripIndex = shift(@_);
#  if ($SubripIndex == 8) {
#    print $SubripLines."\n".$clearFrame."\n".$startFrame."\n";
#    print $lastFrame."\n".$SubripIndex."\n";
#  }
  my $SccClearLine = '';
  my $SccLine = '';
  my @SccList = ();
  my $SccLineMode = 1; # this is 1 for a line to be displayed or 0 for a clear screen line
  my $counter = 0; # used to step through various arrays
  
  # the hardest part of this routine is to figure out where the carriage returns should
  #  go: the closed caption screen is only 32 characters wide, and can only display a
  #  maximum of 4 lines at a time
  my @lines = (); # one record per line from $SubripLines, adjusted to CC requirements
  my $column = 32; # counts down space in current row
  my $row = 5; # counts down number of allowed caption lines
  my @columns = (); # start column for each row in order to center it
  my $bottomLine = 14; # dialog lines go at bottom of screen
  my $topLine = 1; # stage directions go at top of screen
  my $lineType = 0; # 0 for dialog, 1 for stage directions ("[...]" or "(...)")
  LINE: for (my $position = 0; $position < length($SubripLines); $position++) {
    my $character = substr $SubripLines, $position, 1;
    if (length($lines[$counter]) == 0) { # first character of line
      $lineType = 0;
      if (($character eq '[') || ($character eq '(')) {
        $lineType = 1;
      }
    }
    if ($character eq '<') { # this could be a formatting command
      my $nextCharacters = substr $SubripLines, $position + 1, 2;
      if ($nextCharacters =~ /b\>/i) { # bold is ignored
        $position += 2;
        print "(Bold formatting stripped from subtitle $SubripIndex.)\n";
        next LINE;
      }
      if ($nextCharacters =~ m|/b|i) { # remove bold is ignored
        $position += 3;
        next LINE;
      }
      if ($nextCharacters =~ /i\>/i) { # italics on
        $position += 2;
        $lines[$counter] = $lines[$counter].chr 20; # ASCII 20 is this program's code for
                                                    #  italics on
        next LINE;
      }
      if ($nextCharacters =~ m|/i|i) { # italics off
        $position += 3;
        $lines[$counter] = $lines[$counter].chr 21; # ASCII 21 is this program's code for
                                                    #  italics off
        next LINE;
      }
      if ($nextCharacters =~ /u\>/i) { # underline on
        $position += 2;
        $lines[$counter] = $lines[$counter].chr 22; # ASCII 22 is this program's code for
                                                    #  underline on
        next LINE;
      }
      if ($nextCharacters =~ m|/u|i) { # underline off
        $position += 3;
        $lines[$counter] = $lines[$counter].chr 23; # ASCII 23 is this program's code for
                                                    #  underline off
        next LINE;
      }
      if ($nextCharacters =~ /fo/i) { # font color on (ASCII codes 24 - 31)
        $position += 21; # full tag is <font color="#rrggbb">
        $lines[$counter] = $lines[$counter].chr(nearestColorCode(
                                                substr($SubripLines, $position - 7, 6)));
        next LINE;
      }
      if ($nextCharacters =~ m|/f|i) { # font color off
        $position += 6;
        $lines[$counter] = $lines[$counter].chr 19; # ASCII 19 is this program's code for
                                                    #  color off
        next LINE;
      }
      # if none of these conditions are met, this is a normal "<" character
      #  and should be displayed
    }
    if (ord($character) == 13) { # linefeed
      $row--;
      $columns[$counter] = int(16.5 - (length($lines[$counter]) / 2));
      $counter++;
      $column = 32;
      if ($row == 0) {
        print "(Subtitle $SubripIndex is too long and has been truncated.)\n";
        last LINE;
      }
      next LINE;
    }
    # this must be a normal character
    $column--;
    if ($column == 0) { # if we need a new line, the split will be on the last space
      # if line so far ends in spaces, we need to chop those off first
      $position -= ($lines[$counter] =~ s/ *$//);
      $lines[$counter] =~ m/(.*)( )(\S+)$/; # match for any characters (.*)
                                           #  followed by a space () followed by any
                                           #  non-whitespace characters (\S+) followed by
                                           #  end of line ($)
      (my $before, my $space, my $after) = ($1, $2, $3);
#      if ($SubripIndex == 8) {
#        print $before."!".$space."!".$after."!\n";
#      }
      $lines[$counter] = $before;
      $columns[$counter] = int(16.5 - (length($lines[$counter]) / 2));
      $counter++;
      $position = $position - length($after) - 1;
      if ($after =~ /\x13/) { # if you find color off (decimal 19), account for </font>
        $position -= 6;
      }
      if ($after =~ /\x14/) { # if you find italics on (decimal 20), account for <i>
        $position -= 2;
      }
      if ($after =~ /\x15/) { # if you find italics off (decimal 21), account for </i>
        $position -= 3;
      }
      if ($after =~ /\x16/) { # if you find underline on (decimal 22), account for <u>
        $position -= 2;
      }
      if ($after =~ /\x17/) { # if you find underline off (decimal 23), account for </u>
        $position -= 3;
      }
      if ($after =~/[\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f]/) { # if you find a color code,
        $position -= 21;          #  (decimal 24 - 31), account for <font color="#rrggbb">
      }
      $row--;
      $column = 32;
      $lineType = 0;
      $firstCharacter = substr $lines[$counter], 0, 1;
      if (($firstCharacter eq '[') || ($firstCharacter eq '(')) {
        $lineType = 1;
      }
      if ($lineType == 0) {
        $bottomLine--;
      }
      next LINE;
    }
    if ($row == 0) {
      print "(Subtitle $SubripIndex is too long and has been truncated.)\n";
      last LINE;
    }
    if ($column == 32) {
      $lineType = 0;
      if (($character eq '[') || ($character eq '(')) {
        $lineType = 1;
      }
      if ($lineType == 0) {
        $bottomLine--;
      }
    }
    if (($lineType == 0) && ($uppercase == 1)) { # convert to uppercase dialog
      $character = uc $character;
    }
    $lines[$counter] = $lines[$counter].$character;
    next LINE;
  }
  $columns[$counter++] = int(($column + 0.5) / 2);
  # we will now build up the display caption line
  $SccList[0] = ($channel == 1)?0x14:0x1c; # command:
  $SccList[1] = 0x2e;                      # ENM (Erase Non-Displayed Memory)
  $SccList[2] = $SccList[0];               # (all commands are in pairs)
  $SccList[3] = $SccList[1];
  $SccList[4] = ($channel == 1)?0x14:0x1c; # command:
  $SccList[5] = 0x20;                      # RCL (Resume Caption Loading)
  $SccList[6] = $SccList[4];
  $SccList[7] = $SccList[5];
  $counter = 8;
  my $underline = 0;
  my $italics = 0;
  my @currentColor; # this will be used as a stack to keep track of the current color
  my @colorList = ('white', 'green', 'blue', 'cyan', 'red', 'yellow', 'magenta', 'black');
  my %colorCode = ( 'white' => 24, 'green' => 25, 'blue' => 26, 'cyan' => 27,
                    'red' => 28, 'yellow' => 29, 'magenta' => 30, 'black' => 31 ); 
  push @currentColor, 'white'; # default color is white
  LINELOOP: for (my $i = 0; $i <= $#lines; $i++) {
    my $line = $lines[$i];
#    if ($SubripIndex == 8) {
#      print $line."\n";
#    }
    my $position = 0;
    while ((my $code = ord(substr $line, $position, 1)) < 32) {
      # code 19 (color off) wouldn't make sense before a color command,
      #  so we don't react to it
      if ($code == 20) {
        $italics = 1;
      }
      if ($code == 21) {
        $italics = 0;
      }
      if ($code == 22) {
        $underline = 1;
      }
      if ($code == 23) {
        $underline = 0; 
      }
      if (($code > 23) && ($code < 32)) {
        push @currentColor, $colorList[$code - 24];
      }
      $position++;
    }
    my $character = substr $line, $position++, 1;
    if (($character eq '[') || ($character eq '(')) {
      $row = $topLine++;
    } else {
      $row = $bottomLine++;
    }
    # Preamble Access Code
    # caption columns are two part: multiple of 4, and what's left over
    my $evenColumn = int($columns[$i] / 4);
    my $state = $underline;
    if (($evenColumn == 0) && ($currentColor[$#currentColor] eq 'white')) {
      $state += $italics * 2;
    }
    my @rowCode1 = ();
    if ($channel == 1) {
      @rowCode1 = (0, 0x11, 0x11, 0x12, 0x12, 0x15, 0x15, 0x16, 0x16,
                   0x17, 0x17, 0x10, 0x13, 0x13, 0x14, 0x14);
    } else {
      @rowCode1 = (0, 0x19, 0x19, 0x1a, 0x1a, 0x1d, 0x1d, 0x1e, 0x1e,
                   0x1f, 0x1f, 0x18, 0x1b, 0x1b, 0x1c, 0x1c);
    }
    my @evenColumnCode2a = (0x40, 0x52, 0x54, 0x56, 0x58, 0x5a, 0x5c, 0x5e);
    my @evenColumnCode2b = (0x60, 0x72, 0x74, 0x76, 0x78, 0x7a, 0x7c, 0x7e);
    my $colorFactor = 0; # what to add to code 2 to get various colors
    if ($evenColumn == 0) {
      $colorFactor = ($colorCode{$currentColor[$#currentColor]} - 24) * 2;
    }
    my @stateFactor = (0, 1, 14, 15); # what to add to code 2 to get various states
    $SccList[$counter++] = $rowCode1[$row];
    my @columnSelect = (0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0);
    if ($columnSelect[$row]) {
      $SccList[$counter++] = $evenColumnCode2a[$evenColumn] +
                             $colorFactor + $stateFactor[$state];
    } else {
      $SccList[$counter++] = $evenColumnCode2b[$evenColumn] +
                             $colorFactor + $stateFactor[$state];
    }
    $SccList[$counter] = $SccList[$counter - 2]; # PAC is a command, so we repeat it
    $counter++;
    $SccList[$counter] = $SccList[$counter - 2];
    $counter++;
    # tab offset
    my $oddColumn = $columns[$i] % 4;
    if ($oddColumn > 0) {
      $SccList[$counter++] = ($channel == 1)?0x17:0x1f;
      $SccList[$counter++] = 0x20 + $oddColumn;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
    }
    # set color if not set already
    if (($currentColor[$#currentColor] ne 'white') && ($evenColumn > 0)) {
      $colorFactor = 0x20 + ($colorCode{$currentColor[$#currentColor]} - 24) * 2 +
                     $underline;
      $SccList[$counter++] = ($channel == 1)?0x11:0x19;
      $SccList[$counter++] = $colorFactor;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
    }
    # turn on italics if not already on
    if ($italics && (($evenColumn > 0) || ($currentColor[$#currentColor] ne 'white'))) {
      $SccList[$counter++] = ($channel == 1)?0x11:0x19;
      $SccList[$counter++] = 0x2f;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
      $SccList[$counter] = $SccList[$counter - 2];
      $counter++;
    }
    # Note for something that happens a lot in the following code:
    #  SCC is transmitted in pairs: two characters or one two-byte command per frame.
    #  This means that if we're about to transmit a command and we're not on an even
    #   frame boundary, we must pad with a byte value of zero.
    CHARLOOP: for ($position--; $position < length($line); $position++) {
      my $character = substr $line, $position, 1;
      my $code = ord $character;
      if (($code == 19) || (($code > 23) && ($code < 32))) { # color off or color set
        if ($code == 19) {
          pop @currentColor; # go back to last-set color
        } else {
          # catch trying to change to the current color
          if ($colorList[$code - 24] eq $currentColor[$#currentColor]) { 
            next CHARLOOP;
          }
          push @currentColor, $colorList[$code - 24];
        }
        if ($counter % 2 == 1) { # checking for even boundary
          $SccList[$counter++] = 0x00;
        }
        # now set the color
        $colorFactor = 0x20 + ($colorCode{$currentColor[$#currentColor]} - 24) * 2 +
                       $underline;
        $SccList[$counter++] = ($channel == 1)?0x11:0x19;
        $SccList[$counter++] = $colorFactor;
        $SccList[$counter] = $SccList[$counter - 2];
        $counter++;
        $SccList[$counter] = $SccList[$counter - 2];
        $counter++;
        # reset italics if necessary
        if ($italics) {
          $SccList[$counter++] = ($channel == 1)?0x11:0x19;
          $SccList[$counter++] = 0x2e + $underline;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
        }
        next CHARLOOP;
      }
      if ($code == 20) { # italics on
        if ($italics == 0) {
          $italics = 1;
          if ($counter % 2 == 1) { # checking for even boundary
            $SccList[$counter++] = 0x00;
          }
         $SccList[$counter++] = ($channel == 1)?0x11:0x19;
          # the commands for italics and italics underline are 1 digit apart
          $SccList[$counter++] = 0x2e + $underline;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
        }
        next CHARLOOP;
      }
      if ($code == 21) { # italics off
        if ($italics == 1) {
          $italics = 0;
          if ($counter % 2 == 1) { # checking for even boundary
            $SccList[$counter++] = 0x00;
          }
          # the commands for color and color underline are 1 digit apart
          $colorFactor = 0x20 + ($colorCode{$currentColor[$#currentColor]} - 24) * 2 +
                         $underline;
          $SccList[$counter++] = ($channel == 1)?0x11:0x19;
          $SccList[$counter++] = $colorFactor;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
        }
        next CHARLOOP;
      }
      if ($code == 22) { # underline on
        if ($underline == 0) {
          $underline = 1;
          if ($counter % 2 == 1) { # checking for even boundary
            $SccList[$counter++] = 0x00;
          }
          $SccList[$counter++] = ($channel == 1)?0x11:0x19;
          if ($italics) {
            $SccList[$counter++] = 0x2f;
          } else {
            $colorFactor = 0x21 + ($colorCode{$currentColor[$#currentColor]} - 24) * 2;
            $SccList[$counter++] = $colorFactor;
          }
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
        }
        next CHARLOOP;
      }
      if ($code == 23) { # underline off
        if ($underline == 1) {
          $underline = 0;
          if ($counter % 2 == 1) { # checking for even boundary
            $SccList[$counter++] = 0x00;
          }
          $SccList[$counter++] = ($channel == 1)?0x11:0x19;
          if ($italics) {
            $SccList[$counter++] = 0x2e;
          } else {
            $colorFactor = 0x20 + ($colorCode{$currentColor[$#currentColor]} - 24) * 2;
            $SccList[$counter++] = $colorFactor;
          }
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
          $SccList[$counter] = $SccList[$counter - 2];
          $counter++;
        }
        next CHARLOOP;
      }
      # must be a normal character to get this far
      my $repeat = 0; # keep track of whether this is a command (which we'll need to repeat)
      my $match = 0; # keep track of whether any match was found
      SWITCH: for ($character) {
        # standard characters
        / / && do {$SccList[$counter++] = 0x20; $match = 1; last SWITCH;};
        /\!/ && do {$SccList[$counter++] = 0x21; $match = 1; last SWITCH;};
        /\"/ && do {$SccList[$counter++] = 0x22; $match = 1; last SWITCH;}; 
        /\#/ && do {$SccList[$counter++] = 0x23; $match = 1; last SWITCH;};  
        /\$/ && do {$SccList[$counter++] = 0x24; $match = 1; last SWITCH;};
        /%/ && do {$SccList[$counter++] = 0x25; $match = 1; last SWITCH;};
        /&/ && do {$SccList[$counter++] = 0x26; $match = 1; last SWITCH;};
        /\'/ && do {$SccList[$counter++] = 0x27; $match = 1; last SWITCH;};
        /\(/ && do {$SccList[$counter++] = 0x28; $match = 1; last SWITCH;};
        /\)/ && do {$SccList[$counter++] = 0x29; $match = 1; last SWITCH;};
        /á/ && do {$SccList[$counter++] = 0x2a; $match = 1; last SWITCH;};
        /\+/ && do {$SccList[$counter++] = 0x2b; $match = 1; last SWITCH;};
        /\,/ && do {$SccList[$counter++] = 0x2c; $match = 1; last SWITCH;};
        /\-/ && do {$SccList[$counter++] = 0x2d; $match = 1; last SWITCH;};
        /\./ && do {$SccList[$counter++] = 0x2e; $match = 1; last SWITCH;};
        /\// && do {$SccList[$counter++] = 0x2f; $match = 1; last SWITCH;};
        /0/ && do {$SccList[$counter++] = 0x30; $match = 1; last SWITCH;};
        /1/ && do {$SccList[$counter++] = 0x31; $match = 1; last SWITCH;};
        /2/ && do {$SccList[$counter++] = 0x32; $match = 1; last SWITCH;};
        /3/ && do {$SccList[$counter++] = 0x33; $match = 1; last SWITCH;};
        /4/ && do {$SccList[$counter++] = 0x34; $match = 1; last SWITCH;};
        /5/ && do {$SccList[$counter++] = 0x35; $match = 1; last SWITCH;};
        /6/ && do {$SccList[$counter++] = 0x36; $match = 1; last SWITCH;};
        /7/ && do {$SccList[$counter++] = 0x37; $match = 1; last SWITCH;};
        /8/ && do {$SccList[$counter++] = 0x38; $match = 1; last SWITCH;};
        /9/ && do {$SccList[$counter++] = 0x39; $match = 1; last SWITCH;};
        /\:/ && do {$SccList[$counter++] = 0x3a; $match = 1; last SWITCH;};
        /;/ && do {$SccList[$counter++] = 0x3b; $match = 1; last SWITCH;};
        /</ && do {$SccList[$counter++] = 0x3c; $match = 1; last SWITCH;};
        /=/ && do {$SccList[$counter++] = 0x3d; $match = 1; last SWITCH;};
        />/ && do {$SccList[$counter++] = 0x3e; $match = 1; last SWITCH;};
        /\?/ && do {$SccList[$counter++] = 0x3f; $match = 1; last SWITCH;};
        /@/ && do {$SccList[$counter++] = 0x40; $match = 1; last SWITCH;};
        /A/ && do {$SccList[$counter++] = 0x41; $match = 1; last SWITCH;};
        /B/ && do {$SccList[$counter++] = 0x42; $match = 1; last SWITCH;};
        /C/ && do {$SccList[$counter++] = 0x43; $match = 1; last SWITCH;};
        /D/ && do {$SccList[$counter++] = 0x44; $match = 1; last SWITCH;};
        /E/ && do {$SccList[$counter++] = 0x45; $match = 1; last SWITCH;};
        /F/ && do {$SccList[$counter++] = 0x46; $match = 1; last SWITCH;};
        /G/ && do {$SccList[$counter++] = 0x47; $match = 1; last SWITCH;};
        /H/ && do {$SccList[$counter++] = 0x48; $match = 1; last SWITCH;};
        /I/ && do {$SccList[$counter++] = 0x49; $match = 1; last SWITCH;};
        /J/ && do {$SccList[$counter++] = 0x4a; $match = 1; last SWITCH;};
        /K/ && do {$SccList[$counter++] = 0x4b; $match = 1; last SWITCH;};
        /L/ && do {$SccList[$counter++] = 0x4c; $match = 1; last SWITCH;};
        /M/ && do {$SccList[$counter++] = 0x4d; $match = 1; last SWITCH;};
        /N/ && do {$SccList[$counter++] = 0x4e; $match = 1; last SWITCH;};
        /O/ && do {$SccList[$counter++] = 0x4f; $match = 1; last SWITCH;};
        /P/ && do {$SccList[$counter++] = 0x50; $match = 1; last SWITCH;};
        /Q/ && do {$SccList[$counter++] = 0x51; $match = 1; last SWITCH;};
        /R/ && do {$SccList[$counter++] = 0x52; $match = 1; last SWITCH;};
        /S/ && do {$SccList[$counter++] = 0x53; $match = 1; last SWITCH;};
        /T/ && do {$SccList[$counter++] = 0x54; $match = 1; last SWITCH;};
        /U/ && do {$SccList[$counter++] = 0x55; $match = 1; last SWITCH;};
        /V/ && do {$SccList[$counter++] = 0x56; $match = 1; last SWITCH;};
        /W/ && do {$SccList[$counter++] = 0x57; $match = 1; last SWITCH;};
        /X/ && do {$SccList[$counter++] = 0x58; $match = 1; last SWITCH;};
        /Y/ && do {$SccList[$counter++] = 0x59; $match = 1; last SWITCH;};
        /Z/ && do {$SccList[$counter++] = 0x5a; $match = 1; last SWITCH;};
        /\[/ && do {$SccList[$counter++] = 0x5b; $match = 1; last SWITCH;};
        /é/ && do {$SccList[$counter++] = 0x5c; $match = 1; last SWITCH;};
        /\]/ && do {$SccList[$counter++] = 0x5d; $match = 1; last SWITCH;};
        /í/ && do {$SccList[$counter++] = 0x5e; $match = 1; last SWITCH;};
        /ó/ && do {$SccList[$counter++] = 0x5f; $match = 1; last SWITCH;};
        /ú/ && do {$SccList[$counter++] = 0x60; $match = 1; last SWITCH;};
        /a/ && do {$SccList[$counter++] = 0x61; $match = 1; last SWITCH;};
        /b/ && do {$SccList[$counter++] = 0x62; $match = 1; last SWITCH;};
        /c/ && do {$SccList[$counter++] = 0x63; $match = 1; last SWITCH;};
        /d/ && do {$SccList[$counter++] = 0x64; $match = 1; last SWITCH;};
        /e/ && do {$SccList[$counter++] = 0x65; $match = 1; last SWITCH;};
        /f/ && do {$SccList[$counter++] = 0x66; $match = 1; last SWITCH;};
        /g/ && do {$SccList[$counter++] = 0x67; $match = 1; last SWITCH;};
        /h/ && do {$SccList[$counter++] = 0x68; $match = 1; last SWITCH;};
        /i/ && do {$SccList[$counter++] = 0x69; $match = 1; last SWITCH;};
        /j/ && do {$SccList[$counter++] = 0x6a; $match = 1; last SWITCH;};
        /k/ && do {$SccList[$counter++] = 0x6b; $match = 1; last SWITCH;};
        /l/ && do {$SccList[$counter++] = 0x6c; $match = 1; last SWITCH;};
        /m/ && do {$SccList[$counter++] = 0x6d; $match = 1; last SWITCH;};
        /n/ && do {$SccList[$counter++] = 0x6e; $match = 1; last SWITCH;};
        /o/ && do {$SccList[$counter++] = 0x6f; $match = 1; last SWITCH;};
        /p/ && do {$SccList[$counter++] = 0x70; $match = 1; last SWITCH;};
        /q/ && do {$SccList[$counter++] = 0x71; $match = 1; last SWITCH;};
        /r/ && do {$SccList[$counter++] = 0x72; $match = 1; last SWITCH;};
        /s/ && do {$SccList[$counter++] = 0x73; $match = 1; last SWITCH;};
        /t/ && do {$SccList[$counter++] = 0x74; $match = 1; last SWITCH;};
        /u/ && do {$SccList[$counter++] = 0x75; $match = 1; last SWITCH;};
        /v/ && do {$SccList[$counter++] = 0x76; $match = 1; last SWITCH;};
        /w/ && do {$SccList[$counter++] = 0x77; $match = 1; last SWITCH;};
        /x/ && do {$SccList[$counter++] = 0x78; $match = 1; last SWITCH;};
        /y/ && do {$SccList[$counter++] = 0x79; $match = 1; last SWITCH;};
        /z/ && do {$SccList[$counter++] = 0x7a; $match = 1; last SWITCH;};
        /ç/ && do {$SccList[$counter++] = 0x7b; $match = 1; last SWITCH;};
        /÷/ && do {$SccList[$counter++] = 0x7c; $match = 1; last SWITCH;};
        /Ñ/ && do {$SccList[$counter++] = 0x7d; $match = 1; last SWITCH;};
        /ñ/ && do {$SccList[$counter++] = 0x7e; $match = 1; last SWITCH;};
        /\|/ && do {$SccList[$counter++] = 0x7f; $match = 1; last SWITCH;};

        $repeat = 1; # remaining characters are actually commands

        # Extended Characters (includes replacement character)
        /Á/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x20;
                   $match = 1; last SWITCH;};
        /É/ && do {$SccList[$counter++] = 0x45;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x21;
                   $match = 1; last SWITCH;};
        /Ó/ && do {$SccList[$counter++] = 0x44;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x22;
                   $match = 1; last SWITCH;};
        /Ú/ && do {$SccList[$counter++] = 0x55;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x23;
                   $match = 1; last SWITCH;};
        /Ü/ && do {$SccList[$counter++] = 0x55;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x24;
                   $match = 1; last SWITCH;};
        /ü/ && do {$SccList[$counter++] = 0x75;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a;
                   $SccList[$counter++] = 0x25;
                   $match = 1; last SWITCH;};
        /'/ && do {$SccList[$counter++] = 0x27;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x26;
                   $match = 1; last SWITCH;};
        /¡/ && do {$SccList[$counter++] = 0x21;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x27;
                   $match = 1; last SWITCH;};
        /\*/ && ($convertAsterisk == 0) && do {$SccList[$counter++] = 0x23;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x28;
                   $match = 1; last SWITCH;};
        /'/ && do {$SccList[$counter++] = 0x27;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x29;
                   $match = 1; last SWITCH;};
        /-/ && do {$SccList[$counter++] = 0x2d;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x2a;
                   $match = 1; last SWITCH;};
        /©/ && do {$SccList[$counter++] = 0x63;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x2b;
                   $match = 1; last SWITCH;};
        # can't handle Service Mark (Unicode 2120, not supported by Windows)
        /o/ && do {$SccList[$counter++] = 0x2e;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x2d;
                   $match = 1; last SWITCH;};
        /"/ && do {$SccList[$counter++] = 0x22;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x2e;
                   $match = 1; last SWITCH;};
        /"/ && do {$SccList[$counter++] = 0x22;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x2f;
                   $match = 1; last SWITCH;};
        /À/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x30;
                   $match = 1; last SWITCH;};
        /Â/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x31;
                   $match = 1; last SWITCH;};
        /Ç/ && do {$SccList[$counter++] = 0x43;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x32;
                   $match = 1; last SWITCH;};
        /È/ && do {$SccList[$counter++] = 0x45;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x33;
                   $match = 1; last SWITCH;};
        /Ê/ && do {$SccList[$counter++] = 0x45;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x34;
                   $match = 1; last SWITCH;};
        /Ë/ && do {$SccList[$counter++] = 0x45;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x35;
                   $match = 1; last SWITCH;};
        /ë/ && do {$SccList[$counter++] = 0x65;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x36;
                   $match = 1; last SWITCH;};
        /Î/ && do {$SccList[$counter++] = 0x49;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x37;
                   $match = 1; last SWITCH;};
        /Ï/ && do {$SccList[$counter++] = 0x49;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x38;
                   $match = 1; last SWITCH;};
        /ï/ && do {$SccList[$counter++] = 0x69;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x39;
                   $match = 1; last SWITCH;};
        /Ô/ && do {$SccList[$counter++] = 0x4f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3a;
                   $match = 1; last SWITCH;};
        /Ù/ && do {$SccList[$counter++] = 0x55;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3b;
                   $match = 1; last SWITCH;};
        /ù/ && do {$SccList[$counter++] = 0x75;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3c;
                   $match = 1; last SWITCH;};
        /Û/ && do {$SccList[$counter++] = 0x55;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3d;
                   $match = 1; last SWITCH;};
        /"/ && do {$SccList[$counter++] = 0x22;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3e;
                   $match = 1; last SWITCH;};
        /"/ && do {$SccList[$counter++] = 0x22;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x12:0x1a; 
                   $SccList[$counter++] = 0x3f;
                   $match = 1; last SWITCH;};
        /Ã/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x20;
                   $match = 1; last SWITCH;};
        /ã/ && do {$SccList[$counter++] = 0x61;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x21;
                   $match = 1; last SWITCH;};
        /Í/ && do {$SccList[$counter++] = 0x49;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x22;
                   $match = 1; last SWITCH;};
        /Ì/ && do {$SccList[$counter++] = 0x49;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x23;
                   $match = 1; last SWITCH;};
        /ì/ && do {$SccList[$counter++] = 0x69;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x24;
                   $match = 1; last SWITCH;};
        /Ò/ && do {$SccList[$counter++] = 0x4f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x25;
                   $match = 1; last SWITCH;};
        /ò/ && do {$SccList[$counter++] = 0x6f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x26;
                   $match = 1; last SWITCH;};
        /Õ/ && do {$SccList[$counter++] = 0x4f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x27;
                   $match = 1; last SWITCH;};
        /õ/ && do {$SccList[$counter++] = 0x6f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x28;
                   $match = 1; last SWITCH;};
        /\{/ && do {$SccList[$counter++] = 0x5b;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x29;
                   $match = 1; last SWITCH;};
        /\}/ && do {$SccList[$counter++] = 0x5d;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2a;
                   $match = 1; last SWITCH;};
        /\\/ && do {$SccList[$counter++] = 0x2f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2b;
                   $match = 1; last SWITCH;};
        /\^/ && do {$SccList[$counter++] = 0x2f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2c;
                   $match = 1; last SWITCH;};
        /_/ && do {$SccList[$counter++] = 0x2d;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2d;
                   $match = 1; last SWITCH;};
        /¦/ && do {$SccList[$counter++] = 0x2d;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2e;
                   $match = 1; last SWITCH;};
        /~/ && do {$SccList[$counter++] = 0x2d;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x2f;
                   $match = 1; last SWITCH;};
        /Ä/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x30;
                   $match = 1; last SWITCH;};
        /ä/ && do {$SccList[$counter++] = 0x61;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x31;
                   $match = 1; last SWITCH;};
        /Ö/ && do {$SccList[$counter++] = 0x4f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x32;
                   $match = 1; last SWITCH;};
        /ö/ && do {$SccList[$counter++] = 0x6f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x33;
                   $match = 1; last SWITCH;};
        /ß/ && do {$SccList[$counter++] = 0x73;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x34;
                   $match = 1; last SWITCH;};
        /¥/ && do {$SccList[$counter++] = 0x59;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x35;
                   $match = 1; last SWITCH;};
        /¤/ && do {$SccList[$counter++] = 0x43;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x36;
                   $match = 1; last SWITCH;};
        /\|/ && do {$SccList[$counter++] = 0x2f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x37;
                   $match = 1; last SWITCH;};
        /Å/ && do {$SccList[$counter++] = 0x41;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x38;
                   $match = 1; last SWITCH;};
        /å/ && do {$SccList[$counter++] = 0x61;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x39;
                   $match = 1; last SWITCH;};
        /Ø/ && do {$SccList[$counter++] = 0x4f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x3a;
                   $match = 1; last SWITCH;};
        /ø/ && do {$SccList[$counter++] = 0x6f;
                   if ($counter % 2 == 1) {$SccList[$counter++] = 0x00;}
                   $SccList[$counter++] = ($channel == 1)?0x13:0x1b; 
                   $SccList[$counter++] = 0x3b;
                   $match = 1; last SWITCH;};
        # can't handle down & right corner (Unicode 250C)
        # can't handle down & left corner (Unicode 2510)
        # can't handle up & right corner (Unicode 2514)
        # can't handle up & left corner (Unicode 2518)

        # Special Characters (minus Unicode characters)
        # we'll assume for the moment that the character will match one of the below
        #  characters
        if ($counter % 2 == 1) { # checking for even boundary
          $SccList[$counter++] = 0x00;
        }
        /®/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x30;
                   $match = 1; last SWITCH;};
        /°/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x31; 
                   $match = 1; last SWITCH;};
        /½/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x32; 
                   $match = 1; last SWITCH;};
        /¿/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x33; 
                   $match = 1; last SWITCH;};
        /™/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x34; 
                   $match = 1; last SWITCH;};
        /¢/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x35; 
                   $match = 1; last SWITCH;};
        /£/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x36; 
                   $match = 1; last SWITCH;};
        # convert asterisk into eighth note
        /\*/ && ($convertAsterisk == 1) && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x37; 
                   $match = 1; last SWITCH;};
        /à/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x38; 
                   $match = 1; last SWITCH;};
        # can't handle transparent space
        /è/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3a; 
                   $match = 1; last SWITCH;};
        /â/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3b; 
                   $match = 1; last SWITCH;};
        /ê/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3c; 
                   $match = 1; last SWITCH;};
        /î/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3d; 
                   $match = 1; last SWITCH;};
        /ô/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3e; 
                   $match = 1; last SWITCH;};
        /û/ && do {$SccList[$counter++] = ($channel == 1)?0x11:0x19; 
                   $SccList[$counter++] = 0x3f; 
                   $match = 1; last SWITCH;};
      }
      if ($match == 0) {
        $repeat = 0;
        if ($SccList[$counter - 1] == 0) { # undo above "even-ing"
          $SccList[--$counter] = -1;
        }
        print "(Illegal character $code in Subrip subtitle $SubripIndex.)\n";
      }
      if ($repeat == 1) {
        $SccList[$counter] = $SccList[$counter - 2];
        $counter++;
        $SccList[$counter] = $SccList[$counter - 2];
        $counter++;
      }
      next CHARLOOP;
    }
    if ($counter % 2 == 1) {
      $SccList[$counter++] = 0x00;
    }
    next LINELOOP;
  }
  $SccList[$counter++] = ($channel == 1)?0x14:0x1c; # command:
  $SccList[$counter++] = 0x2f;                      # EOC (End of Caption)
  $SccList[$counter++] = ($channel == 1)?0x14:0x1c;
  $SccList[$counter++] = 0x2f;
  # two values per frame
  my $actualStartFrame = $startFrame - int(($counter + 0.5) / 2);
  # print "$lastFrame, $actualStartFrame\n";
  if ($actualStartFrame < $lastFrame) {
    $actualStartFrame = $lastFrame + 1;
    print "(Forced to shorten start of subtitle $SubripIndex.)\n";
  }
  # The clear screen line is just {EDM}{EDM}, 2 frames long
  if ($actualStartFrame - $clearFrame > 2) { # clear command is outside caption
    # "942c" is the odd-Parity version of EDM
    if ($channel == 1) {
      $SccClearLine = SccTimecode($clearFrame - 2)."\t942c 942c\n\n";
    } else {
      $SccClearLine = SccTimecode($clearFrame - 2)."\t1c2c 1c2c\n\n";
    }
  }
  my $displayStartFrame = $actualStartFrame + int(($counter + 0.5) / 2);
  # print "$clearFrame, $displayStartFrame\n";
  if (($clearFrame - $displayStartFrame < 2) &&
   (($clearFrame - $actualStartFrame) > 2)) { # clear command is inside caption
    #print "(Inserting in line $SubripIndex.)\n";
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
  $SccLine = SccTimecode($actualStartFrame + 2);
  for (my $i = 0; $i < $counter; $i += 2) {
    $SccLine = $SccLine.sprintf(" %02x%02x",
                                oddParity($SccList[$i]), oddParity($SccList[$i+1]));
  }
  $SccLine =~ m/(..:..:..[:;]..)(\s)(.+)/;
  $SccLine = $SccClearLine.$1."\t".$3."\n\n";
  return $SccLine.",".$displayStartFrame;
}

sub usage {
  print "\nSUBRIP2SCC Version 2.9\n";
  print "  Converts Subrip subtitle format to Scenarist Closed Caption format.\n";
  print "  Note: cannot handle characters not in the ISO 8859-1 character set,\n";
  print "    such as the Eighth Note, the Transparent Space, the Service Mark\n";
  print "    or the four corner characters.\n";
  print "  Syntax: SUBRIP2SCC -2 -u -k -o01:00:00,000 -td infile.srt outfile.scc\n";
  print "    -2 (OPTIONAL): Write as Channel 2 captions\n";
  print "         (DEFAULT is to write as Channel 1 captions)\n";
  print "    -u (OPTIONAL): Convert all dialog to uppercase\n";
  print "    -k (OPTIONAL): Leave the character '*' alone\n";
  print "         (DEFAULT is to convert it into the eighth note character)\n";
  print "    -o (OPTIONAL): Offset to apply to Subrip timecodes, in HH:MM:SS,MIL format\n";
  print "         (DEFAULT: 00:00:00,000 - negative values are permitted)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60)\n";
  print "         (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe)\n";
  print "         (DEFAULT: n)\n";
  print "    Outfile will be overwritten if it exists.\n";
  print "  Notes: outfile argument is optional and is assumed to be infile.scc.\n\n";
}

sub SubripFrame {
  my $timecode = shift(@_);
  my $hh = 0;
  my $mm = 0;
  my $ss = 0;
  my $ms = 0;
  my $signmultiplier = +1;
  if (substr($timecode, 0, 1) eq '-') {
    $signmultiplier = -1;
    $timecode = substr $timecode, 1, 12;
  }
  # Subrip subtitles can use comma or period to separate seconds from milliseconds
  if (substr($timecode, 8, 1) eq ',') {
    $timecode =~ m/(\d\d):(\d\d):(\d\d)\,(\d\d\d)/;
    ($hh, $mm, $ss, $ms) = ($1, $2, $3, $4);
  } else {
    $timecode =~ m/(\d\d):(\d\d):(\d\d)\.(\d\d\d)/;
    ($hh, $mm, $ss, $ms) = ($1, $2, $3, $4);
  }
  my $ff = sprintf("%d", $ms * $fps / 1000);
  my $framecount = ($hh * 3600) + ($mm * 60) + $ss;
  $framecount *= $fps;
  $framecount += $ff;
  $framecount *= $signmultiplier;
  return $framecount;
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

# this subroutine converts a hexidecimal red-green-blue code into nearest match of one
#  of the following:
#  24: ffffff white
#  25: 00ff00 green
#  26: 0000ff blue
#  27: 00ffff cyan
#  28: ff0000 red
#  29: ffff00 yellow
#  30: ff00ff magenta
#  31: 000000 black
sub nearestColorCode {
  my $rgb = shift(@_);
  my %colorCode = ( 'white' => 24, 'green' => 25, 'blue' => 26, 'cyan' => 27,
                    'red' => 28, 'yellow' => 29, 'magenta' => 30, 'black' => 31 ); 
  my %colors;
  $rgb =~ /(..)(..)(..)/;
  ($colors{'red'}, $colors{'green'}, $colors{'blue'}) = (hex $1, hex $2, hex $3);
  my $rg = abs($colors{'red'} - $colors{'green'});
  my $gb = abs($colors{'green'} - $colors{'blue'});
  my $rb = abs($colors{'red'} - $colors{'blue'});
  my @colorOrder = sort { $colors{$b} <=> $colors{$a} } keys %colors;
  my $maxColor = @colorOrder[0];
  my $minColor = @colorOrder[2];
  # if the components are nearly the same, it's either white or black
  if (($rg < 64) && ($gb < 64) && ($rb < 64)) {
    if (($red + $blue + $green) / 3 < 128) {
      return $colorCode{'black'};
    } else {
      return $colorCode{'white'};
    }
  }
  # primary colors (one component is bigger and other two are signicantly smaller)
  if (($maxColor eq 'red') && ($rg > 64) && ($rb > 64)) {
    return $colorCode{'red'};
  }
  if (($maxColor eq 'green') && ($rg > 64) && ($gb > 64)) {
    return $colorCode{'green'};
  }
  if (($maxColor eq 'blue') && ($gb > 64) && ($rb > 64)) {
    return $colorCode{'blue'};
  }
  # complementary colors
  if ($minColor eq 'red') {
    return $colorCode{'cyan'};
  }
  if ($minColor eq 'green') {
    return $colorCode{'magenta'};
  }
  if ($minColor eq 'blue') {
    return $colorCode{'yellow'};
  }
  die "Error in nearestColorCode logic, stopped";
}

