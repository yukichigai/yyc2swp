# yyC2Swp - Y|yukichigai's Caption 2 Subtitle (with positioning!)
#  Forked from CCASDI by McPoodle. Their comments below (with some of mine)
#-------------------------------------------------------------------------------
# ccasdi.pl: Convert between Scenarist Closed Caption format and Closed Caption 
#  Disassembly, convert Scenarist Closed Caption format to subtitle format
# Run file without arguments to see usage
# Closed Caption Disassembly is my own creation and is documented at
#  http://www.geocities.com/mcpoodle43/SCC_TOOLS/DOCS/SCC_TOOLS.HTML.
#
use strict;
use utf8;
my $Version = "0.7";
# McPoodle (mcpoodle43@yahoo.com)
# Further modifications by Y|yukichigai (yukichigai@hotmail.com)
#
# Version History
# 1.0 initial release
# 1.1 fixed timecodeof function to properly round frames to never be above framerate,
#     added $lastframe and $frames to read loop to check for out-of-order timecodes
# 1.2 made SCC format double-spaced, to conform with specification,
#     fixed bug with SCC->CCD when first timecode is 00:00:00:00,
#     added -a flag to adjust display times to start times (CCD to SCC) and
#      start times to display times (SCC to CCD),
#     fixed translation of box corner extended characters,
#     simplified timecodeof function,
#     fixed frame function to handle negative timecodes
# 1.2.1 corrected mis-named -a flag (was -p)
# 2.0 fixed negative offset problem in frame function,
#     changed both formats to have tab character between timecode and content
#       (to absolutely match the SCC standard),
#     changed CCD keyword FIELD to CHANNEL,
#     upp'd CCD format version to 1.1 (because of above change),
#     added default output name,
#     add ability to change channel in mid-file,
#     added line number to out-of-order error message,
#     added parsing of background color commands (used by text captions),
#     added parsing of eXtended Data Service and Interactive TV messages
#       (ITV only requires changed character parsing, since it is stored as plain text),
#     changed invalid character from "*" to "£", since "*" is used by ITV,
#     assume channel is 1 for disassembly (required for XDS to work)
# 2.1 finally figured out drop vs non-drop (changing frame and timecodeof functions)
#       and correctly parsing and outputting non-drop timecodes,
#     added -td and -tn parameters
# 2.6 corrected drop/non-drop calculations (again),
#     drop type set if timecode has semicolon in it,
#     added ability to handle undocumented XDS sequences
# 2.7 changed -s option to include -a and to output subtitle file in format indicated
#       by output file suffix (SubRip default, also supporting MicroDVD, SAMI, PowerDivX,
#       SubStation Alpha, and Advanced SubStation),
#     fixed errors in frame() and timecodeof()
# 2.7.1 fixed rounding errors in timecodeof()
# 2.7.2 fixed subtitle conversion logic for unusual case of no {EDM} codes
# 2.8 fixed problem with losing beginning of line in -s conversion with a mid-caption
#       formatting code,
#     fixed -s code so that most mid-row codes reset italics/underline formatting,
#     fixed -s code to output end codes for italics and underline,
#     fixed -s spacing around formatting codes,
#     fixed -s end-of-line formatting (each line must be self-contained)
# 2.9 added following CC codes: {CSS}, {CSD}, {CS1}, {CS2}, {CSC}, {CSK}, {CGU}
#     added following XDS types: C PD, C MD, F PD, F MD, H TS, M CP, M CH, M CM, P WB, P WM
#     cosmetic: updated my e-mail & web page addresses in the source code
# 2.10 added subtitle export format of Adobe Encore (.txt)
# 3.0 numerous fixes to XDS format, causing CCD format to go to 1.2:
#     fixed definition of XDS class bytes and added continuation class
#       bytes (all but Current were wrong)
#     added support for interrupted and resumed XDS packets
#     changed beginning of XDS checksum from "C" to "\C"
#     XDS ST, MD, TD, IC and CH fields re-arranged to allow interruption
#     XDS ST, MD, TD, TM and IC Tape Delay character changed from D to T
#     XDS ST, MD, TD and IC No Leap Day character changed from N to A
#     XDS PR system change: CE=0x18, CF=0x38 for byte 3, no byte 4 change
#     XDS AR changed 16:9/4:3 to A/_
#     XDS MD and NC split Call Letters with space to get Channel Number
#     Added definitions for Channel 3 and 4 codes, where they differ from
#       Channel 1/2
#     Added remaining channels to -c option
# 3.0.1 Swapped definitions of single right and single left quotation
#         marks ({rsq} and {lsq})
# 3.1 Added subtitle handling of roll-up and paint-on captions
# 3.2 Fixed spacing problem for CCD->SCC conversion
# 3.3 Fixed subtitle output to only include one channel
# 3.3.1 Bug fix to catch lines dropped by 3.3
# 3.4 Fixed character set comparison (was always using ITV set)
# 3.5 Fixed numerous XDS bugs, including using the wrong filler byte
#       (0x80 instead of 0x40)
# 3.5.1 Added check for correct word length in CCD input
# 3.6 Fixed odd parity for CCD->SCC
# 3.6.1 Bug fix for SAMI header and screen clear lines
# 3.7 Added Quicktime Caption format to subtitle export
# 3.7.1 Fixed {ldq} and {rdq} definitions.
# 3.8 Added Timed Text output (from Thomas J. Webb)
# -----------------------------------------------------------------------------------
# 0.4 Y|y - Fork code to create new conversion utility that only converts to formats
#       which preserve positioning information. Add support for unicode and 
#       conversion from g608 format.
# 0.5 Add support for background color and background alpha effects. Add TTML output.
#       Further changes to SAMI and VTT output. TTML, SAMI, and VTT output is still flawed.
# 0.6 Adjust vertical positioning math (y coordinates were not zero-indexed). Further
#       refinements to TTML generation. Output is mostly correct on VLC.
# 0.7 Add code changes from the lost 3.8 version of CCASDI. Thanks to bbgdzxng1 for
#	excavating this and sharing it with me. Rework subtitle conversion to use SSA/ASS 
#	as the default syntax, since that is our primary output format. Include 3.8 code
#	for Quicktime Caption format and add positioning to output. Add initial GPAC Timed
#	Text (TTXT) support; formatting support is not yet present, as that will require a
#	reorganization of how subtitles are generated. Add warning message to subtitle 
#	generation noting if subtitles contain features that are unsupported by the output
#	format (e.g. color, alpha). Rework how VTT and TTML generation is done in order to
#	prevent formatting errors from nested format/color changes. Adjust TTML format
#	to match SMPTE-TT spec using documentation from PBS. This includes breaking up
#	subtitles into individual entries for each line, which partially alleviates but
#	does not fully fix the display inconsistencies with the format on VLC.
sub usage;
sub frame;
sub timecodeof;
sub oddParity;
sub clearScreen;
sub rollUp;
sub convertToSub;
sub outputHeader;
sub outputSubtitle;
sub outputFooter;
sub disCommand;
sub disChar;
sub disXDS;
sub asCommand;
sub asXDS;
sub asChar;

# initial variables
my $offsettimecode = "00:00:00:00";
my $fps = 30000/1001; # NTSC framerate
my $drop = 0; # assume non-drop
my $convert = 0; # convert to subtitles: 1 = yes, 0 = no
my $convertFormat = "Advanced SubStation"; # output format for subtitle conversion
 # other choices: SAMI, SubStation Alpha, and WebVTT
my $convertModeChannel = "CC1"; # which channel to convert
 # other choices: CC2, CC3, CC4, T1, T2, T3, T4
my $subRollupMode = 0; # how to convert roll-up captions to subtitles:
 # 0 = one subtitle per line
 # 1 = closer to caption display, with lines rolling up
my $adjust = 0; # adjust timecodes to start (SCC) or display (CCD) times: 1 = yes, 0 = no
my $input = "~"; # place-holder for no input file yet
my $output = "~"; # place-holder for no output file yet
my $anything = "~";

# Y|y - new stuff
my $writeTemp = 0; # Does this format need a temp file (usually due to the header
#   needing to be added to as we do more conversion, e.g. TTML)
my $Language = "English"; # Human-readable language to list
my $LangCode = "en"; # Language code to use in file 
my $ResX = 640; # Horizontal playback resolution
my $ResY = 480; # Vertical playback resolution
# Y|y - Thanks to Emulgator for figuring out and sharing these ratios
my $Xratio = 2/3; # (480/720 lines) Horizontal portion of the screen which is usable by captions (i.e. minus overscan)
my $Yratio = 13/16; # (390/480 lines) Vertical portion of the screen which is usable by captions (i.e. minus overscan)

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
  if (s/-r//) {
    $subRollupMode = 1;
    next;
  }
  if (s/-a//) {
    $adjust = 1;
    next;
  }
#  Y|y - no longer needed
#  if (s/-s//) {
#    $convert = 1;
#    $adjust = 1;
#    next;
#  }
  if (s/-c//) {
    $convertModeChannel = $_;
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
# print ("\Drop: ", $drop);

if ($anything eq "~") {
  usage();
  exit;
}

my $ok = 0;
my $convertChannel = 1;
my $convertMode = "CC";
if ($convertModeChannel eq "CC1") {
  $convertChannel = 1;
  $convertMode = "CC";
  $ok = 1;
}
if ($convertModeChannel eq "CC2") {
  $convertChannel = 2;
  $convertMode = "CC";
  $ok = 1;
}
if ($convertModeChannel eq "CC3") {
  $convertChannel = 3;
  $convertMode = "CC";
  $ok = 1;
}
if ($convertModeChannel eq "CC4") {
  $convertChannel = 4;
  $convertMode = "CC";
  $ok = 1;
}
if ($convertModeChannel eq "T1") {
  $convertChannel = 1;
  $convertMode = "Text";
  $ok = 1;
}
if ($convertModeChannel eq "T2") {
  $convertChannel = 2;
  $convertMode = "Text";
  $ok = 1;
}
if ($convertModeChannel eq "T3") {
  $convertChannel = 3;
  $convertMode = "Text";
  $ok = 1;
}
if ($convertModeChannel eq "T4") {
  $convertChannel = 4;
  $convertMode = "Text";
  $ok = 1;
}
if ($ok == 0) {
  usage();
  die "Channel to convert must be CC1 - CC4 or T1 - T4, stopped";
}

if ($input eq "~") {
  usage();
  die "No input file, stopped";
}

my $assemble = -1; # 1 to assemble, 0 to disassemble, 2 for Grid 608
my $suffix = ".ass"; # Default to Advanced SubStation
if ($output eq "~") {
  if ($input =~ m/(.*)(\.scc)$/i) {
      $convert = 1;
      $output = $1.$suffix;
  }
  elsif ($input =~ m/(.*)(\.ccd)$/i) {
    $output = $1.".scc";
  }
# Y|y - If we're loading Grid 608 format, convert to default subtitle format
  elsif ($input =~ m/(.*)(\.g608)$/i) {
    $output = $1.$suffix;
    $convert = 1;
    $assemble = 2;
  }
} else {
   $convertFormat = "~";
   if ($output =~ m/.*\.(.*)$/) {
     $suffix = $1;
     if ($suffix =~ m/ccd/i) { 
       if ($input =~ m/(.*)(\.scc)$/i) {
         $convertFormat = "SCC Disassembly"; 
       }
       else {
         die "SCC Disassembly output can only be converted from an SCC input file, stopped.";
       }
     }
     else {
       if ($suffix =~ m/vtt/i) { $convertFormat = "WebVTT"; }
       elsif ($suffix =~ m/smi|sami/i) { $convertFormat = "SAMI"; }
       elsif ($suffix =~ m/ssa/i) { $convertFormat = "SubStation Alpha"; }
       elsif ($suffix =~ m/ass/i) { $convertFormat = "Advanced SubStation"; }
       elsif ($suffix =~ m/ttml|dfxp/i) { $convertFormat = "Timed Text Markup Language"; } # $writeTemp = 1;
       elsif ($suffix =~ m/ttxt/i) { $convertFormat = "GPAC Timed Text"; }
       elsif ($output =~ m/(.*)(\.qt\.txt)$/i) { $convertFormat = "Quicktime Caption"; $suffix = ".qt.txt"; }
       $convert = 1;
     }
   }
   if ($convertFormat eq "~") {
     usage();
     die "Unrecognized output file suffix $suffix, stopped";
   }
   if ($input =~ m/(.*)(\.g608)$/i) {
     $assemble = 2;
   }
}
if ($output eq "~") {
  usage();
  die "Input file must have .scc, .ccd, or .g608 extension, stopped";
}

if (($fps < 12)||($fps > 60)) {
  usage();
  die "Frames per second $fps out of range, stopped";
}

if (($offsettimecode =~ m/\d\d:\d\d:\d\d[:;]\d\d/) != 1) {
  usage();
  die "Wrong format for offset, stopped";
}

if ($input eq $output) {
  die "Input and output files cannot be the same, stopped";
}
# Y|y - Some formats require adding to the header as we go, so we write the body to a temp file and append the contents once we're done
if($writeTemp) {
  open (TH, '+>:encoding(UTF-8)', $output.".temp") or die "Unable to write to temp file: $!";
  print TH "\n"; # Sometimes writing the first line doesn't work, so write a blank line just to "prime" the temp file, so to speak
}
# Need to determine type of input file
open (RH, '<:encoding(UTF-8)', $input) or die "Unable to read from file: $!";
my $header = <RH>;
my $outputheader = "";
chomp $header;
(my $formattype, my $formatversion) = split (/ /, $header);
if ($formattype eq "Scenarist_SCC") {
  $assemble = 0;
  $outputheader = "SCC_disassembly V1.2\n";
}
if ($formattype eq "SCC_disassembly") {
  $assemble = 1;
  if ($convert) {
    die "Cannot convert CCD format to subtitles, stopped";
  }
  $outputheader = "Scenarist_SCC V1.0\n";
}
my $channel = -1; # can be 1 - 4
my $line;
my $timecode;
my @words;
my $hi;
my $lo;
my $skip;
if ($assemble == 1) {
  $line = <RH>;
  chomp $line;
  (my $channelcommand, $channel) = split(/ /, $line);
  # "FIELD" is backward-compatability of 1.0 of CCD, when I incorrectly used the word
  #  "field" to describe channels
  if (($channelcommand ne "CHANNEL") && ($channelcommand ne "FIELD")) {
    $channel = -1;
  }
  if (($channel < 1) or ($channel > 4)) {
    die "CHANNEL set incorrectly, stopped";
  }
} elsif($assemble == 0) {
  $channel = 1; # can be 1 - 4
  do {
    $line = <RH>;
  } until $line ne "\n";
  chomp $line;
  ($timecode, @words) = split(/\s/, $line);
  $words[0] =~ m/(..)(..)/;
  $hi = $1;
  # first word in file will be start caption command, in which case
  #  high byte will reveal channel
  # assume channel is 3 otherwise (XDS)
  $channel = 3;
  if ($hi eq "94") {
    $channel = 1;
  }
  if ($hi eq "1c") {
    $channel = 2;
  }
  if ($hi eq "15") {
    $channel = 3;
  }
  if ($hi eq "9d") {
    $channel = 4;
  }
  $outputheader = $outputheader."CHANNEL ".$channel."\n";
  close RH;
  open (RH, '<:encoding(UTF-8)', $input) or die "Unable to read from file: $!";
  # skip first two lines
  $skip = <RH>;
  $skip = <RH>;
}
elsif ($assemble == 2){
# Y|y - Go back to the beginning of the file
  seek (RH, 0, 0);
}
else {
  die "Unrecognized input format, stopped";
}

open (WH, '>:encoding(UTF-8)', $output) or die "Unable to write to file: $!";
# header
if ($convert) {
  outputHeader($convertFormat);
} else { # SCC to CCD or vice-versa
  print WH $outputheader;
  print WH "\n";
}
my $offset = frame($offsettimecode);

# Conversion Variables
my $row = 1;
my $col = 0;
# Y|y - New stuff for finding positioning
my $startx = 39;
my $starty = 16;
my $endx = 0;
my $endy = 1;
# Y|y - Variable to track the positioning regions we have already made for TTML and SAMI
my $regionList = "";
# Initialize ALL THE THINGS
clearScreen();
my $startTime = ""; # start time of subtitle
my $endTime = ""; # end time of subtitle
my $subtitle = ""; # converted subtitle
my $subtitleNumber = 0; # counter used by... well, nothing we output to, but it helps us track subtitles all the same
# for interrupted/continued XDS sequences
my %XDSPosition = ( 'ST' => 0, 'PL' => 0, 'PN' => 0, 'PT' => 0, 'PR' => 0,
                    'AS' => 0, 'CS' => 0, 'CG' => 0, 'AR' => 0, 'PD' => 0,
                    'MD' => 0, 'D1' => 0, 'D2' => 0, 'D3' => 0, 'D4' => 0,
                    'D5' => 0, 'D6' => 0, 'D7' => 0, 'D8' => 0, 'NN' => 0,
                    'NC' => 0, 'TD' => 0, 'TS' => 0, 'TM' => 0, 'IC' => 0,
                    'SD' => 0, 'TZ' => 0, 'OB' => 0, 'CP' => 0, 'CH' => 0,
                    'CM' => 0, 'WB' => 0, 'WM' => 0, 'XX' => 0 );
my %XDSSum = ( 'ST' => 0, 'PL' => 0, 'PN' => 0, 'PT' => 0, 'PR' => 0,
               'AS' => 0, 'CS' => 0, 'CG' => 0, 'AR' => 0, 'PD' => 0,
               'MD' => 0, 'D1' => 0, 'D2' => 0, 'D3' => 0, 'D4' => 0,
               'D5' => 0, 'D6' => 0, 'D7' => 0, 'D8' => 0, 'NN' => 0,
               'NC' => 0, 'TD' => 0, 'TS' => 0, 'TM' => 0, 'IC' => 0,
               'SD' => 0, 'TZ' => 0, 'OB' => 0, 'CP' => 0, 'CH' => 0,
               'CM' => 0, 'WB' => 0, 'WM' => 0, 'XX' => 0 );
my $frames;
my $outline; # line to be outputted (after timecode)
my @chars;
my $numwords;
my $newword;
my $iscommand;
my $isword;
my $wasword;
my $command;
my $char;
my $string;
my $lastword;
my $word;
my $token;
my @character;  # grid of characters for subtitle conversion: [row][col]
my @color;      # grid of color codes for subtitle conversion: [row][col]
my $color;      # color of current position
my @underlined; # grid of underline flags for subtitle conversion: [row][col]
my $underlined; # underline flag of current position
my @italicized; # grid of italicize flags for subtitle conversion: [row][col]
my $italicized; # italicize flag of current position
my $lastcode;

# Y|y - New stuff. Rarely used stuff, but stuff we can support all the same
my @bgcolor; # grid of background color flags for subtitle conversion: [row][col]
my $bgcolor; # background color flag of current position

# read loop
my $lastframe = -1;
my $mode = "CC"; # other values are Text, XDS, and ITV
my $ccMode = ""; # choices are pop-up, roll-up, and paint-on
my $ruBottom = 15; # bottom row for roll-up captions
my $ruHeight = 0; # height of roll-up window
my @xdslist = (); # used for parsing eXtended Data Service messages
LINELOOP: while (<RH>) {
  #if ($_ eq "\n") {
  if ($_ =~ m/^\s+$/){
    # Y|y - For g608 a blank newline indicates the end of a caption, so output what we have
    if($assemble == 2 and $row > 1){
      $subtitle = convertToSub();
      outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
      clearScreen();
      $startTime = ""; # This stops the last subtitle from being written twice when we close out the file
    }
    next LINELOOP;
  }
  if ($assemble == 1) {
    chomp;
    # Assemble line
    m/(\S+)(\s)(.+)/; # split into timecode and rest of line
    ($timecode, $skip, $line) = ($1, $2, $3);
    # catch blank last line
    if ($timecode eq "") {
      next LINELOOP;
    }
    # allow ability to change channel in mid-file
    # "FIELD" is backward-compatabile with CCD version 1.0
    if (($timecode eq "CHANNEL") || ($timecode eq "FIELD")) {
      $channel = $3;
      next LINELOOP;
    }
    $frames = frame($timecode);
    if ($frames <= $lastframe) {
      print "Warning: Timecode $timecode is out of order in line $.\n";
    }
    $lastframe = $frames;
    $outline = "";
    (@chars) = split(//, $line);
    $numwords = -1; # subtract one for double EOC command
    $newword = 1; # flag for when to insert space
    $iscommand = 0; # flag for command ({X}) or character (X)
    $isword = 0; # flag for word (xxxx) or byte (xx)
    $wasword = 1; # set to word to ensure first output is spaced
    $command = ""; # placeholder for no command parsed
    CHARLOOP: foreach $char (@chars) {
      $string = ""; # output: could be byte (for character) or word (for command)
      if (not ($iscommand) and ($char eq "{")) {
        $command = "";
        $iscommand = 1;
        next CHARLOOP;
      }
      if (($iscommand) and ($char ne "}")) {
        $command = $command.$char;
        next CHARLOOP;
      }
      if (($iscommand) and ($char eq "}")) {
        $string = asCommand($command); # call also sets $mode
        $isword = 1;
        $iscommand = 0;
      }
      if (not ($iscommand) and ($char ne "}")) {
        $string = asChar($char);
        $isword = 0;
      }
      if ($string eq "") {
        print "Mismatched braces in line $.\n";
        next CHARLOOP;
      }
      if ($isword) {
        $newword = 1;
      } else {
        $newword = 1 - $newword;
      }
      # print $isword.$wasword." ";
      # special case of byte following word
      if (not ($isword) and ($wasword)) {
        $newword = 1;
      }
      if ($newword) {
        $outline = $outline." ";
        ++$numwords;
      }
      $outline = $outline.$string;
      $wasword = $isword; # was last string a word or a byte
      next CHARLOOP;
    }
    $frames += $offset;
    # adjusting with assembly goes from display time to start time
    if ($adjust) {
      $frames -= $numwords;
    }
    if ($frames < 0) {
      $frames = 0;
    }
    $timecode = timecodeof($frames);
  } elsif ($assemble == 0) {
    chomp;
    # Disassemble line
    ($timecode, @words) = split(/\s/, $_);
    # catch blank lines
    if ($timecode eq "") {
      next LINELOOP;
    }
    $frames = frame($timecode);
    if ($frames <= $lastframe) {
      # Y|y - All formats we convert to can handle out of order subtitles, but flag a warning just in case
      print "Warning: Timecode $timecode is out of order ($lastframe --> $frames)\n";
    }
    $lastframe = $frames;
    $outline = " "; # line to be outputted (after timecode)
    $numwords = -1; # subtract one for double EOC command
    $lastword = ""; # used in subtitle conversion to prevent repeats
    # check to see if channel has changed
    $words[0] =~ m/(..)(..)/;
    $hi = hex $1;
    if ($hi > 127) {$hi -= 128;}
    if (($channel != 1) and ($hi == 0x14)) {
      $channel = 1;
      if (not $convert) {
        print WH "CHANNEL 1\n";
      }
    }
    if (($channel != 2) and ($hi == 0x1c)) {
      $channel = 2;
      if (not $convert) {
        print WH "CHANNEL 2\n";
      }
    }
    # XDS is Channel 3
    if (($channel != 3) and ((($hi >= 0x01) and ($hi <= 0x0f)) or ($hi == 0x15))) {
      $channel = 3;
      if (not $convert) {
        print WH "CHANNEL 3\n";
      }
    }
    if (($channel != 4) and ($hi == 0x1d)) {
      $channel = 4;
      if (not $convert) {
        print WH "CHANNEL 4\n";
      }
    }
    WORDLOOP: foreach $word (@words) {
      $numwords = $numwords + 1;
      if (length($word) != 4) {
        $outline =~ m/^( )(.+)/;
        $outline = $2;
        if ($convert == 0) {
          print WH $timecode."\t".$outline."\n";
          if ($assemble) {
            print WH "\n";
          }
        }
        die "Incorrect word length for word $numwords, timecode $timecode, stopped";
      }
      $word =~ m/(..)(..)/;
      $hi = hex $1;
      $lo = hex $2;
      if ($hi > 127) {$hi -= 128;}
      if ($lo > 127) {$lo -= 128;}
      $char = "";
      if (($hi == 0x00) and ($lo == 0x00)) {
        $token = ($convert) ? "" : "{}";
        $outline = $outline.$token;
      }
      # XDS messsage starts with 0x0? and ends with 0x0F checksum
      if (($hi >= 0x01) and ($hi < 0x0F)) {
        $mode = "XDS";
        @xdslist = ($hi, $lo);
      }
      if ($hi == 0x0F) {
        push @xdslist, ($hi, $lo);
        # XDS dropped in subtitle conversion
        if (not $convert) {
          $outline = $outline.disXDS(@xdslist);
        }
        $mode = "CC";
      }
      if (($hi >= 0x10) and ($hi < 0x1F)) {
        # check for interrupted XDS
        if ($mode eq "XDS") {
          #print $xdslist[0].", ".$xdslist[1]."\n";
          # XDS dropped in subtitle conversion
          if (not $convert) {
            $outline = $outline.disXDS(@xdslist);
          }
          $mode = "CC";
        }
        # skip second in duplicate pair if converting
        if (($convert) and ($lastword eq $word)) {
          $lastword = "";
          next WORDLOOP;
        }
        $lastword = $word;
        $token = disCommand($hi, $lo);
        # print "\n";
        if ($token ne "") {
          $character[$row][$col] = $token;
          $color[$row][$col] = $color;
          $underlined[$row][$col] = $underlined;
          $italicized[$row][$col] = $italicized;
          $bgcolor[$row][$col] = $bgcolor;
          $col++;
        }
        $outline = $outline.$token;
      }
      if ($hi >= 0x20) {
        if ($mode eq "XDS") {
          push @xdslist, ($hi, $lo);
          next WORDLOOP;
        } else {
          my $hiChar = disChar($hi);
          my $loChar = disChar($lo);
          $outline = $outline.$hiChar.$loChar;
          if ($hiChar ne "") {
            $character[$row][$col] = $hiChar;
            $color[$row][$col] = $color;
            $underlined[$row][$col] = $underlined;
            $italicized[$row][$col] = $italicized;
            $bgcolor[$row][$col] = $bgcolor;
            $col++;
          }
          if ($loChar ne "") {
            $character[$row][$col] = $loChar;
            $color[$row][$col] = $color;
            $underlined[$row][$col] = $underlined;
            $italicized[$row][$col] = $italicized;
            $bgcolor[$row][$col] = $bgcolor;
            $col++;
          }
        }
        $lastcode = "";
      }
      next WORDLOOP;
    }
    $frames += $offset;
    # adjusting with disassembly goes from start time to display time
    if ($adjust) {
      $frames += $numwords;
    }
    if ($frames < 0) {
      $frames = 0;
    }
    $timecode = timecodeof($frames);
  }
  # Y|y - Grid 608 processing
  else {
    # Check if the whole line is an integer, i.e. the subtitle number, which we really don't need except for debugging
    if ($_ =~ m/^[0-9]+\s$/){
      $subtitleNumber = int($_)-1;
      next LINELOOP;
    }
    # Check for the starttime --> endtime line
    elsif(length($_) >= 30 and index($_, " --> ") == 12){ # Line length and positioning are fixed for timecodes in g608
      # Get the start time, but convert from g608 formatting (00:00:00,000) to internal 00:00:00:00. Convert miliseconds to framecount
      $startTime = substr($_,0,8).":".(substr($_,9,3)*$fps)/1000;
      $endTime = substr($_,17,8).":".(substr($_,26,3)*$fps)/1000;
    }
    # Caption lines will be at least 98 characters long (with line break)
    elsif(length($_) >= 98){
      # check for invalid characters in the color and style definitions
      if(!(substr($_,33,32) =~ m/^[0-9]+$/ and substr($_,65,32) =~ m/^[BIRU]+$/)){
        die "Invalid characters found in g608 file in subtitle ($subtitleNumber+1) : $_";
      }
      # don't process rows we can immediately consider blank: all 9s in the color definition, all whitespace in the character list
      if(!(substr($_,33,32) =~ m/^9+$/ or substr($_,0,32) =~m/^\s+$/)){
        for(my $_x = 0; $_x < 32; $_x++){
          if(substr($_,$_x+33,1) != "9"){
            # Copy the character
            $character[$row][$_x] = substr($_,$_x,1);
            # Copy formatting
            if(substr($_,$_x+65,1) =~ m/[BI]/){
              $italicized[$row][$_x] = 1;
            }
            if(substr($_,$_x+65,1) =~ m/[BU]/){
              $underlined[$row][$_x] = 1;
            }
            # Copy color
            $color[$row][$_x] = substr($_,$_x+33,1);
          }
        }
      }
      $row++;
    }
    else{
      print "Unidentified line type, length ".length($_)."\n";
      print $_."\n";
    }
  }
  # catch interrupted XDS packets
  if ($mode eq "XDS") {
    if (not $convert) {
      $outline = $outline.disXDS(@xdslist);
    }
    $mode = "CC";
  }
  # start line
  # remove first space
  $outline =~ m/^( )(.+)/;
  $outline = $2;
  if ($convert == 0) {
    print WH $timecode."\t".$outline."\n";
    if ($assemble) {
      print WH "\n";
    }
  }
  next LINELOOP;
}
# footer
if ($convert) {
  if ($endTime eq "") {
    $endTime = timecodeof($frames + $offset + $numwords);
  }
  outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
  outputFooter ($convertFormat);
}
close WH;
close RH;
exit;

sub usage {
  printf "\nyyC2Swp Version %s\n", $Version;
  print "  Y|yukichigai's Caption to Subtitle (with positioning!)\n";
  print "  Converts Scenarist Closed Captions or Grid 608 files to subtitles while\n";
  print "    preserving positioning information. Also converts to SCC Dissasembly.\n";
  print "  Based on CCASDI by McPoodle.\n";
  print "  Syntax: yyC2Swp [-cCC3] [-a] [-o01:00:00:00] [-td] infile.scc [outfile.ass]\n";
  print "    -c (OPTIONAL; SCC only): Channel to convert to subtitle.\n";
  print "         (CC1 default, CC2, CC3, CC4, T1, T2, T3 and T4 are other choices)\n";
  print "    -r (OPTIONAL): Output roll-up subtitles in roll-up format, instead of\n";
  print "         one line at a time\n";
  print "    -a (OPTIONAL): Adjust timecodes to be start time for SCC\n";
  print "         and display time for dissassembly\n";
  print "    -o (OPTIONAL): Offset to apply to timecodes, in HH:MM:SS:FF format\n";
  print "         (DEFAULT: 00:00:00:00, negative values are permitted)\n";
  print "    -f (OPTIONAL): Number of frames per second (range 12 - 60) (DEFAULT: 29.97)\n";
  print "    -t (OPTIONAL; automatically sets fps to 29.97):\n";
  print "         NTSC timebase: d (dropframe) or n (non-dropframe) (DEFAULT: n)\n";
  print "  NOTE: outfile argument is optional (name.scc/g608 -> name.ass). Format is\n";
  print "    controlled by outfile suffix: .vtt WebVTT, .smi/.sami SAMI, .ssa SubStation Alpha,\n";
  print "    .ttml/.dfxp SMPTE-TT/Timed Text Markup Language, .qt.txt Quicktime Caption,\n";
  print "    .ttxt GPAC Timed Text, .ass Advanced SubStation (default),\n";
  print "    .ccd SCC Disassembly (SCC input only).\n\n";
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
  my $dm = sprintf("%d", $mm/10); # "deci-minutes"
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
  return sprintf("%d", $framecount + 0.5);
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
  my $hh = sprintf("%d", $frames / $divisor);
  my $remainder = $frames - ($hh * $divisor);
  # tens of minutes (required by drop-frame)
  $divisor = 600 * $fps;
  if ($drop) {
    $divisor -= 18; # number of frames dropped every 10 minutes
  }
  my $dm = sprintf("%d", $remainder / $divisor);
  $remainder = $remainder - ($dm * $divisor);
  # single minutes
  $divisor = 60 * $fps;
  if ($drop) {
    $divisor -= 2; # number of frames dropped every minute except the 10th
  }
  my $sm = sprintf("%d", $remainder / $divisor);
  my $mm = $dm * 10 + $sm;
  $remainder = $remainder - ($sm * $divisor);
  # seconds
  my $ss = sprintf("%d", $remainder / $fps);
  # frames
  $remainder -= ($ss * $fps);
  my $ff = sprintf("%d", $remainder + 0.5);
  
  # correct for calculation errors that would produce illegal timecodes
  if ($ff > sprintf("%d", $fps)) { $ff = 0; $ss++;}
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

# subroutine to reset subtitle conversion variables for clear screen
sub clearScreen {
  for (my $row=1; $row < 17; $row++) {
    for (my $col=0; $col < 40; $col++) { # should be 32, but I'm being safe
      $character[$row][$col] = "\x00";
      $color[$row][$col] = "0";
       # other colors are Green, Blue, Cyan, Red, Yellow, Magenta, and Black
      $underlined[$row][$col] = 0;
      $italicized[$row][$col] = 0;
      # The flash effect can only KIND OF be implemented in ASS. It will need to be approximated.
      #  Ignored for now.
      # On the other hand, background color and alpha level for text channels is possible with
      #  newer subtitle formats: ASS supports it baseline, as do stylesheet-aware WebVTT parsers
      #  (though there are few of those). Similarly, SAMI and TTML support these changes in theory,
      #  again provided that the parser interprets styles/stylesheets. SSA also technically can
      #  produce background color/alpha changes, though only for entire subtitles. Hell, I think
      #  the old S2K format supports it, though I'm not going to add support for that. Probably.
      #  ....
      #  ...maybe just because I can?
      $bgcolor[$row][$col] = "B";
    }
  }
  $row = 1;
  $col = 0;
  $color = "0";
  $underlined = 0;
  $italicized = 0;
  $bgcolor = "B";
}

# subroutine to roll up lines when {CR} is received in roll-up mode
sub rollUp {
  my $row;
  my $col;
  for ($row = $ruBottom - $ruHeight + 1; $row <= $ruBottom; $row++) {
    for ($col = 0; $col < 40; $col++) { # should be 32, but I'm being safe
      $character[$row][$col] = $character[$row+1][$col];
      $color[$row][$col] = $color[$row+1][$col];
      $underlined[$row][$col] = $underlined[$row+1][$col];
      $italicized[$row][$col] = $italicized[$row+1][$col];
      $bgcolor[$row][$col] = $bgcolor[$row+1][$col];
    }
  }
}

# subroutine to convert caption grid into subtitle string
sub convertToSub {
  # print $character[1][0]."\n";
  my $subtitle = "";
  $color = "0";
  $underlined = 0;
  $italicized = 0;
  $bgcolor = "B";

  $startx = 39;
  $starty = 16;
  $endx = 0;
  $endy = 1;
  
  my $preformat = 0;

  # Y|y - Find the bounds of the printable characters in the caption
  for (my $x = 0; $x < 40; $x++){
    for (my $y = 1; $y < 17; $y++){
      if ($character[$y][$x] ne "\x00"){
        if($startx > $x){
          $startx = $x;}
        if($starty > $y){
          $starty = $y;}
        if($endx < $x){
          $endx = $x;}
        if($endy < $y){
          $endy = $y;}
      }
    }
  }

  # Most uses of these values require us to add 1 to them, so just do that now
  $endy++;
  $endx++;

  for (my $_row = $starty; $_row < $endy; $_row++) {
    # Write a new line if this isn't the first row. We need to do this here
    #  rather than the end of the loop because we might need to close out style
    #  tags on the final line of the subtitle
    if ($_row > $starty){
      # TTML has to be output per-line, so we need to close the span tags if there are any open (and reset values)
      if(($convertFormat eq "Timed Text Markup Language") and (($color ne "0") or ($bgcolor ne "B") or ($italicized) or ($underlined))){
        $subtitle = $subtitle."</span>";
        $color = "0";
        $bgcolor = "B";
        $italicized = 0;
        $underlined = 0;
      }
      $subtitle = $subtitle."\n";
    }
    for (my $_col = $startx; $_col < $endx; $_col++) {
      if ($character[$_row][$_col] eq "\x00") {
        $subtitle = $subtitle."\xa0"; # add a no-break space
      # Y|y - new stuff. Some formats need special handling during construction, not after (TTML, TTXT, VTT)
      } elsif ($convertFormat eq "Timed Text Markup Language") { # TTML uses span tags for EVERYTHING, so nesting them risks inaccurate conversion. Whenever there is a format change we need to close the span and open a new one
        # Any formatting change means we need to redo span tags
        $preformat = 1;
        if(($color[$_row][$_col] ne $color) or ($underlined[$_row][$_col] ne $underlined) or ($italicized[$_row][$_col] ne $italicized) or ($bgcolor[$_row][$_col] ne $bgcolor)){
          # If there were any existing formats then we need to close the span
          if(($color ne "0") or ($bgcolor ne "B") or ($underlined) or ($italicized)){
            $subtitle = $subtitle."</span>";
          }
          # If there's anything different from default, start a new span
          if(($color[$_row][$_col] ne "0") or ($bgcolor[$_row][$_col] ne "B") or $italicized[$_row][$_col] or $underlined[$_row][$_col]){
            # Start the span
            $subtitle = $subtitle."<span";
            # Now see what changed. Start with color
            if($color[$_row][$_col] ne "0"){
              if ($color[$_row][$_col] eq "0") { # White
                $subtitle = $subtitle." tts:color=\"white\"";
              }
              if ($color[$_row][$_col] eq "1") { # Green (Lime in modern standards)
                $subtitle = $subtitle." tts:color=\"lime\"";
              }
              if ($color[$_row][$_col] eq "2") { # Blue
                $subtitle = $subtitle." tts:color=\"blue\"";
              }
              if ($color[$_row][$_col] eq "3") { # Cyan (AKA Aqua)
                $subtitle = $subtitle." tts:color=\"cyan\"";
              }
              if ($color[$_row][$_col] eq "4") { # Red
                $subtitle = $subtitle." tts:color=\"red\"";
              }
              if ($color[$_row][$_col] eq "5") { # Yellow
                $subtitle = $subtitle." tts:color=\"yellow\"";
              }
              if ($color[$_row][$_col] eq "6") { # Magenta (AKA Fuchsia)
                $subtitle = $subtitle." tts:color=\"magenta\"";
              }
              if ($color[$_row][$_col] eq "8") { # Black
                $subtitle = $subtitle." tts:color=\"black\"";
              }
            }
            # Now background color (and alpha)
            if ($bgcolor[$_row][$_col] ne "B") {
              # Check if the background color changed or just the transparency (upper vs lower)
              # Start with the color portion
              if(uc($bgcolor) ne uc($bgcolor[$_row][$_col])){
  	        if (uc($bgcolor[$_row][$_col]) eq "W") { # White
	          $subtitle = $subtitle." tts:backgroundColor=\"#FFFFFF"; 
    	        }
  	        if (uc($bgcolor[$_row][$_col]) eq "G") { # Green
                  $subtitle = $subtitle." tts:backgroundColor=\"#00FF00";
                }
                if (uc($bgcolor[$_row][$_col]) eq "U") { # Blue
                  $subtitle = $subtitle." tts:backgroundColor=\"#0000FF";
                }
                if (uc($bgcolor[$_row][$_col]) eq "C") { # Cyan
                  $subtitle = $subtitle." tts:backgroundColor=\"#00FFFF";
                }
                if (uc($bgcolor[$_row][$_col]) eq "R") { # Red
                  $subtitle = $subtitle." tts:backgroundColor=\"#FF0000";
                }
                if (uc($bgcolor[$_row][$_col]) eq "Y") { # Yellow
                  $subtitle = $subtitle." tts:backgroundColor=\"#FFFF00";
                }
                if (uc($bgcolor[$_row][$_col]) eq "M") { # Magenta
                  $subtitle = $subtitle." tts:backgroundColor=\"#FF00FF";
                }
                if (uc($bgcolor[$_row][$_col]) eq "B") { # Black
                  $subtitle = $subtitle." tts:backgroundColor=\"#000000";
                }
              }
              # Handle transparency
              if (uc($bgcolor[$_row][$_col]) eq "T") { # Transparent
                $subtitle = $subtitle." tts:backgroundColor=\"transparent\"";
              }
              elsif(uc($bgcolor) eq $bgcolor and uc($bgcolor[$_row][$_col]) ne $bgcolor[$_row][$_col]){ # Semi-transparent (lowercase)
  	        $subtitle = $subtitle."80\"";
	      }
	      elsif(uc($bgcolor) ne $bgcolor and uc($bgcolor[$_row][$_col]) eq $bgcolor[$_row][$_col]){ # Opaque (uppercase)
	        $subtitle = $subtitle."FF\"";
	      }
            }
            if($italicized[$_row][$_col]){
              $subtitle = $subtitle." tts:fontStyle=\"italic\"";
            }
            if($underlined[$_row][$_col]){
              $subtitle = $subtitle." tts:textDecoration=\"underline\"";
            }
            $subtitle = $subtitle.">";
          }
        }
        # Finally, copy over the formatting tags and the new character
        $color = $color[$_row][$_col];
        $bgcolor = $bgcolor[$_row][$_col];            
        $italicized = $italicized[$_row][$_col];
        $underlined = $underlined[$_row][$_col];
        $subtitle = $subtitle.$character[$_row][$_col];
      } elsif ($convertFormat eq "WebVTT") { # WebVTT uses cue tags for color changes. Fortunately italic and underline just use normal html tags
        $preformat = 1;
        # Any color change means we need to close out the old cue tag and/or write a new one
        if(($color[$_row][$_col] ne $color) or ($bgcolor[$_row][$_col] ne $bgcolor)){
          # Close out any existing colors
          if(($color ne "0") or ($bgcolor ne "B")){
            $subtitle = $subtitle."</c>";
          }
          # Color differences from default require a new cue tag
          if(($color[$_row][$_col] ne "0") or ($bgcolor[$_row][$_col] ne "B")){
            # Start the cue tag
            $subtitle = $subtitle."<c";
            # Now see what changed. Start with color
            if($color[$_row][$_col] ne "0"){
              if ($color[$_row][$_col] eq "0") { # White
                $subtitle = $subtitle.".white";
              }
              if ($color[$_row][$_col] eq "1") { # Green (Lime in modern standards)
                $subtitle = $subtitle.".lime";
              }
              if ($color[$_row][$_col] eq "2") { # Blue
                $subtitle = $subtitle.".blue";
              }
              if ($color[$_row][$_col] eq "3") { # Cyan 
                $subtitle = $subtitle.".cyan";
              }
              if ($color[$_row][$_col] eq "4") { # Red
                $subtitle = $subtitle.".red";
              }
              if ($color[$_row][$_col] eq "5") { # Yellow
                $subtitle = $subtitle.".yellow";
              }
              if ($color[$_row][$_col] eq "6") { # Magenta
                $subtitle = $subtitle.".magenta";
              }
              if ($color[$_row][$_col] eq "8") { # Black
                $subtitle = $subtitle.".black";
              }
            }
            # Now background color (and alpha)
            if ($bgcolor[$_row][$_col] ne "B") {
              # Check if the background color changed or just the transparency (upper vs lower)
              # Start with the color portion
              if(uc($bgcolor) ne uc($bgcolor[$_row][$_col])){
  	        if (uc($bgcolor[$_row][$_col]) eq "W") { # White
	          $subtitle = $subtitle.".bg_white"; 
    	        }
  	        if (uc($bgcolor[$_row][$_col]) eq "G") { # Green (Lime)
                  $subtitle = $subtitle.".bg_lime";
                }
                if (uc($bgcolor[$_row][$_col]) eq "U") { # Blue
                  $subtitle = $subtitle.".bg_blue";
                }
                if (uc($bgcolor[$_row][$_col]) eq "C") { # Cyan
                  $subtitle = $subtitle.".bg_cyan";
                }
                if (uc($bgcolor[$_row][$_col]) eq "R") { # Red
                  $subtitle = $subtitle.".bg_red";
                }
                if (uc($bgcolor[$_row][$_col]) eq "Y") { # Yellow
                  $subtitle = $subtitle.".bg_yellow";
                }
                if (uc($bgcolor[$_row][$_col]) eq "M") { # Magenta
                  $subtitle = $subtitle.".bg_magenta";
                }
                # Commenting out since we want black to be converted as transparent.
                #  Later I'll add a mode to enable caption backgrounds by default
#                if (uc($bgcolor[$_row][$_col]) eq "B") { # Black
#                  $subtitle = $subtitle.".bg_black";
#                }
              }
              # Commenting this out for now. No premade classes for transparency. Need to add custom ones. TO DO
#              if (uc($bgcolor[$_row][$_col]) eq "T") { # Transparent
#                $subtitle = $subtitle." tts:backgroundColor=\"transparent\"";
#              }
#              elsif(uc($bgcolor) eq $bgcolor and uc($bgcolor[$_row][$_col]) ne $bgcolor[$_row][$_col]){ # Semi-transparent (lowercase)
#  	        $subtitle = $subtitle."80\"";
#	      }
#	      elsif(uc($bgcolor) ne $bgcolor and uc($bgcolor[$_row][$_col]) eq $bgcolor[$_row][$_col]){ # Opaque (uppercase)
#	        $subtitle = $subtitle."FF\"";
#	      }
            }
            $subtitle = $subtitle.">";
          }
        }
        # Italics and underline are handled as normal
        if ($underlined[$_row][$_col] ne $underlined) {
          $subtitle = $subtitle.(($underlined[$_row][$_col]) ? "<u>" : "</u>");
          $underlined = $underlined[$_row][$_col];
        }
        if ($italicized[$_row][$_col] ne $italicized) {
          $subtitle = $subtitle.(($italicized[$_row][$_col]) ? "<i>" : "</i>");
          $italicized = $italicized[$_row][$_col];
        }
        # Finally, copy over the formatting tags and the new character
        $color = $color[$_row][$_col];
        $bgcolor = $bgcolor[$_row][$_col];            
        $subtitle = $subtitle.$character[$_row][$_col];
      } else {
        if ($color[$_row][$_col] ne $color) {
          if ($color[$_row][$_col] eq "0") { # White
            $subtitle = $subtitle."{\\c&HFFFFFF&}";
          }
          if ($color[$_row][$_col] eq "1") { # Green
            $subtitle = $subtitle."{\\c&H00FF00&}";
          }
          if ($color[$_row][$_col] eq "2") { # Blue
            $subtitle = $subtitle."{\\c&HFF0000&}";
          }
          if ($color[$_row][$_col] eq "3") { # Cyan
            $subtitle = $subtitle."{\\c&HFFFF00&}";
          }
          if ($color[$_row][$_col] eq "4") { # Red
            $subtitle = $subtitle."{\\c&H0000FF&}";
          }
          if ($color[$_row][$_col] eq "5") { # Yellow
            $subtitle = $subtitle."{\\c&H00FFFF&}";
          }
          if ($color[$_row][$_col] eq "6") { # Magenta
            $subtitle = $subtitle."{\\c&HFF00FF&}";
          }
          if ($color[$_row][$_col] eq "8") { # Black
            $subtitle = $subtitle."{\\c&H000000&}";
          }
          $color = $color[$_row][$_col];
        }
        if ($bgcolor[$_row][$_col] ne $bgcolor) {
          # Check if the background color changed or just the transparency (upper vs lower)
          if(uc($bgcolor) ne uc($bgcolor[$_row][$_col])){
	    if (uc($bgcolor[$_row][$_col]) eq "W") { # White
	          $subtitle = $subtitle."{\\c3&HFFFFFF&}"; 
	    }
	    if (uc($bgcolor[$_row][$_col]) eq "G") { # Green
              $subtitle = $subtitle."{\\c3&H00FF00&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "U") { # Blue
              $subtitle = $subtitle."{\\c3&HFF0000&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "C") { # Cyan
              $subtitle = $subtitle."{\\c3&HFFFF00&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "R") { # Red
              $subtitle = $subtitle."{\\c3&H0000FF&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "Y") { # Yellow
              $subtitle = $subtitle."{\\c3&H00FFFF&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "M") { # Magenta
              $subtitle = $subtitle."{\\c3&HFF00FF&}";
            }
            if (uc($bgcolor[$_row][$_col]) eq "B") { # Black
              $subtitle = $subtitle."{\\c3&H000000&}";
            }
          }
          # Handle transparency
          if (uc($bgcolor[$_row][$_col]) eq "T") { # Transparent
            $subtitle = $subtitle."{\\a3&HFF&}";
          }
          elsif(uc($bgcolor) eq $bgcolor and uc($bgcolor[$_row][$_col]) ne $bgcolor[$_row][$_col]){ # Semi-transparent (lowercase)
  	     $subtitle = $subtitle."{\\a3&H80&}";
	  }
	  elsif(uc($bgcolor) ne $bgcolor and uc($bgcolor[$_row][$_col]) eq $bgcolor[$_row][$_col]){ # Opaque (uppercase)
	     $subtitle = $subtitle."{\\a3&H00&}";
	  }
          $bgcolor = $bgcolor[$_row][$_col];
        }
        if ($underlined[$_row][$_col] ne $underlined) {
          $subtitle = $subtitle.(($underlined[$_row][$_col]) ? "{\\u1}" : "{\\u0}");
          $underlined = $underlined[$_row][$_col];
        }
        if ($italicized[$_row][$_col] ne $italicized) {
          $subtitle = $subtitle.(($italicized[$_row][$_col]) ? "{\\i1}" : "{\\i0}");
          $italicized = $italicized[$_row][$_col];
        }
        $subtitle = $subtitle.$character[$_row][$_col];
      }
    }
  }
  # Although it doesn't technically matter, close out any remaining color/style tags
  if(!($preformat)){
    if ($color ne "0") {
      $color = "0";
      $subtitle = $subtitle."{\\c&HFFFFFF&}";
    }
    if ($bgcolor ne "B") {
      $bgcolor = "B";
      $subtitle = $subtitle."{\\a3&H00&}";
    }
    if ($underlined) {
      $underlined = 0;
      $subtitle = $subtitle."{\\u0}";
    }
    if ($italicized) {
      $italicized = 0;
      $subtitle = $subtitle."{\\i0}";
    }
  }
  # Now we need to readjust the y coordinates to be zero-indexed (i.e. subtract one from each)
  #  Otherwise vertical positioning math will be slightly off
  $starty--;
  $endy--;
  return $subtitle;
}

# subroutine to ouput subtitle file's header
sub outputHeader {
  my $convertFormat = shift(@_);
  if ($convertFormat eq "WebVTT"){
    print WH "WEBVTT\n\n";
    print WH "STYLE\n::cue {\n  font-family: \"Courier New\", courier, monospace;\n  font-weight: bold;\n  font-size: 30pt;\n}\n\n";
    $input =~ m/.*\.(.*)$/; # Get the extension of the input file
    print WH "NOTE Converted from ".$1." Closed Captions by yyC2Swp ".$Version." (a CCASDI fork)\n\n";
  }
  # SMPTE-TT compliant (I think) thanks to https://docs.pbs.org/space/MM/5344210/Closed+Captioning
  elsif ($convertFormat eq "Timed Text Markup Language"){
    print WH "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print WH "<tt xmlns=\"http://www.w3.org/2006/10/ttaf1\" xmlns:tts=\"http://www.w3.org/2006/10/ttaf1#styling\" xmlns:ttm=\"http://www.w3.org/2006/10/ttaf1#metadata\" xmlns:smpte=\"http://www.smpte-ra.org/schemas/2052-1/2010/smpte-tt\" xmlns:m608=\"http://www.smpte-ra.org/schemas/2052-1/2010/smpte-tt#cea608\"\n";
    # By default TTML divides the video into 32 horizontal cells and 15 vertical cells, just like captions. Unfortunately it doesn't
    #  account for overscan, so add some extra padding to mimic how captions are rendered on analog devices (and how they were designed)
    print WH "  xml:lang=\"".$LangCode."\" ttp:cellResolution=\"96 36\">\n"; # Double both values since VLC doesn't support non-uniform font scaling
    print WH "  <head>\n        <metadata>\n            <ttm:title>".$Language." Closed Captions</ttm:title>\n";
    $input =~ m/.*\.(.*)$/;
    print WH "            <ttm:desc>Converted from ".$1." Closed Captions by yyC2Swp ".$Version." (a CCASDI fork)</ttm:desc>\n";
    print WH "            <smpte:information xmlns:m608=\"http://www.smpte-ra.org/schemas/2052-1/2010/smpte-tt#cea608\" origin=\"http://www.smpte-ra.org/schemas/2052-1/2010/smpte-tt#cea608\""; 
    if ($channel < 0){$channel = 1;} # Default to 1 if we don't have a channel specified
    print WH " mode=\"Preserved\" m608:channel=\"CC".$channel."\" m608:captionService=\"F1C".$channel."CC\"/>\n";
    print WH "        </metadata>\n        <styling>\n";
    print WH "          <style xml:id=\"s1\" tts:textAlign=\"left\" tts:fontFamily=\"Courier New\" tts:fontSize=\"2c\" tts:fontWeight=\"bold\"/>\n";
    print WH "        </styling>\n        <layout>\n";
    print WH "          <region xml:id=\"pop1\" tts:backgroundColor=\"transparent\"/>\n";
    print WH "          <region xml:id=\"pop2\" tts:backgroundColor=\"transparent\"/>\n";
    print WH "          <region xml:id=\"pop3\" tts:backgroundColor=\"transparent\"/>\n";
    print WH "          <region xml:id=\"pop4\" tts:backgroundColor=\"transparent\"/>\n"; # We should only ever get 4 lines of captions
    print WH "        </layout>\n    </head>\n\n    <body style=\"s1\" xml:space=\"preserve\">\n        <div>\n";
  }
  # I'd like to get proper 3GPP/MPEG-4 Timed Text (tx3g) output, but for now this format converts straight to that via GPAC
  elsif ($convertFormat eq "GPAC Timed Text"){
    $input =~ m/.*\.(.*)$/;
    print WH "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- Converted from ".$1." Closed Captions by yyC2Swp ".$Version." (a CCASDI fork) -->\n<TextStream version=\"1.0\">\n";
    print WH "<TextStreamHeader width=\"".$ResX."\" height=\"".$ResY."\">\n";
    print WH "<TextSampleDescription horizontalJustification=\"left\" verticalJustification=\"top\" fillTextRegion=\"no\">\n";
    print WH "<FontTable>\n<FontTableEntry fontName=\"Courier New\" fontID=\"0\"/>\n</FontTable>\n<TextBox top=\"0\" left=\"0\" bottom=\"".$ResX."\" right=\"".$ResY."\"/>\n";
    print WH "<Style styles=\"Bold\" fontSize=\"30\" color=\"ff ff ff ff\"/>\n</TextSampleDescription>\n</TextStreamHeader>\n";
  }
  elsif ($convertFormat eq "SAMI") {
    print WH "<SAMI>\n";
    print WH "<HEAD>\n";
    print WH "<SAMIParam><!--\n  Metrics {time:ms;}\n  Spec {MSFT:1.0;} -->\n</SAMIParam>\n";
    print WH "<STYLE TYPE=\"text/css\">\n";
    print WH "<!--\n";
    print WH "P {text-align: center; font-size: 30pt; font-family: Courier New; font-weight: bold; color: #f0f0f0;}\n";
    print WH ".".uc($LangCode)."CC {Name:".$Language."; lang:".$LangCode."; SAMIType:CC;}\n";
    print WH "-->\n";
    print WH "</STYLE>\n";
    print WH "</HEAD>\n\n";
    print WH "<BODY>\n";
  }
  # https://web.archive.org/web/20031103011212/http://developer.apple.com/documentation/QuickTime/REF/refDataExchange.6.htm
  # https://web.archive.org/web/20130502224223/http://webaim.org/techniques/captions/quicktime/caption_file
  #  In case anyone is wondering where I pulled this arcane knowledge from
  if ($convertFormat eq "Quicktime Caption") {
    print WH "{QTtext}{font:Courier New}{justify:center}{size:30}{backColor:0,0,0}{keyedText:on}{dropShadow:on}\n"; # keyedText removes the background on the text box
    print WH "{textColor:65535,65535,65535}{textEncoding:256}{timescale:1000}{width:0}{height:0}\n"; # textEncoding:256 enables unicode
    print WH "[00:00:00.000] \n"; # Blank line at the start so the stream can be detected immediately
  }
  elsif ($convertFormat eq "SubStation Alpha") {
    print WH "[Script Info]\n";
    $input =~ m/.*\.(.*)$/;
    print WH "Update Details: Converted from ".$1." Closed Captions by yyC2Swp ".$Version." (a CCASDI fork)\n";
    print WH "ScriptType: v4.00\n";
    print WH "Collisions: Normal\n";
    print WH "PlayResX: ".$ResX."\n";
    print WH "PlayResY: ".$ResY."\n";
    print WH "Timer: 100.0000\n";
    print WH "\n";
    print WH "[V4 Styles]\n";
    print WH "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding\n";
    print WH "Style: *Default,Courier New,30,&HFFFFFF,&H00FFFF,&H000000,&H000000,1,0,1,2,3,6,0,0,0,00,1\n";
    print WH "\n";
    print WH "[Events]\n";
    print WH "Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n";
  }
  elsif ($convertFormat eq "Advanced SubStation") {
    print WH "[Script Info]\n";
    $input =~ m/.*\.(.*)$/;
    print WH "Update Details: Converted from ".$1." Closed Captions by yyC2Swp ".$Version." (a CCASDI fork)\n";
    print WH "ScriptType: v4.00+\n";
    print WH "Collisions: Normal\n";
    print WH "PlayResX: ".$ResX."\n";
    print WH "PlayResY: ".$ResY."\n";
    print WH "Timer: 100.0000\n";
    print WH "WrapStyle: 1\n"; # No line breaks other than manual ones
    print WH "\n";
    print WH "[V4+ Styles]\n";
    print WH "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n";
    print WH "Style: *Default,Courier New,30,&H00FFFFFF,&H0000FFFF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,2,3,8,0,0,0,1\n";
    print WH "\n";
    print WH "[Events]\n";
    print WH "Format: Layer, Start, End, Style, Actor, MarginL, MarginR, MarginV, Effect, Text\n";
  }
}

# subroutine to output subtitle
sub outputSubtitle {
  my $subtitleCount = shift(@_);
  my $startTime = shift(@_);
  my $endTime = shift(@_);
  my $subtitle = shift(@_);
  if ($startTime eq "") {
    $subtitleNumber--; # reset global counter
    return;
  }
  my $hh;
  my $mm;
  my $ss;
  my $ff;
  my $ms;
  my $hs; # hundreds of a second
  my $tc1;
  my $tc2;
  my $formatting;
  # print $startTime.".".$endTime.".".$subtitle."\n";
  # print $mode.".".$channel."\n";
  if ($endTime ne "") {
    if ($convertFormat eq "WebVTT") {
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc1 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc2 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      # No subtitle manipulation needed since convertToSub handles all that
      # Y|y - this would be nice if VLC would parse position with alignment, but it refuses to.
      #  This code winds up with stuff crammed against the far sides of the screen with no margin
      #
      # Figure out what third of the horizontal our text is centered on and align accordingly
      # my $xthird = int((($startx+$endx)/32)+0.5);
      # output subtitle
      #if ($xthird eq "2"){
      #  print WH $tc1." --> ".$tc2." line:".int(($starty/15*100*$Yratio)+((1-$Yratio)/2*100))."% position:".int((($endx)/32*100*$Xratio)+((1-$Xratio)/2*100))."% align:end\n";
      #} elsif ($xthird eq "0"){
      #  print WH $tc1." --> ".$tc2." line:".int(($starty/15*100*$Yratio)+((1-$Yratio)/2*100))."% position:".int((($startx)/32*100*$Xratio)+((1-$Xratio)/2*100))."% align:start\n";
      #} else {
        print WH $tc1." --> ".$tc2." line:".int(($starty/15*100*$Yratio)+((1-$Yratio)/2*100))."% position:".int((($startx+$endx)/64*100*$Xratio)+((1-$Xratio)/2*100))."% align:center\n";
      #}
      print WH $subtitle."\n\n";
    }
    elsif ($convertFormat eq "Timed Text Markup Language"){
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc1 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc2 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      # Unlike other formats, TTML natively supports automatic font sizing so that characters are the correct width and length, even if
      #  the font is not the one specified. As such we don't need to do any trickery with centering the text.
      # With the new changes to convertToSub we don't need to do any substitution. We *do* need to break the subtitle up by lines though
      $subtitle = $subtitle."\n"; # Append a newline to ensure the below parsing gets the full subtitle
      my $yoffset = 0;
      my $regionnum = 1;
      while($subtitle =~ /(.*\n)/g){
      	my $subsub = $1; # It's fun to say
      	my $xoffset = 0;
      	if(!($subsub =~ m/^\s*$/)){ # skip completely blank lines
          $subsub =~ s/\n|(\xa0+)$//g; # strip any newlines or trailing NBSPs
          # Check for leading NBSPs. If found, trim and offset the start of the line accordingly
	  if($subsub =~ m/^(\xa0+)/){
	    $xoffset = length($1);
	    $subsub =~ s/^(\xa0+)//;
	  }
      	  print WH "            <p region=\"pop".$regionnum++."\" tts:origin=\"".(($startx+$xoffset+8)*2)."c ".((($starty+$yoffset)*2) + 3)."c\" begin=\"".$tc1."\" end=\"".$tc2."\">".$subsub."</p>\n"; # xml:id=\"sub".sprintf("%05d", $subtitleNumber)."\"
      	}
      	$yoffset++;
      }
      # If we generated more than 4 lines of captions warn that this isn't SMPTE-TT compliant and the lines will probably not show up
      if($regionnum > 5){
      	print "Warning: subtitle $subtitleNumber has more than 4 lines of text, which is not SMPTE-TT (or EIA-608) compliant. Some lines will likely not be displayed.\n";
      }
    }
    elsif ($convertFormat eq "GPAC Timed Text"){
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc1 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc2 = sprintf("%02d:%02d:%02d.%03d", $hh, $mm, $ss, $ms);
      # subtitle manipulation
      if ($subtitle =~ m/{\\a3&H.{2}&}|{\\c3&H.{6}&}/gi){
        print "Warning: subtitle $subtitleNumber contains background color and/or alpha changes, which are not supported by $convertFormat and will not be present in the converted subtitles. Convert to another format if you want to preserve these features.\n";
      }
      $subtitle =~ s|{\\c3&H.{6}&}||g; # Strip background color
      $subtitle =~ s|{\\a3&H.{2}&}||g; # Strip background alpha
      # Encode special characters (per XML spec)
      $subtitle =~ s|\"|&quot;|g; # Quotes
      $subtitle =~ s|'|&apos;|g; # Apostrophes
      $subtitle =~ s|<|&lt;|g; # Less Than
      $subtitle =~ s|>|&gt;|g; # Greater Than
      $subtitle =~ s|&|&amp;|g; # Ampersand
      $subtitle =~ s|\n|''|g; # Replace newlines with double single quotes
      # italics and underline will be a pain because you have to do Styles with fromchar and tochar. Plus side: you can do background via highlights. TO DO
      # And now some positioning trickery. First, calculate the expected left and right margins
      my $Lmargin = int(($startx/32*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5);
      my $Rmargin = ($ResX - int(($endx/32*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5));
      # ...now because we can't be certain fonts are rendered the same, we expand the margins
      #  as far as we can while keeping the center of the two points the same. That way if
      #  font difference renders the subtitle larger than we expect the line won't break, but
      #  the location will still be mostly correct.
      if ($Lmargin > $Rmargin){
        $Lmargin -= $Rmargin;
        $Rmargin = 0;
      } else {
        $Rmargin -= $Lmargin;
        $Lmargin = 0;
      }
      print WH "<TextSample sampleTime=\"".$tc1."\" text=\"'".$subtitle."'\">\n";
      print WH "<TextBox top=\"".int(($starty/15*($ResY*$Yratio))+($ResY*(1-$Yratio)/2)+0.5)."\" left=\"".$Lmargin."\" bottom=\"".$ResY."\" right=\"".$Rmargin."\"/></TextSample>\n";
      print WH "<TextSample sampleTime=\"".$tc2."\" text=\"''\"/>\n";
    }
    # SAMI support works in theory, but there's not a single modern player that actually
    #  honors the positioning information (or the font information, color, size....)
    #  I'll still leave this enabled in case that changes.
    elsif ($convertFormat eq "SAMI") {
      # timecode manipulation
      $ff = frame($startTime);
      $tc1 = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $ff = frame($endTime);
      $tc2 = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      # subtitle manipulation
      if ($subtitle =~ m/{\\a3&H.{2}&}|{\\c3&H.{6}&}/gi){
        print "Warning: subtitle $subtitleNumber contains background color and/or alpha changes, which are not supported by $convertFormat and will not be present in the converted subtitles. Convert to another format if you want to preserve these features.\n";
      }
      $subtitle =~ s|{\\c3&H.{6}&}||g; # Strip background color
      $subtitle =~ s|{\\a3&H.{2}&}||g; # Strip background alpha
      $subtitle =~ s|{\\i1}|<i>|g; # replace italics
      $subtitle =~ s|{\\u1}|<u>|g; # replace underline
      $subtitle =~ s|{\\i0}|</i>|g; # replace close italics
      $subtitle =~ s|{\\u0}|</u>|g; # replace close underline
      #$subtitle =~ s/\xa0/&nbsp;/g;
      $subtitle =~ s|\n|<br>|g; # convert newlines to <br>
      # output subtitle
      print WH "<SYNC start=\"".$tc1."\"><P CLASS=\"".uc($Language)."\"><CaptionBlock PosX=".int(((($startx+$endx)/64*($ResX*$Xratio))+($ResX*(1-$Xratio)/2))*3/4+0.5)."pt PosY=".int(((($starty/15*($ResY*$Yratio))+($ResY*(1-$Yratio)/2))*3/4)+0.5)."pt>"; # STYLE=\"margin-left: ".$Lmargin."pt; margin-right: ".$Rmargin."pt; margin-top: ".int(((($starty/16*($ResY*$Yratio))+($ResY*(1-$Yratio)/2))*3/4)+0.5)."pt;\"
      print WH "<TT>".$subtitle."</TT></CaptionBlock></P></SYNC>\n";
      print WH "<SYNC start=\"".$tc2."\"><P CLASS=\"".uc($Language)."\">&nbsp;</P></SYNC>\n\n";
    }
    # Format added in the lost CCASDI 3.8. QTtext supports text box sizing and positioning
    #  along with shirking text to fit the box size, all of which is perfect for captions
    if ($convertFormat eq "Quicktime Caption") {
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc1 = sprintf("[%02s:%02s:%02s.%03d] ", $hh, $mm, $ss, $ms);
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $ms = sprintf("%d", ($ff / $fps * 1000) + 0.5);
      $tc2 = sprintf("[%02s:%02s:%02s.%03d]", $hh, $mm, $ss, $ms);
      # subtitle manipulation
      $subtitle =~ s/\n/\x0d/g; # convert newlines (LF\CRLF) to Mac newlines (CR)
      my $red = 0;
      my $blue = 0;
      my $green = 0;
      my $colortag = "";
      # Search for any color tags and convert them to Quicktime syntax
      while ($subtitle =~ m/{\\c&H(.{2})(.{2})(.{2})&}/) {
        $red = hex($3) * 256;
        $green = hex($2) * 256;
        $blue = hex($1) * 256;
        if (uc($3) eq "FF") { $red = 65535; }
        if (uc($2) eq "FF") { $green = 65535; }
        if (uc($1) eq "FF") { $blue = 65535; }
        $colortag = sprintf("{textColor:%d,%d,%d}", $red, $green, $blue);
        $subtitle =~ s/{\\c&H$1$2$3&}/$colortag/g;
      }
      # Warn about background alpha and color features not being supported.
      if ($subtitle =~ m/{\\a3&H.{2}&}|{\\c3&H.{6}&}/gi){
        print "Warning: subtitle $subtitleNumber contains background color and/or alpha changes, which are not supported by $convertFormat and will not be present in the converted subtitles. Convert to another format if you want to preserve these features.\n";
      }
      $subtitle =~ s|{\\c3&H.{6}&}||g; # Strip background color. We can only do all-or-nothing with QT: either the whole subtitle or none of it
      $subtitle =~ s|{\\a3&H.{2}&}||g; # Strip background alpha
      $subtitle =~ s/{\\i1}/{italic}/g; # Convert italic
      $subtitle =~ s/{\\u1}/{underline}/g; # Convert underline
      $subtitle =~ s|{\\[iu]0}|{plain}|g; # replace all end tags with {plain}. This may cause inaccuracies with nested italic+underline (TO DO)
      # Get position and extent. We could do this inline but then it would look messy
      my $Hpos = int(($startx/32*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5);
      my $Hlen = int(($endx-$startx)/32*($ResX*$Xratio));
      my $Vpos = int(($starty/15*($ResY*$Yratio))+($ResY*(1-$Yratio)/2)+0.5);
      my $Vlen = int(($endy-$starty)/15*($ResY*$Yratio));
      # output subtitle. shrinkTextBox needs to be on for textBox to do anything
      print WH $tc1."{shrinkTextBox:on}{textBox:".$Hpos.", ".$Vpos.", ".$Hlen.", ".$Vlen."}".$subtitle."\n";
      print WH $tc2."\n"; # 2nd line clears screen
    }
    elsif ($convertFormat eq "SubStation Alpha") {
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $hs = sprintf("%d", ($ff / $fps * 100) + 0.5);
      if($hs > 99){ $hs = 99;} # hacky but whatever
      $tc1 = sprintf("%01d:%02s:%02s.%02s", $hh, $mm, $ss, $hs); # SSA requires one digit for the hours and two for the rest
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $hs = sprintf("%d", ($ff / $fps * 100) + 0.5);
      if($hs > 99){ $hs = 99;}
      $tc2 = sprintf("%01d:%02s:%02s.%02s", $hh, $mm, $ss, $hs);
      # subtitle manipulation
      # Strictly speaking SSA does not support Underline tags, but most players will honor them. Print a warning if there were any though.
      if ($subtitle =~ m|{\\u1}|gi){
        print "Warning: subtitle $subtitleNumber contains underlines, which are not officially supported by the SubStation Alpha format but are USUALLY displayed correctly. If not, you may want to convert to Advanced SubStation instead.\n";
      }
      # SSA doesn't support background color and alpha changes either and those WON'T be displayed, so warn about that
      if ($subtitle =~ m/{\\a3&H.{2}&}|{\\c3&H.{6}&}/gi){
        print "Warning: subtitle $subtitleNumber contains background color and/or alpha changes, which are not supported by $convertFormat and will not be present in the converted subtitles. Convert to another format if you want to preserve these features.\n";
      }
      $subtitle =~ s|{\\c3&H.{6}&}||g; # Strip background color
      $subtitle =~ s|{\\a3&H.{2}&}||g; # Strip background alpha
      $subtitle =~ s|\xa0|\\h|g; # Convert NBSP to \h
      $subtitle =~ s|\n|\\N|g; # convert newlines to "\N" string
      # Strip any "close" tags that are at the end of the subtitle, since they aren't needed in SubStation formatting
      $subtitle =~ s|({\\[iu]0})*({\\c&H.{6}&})*$||;
      # And now some positioning trickery. First, calculate the expected left and right margins
      my $Lmargin = int(($startx/32*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5);
      my $Rmargin = ($ResX - int(($endx/32*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5));
      # ...now because we can't be certain fonts are rendered the same, we expand the margins
      #  as far as we can while keeping the center of the two points the same. That way if
      #  font difference renders the subtitle larger than we expect the line won't break, but
      #  the location will still be mostly correct.
      if ($Lmargin > $Rmargin){
        $Lmargin -= $Rmargin;
        $Rmargin = 0;
      } else {
        $Rmargin -= $Lmargin;
        $Lmargin = 0;
      }
      # output subtitle
      print WH "Dialogue: Marked=0,".$tc1.",".$tc2.",*Default,,".sprintf("%04d",$Lmargin).",".sprintf("%04d",$Rmargin).",".sprintf("%04d",int(($starty/15*($ResY*$Yratio))+($ResY*(1-$Yratio)/2)+0.5)).",,".$subtitle."\n";
    }
    elsif ($convertFormat eq "Advanced SubStation") {
      # timecode manipulation
      ($hh, $mm, $ss, $ff) = split("[:;]", $startTime);
      $hs = sprintf("%d", ($ff / $fps * 100) + 0.5);
      if($hs > 99){ $hs = 99;} # hacky but whatever
      $tc1 = sprintf("%01d:%02s:%02s.%02s", $hh, $mm, $ss, $hs); # ASS requires one digit for the hours and two for the rest
      ($hh, $mm, $ss, $ff) = split("[:;]", $endTime);
      $hs = sprintf("%d", ($ff / $fps * 100) + 0.5);
      if($hs > 99){ $hs = 99;}
      $tc2 = sprintf("%01d:%02s:%02s.%02s", $hh, $mm, $ss, $hs);
      # subtitle manipulation
      $subtitle =~ s|\n|\\N|g; # convert newlines to "\N" string
      # Strip any "close" tags that are at the end of the subtitle, since they aren't needed in SubStation formatting
      $subtitle =~ s|({\\[iu]0})*({\\c3?&H.{6}&})*({\\a3&H.{2}&})*$||;
      # output subtitle. Unlike SSA we can just use the "pos" tag override to set the position directly, no funky margin trickery needed.
      print WH "Dialogue: 0,".$tc1.",".$tc2.",*Default,,0000,0000,0000,,{\\pos(".int((($startx+$endx)/64*($ResX*$Xratio))+($ResX*(1-$Xratio)/2)+0.5).",".int(($starty/15*($ResY*$Yratio))+($ResY*(1-$Yratio)/2)+0.5).")}".$subtitle."\n";
    }
    # $startTime = "";
    # $endTime = "";
    # $subtitle = "";
  }
}

# subroutine to output subtitle file's footer
sub outputFooter {
  my $convertFormat = shift(@_);
  
  # Y|y - check for a temp file and write those lines to the output file
  #  Nothing uses this now that I've figured out the new way to do TTML,
  #  but I'll leave it in for possible future use
  if($writeTemp){
    seek(TH, 0, 0);
    while(<TH>){
      print WH $_;
    }
    my $tempfile = $output.".temp";
    # try to delete the temp file, but don't blow up if we can't
    close(TH);
    unlink($tempfile) or print "Warning: could not delete temp file $tempfile: $!";
  }
  if ($convertFormat eq "SAMI") {
    print WH "</BODY>\n</SAMI>\n";
  }
  elsif ($convertFormat eq "Timed Text Markup Language") {
    print WH "        </div>\n    </body>\n</tt>";
  }
  elsif ($convertFormat eq "GPAC Timed Text"){
    print WH "</TextStream>";
  }
}

# subroutine to disassemble command code
sub disCommand {
  my $hi = sprintf ("%02x", shift(@_));
  my $lo = sprintf ("%02x", shift(@_));
  my $commandtoken = "{??}"; # placeholder for failed match
  if ($convert) {
    $commandtoken = ""; # accept everything
    my $extendedChar = 0;
    if ($hi eq "18") { $hi = "10"; }
    if ($hi eq "19") { $hi = "11"; }
    if ($hi eq "1a") { $hi = "12"; }
    if ($hi eq "1b") { $hi = "13"; }
    if ($hi eq "1c") { $hi = "14"; }
    if ($hi eq "1d") { $hi = "15"; }
    if ($hi eq "1e") { $hi = "16"; }
    if ($hi eq "1f") { $hi = "17"; }
    # Y|y - this one is a weird outlier so just check it directly
    if (($hi eq "97" or $hi eq "1f") and $lo eq "ad"){$bgcolor = "T"; $extendedChar = 1;}
    SWITCH: for ($hi) {
      /10/ && do {
        for ($lo) {
      	  # Y|y - Add support for background color/alpha tags. Format is CAPS = solid color, lower = semi-transparent color
      	  # TO DO: Do we need to repeat this for $hi = 98?
          /20/ && do {$bgcolor = "W"; $extendedChar = 1; last SWITCH;};
          /a1/ && do {$bgcolor = "w"; $extendedChar = 1; last SWITCH;};
          /a2/ && do {$bgcolor = "G"; $extendedChar = 1; last SWITCH;};
          /23/ && do {$bgcolor = "g"; $extendedChar = 1; last SWITCH;};
          /a4/ && do {$bgcolor = "U"; $extendedChar = 1; last SWITCH;}; # Yeah I play MTG a bit
          /25/ && do {$bgcolor = "u"; $extendedChar = 1; last SWITCH;};
          /26/ && do {$bgcolor = "C"; $extendedChar = 1; last SWITCH;};
          /a7/ && do {$bgcolor = "c"; $extendedChar = 1; last SWITCH;};
          /a8/ && do {$bgcolor = "R"; $extendedChar = 1; last SWITCH;};
          /29/ && do {$bgcolor = "r"; $extendedChar = 1; last SWITCH;};
          /2a/ && do {$bgcolor = "Y"; $extendedChar = 1; last SWITCH;};
          /ab/ && do {$bgcolor = "y"; $extendedChar = 1; last SWITCH;};
          /2c/ && do {$bgcolor = "M"; $extendedChar = 1; last SWITCH;};
          /ad/ && do {$bgcolor = "m"; $extendedChar = 1; last SWITCH;};
          /ae/ && do {$bgcolor = "B"; $extendedChar = 1; last SWITCH;};
          /2f/ && do {$bgcolor = "b"; $extendedChar = 1; last SWITCH;};
          
          /40/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 11; $col = 0; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 11; $col = 4; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 11; $col = 4; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 11; $col = 8; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 11; $col = 8; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 11; $col = 12; $ruBottom = 11;  $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 11; $col = 12; $ruBottom = 11;  $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 11; $col = 16; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 11; $col = 16; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 11; $col = 20; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 11; $col = 20; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 11; $col = 24; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 11; $col = 24; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 11; $col = 28; $ruBottom = 11; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 11; $col = 28; $ruBottom = 11; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /11/ && do {
        for ($lo) {
          /20/ && do {$color = "0"; $italicized = 0; $underlined = 0; last SWITCH;};
          /21/ && do {$color = "0"; $italicized = 0; $underlined = 1; last SWITCH;};
          /22/ && do {$color = "1"; $italicized = 0; $underlined = 0; last SWITCH;};
          /23/ && do {$color = "1"; $italicized = 0; $underlined = 1; last SWITCH;};
          /24/ && do {$color = "2"; $italicized = 0; $underlined = 0; last SWITCH;};
          /25/ && do {$color = "2"; $italicized = 0; $underlined = 1; last SWITCH;};
          /26/ && do {$color = "3"; $italicized = 0; $underlined = 0; last SWITCH;};
          /27/ && do {$color = "3"; $italicized = 0; $underlined = 1; last SWITCH;};
          /28/ && do {$color = "4"; $italicized = 0; $underlined = 0; last SWITCH;};
          /29/ && do {$color = "4"; $italicized = 0; $underlined = 1; last SWITCH;};
          /2a/ && do {$color = "5"; $italicized = 0; $underlined = 0; last SWITCH;};
          /2b/ && do {$color = "5"; $italicized = 0; $underlined = 1; last SWITCH;};
          /2c/ && do {$color = "6"; $italicized = 0; $underlined = 0; last SWITCH;};
          /2d/ && do {$color = "6"; $italicized = 0; $underlined = 1; last SWITCH;};
          /2e/ && do {$italicized = 1; last SWITCH;};
          /2f/ && do {$italicized = 1; $underlined = 1; last SWITCH;};
          /30/ && do {$commandtoken = "®"; last SWITCH;};
          /31/ && do {$commandtoken = "°"; last SWITCH;};
          /32/ && do {$commandtoken = "½"; last SWITCH;};
          /33/ && do {$commandtoken = "¿"; last SWITCH;};
          /34/ && do {$commandtoken = "\N{U+2122}"; last SWITCH;}; # {tm}
          /35/ && do {$commandtoken = "¢"; last SWITCH;};
          /36/ && do {$commandtoken = "£"; last SWITCH;};
          /37/ && do {$commandtoken = "\N{U+266a}"; last SWITCH;}; # {note}
          /38/ && do {$commandtoken = "à"; last SWITCH;};
          /39/ && do {$commandtoken = " "; last SWITCH;};
          /3a/ && do {$commandtoken = "è"; last SWITCH;};
          /3b/ && do {$commandtoken = "â"; last SWITCH;};
          /3c/ && do {$commandtoken = "ê"; last SWITCH;};
          /3d/ && do {$commandtoken = "î"; last SWITCH;};
          /3e/ && do {$commandtoken = "ô"; last SWITCH;};
          /3f/ && do {$commandtoken = "û"; last SWITCH;};
          /40/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 1; $col = 0; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 1; $col = 4; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 1; $col = 4; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 1; $col = 8; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 1; $col = 8; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 1; $col = 12; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 1; $col = 12; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 1; $col = 16; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 1; $col = 16; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 1; $col = 20; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 1; $col = 20; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 1; $col = 24; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 1; $col = 24; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 1; $col = 28; $ruBottom = 1; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 1; $col = 28; $ruBottom = 1; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 2; $col = 0; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 2; $col = 4; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 2; $col = 4; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 2; $col = 8; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 2; $col = 8; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 2; $col = 12; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 2; $col = 12; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 2; $col = 16; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 2; $col = 16; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 2; $col = 20; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 2; $col = 20; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 2; $col = 24; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 2; $col = 24; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 2; $col = 28; $ruBottom = 2; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 2; $col = 28; $ruBottom = 2; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /12/ && do {
        for ($lo) {
          /20/ && do {$commandtoken = "Á"; $extendedChar = 1; last SWITCH;};
          /21/ && do {$commandtoken = "É"; $extendedChar = 1; last SWITCH;};
          /22/ && do {$commandtoken = "Ó"; $extendedChar = 1; last SWITCH;};
          /23/ && do {$commandtoken = "Ú"; $extendedChar = 1; last SWITCH;};
          /24/ && do {$commandtoken = "Ü"; $extendedChar = 1; last SWITCH;};
          /25/ && do {$commandtoken = "ü"; $extendedChar = 1; last SWITCH;};
          /26/ && do {$commandtoken = "'"; $extendedChar = 1; last SWITCH;};
          /27/ && do {$commandtoken = "¡"; $extendedChar = 1; last SWITCH;};
          /28/ && do {$commandtoken = "*"; $extendedChar = 1; last SWITCH;};
          /29/ && do {$commandtoken = "'"; $extendedChar = 1; last SWITCH;};
          /2a/ && do {$commandtoken = "-"; $extendedChar = 1; last SWITCH;};
          /2b/ && do {$commandtoken = "©"; $extendedChar = 1; last SWITCH;};
          /2c/ && do {$commandtoken = "\N{U+2120}"; $extendedChar = 1; last SWITCH;}; # {sm}
          /2d/ && do {$commandtoken = "·"; $extendedChar = 1; last SWITCH;};
          /2e/ && do {$commandtoken = "\""; $extendedChar = 1; last SWITCH;};
          /2f/ && do {$commandtoken = "\""; $extendedChar = 1; last SWITCH;};
          /30/ && do {$commandtoken = "À"; $extendedChar = 1; last SWITCH;};
          /31/ && do {$commandtoken = "Â"; $extendedChar = 1; last SWITCH;};
          /32/ && do {$commandtoken = "Ç"; $extendedChar = 1; last SWITCH;};
          /33/ && do {$commandtoken = "È"; $extendedChar = 1; last SWITCH;};
          /34/ && do {$commandtoken = "Ê"; $extendedChar = 1; last SWITCH;};
          /35/ && do {$commandtoken = "Ë"; $extendedChar = 1; last SWITCH;};
          /36/ && do {$commandtoken = "ë"; $extendedChar = 1; last SWITCH;};
          /37/ && do {$commandtoken = "Î"; $extendedChar = 1; last SWITCH;};
          /38/ && do {$commandtoken = "Ï"; $extendedChar = 1; last SWITCH;};
          /39/ && do {$commandtoken = "ï"; $extendedChar = 1; last SWITCH;};
          /3a/ && do {$commandtoken = "Ô"; $extendedChar = 1; last SWITCH;};
          /3b/ && do {$commandtoken = "Ù"; $extendedChar = 1; last SWITCH;};
          /3c/ && do {$commandtoken = "ù"; $extendedChar = 1; last SWITCH;};
          /3d/ && do {$commandtoken = "Û"; $extendedChar = 1; last SWITCH;};
          /3e/ && do {$commandtoken = "«"; $extendedChar = 1; last SWITCH;};
          /3f/ && do {$commandtoken = "»"; $extendedChar = 1; last SWITCH;};
          /40/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 3; $col = 0; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 3; $col = 4; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 3; $col = 4; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 3; $col = 8; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 3; $col = 8; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 3; $col = 12; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 3; $col = 12; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 3; $col = 16; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 3; $col = 16; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 3; $col = 20; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 3; $col = 20; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 3; $col = 24; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 3; $col = 24; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 3; $col = 28; $ruBottom = 3; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 3; $col = 28; $ruBottom = 3; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 4; $col = 0; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 4; $col = 4; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 4; $col = 4; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 4; $col = 8; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 4; $col = 8; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 4; $col = 12; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 4; $col = 12; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 4; $col = 16; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 4; $col = 16; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 4; $col = 20; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 4; $col = 20; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 4; $col = 24; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 4; $col = 24; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 4; $col = 28; $ruBottom = 4; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 4; $col = 28; $ruBottom = 4; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /13/ && do {
        for ($lo) {
          /20/ && do {$commandtoken = "Ã"; $extendedChar = 1; last SWITCH;};
          /21/ && do {$commandtoken = "ã"; $extendedChar = 1; last SWITCH;};
          /22/ && do {$commandtoken = "Í"; $extendedChar = 1; last SWITCH;};
          /23/ && do {$commandtoken = "Ì"; $extendedChar = 1; last SWITCH;};
          /24/ && do {$commandtoken = "ì"; $extendedChar = 1; last SWITCH;};
          /25/ && do {$commandtoken = "Ò"; $extendedChar = 1; last SWITCH;};
          /26/ && do {$commandtoken = "ò"; $extendedChar = 1; last SWITCH;};
          /27/ && do {$commandtoken = "Õ"; $extendedChar = 1; last SWITCH;};
          /28/ && do {$commandtoken = "õ"; $extendedChar = 1; last SWITCH;};
          /29/ && do {$commandtoken = "{"; $extendedChar = 1; last SWITCH;};
          /2a/ && do {$commandtoken = "}"; $extendedChar = 1; last SWITCH;};
          /2b/ && do {$commandtoken = "\\"; $extendedChar = 1; last SWITCH;};
          /2c/ && do {$commandtoken = "^"; $extendedChar = 1; last SWITCH;};
          /2d/ && do {$commandtoken = "_"; $extendedChar = 1; last SWITCH;};
          /2e/ && do {$commandtoken = "|"; $extendedChar = 1; last SWITCH;};
          /2f/ && do {$commandtoken = "~"; $extendedChar = 1; last SWITCH;};
          /30/ && do {$commandtoken = "Ä"; $extendedChar = 1; last SWITCH;};
          /31/ && do {$commandtoken = "ä"; $extendedChar = 1; last SWITCH;};
          /32/ && do {$commandtoken = "Ö"; $extendedChar = 1; last SWITCH;};
          /33/ && do {$commandtoken = "ö"; $extendedChar = 1; last SWITCH;};
          /34/ && do {$commandtoken = "ß"; $extendedChar = 1; last SWITCH;};
          /35/ && do {$commandtoken = "¥"; $extendedChar = 1; last SWITCH;};
          /36/ && do {$commandtoken = "¤"; $extendedChar = 1; last SWITCH;};
          /37/ && do {$commandtoken = "|"; $extendedChar = 1; last SWITCH;};
          /38/ && do {$commandtoken = "Å"; $extendedChar = 1; last SWITCH;};
          /39/ && do {$commandtoken = "å"; $extendedChar = 1; last SWITCH;};
          /3a/ && do {$commandtoken = "Ø"; $extendedChar = 1; last SWITCH;};
          /3b/ && do {$commandtoken = "ø"; $extendedChar = 1; last SWITCH;};
          /3c/ && do {$commandtoken = "\N{U+231C}"; $extendedChar = 1; last SWITCH;}; # {ul}
          /3d/ && do {$commandtoken = "\N{U+231D}"; $extendedChar = 1; last SWITCH;}; # {ur}
          /3e/ && do {$commandtoken = "\N{U+231E}"; $extendedChar = 1; last SWITCH;}; # {ll}
          /3f/ && do {$commandtoken = "\N{U+231F}"; $extendedChar = 1; last SWITCH;}; # {lr}
          /40/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 12; $col = 0; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 12; $col = 4; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 12; $col = 4; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 12; $col = 8; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 12; $col = 8; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 12; $col = 12; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 12; $col = 12; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 12; $col = 16; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 12; $col = 16; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 12; $col = 20; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 12; $col = 20; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 12; $col = 24; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 12; $col = 24; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 12; $col = 28; $ruBottom = 12; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 12; $col = 28; $ruBottom = 12; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 13; $col = 0; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 13; $col = 4; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 13; $col = 4; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 13; $col = 8; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 13; $col = 8; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 13; $col = 12; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 13; $col = 12; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 13; $col = 16; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 13; $col = 16; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 13; $col = 20; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 13; $col = 20; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 13; $col = 24; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 13; $col = 24; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 13; $col = 28; $ruBottom = 13; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 13; $col = 28; $ruBottom = 13; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /14/ && do { # skipping codes that don't apply
        for ($lo) {
          /20/ && do {$mode = "CC"; $ruHeight = 0;
                      if ($ccMode ne "pop-on") {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        # if ($subtitle ne "") {
                        #   outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        # }
                        clearScreen();
                      }
                      $ccMode = "pop-on"; 
                      last SWITCH;}; # {RCL}
          /21/ && do {$col--; last SWITCH;}; # {BS}
          /24/ && do {for (my $_col = $col - 1; $_col < 16; $_col++) {
                        $character[$row][$_col] = "\x00";
                      }; last SWITCH;}; # {DER}                          
          /25/ && do {$mode = "CC"; $ccMode = "roll-up";
                      if ($ruHeight != 2) {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        clearScreen();
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $ruBottom = 15;
                      }
                      $ruHeight = 2;
                      $row = $ruBottom;
                      $col = 0;
                      last SWITCH;}; # {RU2}
          /26/ && do {$mode = "CC"; $ccMode = "roll-up";
                      if ($ruHeight != 3) {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        clearScreen();
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $ruBottom = 15;
                      }
                      $ruHeight = 3;
                      $row = $ruBottom;
                      $col = 0;
                      last SWITCH;}; # {RU3}
          /27/ && do {$mode = "CC"; $ccMode = "roll-up";
                      if ($ruHeight != 4) {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        clearScreen();
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $ruBottom = 15;
                      }
                      $ruHeight = 4;
                      $row = $ruBottom;
                      $col = 0;
                      last SWITCH;}; # {RU4}
          /29/ && do {$mode = "CC"; $ruHeight = 0;
                      if ($ccMode ne "paint-on") {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        clearScreen();
                      }
                      $ccMode = "paint-on";
                      $startTime = timecodeof($frames + $offset + $numwords);
                      last SWITCH;}; # {RDC}
          /2a/ && do {if ((!$convert) or ($convertMode eq "Text")) {
                        $mode = "Text"; $ccMode = "";
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $endTime = ""; $subtitle = "";
                      }; last SWITCH;}; # {TR}
          /2b/ && do {if ((!$convert) or ($convertMode eq "Text")) {
                        $mode = "Text"; $ccMode = "";
                      }; last SWITCH;}; # {RTD}
          /2c/ && do {if ($ccMode eq "pop-on") {
                        if ($endTime eq "") {
                          $endTime = timecodeof($frames + $offset + $numwords);
                        }
                      } else {
                        if ($startTime eq "") {
                          $startTime = timecodeof($frames + $offset + $numwords);
                          $subtitle = convertToSub();
                        } else {
                          $endTime = timecodeof($frames + $offset + $numwords);
                          $subtitle = convertToSub();
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                          $startTime = "";
                          $endTime = "";
                          $subtitle = "";
                          clearScreen();
                        }
                      }; last SWITCH;}; # {EDM}
          /2d/ && do {if (($ccMode eq "roll-up") or ($mode eq "Text") or ($mode eq "ITV")) {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        $startTime = timecodeof($frames + $offset + $numwords);
                        if ($subRollupMode) {
                          rollUp();
                        } else {
                          clearScreen();
                        }
                      }; last SWITCH;}; # {CR}
          /2e/ && do {clearScreen(); last SWITCH;}; # {ENM}
          /2f/ && do {if ($ccMode eq "pop-on") {
                        if ($endTime eq "") {
                          $endTime = timecodeof($frames + $offset + $numwords);
                        }
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        clearScreen();
                        $endTime = "";
                      }
                      last SWITCH;}; # {EOC}
          /40/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 14; $col = 0; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 14; $col = 4; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 14; $col = 4; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 14; $col = 8; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 14; $col = 8; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 14; $col = 12; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 14; $col = 12; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 14; $col = 16; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 14; $col = 16; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 14; $col = 20; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 14; $col = 20; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 14; $col = 24; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 14; $col = 24; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 14; $col = 28; $ruBottom = 14; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 14; $col = 28; $ruBottom = 14; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 15; $col = 0; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 15; $col = 4; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 15; $col = 4; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 15; $col = 8; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 15; $col = 8; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 15; $col = 12; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 15; $col = 12; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 15; $col = 16; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 15; $col = 16; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 15; $col = 20; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 15; $col = 20; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 15; $col = 24; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 15; $col = 24; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 15; $col = 28; $ruBottom = 15; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 15; $col = 28; $ruBottom = 15; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /15/ && do {
        for ($lo) {
          /20/ && do {$mode = "CC"; $ruHeight = 0;
                      if ($ccMode ne "pop-on") {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                      }
                      $ccMode = "pop-on"; 
                      last SWITCH;}; # {RCL}
          /21/ && do {$col--; last SWITCH;}; # {BS}
          /24/ && do {for (my $_col = $col - 1; $_col < 16; $_col++) {
                        $character[$row][$_col] = "\x00";
                      }; last SWITCH;}; # {DER}                          
          /25/ && do {$mode = "CC"; $ccMode = "roll-up"; last SWITCH;}; # {RU2}
          /26/ && do {$mode = "CC"; $ccMode = "roll-up"; last SWITCH;}; # {RU3}
          /27/ && do {$mode = "CC"; $ccMode = "roll-up"; last SWITCH;}; # {RU4}
          /29/ && do {$mode = "CC"; $ruHeight = 0;
                      if ($ccMode ne "paint-on") {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                      }
                      $ccMode = "paint-on";
                      last SWITCH;}; # {RDC}
          /2a/ && do {if ((!$convert) or ($convertMode eq "Text")) {
                        $mode = "Text"; $ccMode = "";
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $endTime = ""; $subtitle = "";
                      }; last SWITCH;}; # {TR}
          /2b/ && do {if ((!$convert) or ($convertMode eq "Text")) {
                        $mode = "Text"; $ccMode = "";
                      }; last SWITCH;}; # {RTD}
          /2c/ && do {if ($ccMode eq "pop-on") {
                        if ($endTime eq "") {
                          $endTime = timecodeof($frames + $offset + $numwords);
                        }
                      } else {
                        if ($startTime eq "") {
                          $startTime = timecodeof($frames + $offset + $numwords);
                          $subtitle = convertToSub();
                        } else {
                          $endTime = timecodeof($frames + $offset + $numwords);
                          $subtitle = convertToSub();
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                          $startTime = "";
                          $endTime = "";
                          $subtitle = "";
                          clearScreen();
                        }
                      }; last SWITCH;}; # {EDM}
          /2d/ && do {if ($ccMode eq "roll-up") {
                        $endTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        $startTime = timecodeof($frames + $offset + $numwords);
                        if ($subRollupMode) {
                          rollUp();
                        } else {
                          clearScreen();
                        }
                      }; last SWITCH;}; # {CR}
          /2e/ && do {clearScreen(); last SWITCH;}; # {ENM}
          /2f/ && do {if ($ccMode eq "pop-on") {
                        if ($endTime eq "") {
                          $endTime = timecodeof($frames + $offset + $numwords);
                        }
                        if ($subtitle ne "") {
                          outputSubtitle($subtitleNumber++, $startTime, $endTime, $subtitle);
                        }
                        $startTime = timecodeof($frames + $offset + $numwords);
                        $subtitle = convertToSub();
                        clearScreen();
                        $endTime = "";
                      }
                      last SWITCH;}; # {EOC}
          /40/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 5; $col = 0; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 5; $col = 4; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 5; $col = 4; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 5; $col = 8; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 5; $col = 8; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 5; $col = 12; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 5; $col = 12; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 5; $col = 16; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 5; $col = 16; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 5; $col = 20; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 5; $col = 20; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 5; $col = 24; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 5; $col = 24; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 5; $col = 28; $ruBottom = 5; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 5; $col = 28; $ruBottom = 5; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 6; $col = 0; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 6; $col = 4; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 6; $col = 4; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 6; $col = 8; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 6; $col = 8; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 6; $col = 12; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 6; $col = 12; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 6; $col = 16; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 6; $col = 16; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 6; $col = 20; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 6; $col = 20; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 6; $col = 24; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 6; $col = 24; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 6; $col = 28; $ruBottom = 6; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 6; $col = 28; $ruBottom = 6; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /16/ && do {
        for ($lo) {
          /40/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 7; $col = 0; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 7; $col = 4; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 7; $col = 4; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 7; $col = 8; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 7; $col = 8; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 7; $col = 12; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 7; $col = 12; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 7; $col = 16; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 7; $col = 16; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 7; $col = 20; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 7; $col = 20; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 7; $col = 24; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 7; $col = 24; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 7; $col = 28; $ruBottom = 7; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 7; $col = 28; $ruBottom = 7; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 8; $col = 0; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 8; $col = 4; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 8; $col = 4; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 8; $col = 8; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 8; $col = 8; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 8; $col = 12; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 8; $col = 12; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 8; $col = 16; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 8; $col = 16; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 8; $col = 20; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 8; $col = 20; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 8; $col = 24; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 8; $col = 24; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 8; $col = 28; $ruBottom = 8; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 8; $col = 28; $ruBottom = 8; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
      /17/ && do { # skipping codes that don't apply
        for ($lo) {
          /21/ && do {$col += 1; last SWITCH;}; # {TO1}
          /22/ && do {$col += 2; last SWITCH;}; # {TO2}
          /23/ && do {$col += 3; last SWITCH;}; # {TO3}
          /2e/ && do {$color = "8"; $underlined = 0; $italicized = 0; last SWITCH;};
          /2f/ && do {$color = "8"; $underlined = 1; $italicized = 0; last SWITCH;};
          /40/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /41/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /42/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /43/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /44/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /45/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /46/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /47/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /48/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /49/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4a/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /4b/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4c/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4d/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /4e/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /4f/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /50/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /51/ && do {$row = 9; $col = 0; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /52/ && do {$row = 9; $col = 4; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /53/ && do {$row = 9; $col = 4; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /54/ && do {$row = 9; $col = 8; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /55/ && do {$row = 9; $col = 8; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /56/ && do {$row = 9; $col = 12; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /57/ && do {$row = 9; $col = 12; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /58/ && do {$row = 9; $col = 16; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /59/ && do {$row = 9; $col = 16; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5a/ && do {$row = 9; $col = 20; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5b/ && do {$row = 9; $col = 20; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5c/ && do {$row = 9; $col = 24; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5d/ && do {$row = 9; $col = 24; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /5e/ && do {$row = 9; $col = 28; $ruBottom = 9; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /5f/ && do {$row = 9; $col = 28; $ruBottom = 9; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /60/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /61/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /62/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "1";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /63/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "1";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /64/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "2";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /65/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "2";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /66/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "3";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /67/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "3";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /68/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "4";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /69/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "4";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6a/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "5";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /6b/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "5";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6c/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6d/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "6";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /6e/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 1; last SWITCH;};
          /6f/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 1; last SWITCH;};
          /70/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /71/ && do {$row = 10; $col = 0; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /72/ && do {$row = 10; $col = 4; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /73/ && do {$row = 10; $col = 4; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /74/ && do {$row = 10; $col = 8; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /75/ && do {$row = 10; $col = 8; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /76/ && do {$row = 10; $col = 12; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /77/ && do {$row = 10; $col = 12; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /78/ && do {$row = 10; $col = 16; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /79/ && do {$row = 10; $col = 16; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7a/ && do {$row = 10; $col = 20; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7b/ && do {$row = 10; $col = 20; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7c/ && do {$row = 10; $col = 24; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7d/ && do {$row = 10; $col = 24; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
          /7e/ && do {$row = 10; $col = 28; $ruBottom = 10; $color = "0";
                      $underlined = 0; $italicized = 0; last SWITCH;};
          /7f/ && do {$row = 10; $col = 28; $ruBottom = 10; $color = "0";
                      $underlined = 1; $italicized = 0; last SWITCH;};
        };
      };
    }
    # extended characters replace the character immediately preceeding
    if ($extendedChar) {
      $outline = substr $outline, 0, -1;
      $col--;
    }
    if (($convertChannel ne $channel) or ($convertMode ne $mode)) {
      return "";
    }
    return $commandtoken;
  }
  # non-conversion
  SWITCH: for ($hi) {
    /10/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{BWh}"; last SWITCH;};
        /21/ && do {$commandtoken = "{BWhS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{BGr}"; last SWITCH;};
        /23/ && do {$commandtoken = "{BGrS}"; last SWITCH;};
        /24/ && do {$commandtoken = "{BBl}"; last SWITCH;};
        /25/ && do {$commandtoken = "{BBlS}"; last SWITCH;};
        /26/ && do {$commandtoken = "{BCy}"; last SWITCH;};
        /27/ && do {$commandtoken = "{BCyS}"; last SWITCH;};
        /28/ && do {$commandtoken = "{BR}"; last SWITCH;};
        /29/ && do {$commandtoken = "{BRS}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{BY}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{BYS}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{BMa}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{BMaS}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{BBk}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{BBkS}"; last SWITCH;};
        /40/ && do {$commandtoken = "{11Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{11WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{11Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{11GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{11Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{11BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{11Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{11CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{11R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{11RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{11Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{11YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{11Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{11MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{11WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{11WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1100}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1100U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1104}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1104U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1108}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1108U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1112}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1112U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1116}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1116U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1120}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1120U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1124}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1124U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1128}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1128U}"; last SWITCH;};
      };
    };
    /11/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Wh}"; last SWITCH;};
        /21/ && do {$commandtoken = "{WhU}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Gr}"; last SWITCH;};
        /23/ && do {$commandtoken = "{GrU}"; last SWITCH;};
        /24/ && do {$commandtoken = "{Bl}"; last SWITCH;};
        /25/ && do {$commandtoken = "{BlU}"; last SWITCH;};
        /26/ && do {$commandtoken = "{Cy}"; last SWITCH;};
        /27/ && do {$commandtoken = "{CyU}"; last SWITCH;};
        /28/ && do {$commandtoken = "{R}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RU}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{Y}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{YU}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{Ma}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{MaU}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{I}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{IU}"; last SWITCH;};
        /30/ && do {$commandtoken = "{reg}"; last SWITCH;};
        /31/ && do {$commandtoken = "{o}"; last SWITCH;};
        /32/ && do {$commandtoken = "{1/2}"; last SWITCH;};
        /33/ && do {$commandtoken = "{?}"; last SWITCH;};
        /34/ && do {$commandtoken = "{tm}"; last SWITCH;};
        /35/ && do {$commandtoken = "{cent}"; last SWITCH;};
        /36/ && do {$commandtoken = "{L}"; last SWITCH;};
        /37/ && do {$commandtoken = "{note}"; last SWITCH;};
        /38/ && do {$commandtoken = "{à}"; last SWITCH;};
        /39/ && do {$commandtoken = "{ }"; last SWITCH;};
        /3a/ && do {$commandtoken = "{è}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{â}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ê}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{î}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{ô}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{û}"; last SWITCH;};
        /40/ && do {$commandtoken = "{01Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{01WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{01Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{01GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{01Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{01BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{01Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{01CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{01R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{01RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{01Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{01YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{01Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{01MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{01WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{01WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0100}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0100U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0104}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0104U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0108}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0108U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0112}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0112U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0116}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0116U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0120}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0120U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0124}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0124U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0128}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0128U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{02Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{02WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{02Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{02GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{02Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{02BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{02Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{02CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{02R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{02RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{02Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{02YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{02Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{02MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{02WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{02WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0200}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0200U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0204}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0204U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0208}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0208U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0212}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0212U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0216}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0216U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0220}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0220U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0224}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0224U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0228}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0228U}"; last SWITCH;};
      };
    };
    /12/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Á}"; last SWITCH;};
        /21/ && do {$commandtoken = "{É}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Ó}"; last SWITCH;};
        /23/ && do {$commandtoken = "{Ú}"; last SWITCH;};
        /24/ && do {$commandtoken = "{Ü}"; last SWITCH;};
        /25/ && do {$commandtoken = "{ü}"; last SWITCH;};
        /26/ && do {$commandtoken = "{lsq}"; last SWITCH;};
        /27/ && do {$commandtoken = "{!}"; last SWITCH;};
        /28/ && do {$commandtoken = "{*}"; last SWITCH;};
        /29/ && do {$commandtoken = "{rsq}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{-}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{C}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{sm}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{.}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{rdq}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{ldq}"; last SWITCH;};
        /30/ && do {$commandtoken = "{À}"; last SWITCH;};
        /31/ && do {$commandtoken = "{Â}"; last SWITCH;};
        /32/ && do {$commandtoken = "{Ç}"; last SWITCH;};
        /33/ && do {$commandtoken = "{È}"; last SWITCH;};
        /34/ && do {$commandtoken = "{Ê}"; last SWITCH;};
        /35/ && do {$commandtoken = "{Ë}"; last SWITCH;};
        /36/ && do {$commandtoken = "{ë}"; last SWITCH;};
        /37/ && do {$commandtoken = "{Î}"; last SWITCH;};
        /38/ && do {$commandtoken = "{Ï}"; last SWITCH;};
        /39/ && do {$commandtoken = "{ï}"; last SWITCH;};
        /3a/ && do {$commandtoken = "{Ô}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{Ù}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ù}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{Û}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{<<}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{>>}"; last SWITCH;};
        /40/ && do {$commandtoken = "{03Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{03WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{03Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{03GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{03Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{03BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{03Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{03CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{03R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{03RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{03Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{03YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{03Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{03MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{03WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{03WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0300}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0300U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0304}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0304U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0308}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0308U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0312}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0312U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0316}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0316U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0320}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0320U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0324}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0324U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0328}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0328U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{04Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{04WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{04Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{04GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{04Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{04BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{04Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{04CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{04R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{04RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{04Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{04YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{04Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{04MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{04WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{04WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0400}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0400U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0404}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0404U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0408}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0408U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0412}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0412U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0416}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0416U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0420}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0420U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0424}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0424U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0428}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0428U}"; last SWITCH;};
      };
    };
    /13/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Ã}"; last SWITCH;};
        /21/ && do {$commandtoken = "{ã}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Í}"; last SWITCH;};
        /23/ && do {$commandtoken = "{Ì}"; last SWITCH;};
        /24/ && do {$commandtoken = "{ì}"; last SWITCH;};
        /25/ && do {$commandtoken = "{Ò}"; last SWITCH;};
        /26/ && do {$commandtoken = "{ò}"; last SWITCH;};
        /27/ && do {$commandtoken = "{Õ}"; last SWITCH;};
        /28/ && do {$commandtoken = "{õ}"; last SWITCH;};
        /29/ && do {$commandtoken = "{rb}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{lb}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{\}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{^}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{_}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{|}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{~}"; last SWITCH;};
        /30/ && do {$commandtoken = "{Ä}"; last SWITCH;};
        /31/ && do {$commandtoken = "{ä}"; last SWITCH;};
        /32/ && do {$commandtoken = "{Ö}"; last SWITCH;};
        /33/ && do {$commandtoken = "{ö}"; last SWITCH;};
        /34/ && do {$commandtoken = "{ß}"; last SWITCH;};
        /35/ && do {$commandtoken = "{yen}"; last SWITCH;};
        /36/ && do {$commandtoken = "{x}"; last SWITCH;};
        /37/ && do {$commandtoken = "{bar}"; last SWITCH;};
        /38/ && do {$commandtoken = "{Å}"; last SWITCH;};
        /39/ && do {$commandtoken = "{å}"; last SWITCH;};
        /3a/ && do {$commandtoken = "{Ø}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{ø}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ul}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{ur}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{ll}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{lr}"; last SWITCH;};
        /40/ && do {$commandtoken = "{12Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{12WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{12Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{12GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{12Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{12BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{12Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{12CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{12R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{12RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{12Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{12YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{12Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{12MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{12WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{12WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1200}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1200U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1204}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1204U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1208}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1208U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1212}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1212U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1216}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1216U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1220}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1220U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1224}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1224U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1228}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1228U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{13Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{13WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{13Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{13GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{13Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{13BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{13Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{13CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{13R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{13RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{13Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{13YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{13Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{13MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{13WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{13WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1300}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1300U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1304}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1304U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1308}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1308U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1312}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1312U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1316}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1316U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1320}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1320U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1324}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1324U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1328}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1328U}"; last SWITCH;};
      };
    };
    /14/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{RCL}"; $mode = "CC"; last SWITCH;};
        /21/ && do {$commandtoken = "{BS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{AOF}"; last SWITCH;};
        /23/ && do {$commandtoken = "{AON}"; last SWITCH;};
        /24/ && do {$commandtoken = "{DER}"; last SWITCH;};
        /25/ && do {$commandtoken = "{RU2}"; $mode = "CC"; last SWITCH;};
        /26/ && do {$commandtoken = "{RU3}"; $mode = "CC"; last SWITCH;};
        /27/ && do {$commandtoken = "{RU4}"; $mode = "CC"; last SWITCH;};
        /28/ && do {$commandtoken = "{FON}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RDC}"; $mode = "CC"; last SWITCH;};
        /2a/ && do {$commandtoken = "{TR}"; $mode = "Text"; last SWITCH;};
        /2b/ && do {$commandtoken = "{RTD}"; $mode = "Text"; last SWITCH;};
        /2c/ && do {$commandtoken = "{EDM}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{CR}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{ENM}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{EOC}"; last SWITCH;};
        /40/ && do {$commandtoken = "{14Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{14WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{14Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{14GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{14Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{14BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{14Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{14CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{14R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{14RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{14Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{14YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{14Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{14MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{14WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{14WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1400}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1400U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1404}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1404U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1408}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1408U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1412}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1412U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1416}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1416U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1420}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1420U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1424}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1424U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1428}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1428U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{15Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{15WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{15Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{15GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{15Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{15BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{15Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{15CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{15R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{15RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{15Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{15YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{15Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{15MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{15WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{15WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1500}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1500U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1504}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1504U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1508}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1508U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1512}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1512U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1516}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1516U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1520}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1520U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1524}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1524U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1528}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1528U}"; last SWITCH;};
      };
    };
    /15/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{RCL}"; $mode = "CC"; last SWITCH;};
        /21/ && do {$commandtoken = "{BS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{AOF}"; last SWITCH;};
        /23/ && do {$commandtoken = "{AON}"; last SWITCH;};
        /24/ && do {$commandtoken = "{DER}"; last SWITCH;};
        /25/ && do {$commandtoken = "{RU2}"; $mode = "CC"; last SWITCH;};
        /26/ && do {$commandtoken = "{RU3}"; $mode = "CC"; last SWITCH;};
        /27/ && do {$commandtoken = "{RU4}"; $mode = "CC"; last SWITCH;};
        /28/ && do {$commandtoken = "{FON}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RDC}"; $mode = "CC"; last SWITCH;};
        /2a/ && do {$commandtoken = "{TR}"; $mode = "Text"; last SWITCH;};
        /2b/ && do {$commandtoken = "{RTD}"; $mode = "Text"; last SWITCH;};
        /2c/ && do {$commandtoken = "{EDM}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{CR}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{ENM}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{EOC}"; last SWITCH;};
        /40/ && do {$commandtoken = "{05Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{05WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{05Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{05GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{05Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{05BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{05Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{05CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{05R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{05RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{05Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{05YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{05Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{05MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{05WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{05WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0500}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0500U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0504}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0504U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0508}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0508U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0512}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0512U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0516}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0516U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0520}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0520U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0524}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0524U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0528}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0528U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{06Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{06WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{06Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{06GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{06Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{06BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{06Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{06CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{06R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{06RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{06Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{06YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{06Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{06MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{06WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{06WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0600}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0600U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0604}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0604U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0608}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0608U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0612}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0612U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0616}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0616U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0620}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0620U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0624}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0624U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0628}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0628U}"; last SWITCH;};
      };
    };
    /16/ && do {
      for ($lo) {
        /40/ && do {$commandtoken = "{07Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{07WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{07Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{07GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{07Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{07BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{07Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{07CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{07R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{07RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{07Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{07YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{07Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{07MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{07WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{07WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0700}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0700U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0704}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0704U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0708}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0708U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0712}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0712U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0716}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0716U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0720}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0720U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0724}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0724U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0728}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0728U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{08Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{08WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{08Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{08GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{08Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{08BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{08Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{08CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{08R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{08RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{08Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{08YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{08Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{08MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{08WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{08WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0800}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0800U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0804}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0804U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0808}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0808U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0812}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0812U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0816}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0816U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0820}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0820U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0824}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0824U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0828}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0828U}"; last SWITCH;};
      };
    };
    /17/ && do {
      for ($lo) {
        /21/ && do {$commandtoken = "{TO1}"; last SWITCH;};
        /22/ && do {$commandtoken = "{TO2}"; last SWITCH;};
        /23/ && do {$commandtoken = "{TO3}"; last SWITCH;};
        /24/ && do {$commandtoken = "{CSS}"; last SWITCH;};
        /25/ && do {$commandtoken = "{CSD}"; last SWITCH;};
        /26/ && do {$commandtoken = "{CS1}"; last SWITCH;};
        /27/ && do {$commandtoken = "{CS2}"; last SWITCH;};
        /28/ && do {$commandtoken = "{CSC}"; last SWITCH;};
        /29/ && do {$commandtoken = "{CSK}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{CGU}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{BT}"; last SWITCH;};
        /40/ && do {$commandtoken = "{09Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{09WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{09Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{09GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{09Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{09BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{09Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{09CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{09R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{09RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{09Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{09YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{09Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{09MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{09WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{09WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0900}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0900U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0904}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0904U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0908}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0908U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0912}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0912U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0916}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0916U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0920}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0920U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0924}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0924U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0928}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0928U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{10Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{10WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{10Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{10GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{10Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{10BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{10Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{10CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{10R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{10RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{10Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{10YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{10Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{10MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{10WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{10WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1000}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1000U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1004}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1004U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1008}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1008U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1012}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1012U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1016}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1016U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1020}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1020U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1024}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1024U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1028}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1028U}"; last SWITCH;};
      };
    };
    /18/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{BWh}"; last SWITCH;};
        /21/ && do {$commandtoken = "{BWhS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{BGr}"; last SWITCH;};
        /23/ && do {$commandtoken = "{BGrS}"; last SWITCH;};
        /24/ && do {$commandtoken = "{BBl}"; last SWITCH;};
        /25/ && do {$commandtoken = "{BBlS}"; last SWITCH;};
        /26/ && do {$commandtoken = "{BCy}"; last SWITCH;};
        /27/ && do {$commandtoken = "{BCyS}"; last SWITCH;};
        /28/ && do {$commandtoken = "{BR}"; last SWITCH;};
        /29/ && do {$commandtoken = "{BRS}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{BY}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{BYS}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{BMa}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{BMaS}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{BBk}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{BBkS}"; last SWITCH;};
        /40/ && do {$commandtoken = "{11Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{11WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{11Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{11GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{11Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{11BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{11Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{11CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{11R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{11RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{11Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{11YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{11Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{11MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{11WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{11WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1100}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1100U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1104}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1104U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1108}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1108U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1112}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1112U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1116}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1116U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1120}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1120U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1124}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1124U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1128}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1128U}"; last SWITCH;};
      };
    };
    /19/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Wh}"; last SWITCH;};
        /21/ && do {$commandtoken = "{WhU}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Gr}"; last SWITCH;};
        /23/ && do {$commandtoken = "{GrU}"; last SWITCH;};
        /24/ && do {$commandtoken = "{Bl}"; last SWITCH;};
        /25/ && do {$commandtoken = "{BlU}"; last SWITCH;};
        /26/ && do {$commandtoken = "{Cy}"; last SWITCH;};
        /27/ && do {$commandtoken = "{CyU}"; last SWITCH;};
        /28/ && do {$commandtoken = "{R}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RU}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{Y}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{YU}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{Ma}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{MaU}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{I}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{IU}"; last SWITCH;};
        /30/ && do {$commandtoken = "{reg}"; last SWITCH;};
        /31/ && do {$commandtoken = "{o}"; last SWITCH;};
        /32/ && do {$commandtoken = "{1/2}"; last SWITCH;};
        /33/ && do {$commandtoken = "{?}"; last SWITCH;};
        /34/ && do {$commandtoken = "{tm}"; last SWITCH;};
        /35/ && do {$commandtoken = "{cent}"; last SWITCH;};
        /36/ && do {$commandtoken = "{L}"; last SWITCH;};
        /37/ && do {$commandtoken = "{note}"; last SWITCH;};
        /38/ && do {$commandtoken = "{à}"; last SWITCH;};
        /39/ && do {$commandtoken = "{ }"; last SWITCH;};
        /3a/ && do {$commandtoken = "{è}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{â}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ê}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{î}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{ô}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{û}"; last SWITCH;};
        /40/ && do {$commandtoken = "{01Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{01WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{01Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{01GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{01Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{01BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{01Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{01CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{01R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{01RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{01Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{01YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{01Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{01MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{01WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{01WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0100}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0100U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0104}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0104U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0108}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0108U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0112}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0112U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0116}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0116U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0120}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0120U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0124}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0124U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0128}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0128U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{02Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{02WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{02Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{02GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{02Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{02BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{02Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{02CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{02R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{02RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{02Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{02YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{02Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{02MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{02WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{02WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0200}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0200U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0204}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0204U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0208}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0208U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0212}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0212U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0216}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0216U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0220}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0220U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0224}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0224U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0228}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0228U}"; last SWITCH;};
      };
    };
    /1a/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Á}"; last SWITCH;};
        /21/ && do {$commandtoken = "{É}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Ó}"; last SWITCH;};
        /23/ && do {$commandtoken = "{Ú}"; last SWITCH;};
        /24/ && do {$commandtoken = "{Ü}"; last SWITCH;};
        /25/ && do {$commandtoken = "{ü}"; last SWITCH;};
        /26/ && do {$commandtoken = "{lsq}"; last SWITCH;};
        /27/ && do {$commandtoken = "{!}"; last SWITCH;};
        /28/ && do {$commandtoken = "{*}"; last SWITCH;};
        /29/ && do {$commandtoken = "{rsq}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{-}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{C}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{sm}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{.}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{rdq}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{ldq}"; last SWITCH;};
        /30/ && do {$commandtoken = "{À}"; last SWITCH;};
        /31/ && do {$commandtoken = "{Â}"; last SWITCH;};
        /32/ && do {$commandtoken = "{Ç}"; last SWITCH;};
        /33/ && do {$commandtoken = "{È}"; last SWITCH;};
        /34/ && do {$commandtoken = "{Ê}"; last SWITCH;};
        /35/ && do {$commandtoken = "{Ë}"; last SWITCH;};
        /36/ && do {$commandtoken = "{ë}"; last SWITCH;};
        /37/ && do {$commandtoken = "{Î}"; last SWITCH;};
        /38/ && do {$commandtoken = "{Ï}"; last SWITCH;};
        /39/ && do {$commandtoken = "{ï}"; last SWITCH;};
        /3a/ && do {$commandtoken = "{Ô}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{Ù}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ù}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{Û}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{<<}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{>>}"; last SWITCH;};
        /40/ && do {$commandtoken = "{03Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{03WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{03Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{03GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{03Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{03BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{03Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{03CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{03R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{03RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{03Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{03YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{03Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{03MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{03WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{03WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0300}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0300U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0304}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0304U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0308}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0308U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0312}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0312U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0316}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0316U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0320}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0320U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0324}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0324U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0328}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0328U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{04Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{04WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{04Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{04GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{04Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{04BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{04Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{04CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{04R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{04RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{04Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{04YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{04Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{04MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{04WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{04WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0400}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0400U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0404}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0404U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0408}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0408U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0412}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0412U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0416}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0416U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0420}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0420U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0424}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0424U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0428}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0428U}"; last SWITCH;};
      };
    };
    /1b/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{Ã}"; last SWITCH;};
        /21/ && do {$commandtoken = "{ã}"; last SWITCH;};
        /22/ && do {$commandtoken = "{Í}"; last SWITCH;};
        /23/ && do {$commandtoken = "{Ì}"; last SWITCH;};
        /24/ && do {$commandtoken = "{ì}"; last SWITCH;};
        /25/ && do {$commandtoken = "{Ò}"; last SWITCH;};
        /26/ && do {$commandtoken = "{ò}"; last SWITCH;};
        /27/ && do {$commandtoken = "{Õ}"; last SWITCH;};
        /28/ && do {$commandtoken = "{õ}"; last SWITCH;};
        /29/ && do {$commandtoken = "{rb}"; last SWITCH;};
        /2a/ && do {$commandtoken = "{lb}"; last SWITCH;};
        /2b/ && do {$commandtoken = "{\}"; last SWITCH;};
        /2c/ && do {$commandtoken = "{^}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{_}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{|}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{~}"; last SWITCH;};
        /30/ && do {$commandtoken = "{Ä}"; last SWITCH;};
        /31/ && do {$commandtoken = "{ä}"; last SWITCH;};
        /32/ && do {$commandtoken = "{Ö}"; last SWITCH;};
        /33/ && do {$commandtoken = "{ö}"; last SWITCH;};
        /34/ && do {$commandtoken = "{ß}"; last SWITCH;};
        /35/ && do {$commandtoken = "{yen}"; last SWITCH;};
        /36/ && do {$commandtoken = "{x}"; last SWITCH;};
        /37/ && do {$commandtoken = "{bar}"; last SWITCH;};
        /38/ && do {$commandtoken = "{Å}"; last SWITCH;};
        /39/ && do {$commandtoken = "{å}"; last SWITCH;};
        /3a/ && do {$commandtoken = "{Ø}"; last SWITCH;};
        /3b/ && do {$commandtoken = "{ø}"; last SWITCH;};
        /3c/ && do {$commandtoken = "{ul}"; last SWITCH;};
        /3d/ && do {$commandtoken = "{ur}"; last SWITCH;};
        /3e/ && do {$commandtoken = "{ll}"; last SWITCH;};
        /3f/ && do {$commandtoken = "{lr}"; last SWITCH;};
        /40/ && do {$commandtoken = "{12Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{12WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{12Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{12GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{12Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{12BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{12Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{12CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{12R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{12RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{12Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{12YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{12Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{12MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{12WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{12WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1200}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1200U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1204}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1204U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1208}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1208U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1212}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1212U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1216}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1216U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1220}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1220U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1224}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1224U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1228}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1228U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{13Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{13WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{13Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{13GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{13Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{13BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{13Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{13CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{13R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{13RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{13Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{13YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{13Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{13MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{13WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{13WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1300}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1300U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1304}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1304U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1308}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1308U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1312}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1312U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1316}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1316U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1320}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1320U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1324}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1324U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1328}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1328U}"; last SWITCH;};
      };
    };
    /1c/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{RCL}"; $mode = "CC"; last SWITCH;};
        /21/ && do {$commandtoken = "{BS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{AOF}"; last SWITCH;};
        /23/ && do {$commandtoken = "{AON}"; last SWITCH;};
        /24/ && do {$commandtoken = "{DER}"; last SWITCH;};
        /25/ && do {$commandtoken = "{RU2}"; $mode = "CC"; last SWITCH;};
        /26/ && do {$commandtoken = "{RU3}"; $mode = "CC"; last SWITCH;};
        /27/ && do {$commandtoken = "{RU4}"; $mode = "CC"; last SWITCH;};
        /28/ && do {$commandtoken = "{FON}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RDC}"; $mode = "CC"; last SWITCH;};
        # text channel 2 is reserved for ITV messages
        /2a/ && do {$commandtoken = "{TR}"; $mode = "ITV"; last SWITCH;};
        /2b/ && do {$commandtoken = "{RTD}"; $mode = "ITV"; last SWITCH;};
        /2c/ && do {$commandtoken = "{EDM}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{CR}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{ENM}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{EOC}"; last SWITCH;};
        /40/ && do {$commandtoken = "{14Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{14WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{14Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{14GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{14Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{14BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{14Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{14CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{14R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{14RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{14Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{14YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{14Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{14MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{14WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{14WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{1400}"; last SWITCH;};
        /51/ && do {$commandtoken = "{1400U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{1404}"; last SWITCH;};
        /53/ && do {$commandtoken = "{1404U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{1408}"; last SWITCH;};
        /55/ && do {$commandtoken = "{1408U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{1412}"; last SWITCH;};
        /57/ && do {$commandtoken = "{1412U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{1416}"; last SWITCH;};
        /59/ && do {$commandtoken = "{1416U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{1420}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{1420U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{1424}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{1424U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{1428}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{1428U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{15Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{15WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{15Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{15GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{15Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{15BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{15Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{15CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{15R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{15RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{15Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{15YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{15Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{15MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{15WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{15WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1500}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1500U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1504}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1504U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1508}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1508U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1512}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1512U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1516}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1516U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1520}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1520U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1524}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1524U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1528}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1528U}"; last SWITCH;};
      };
    };
    /1d/ && do {
      for ($lo) {
        /20/ && do {$commandtoken = "{RCL}"; $mode = "CC"; last SWITCH;};
        /21/ && do {$commandtoken = "{BS}"; last SWITCH;};
        /22/ && do {$commandtoken = "{AOF}"; last SWITCH;};
        /23/ && do {$commandtoken = "{AON}"; last SWITCH;};
        /24/ && do {$commandtoken = "{DER}"; last SWITCH;};
        /25/ && do {$commandtoken = "{RU2}"; $mode = "CC"; last SWITCH;};
        /26/ && do {$commandtoken = "{RU3}"; $mode = "CC"; last SWITCH;};
        /27/ && do {$commandtoken = "{RU4}"; $mode = "CC"; last SWITCH;};
        /28/ && do {$commandtoken = "{FON}"; last SWITCH;};
        /29/ && do {$commandtoken = "{RDC}"; $mode = "CC"; last SWITCH;};
        /2a/ && do {$commandtoken = "{TR}"; $mode = "Text"; last SWITCH;};
        /2b/ && do {$commandtoken = "{RTD}"; $mode = "Text"; last SWITCH;};
        /2c/ && do {$commandtoken = "{EDM}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{CR}"; last SWITCH;};
        /2e/ && do {$commandtoken = "{ENM}"; last SWITCH;};
        /2f/ && do {$commandtoken = "{EOC}"; last SWITCH;};
        /40/ && do {$commandtoken = "{05Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{05WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{05Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{05GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{05Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{05BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{05Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{05CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{05R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{05RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{05Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{05YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{05Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{05MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{05WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{05WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0500}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0500U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0504}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0504U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0508}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0508U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0512}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0512U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0516}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0516U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0520}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0520U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0524}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0524U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0528}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0528U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{06Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{06WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{06Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{06GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{06Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{06BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{06Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{06CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{06R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{06RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{06Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{06YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{06Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{06MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{06WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{06WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0600}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0600U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0604}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0604U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0608}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0608U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0612}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0612U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0616}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0616U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0620}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0620U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0624}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0624U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0628}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0628U}"; last SWITCH;};
      };
    };
    /1e/ && do {
      for ($lo) {
        /40/ && do {$commandtoken = "{07Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{07WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{07Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{07GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{07Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{07BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{07Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{07CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{07R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{07RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{07Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{07YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{07Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{07MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{07WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{07WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0700}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0700U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0704}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0704U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0708}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0708U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0712}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0712U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0716}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0716U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0720}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0720U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0724}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0724U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0728}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0728U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{08Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{08WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{08Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{08GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{08Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{08BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{08Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{08CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{08R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{08RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{08Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{08YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{08Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{08MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{08WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{08WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{0800}"; last SWITCH;};
        /71/ && do {$commandtoken = "{0800U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{0804}"; last SWITCH;};
        /73/ && do {$commandtoken = "{0804U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{0808}"; last SWITCH;};
        /75/ && do {$commandtoken = "{0808U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{0812}"; last SWITCH;};
        /77/ && do {$commandtoken = "{0812U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{0816}"; last SWITCH;};
        /79/ && do {$commandtoken = "{0816U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{0820}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{0820U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{0824}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{0824U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{0828}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{0828U}"; last SWITCH;};
      };
    };
    /1f/ && do {
      for ($lo) {
        /21/ && do {$commandtoken = "{TO1}"; last SWITCH;};
        /22/ && do {$commandtoken = "{TO2}"; last SWITCH;};
        /23/ && do {$commandtoken = "{TO3}"; last SWITCH;};
        /2d/ && do {$commandtoken = "{BT}"; last SWITCH;};
        /40/ && do {$commandtoken = "{09Wh}"; last SWITCH;};
        /41/ && do {$commandtoken = "{09WhU}"; last SWITCH;};
        /42/ && do {$commandtoken = "{09Gr}"; last SWITCH;};
        /43/ && do {$commandtoken = "{09GrU}"; last SWITCH;};
        /44/ && do {$commandtoken = "{09Bl}"; last SWITCH;};
        /45/ && do {$commandtoken = "{09BlU}"; last SWITCH;};
        /46/ && do {$commandtoken = "{09Cy}"; last SWITCH;};
        /47/ && do {$commandtoken = "{09CyU}"; last SWITCH;};
        /48/ && do {$commandtoken = "{09R}"; last SWITCH;};
        /49/ && do {$commandtoken = "{09RU}"; last SWITCH;};
        /4a/ && do {$commandtoken = "{09Y}"; last SWITCH;};
        /4b/ && do {$commandtoken = "{09YU}"; last SWITCH;};
        /4c/ && do {$commandtoken = "{09Ma}"; last SWITCH;};
        /4d/ && do {$commandtoken = "{09MaU}"; last SWITCH;};
        /4e/ && do {$commandtoken = "{09WhI}"; last SWITCH;};
        /4f/ && do {$commandtoken = "{09WhIU}"; last SWITCH;};
        /50/ && do {$commandtoken = "{0900}"; last SWITCH;};
        /51/ && do {$commandtoken = "{0900U}"; last SWITCH;};
        /52/ && do {$commandtoken = "{0904}"; last SWITCH;};
        /53/ && do {$commandtoken = "{0904U}"; last SWITCH;};
        /54/ && do {$commandtoken = "{0908}"; last SWITCH;};
        /55/ && do {$commandtoken = "{0908U}"; last SWITCH;};
        /56/ && do {$commandtoken = "{0912}"; last SWITCH;};
        /57/ && do {$commandtoken = "{0912U}"; last SWITCH;};
        /58/ && do {$commandtoken = "{0916}"; last SWITCH;};
        /59/ && do {$commandtoken = "{0916U}"; last SWITCH;};
        /5a/ && do {$commandtoken = "{0920}"; last SWITCH;};
        /5b/ && do {$commandtoken = "{0920U}"; last SWITCH;};
        /5c/ && do {$commandtoken = "{0924}"; last SWITCH;};
        /5d/ && do {$commandtoken = "{0924U}"; last SWITCH;};
        /5e/ && do {$commandtoken = "{0928}"; last SWITCH;};
        /5f/ && do {$commandtoken = "{0928U}"; last SWITCH;};
        /60/ && do {$commandtoken = "{10Wh}"; last SWITCH;};
        /61/ && do {$commandtoken = "{10WhU}"; last SWITCH;};
        /62/ && do {$commandtoken = "{10Gr}"; last SWITCH;};
        /63/ && do {$commandtoken = "{10GrU}"; last SWITCH;};
        /64/ && do {$commandtoken = "{10Bl}"; last SWITCH;};
        /65/ && do {$commandtoken = "{10BlU}"; last SWITCH;};
        /66/ && do {$commandtoken = "{10Cy}"; last SWITCH;};
        /67/ && do {$commandtoken = "{10CyU}"; last SWITCH;};
        /68/ && do {$commandtoken = "{10R}"; last SWITCH;};
        /69/ && do {$commandtoken = "{10RU}"; last SWITCH;};
        /6a/ && do {$commandtoken = "{10Y}"; last SWITCH;};
        /6b/ && do {$commandtoken = "{10YU}"; last SWITCH;};
        /6c/ && do {$commandtoken = "{10Ma}"; last SWITCH;};
        /6d/ && do {$commandtoken = "{10MaU}"; last SWITCH;};
        /6e/ && do {$commandtoken = "{10WhI}"; last SWITCH;};
        /6f/ && do {$commandtoken = "{10WhIU}"; last SWITCH;};
        /70/ && do {$commandtoken = "{1000}"; last SWITCH;};
        /71/ && do {$commandtoken = "{1000U}"; last SWITCH;};
        /72/ && do {$commandtoken = "{1004}"; last SWITCH;};
        /73/ && do {$commandtoken = "{1004U}"; last SWITCH;};
        /74/ && do {$commandtoken = "{1008}"; last SWITCH;};
        /75/ && do {$commandtoken = "{1008U}"; last SWITCH;};
        /76/ && do {$commandtoken = "{1012}"; last SWITCH;};
        /77/ && do {$commandtoken = "{1012U}"; last SWITCH;};
        /78/ && do {$commandtoken = "{1016}"; last SWITCH;};
        /79/ && do {$commandtoken = "{1016U}"; last SWITCH;};
        /7a/ && do {$commandtoken = "{1020}"; last SWITCH;};
        /7b/ && do {$commandtoken = "{1020U}"; last SWITCH;};
        /7c/ && do {$commandtoken = "{1024}"; last SWITCH;};
        /7d/ && do {$commandtoken = "{1024U}"; last SWITCH;};
        /7e/ && do {$commandtoken = "{1028}"; last SWITCH;};
        /7f/ && do {$commandtoken = "{1028U}"; last SWITCH;};
      };
    };
  }
  return $commandtoken;
}

sub disChar {
  if (($convert) and (($convertChannel ne $channel) or ($convertMode ne $mode))) {
    return "";
  }
  my $byte = sprintf ("%02x", shift(@_));
  my $char = "£"; # placeholder for failed match
  # ITV uses a slightly different character set
  SWITCH: for ($byte) {
    /00/ && do {$char = "_"; last SWITCH;};
    /20/ && do {$char = " "; last SWITCH;};
    /21/ && do {$char = "!"; last SWITCH;};
    /22/ && do {$char = "\""; last SWITCH;};
    /23/ && do {$char = "#"; last SWITCH;};
    /24/ && do {$char = "\$"; last SWITCH;};
    /25/ && do {$char = "%"; last SWITCH;};
    /26/ && do {$char = "&"; last SWITCH;};
    /27/ && do {$char = "'"; last SWITCH;};
    /28/ && do {$char = "("; last SWITCH;};
    /29/ && do {$char = ")"; last SWITCH;};
    /2a/ && do {
      if ($mode eq "ITV") {$char = "*";} else {$char = "á";}
      last SWITCH;};
    /2b/ && do {$char = "+"; last SWITCH;};
    /2c/ && do {$char = ","; last SWITCH;};
    /2d/ && do {$char = "-"; last SWITCH;};
    /2e/ && do {$char = "."; last SWITCH;};
    /2f/ && do {$char = "/"; last SWITCH;};
    /30/ && do {$char = "0"; last SWITCH;};
    /31/ && do {$char = "1"; last SWITCH;};
    /32/ && do {$char = "2"; last SWITCH;};
    /33/ && do {$char = "3"; last SWITCH;};
    /34/ && do {$char = "4"; last SWITCH;};
    /35/ && do {$char = "5"; last SWITCH;};
    /36/ && do {$char = "6"; last SWITCH;};
    /37/ && do {$char = "7"; last SWITCH;};
    /38/ && do {$char = "8"; last SWITCH;};
    /39/ && do {$char = "9"; last SWITCH;};
    /3a/ && do {$char = ":"; last SWITCH;};
    /3b/ && do {$char = ";"; last SWITCH;};
    /3c/ && do {$char = "<"; last SWITCH;};
    /3d/ && do {$char = "="; last SWITCH;};
    /3e/ && do {$char = ">"; last SWITCH;};
    /3f/ && do {$char = "?"; last SWITCH;};
    /40/ && do {$char = "@"; last SWITCH;};
    /41/ && do {$char = "A"; last SWITCH;};
    /42/ && do {$char = "B"; last SWITCH;};
    /43/ && do {$char = "C"; last SWITCH;};
    /44/ && do {$char = "D"; last SWITCH;};
    /45/ && do {$char = "E"; last SWITCH;};
    /46/ && do {$char = "F"; last SWITCH;};
    /47/ && do {$char = "G"; last SWITCH;};
    /48/ && do {$char = "H"; last SWITCH;};
    /49/ && do {$char = "I"; last SWITCH;};
    /4a/ && do {$char = "J"; last SWITCH;};
    /4b/ && do {$char = "K"; last SWITCH;};
    /4c/ && do {$char = "L"; last SWITCH;};
    /4d/ && do {$char = "M"; last SWITCH;};
    /4e/ && do {$char = "N"; last SWITCH;};
    /4f/ && do {$char = "O"; last SWITCH;};
    /50/ && do {$char = "P"; last SWITCH;};
    /51/ && do {$char = "Q"; last SWITCH;};
    /52/ && do {$char = "R"; last SWITCH;};
    /53/ && do {$char = "S"; last SWITCH;};
    /54/ && do {$char = "T"; last SWITCH;};
    /55/ && do {$char = "U"; last SWITCH;};
    /56/ && do {$char = "V"; last SWITCH;};
    /57/ && do {$char = "W"; last SWITCH;};
    /58/ && do {$char = "X"; last SWITCH;};
    /59/ && do {$char = "Y"; last SWITCH;};
    /5a/ && do {$char = "Z"; last SWITCH;};
    /5b/ && do {$char = "["; last SWITCH;};
    /5c/ && do {
      if ($mode eq "ITV") {$char = "\\";} else {$char = "é";}
      last SWITCH;};
    /5d/ && do {$char = "]"; last SWITCH;};
    /5e/ && do {
      if ($mode eq "ITV") {$char = "^";} else {$char = "í";}
      last SWITCH;};
    /5f/ && do {
      if ($mode eq "ITV") {$char = "_";} else {$char = "ó";}
      last SWITCH;};
    /60/ && do {
      if ($mode eq "ITV") {$char = "`";} else {$char = "ú";}
      last SWITCH;};
    /61/ && do {$char = "a"; last SWITCH;};
    /62/ && do {$char = "b"; last SWITCH;};
    /63/ && do {$char = "c"; last SWITCH;};
    /64/ && do {$char = "d"; last SWITCH;};
    /65/ && do {$char = "e"; last SWITCH;};
    /66/ && do {$char = "f"; last SWITCH;};
    /67/ && do {$char = "g"; last SWITCH;};
    /68/ && do {$char = "h"; last SWITCH;};
    /69/ && do {$char = "i"; last SWITCH;};
    /6a/ && do {$char = "j"; last SWITCH;};
    /6b/ && do {$char = "k"; last SWITCH;};
    /6c/ && do {$char = "l"; last SWITCH;};
    /6d/ && do {$char = "m"; last SWITCH;};
    /6e/ && do {$char = "n"; last SWITCH;};
    /6f/ && do {$char = "o"; last SWITCH;};
    /70/ && do {$char = "p"; last SWITCH;};
    /71/ && do {$char = "q"; last SWITCH;};
    /72/ && do {$char = "r"; last SWITCH;};
    /73/ && do {$char = "s"; last SWITCH;};
    /74/ && do {$char = "t"; last SWITCH;};
    /75/ && do {$char = "u"; last SWITCH;};
    /76/ && do {$char = "v"; last SWITCH;};
    /77/ && do {$char = "w"; last SWITCH;};
    /78/ && do {$char = "x"; last SWITCH;};
    /79/ && do {$char = "y"; last SWITCH;};
    /7a/ && do {$char = "z"; last SWITCH;};
    /7b/ && do {
      if ($mode eq "ITV") {$char = "{";} else {$char = "ç";}
      last SWITCH;};
    /7c/ && do {
      if ($mode eq "ITV") {$char = "|";} else {$char = "÷";}
      last SWITCH;};
    /7d/ && do {
      if ($mode eq "ITV") {$char = "}";} else {$char = "Ñ";}
      last SWITCH;};
    /7e/ && do {
      if ($mode eq "ITV") {$char = "~";} else {$char = "ñ";}
      last SWITCH;};
    /7f/ && do {
      if ($mode eq "ITV") {$char = "£";} else {$char = "|";}
      last SWITCH;};
  }
  if (($convert) and (($byte eq "00") or ($char eq "£"))) {
    $char = "";
  }
  return $char;
}

sub disXDS {
  my @xdsList = @_;
  my $xds = "{XDS";
  # byte 0 is class of Current, Future, cHannel, Miscellaneous,
  #  Public service, Reserved, or Undefined, each of which can
  #  be a start code or a continue code
  my $class;
  # byte 1 is type, which varies based on class--see below
  my $type = sprintf("%02x",$xdsList[1]);
  my $typeDefined = 1; # Reserved and Undefined Classes have no defined types
  SWITCH: for ($xdsList[0]) {
    /^1$/ && do {$class = "Cs"; last SWITCH;};
    /^2$/ && do {$class = "Cc"; last SWITCH;};
    /^3$/ && do {$class = "Fs"; last SWITCH;};
    /^4$/ && do {$class = "Fc"; last SWITCH;};
    /^5$/ && do {$class = "Hs"; last SWITCH;};
    /^6$/ && do {$class = "Hc"; last SWITCH;};
    /^7$/ && do {$class = "Ms"; last SWITCH;};
    /^8$/ && do {$class = "Mc"; last SWITCH;};
    /^9$/ && do {$class = "Ps"; last SWITCH;};
    /^10$/ && do {$class = "Pc"; last SWITCH;};
    /^11$/ && do {$class = "Rs"; last SWITCH;};
    /^12$/ && do {$class = "Rc"; last SWITCH;};
    /^13$/ && do {$class = "Us"; last SWITCH;};
    /^14$/ && do {$class = "Uc"; last SWITCH;};
  }
  $xds = $xds." ".$class;
  
  # if type byte is not defined for class, just output it
  if (($class =~ "C.") or ($class =~ "F.")) {
    SWITCH: for ($xdsList[1]) {
      /^1$/ && do {$type = "ST"; last SWITCH;};  # Start Time/Program ID
      /^2$/ && do {$type = "PL"; last SWITCH;};  # Program Length/Time in Show
      /^3$/ && do {$type = "PN"; last SWITCH;};  # Program Name
      /^4$/ && do {$type = "PT"; last SWITCH;};  # Program Types
      /^5$/ && do {$type = "PR"; last SWITCH;};  # Program Rating (V-Chip)
      /^6$/ && do {$type = "AS"; last SWITCH;};  # Audio Streams
      /^7$/ && do {$type = "CS"; last SWITCH;};  # Caption Streams
      /^8$/ && do {$type = "CG"; last SWITCH;};  # Copy Generation Management System
      /^9$/ && do {$type = "AR"; last SWITCH;};  # Aspect Ratio
      /^12$/ && do {$type = "PD"; last SWITCH;}; # Program Data
      /^13$/ && do {$type = "MD"; last SWITCH;}; # Miscellaneous Data
    }
    if (($xdsList[1] >= 16) and ($xdsList[1] <= 23)) {
      $type = "D".($xdsList[1] - 15); # Program Description, lines 1 - 8
    }
  }
  if ($class =~ "H.") {
    SWITCH: for ($xdsList[1]) {
      /^1$/ && do {$type = "NN"; last SWITCH;}; # Network Name
      /^2$/ && do {$type = "NC"; last SWITCH;}; # Network Call Letters
      /^3$/ && do {$type = "TD"; last SWITCH;}; # Channel Tape Delay
      /^4$/ && do {$type = "TS"; last SWITCH;}; # Transmission Signal Identifier
    }
  }
  if ($class =~ "M.") {
    SWITCH: for ($xdsList[1]) {
      /^1$/ && do {$type = "TM"; last SWITCH;};  # Time of Day
      /^2$/ && do {$type = "IC"; last SWITCH;};  # Impulse Capture ID
      /^3$/ && do {$type = "SD"; last SWITCH;};  # Supplemental Data Location
      /^4$/ && do {$type = "TZ"; last SWITCH;};  # Local Time Zone
      /^64$/ && do {$type = "OB"; last SWITCH;}; # Out of Band Channel
      /^65$/ && do {$type = "CP"; last SWITCH;}; # Channel Map Pointer
      /^66$/ && do {$type = "CH"; last SWITCH;}; # Channel Map Header
      /^67$/ && do {$type = "CM"; last SWITCH;}; # Channel Map
    }
  }
  if ($class =~ "P.") {
    SWITCH: for ($xdslist[1]) {
      /^1$/ && do {$type = "WB"; last SWITCH;}; # National Weather Service Bulletin
      /^2$/ && do {$type = "WM"; last SWITCH;}; # National Weather Service Message
    }
  }
  # Reserved and Undefined Classes have no defined types
  if ($type eq sprintf("%02x",$xdsList[1])) {
    $typeDefined = 0;
  } else {
    $typeDefined = 1;
  }

  $xds = $xds." ".$type;
  
  my @Month = ("", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
  my @Language = ("Unknown", "English", "Español", "Français",
                  "Deutsch", "Italiano", "Other", "None");

  my $typeFound = 0; # flag to find undefined types
  if ($type eq "ST") { # Start Time/Program ID
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $d = "S"; # daylight savings time ("D") or standard time ("S")
      my $hr = $xdsList[3 - $XDSPosition{$type}] - 64; # byte 3 is hour (0 - 23)
      if ($hr > 32) {
        $d = "D";
        $hr -= 32;
      }
      my $mi = $xdsList[2 - $XDSPosition{$type}] - 64; # byte 2 is minute (0 - 59)
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi).$d;
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      my $z = "_"; # zero seconds ("Z") or not ("_")
      my $t = "N"; # tape delay ("T") or not ("N")
      my $l = "A"; # February 29th ("L"eap day) or not ("A")
      my $mo = $xdsList[5 - $XDSPosition{$type}] - 64; # byte 5 is month number
      if ($mo > 32) {
        $z = "Z";
        $mo -= 32;
      }
      if ($mo > 16) {
        $t = "T";
        $mo -= 16;
      }
      my $dy = $xdsList[4 - $XDSPosition{$type}] - 64; # byte 4 is day number
      if ($dy > 32) {
        $l = "L";
        $dy -= 32;
      }
      $xds = $xds." ".$z.$t.$l;
      $xds = $xds." ".$Month[$mo];
      $xds = $xds." ".sprintf("%02d", $dy);
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > 6) {
      # byte 6 is 0x0f, to announce checksum 
      my $checksum = oddParity($xdsList[7 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar(@xdsList) - 2;
    }
  }
  
  if ($type eq "PL") { # Program Length/Time in Show
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $hr = $xdsList[3 - $XDSPosition{$type}] - 64; # byte 3 is hours long
      my $mi = $xdsList[2 - $XDSPosition{$type}] - 64; # byte 2 is minutes long
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi);
    }
    # remaining fields are optional
    my $checksumByte = 5;
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      if ($xdsList[4 - $XDSPosition{$type}] != 15) {
        $checksumByte += 2;
        my $hr = $xdsList[5 - $XDSPosition{$type}] - 64; # byte 5 is hours elapsed
        my $mi = $xdsList[4 - $XDSPosition{$type}] - 64; # byte 4 is minutes elapsed
        $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi);
      }
    }
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      if ($xdsList[6 - $XDSPosition{$type}] != 15) {
        $checksumByte += 2;
        # byte 6 is seconds elapsed, in 8 second increments
        my $se = $xdsList[6 - $XDSPosition{$type}] - 64; 
        $xds = $xds.":".sprintf("%02d", $se);
      }
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > $checksumByte - 1) {
      # last byte (5, 7, or 9) is checksum 
      my $checksum = oddParity($xdsList[$checksumByte - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "PN") { # Program Name
    $xds = $xds." ";
    my $position = 2;
    if (scalar @xdsList > 2) {
      while (($xdsList[$position] != 15) and ($position <= scalar @xdsList)) {
        if (($xdsList[$position - $XDSPosition{$type}] > 0x1f)
            && ($xdsList[$position - $XDSPosition{$type}] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position]);
        }
        $position++;
      }
    }
    if ((scalar @xdsList > $position) && ($xdsList[$position] == 15)) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "PT") { # Program Types
    my @ProgramTypes =
     ("Education", "Entertainment", "Movie", "News",
      "Religious", "Sports", "Other", "Action",
      "Advertisement", "Animated", "Anthology", "Automobile",
      "Awards", "Baseball", "Basketball", "Bulletin",
      "Business", "Classical", "College", "Combat",
      "Comedy", "Commentary", "Concert", "Consumer",
      "Contemporary", "Crime", "Dance", "Documentary",
      "Drama", "Elementary", "Erotica", "Exercise",
      "Fantasy", "Farm", "Fashion", "Fiction",
      "Food", "Football", "Foreign", "Fund-Raiser",
      "Game/Quiz", "Garden", "Golf", "Government",
      "Health", "High_School", "History", "Hobby",
      "Hockey", "Home", "Horror", "Information",
      "Instruction", "International", "Interview", "Language",
      "Legal", "Live", "Local", "Math",
      "Medical", "Meeting", "Military", "Mini-Series",
      "Music", "Mystery", "National", "Nature",
      "Police", "Politics", "Premiere", "Pre-Recorded",
      "Product", "Professional", "Public", "Racing",
      "Reading", "Repair", "Repeat", "Review",
      "Romance", "Science", "Series", "Service",
      "Shopping", "Soap_Opera", "Special", "Suspense",
      "Talk", "Technical", "Tennis", "Travel",
      "Variety", "Video", "Weather", "Western");
    my $position = 2;
    if (scalar @xdsList + $XDSPosition{$type} > 2) {
      while (($xdsList[$position] != 15) and ($position < scalar @xdsList)) {
        $xds = $xds." ".$ProgramTypes[$xdsList[$position] - 32];
        $position++;
      }
    }
    if ((scalar @xdsList > $position) && ($xdsList[$position] == 15)) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "PR") { # Program Rating (V-Chip)
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # advisories, which only apply to ratingSystem TPG
      my $dg = "_"; # sexually-suggestive dialog advisory ("D") or not ("_")
      my $lg = "_"; # coarse language advisory ("L") or not ("_")
      my $sx = "_"; # sexual situations advisory ("S") or not ("_")
      my $vc = "_"; # violent content advisory ("V") or not ("_")
                    #  (doubles as fantasy violence advisory for TV-Y rating)
      my $ratingSystem = ""; # rating system of
                             #  Motion Picture Association of America ("MPAA"),
                             #  Television Parental Guidelines ("TPG"),
                             #  Canada English ("CE") or
                             #  Canada Français ("CF")
      # rating can be in either byte 2 or 3, depending on ratingSystem
      my $byte = $xdsList[2 - $XDSPosition{$type}] - 64; 
      if ($byte == 56) {
        $ratingSystem = "CF";
      }
      if ($byte == 40) {
        $ratingSystem = "TPG";
        $dg = "D";
      }
      if ($byte == 24) {
        $ratingSystem = "CE";
      }
      if ($byte == 8) {
        $ratingSystem = "TPG";
        $dg = "_";
      }
      if ($byte < 8) {
        $ratingSystem = "MPAA";
      }
      my @Ratings = ();
      my $rating = "";
      if ($ratingSystem eq "MPAA") {
        @Ratings = ("", "G", "PG", "PG-13", "R", "NC-17", "X", "NR");
        $rating = $Ratings[$byte];
      } else {
        $byte = $xdsList[3 - $XDSPosition{$type}] - 64;
        if ($byte >= 32) {
          $vc = "V";
          $byte -= 32;
        }
        if ($byte >= 16) {
          $sx = "S";
          $byte -= 16;
        }
        if ($byte >= 8) {
          $lg = "L";
          $byte -= 8;
        }
        if ($ratingSystem eq "TPG") {
          @Ratings = ("None", "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA", "None");
        }
        if ($ratingSystem eq "CE") {
          @Ratings = ("E", "C", "C8+", "G", "PG", "14+", "18+");
        }
        if ($ratingSystem eq "CF") {
          @Ratings = ("E", "G", "8+", "13+", "16+", "18+");
        }
        $rating = $Ratings[$byte];
      }
      $xds = $xds." ".$ratingSystem." ".$rating;
      if ($ratingSystem eq "TPG") {
        $xds = $xds." ".$dg.$lg.$sx.$vc;
      }
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > 4) {
      # byte 4 is 0x0f, to announce checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "AS") { # Audio Streams
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my @StreamType = ("Unknown", "Mono", "Simulated", "Stereo",
                        "Surround", "Data", "Other", "None");
      # byte 2 describes primary audio stream
      my $byte = $xdsList[2 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".$StreamType[$byte % 8];
      $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
      @StreamType = ("Unknown", "Mono", "DAS", "Non-Program",
                     "FX", "Data", "Other", "None");
      # byte 3 describes secondary audio stream
      $byte = $xdsList[3 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".$StreamType[$byte % 8];
      $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > 4) {
      # byte 4 is 0x0f, to announce checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "CS") { # Caption Streams
    my $position = 2;
    if ((scalar @xdsList + $XDSPosition{$type}) > 2) {
      if ((scalar @xdsList + $XDSPosition{$type}) > 2) {
        my @Stream = ("CC1", "T1", "CC2", "T2", "CC3", "T3", "CC4", "T4");
        while (($xdsList[$position] != 15) and ($position < scalar @xdsList)) {
          my $byte = $xdsList[$position];
          if ($byte == 0) {$position++; next;}
          $byte -= 64;
          $xds = $xds." ".$Stream[$byte % 8];
          $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
          $position++;
        }
      }
    }
    if ((scalar @xdsList) > $position) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[$position + 1]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "CG") { # CGMS
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $dataFormat = "D"; # format is digital ("D") or analog ("A")
      my $sgms = "U"; # can copy unlimited times ("U"), never ("0"), or only once ("1")
      my $mv = "N"; # no Macrovision or Colorstripe ("N"), Macrovision only ("M"),
                    #  Macrovision and 2-line Colorstripe ("2"), or
                    #  Macrovision and 4-line Colorstripe ("4")
      # all parts of CGMS in byte 2
      my $byte = $xdsList[2 - $XDSPosition{$type}] - 64; 
      if ($byte >= 24) {
        $sgms = "0";
        $byte -= 24;
      }
      if ($byte >= 16) {
        $sgms = "1";
        $byte -= 16;
      }
      if ($byte >= 6) {
        $mv = "4";
        $byte -= 6;
      }
      if ($byte >= 4) {
        $mv = "2";
        $byte -= 4;
      }
      if ($byte >= 2) {
        $mv = "M";
        $byte -= 2;
      }
      if ($byte == 1) {
        $dataFormat = "A";
      }
      $xds = $xds." ".$dataFormat.$sgms.$mv;
      # byte 3 is filler
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > 4) {
      # byte 4 is 0x0f, to announce checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "AR") { # Aspect Ratio
    my $checksumPosition;
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # byte 2 is number of scanlines between top of visible screen
      #  and top of active video area
      my $top = $xdsList[2 - $XDSPosition{$type}] - 64; 
      # byte 3 is number of scanlines between
      #  bottom of active video area and bottom of visible screen
      my $bottom = $xdsList[3 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".$top." ".$bottom;
      $checksumPosition = 5;
    }
    if ((scalar @xdsList + $XDSPosition{$type} > 4) &&
       ($xdsList[4 - $XDSPosition{$type}] != 15)) {
      $checksumPosition += 2;
      my $ratio = "_"; # optional byte 4 is aspect ratio, either Anamorphic "A" or not "_"
      if ($xdsList[4 - $XDSPosition{$type}] = 65) {
        $ratio = "A";
      }
      $xds = $xds." ".$ratio;
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > $checksumPosition - 1) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[$checksumPosition - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "PD") {  # Program Data
    my $position = 2;
    my $i;
    # 5 Program Types
    my @ProgramTypes =
     ("Education", "Entertainment", "Movie", "News",
      "Religious", "Sports", "Other", "Action",
      "Advertisement", "Animated", "Anthology", "Automobile",
      "Awards", "Baseball", "Basketball", "Bulletin",
      "Business", "Classical", "College", "Combat",
      "Comedy", "Commentary", "Concert", "Consumer",
      "Contemporary", "Crime", "Dance", "Documentary",
      "Drama", "Elementary", "Erotica", "Exercise",
      "Fantasy", "Farm", "Fashion", "Fiction",
      "Food", "Football", "Foreign", "Fund-Raiser",
      "Game/Quiz", "Garden", "Golf", "Government",
      "Health", "High_School", "History", "Hobby",
      "Hockey", "Home", "Horror", "Information",
      "Instruction", "International", "Interview", "Language",
      "Legal", "Live", "Local", "Math",
      "Medical", "Meeting", "Military", "Mini-Series",
      "Music", "Mystery", "National", "Nature",
      "Police", "Politics", "Premiere", "Pre-Recorded",
      "Product", "Professional", "Public", "Racing",
      "Reading", "Repair", "Repeat", "Review",
      "Romance", "Science", "Series", "Service",
      "Shopping", "Soap_Opera", "Special", "Suspense",
      "Talk", "Technical", "Tennis", "Travel",
      "Variety", "Video", "Weather", "Western");
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      $xds = $xds." ".$ProgramTypes[$xdsList[2 - $XDSPosition{$type}] - 32];
      $xds = $xds." ".$ProgramTypes[$xdsList[3 - $XDSPosition{$type}] - 32];
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      $xds = $xds." ".$ProgramTypes[$xdsList[4 - $XDSPosition{$type}] - 32];
      $xds = $xds." ".$ProgramTypes[$xdsList[5 - $XDSPosition{$type}] - 32];
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      $xds = $xds." ".$ProgramTypes[$xdsList[6 - $XDSPosition{$type}] - 32];
      # MPAA Rating
      my @Ratings = ("", "G", "PG", "PG-13", "R", "NC-17", "X", "NR");
      my $byte = $xdsList[7 - $XDSPosition{$type}] & 0x0f;
      $xds = $xds." ".$Ratings[$byte];
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 10) and (scalar @xdsList + $XDSPosition{$type} > 8)) {
      # Program Length
      my $minutes = $xdsList[8 - $XDSPosition{$type}] - 64;
      my $hours = $xdsList[9 - $XDSPosition{$type}] - 64;
      $xds = $xds." ".sprintf("%02d:%02d", $hours, $minutes);
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 12) and (scalar @xdsList + $XDSPosition{$type} > 10)) {
      # Time Elapsed
      my $minutes = $xdsList[10 - $XDSPosition{$type}] - 64;
      my $hours = $xdsList[11 - $XDSPosition{$type}] - 64;
      $xds = $xds." ".sprintf("%02d:%02d", $hours, $minutes);
    }
    $position += 2;
    if ((scalar @xdsList + $XDSPosition{$type}) > 12) {
      # Program Name
      $xds = $xds." ";
      while (($xdsList[$position - $XDSPosition{$type}] != 15) and
         ($position - $XDSPosition{$type} < scalar @xdsList)) {
        if (($xdsList[$position - $XDSPosition{$type}] > 0x1f)
            && ($xdsList[$position - $XDSPosition{$type}] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position - $XDSPosition{$type}]);
        }
        $position++;
      }
    }
    if ((scalar @xdsList + $XDSPosition{$type}) > $position) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[$position + 1 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type eq "MD") {  # Miscellaneous Data
    my $position = 2;
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # Start Time
      my $minutes = $xdsList[2 - $XDSPosition{$type}] - 64;
      my $hours = $xdsList[3 - $XDSPosition{$type}] - 64;
      $xds = $xds.sprintf(" %02d:%02d", $hours, $minutes);
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      my $days = $xdsList[4 - $XDSPosition{$type}] - 64;
      my $byte = $xdsList[5 - $XDSPosition{$type}] - 64;
      my $delayed = "N";
      if ($byte > 16) {
        $delayed = "T";
        $byte -= 16;
      }
      my $month = $Month[$byte];
      $xds = $xds.sprintf(" %s %s %02d", $delayed, $month, $days);
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      # Audio Streams
      my @StreamType = ("Unknown", "Mono", "Simulated", "Stereo",
                        "Surround", "Data", "Other", "None");
      # primary audio stream
      my $byte = $xdsList[6 - $XDSPosition{$type}] - 64;   
      $xds = $xds." ".$StreamType[$byte % 8];
      $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
      @StreamType = ("Unknown", "Mono", "DAS", "Non-Program",
                     "FX", "Data", "Other", "None");
      #  secondary audio stream
      $byte = $xdsList[7 - $XDSPosition{$type}] - 64;
      $xds = $xds." ".$StreamType[$byte % 8];
      $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 10) and (scalar @xdsList + $XDSPosition{$type} > 8)) {
      # Caption Streams
      my @Stream = ("CC1", "T1", "CC2", "T2", "CC3", "T3", "CC4", "T4");
      for (my $i = 8; $i < 10; $i++) {
        my $byte = $xdsList[$i - $XDSPosition{$type}];
        $byte -= 64;
        $xds = $xds." ".$Stream[$byte % 8];
        $xds = $xds." ".$Language[sprintf("%d", ($byte / 8))];
      }
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 12) and (scalar @xdsList + $XDSPosition{$type} > 10)) {
      # Call Letters (first two characters)
      $xds = $xds." ";
      for (my $i = 10; $i < 12; $i++) {
        $xds = $xds.disChar($xdsList[$i - $XDSPosition{$type}]);
      }
    }
    $position += 2;
    if (($XDSPosition{$type} + 2 < 14) and (scalar @xdsList + $XDSPosition{$type} > 12)) {
      # Call Letters (last two characters)
      for (my $i = 12; $i < 14; $i++) {
        $xds = $xds.disChar($xdsList[$i - $XDSPosition{$type}]);
      }
    }
    $position += 2;
    if ((scalar @xdsList + $XDSPosition{$type}) > 14) {
      # Broadcast Channel Number
      $xds = $xds." ";
      my $channelNumber = "";
      for (my $i = 14; $i < 16; $i++) {
        $channelNumber = $channelNumber.disChar($xdsList[$i - $XDSPosition{$type}]);
      }
      if ($channelNumber eq "  ") {
        $channelNumber = "__";
      }
      $xds = $xds.$channelNumber;
    }
    $position += 2;
    if ((scalar @xdsList + $XDSPosition{$type}) > 16) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[17 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type =~ /^D\d$/) {  # Program Description (lines 1 to 8)
    $xds = $xds." ";
    my $position = 2;
    if (scalar @xdsList > 2) {
      while (($xdsList[$position] != 15) and ($position <= scalar @xdsList)) {
        if (($xdsList[$position] > 0x1f) && ($xdsList[$position] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position]);
        }
        $position++;
      }
    }
    if ((scalar @xdsList > $position) && ($xdsList[$position] == 15)) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "NN") { # Network Name
    $xds = $xds." ";
    my $position = 2;
    if (scalar @xdsList > 2) {
      while (($xdsList[$position] != 15) and ($position <= scalar @xdsList)) {
        if (($xdsList[$position] > 0x1f) && ($xdsList[$position] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position]);
        }
        $position++;
      }
    }
    if ((scalar @xdsList >= $position) && ($xdsList[$position] == 15)) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "NC") { # Network Call Letters
    $xds = $xds." ";
    my $position = 2;
    # call letters
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      $xds = $xds.disChar($xdsList[2 - $XDSPosition{$type}]);
      $xds = $xds.disChar($xdsList[3 - $XDSPosition{$type}]);
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      if ($xdsList[4] != 15) {
        $xds = $xds.disChar($xdsList[4 - $XDSPosition{$type}]);
        $xds = $xds.disChar($xdsList[5 - $XDSPosition{$type}]);
      } else {
        $position -= 2;
      }
    }
    $position += 4;
    # optional channel number
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      if ($xdsList[6 - $XDSPosition{$type}] != 15) {
        $xds = $xds." ";
        $xds = $xds.disChar($xdsList[6 - $XDSPosition{$type}]);
        $xds = $xds.disChar($xdsList[7 - $XDSPosition{$type}]);
      }
      $position += 2;
    }
    if (($xdsList[$position - $XDSPosition{$type}] == 15) and
       (scalar @xdsList + $XDSPosition{$type} > $position)) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[$position + 1 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "TD") { # Channel Tape Delay
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # byte 3 is hours tape delayed
      my $hr = $xdsList[3 - $XDSPosition{$type}] - 64; 
      # byte 2 is minutes tape delayed
      my $mi = $xdsList[2 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi);
    }
    if (scalar @xdsList + $XDSPosition{$type} > 4) {
      # byte 5 is checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "TS") { # Transmission Signal Identification
    $xds = $xds." ";
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # TSID digits are in reverse order
      my $digits;
      if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
        $digits = sprintf("%x", $xdsList[5 - $XDSPosition{$type}] - 64);
        $digits = $digits.sprintf("%x", $xdsList[4 - $XDSPosition{$type}] - 64);
      } else {
        $digits = "__";
      }
      if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
        $digits = $digits.sprintf("%x", $xdsList[3 - $XDSPosition{$type}] - 64);
        $digits = $digits.sprintf("%x", $xdsList[2 - $XDSPosition{$type}] - 64);
      } else {
        $digits = $digits."__";
      }
      $xds = $xds.$digits;
    }
    if (scalar @xdsList + $XDSPosition{$type} > 6) {
      # byte 7 is checksum 
      my $checksum = oddParity($xdsList[7 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type eq "TM") { # Time of Day
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $d = "S"; # daylight savings time ("D") or standard time ("S")
      # byte 3 is hour (0 - 23)
      my $hr = $xdsList[3 - $XDSPosition{$type}] - 64; 
      if ($hr > 32) {
        $d = "D";
        $hr -= 32;
      }
      # byte 2 is minute (0 - 59)
      my $mi = $xdsList[2 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi).$d;
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      my $z = "_"; # zero seconds ("Z") or unknown ("_")
      my $t = "S"; # tape is delayed ("T") or simulcast ("S")
      my $l = "A"; # this is February 29th ("L"eap day) or not ("A")
      # byte 5 is month
      my $mo = $xdsList[5 - $XDSPosition{$type}] - 64; 
      if ($mo > 32) {
        $z = "Z";
        $mo -= 32;
      }
      if ($mo > 16) {
        $t = "T";
        $mo -= 16;
      }
      # byte 4 is day of month
      my $dy = $xdsList[4 - $XDSPosition{$type}] - 64; 
      if ($dy > 32) {
        $l = "L";
        $dy -= 32;
      }
      $xds = $xds." ".$z.$t.$l;
      $xds = $xds.sprintf(" %s %02d", $Month[$mo], $dy);
    }
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      # byte 7 is offset from 1990 (1990 - 64 = 1926)
      my $yr = $xdsList[7 - $XDSPosition{$type}] + 1926; 
      $xds = $xds." ".$yr;
      my @Weekday = ("", "Sun", "Mon", "Tue",
                     "Wed", "Thu", "Fri", "Sat");
      # byte 6 is day of the week
      $xds = $xds." ".$Weekday[$xdsList[6 - $XDSPosition{$type}] - 64]; 
    }
    if (scalar @xdsList + $XDSPosition{$type} > 8) {
      # byte 9 is checksum 
      my $checksum = oddParity($xdsList[9 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "IC") { # Impulse Capture ID
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $d = "S"; # daylight savings time ("D") or standard time ("S")
      # byte 3 is hour (0 - 23)
      my $hr = $xdsList[3 - $XDSPosition{$type}] - 64; 
      if ($hr > 32) {
        $d = "D";
        $hr -= 32;
      }
      # byte 2 is minute (0 - 59)
      my $mi = $xdsList[2 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi).$d;
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      my $z = "_"; # zero seconds ("Z") or unknown ("_")
      my $t = "S"; # tape is delayed ("T") or simulcast ("S")
      my $l = "A"; # this is February 29th ("L"eap day) or not ("A")
      # byte 5 is month
      my $mo = $xdsList[5 - $XDSPosition{$type}] - 64; 
      if ($mo > 32) {
        $z = "Z";
        $mo -= 32;
      }
      if ($mo > 16) {
        $t = "T";
        $mo -= 16;
      }
      # byte 4 is day of month
      my $dy = $xdsList[4 - $XDSPosition{$type}] - 64; 
      if ($dy > 32) {
        $l = "L";
        $dy -= 32;
      }
      $xds = $xds." ".$z.$t.$l;
      $xds = $xds.sprintf(" %s %02d", $Month[$mo], $dy);
    }
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      # byte 7 is length of program in hours
      my $hr = $xdsList[7 - $XDSPosition{$type}] - 64; 
      # byte 6 is length of program in minutes
      my $mi = $xdsList[6 - $XDSPosition{$type}] - 64; 
      $xds = $xds." ".sprintf("%02d:%02d", $hr, $mi);
    }
    if (scalar @xdsList + $XDSPosition{$type} > 8) {
      # byte 9 is checksum 
      my $checksum = oddParity($xdsList[9 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "SD") { # Supplemental Data Location
    my $position = 2;
    my $line = 0;
    my $field = .1;
    while (($xdsList[$position] != 15) and ($position < scalar @xdsList)) {
      $line = $xdsList[$position] - 64; # each byte is scanline (10 - 20), with flag for field
      $field = 0.1;
      if ($line > 32) {
        $field = 0.2;
        $line -= 32;
      }
      $xds = $xds." ".sprintf("%02.1f", $field + $line);
      $position++;
    }
    if (scalar @xdsList + $XDSPosition{$type} > $position) {
      # last byte is checksum 
      my $checksum = oddParity($xdsList[$position + 1]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "TZ") { # Local Time Zone
    my $d = "S"; # daylight savings time ("D") or standard time ("S")
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # byte 2 is time zone
      my $tz = $xdsList[2 - $XDSPosition{$type}] - 64; 
      if ($tz > 32) {
        $d = "D";
        $tz -= 32;
      }
      my $hourOffset = $tz - 24; # add this to UTC times to get local times
      $xds = $xds.sprintf(" %+03d", $hourOffset).$d;
      # byte 3 is filler
    }
    if (scalar @xdsList + $XDSPosition{$type} > 4) {
      # byte 5 is checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "OB") {  # Out of Band Channel
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # bytes 2 and 3 hold channel number
      my $lo = $xdsList[2 - $XDSPosition{$type}] - 64; 
      my $hi = $xdsList[3 - $XDSPosition{$type}] - 64;
      my $channel = ($hi * 64) + $lo;
      $xds = $xds.sprintf(" %04d", $channel);
    }
    if (scalar @xdsList + $XDSPosition{$type} > 4) {
      # byte 5 is checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type eq "CP") {   # Channel Map Pointer
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $lo = $xdsList[2 - $XDSPosition{$type}] - 64; 
      my $hi = $xdsList[3 - $XDSPosition{$type}] - 64;
      my $channel = ($hi * 64) + $lo;
      $xds = $xds.sprintf(" %04d", $channel);
    }
    if (scalar @xdsList + $XDSPosition{$type} > 4) {
      # byte 5 is checksum 
      my $checksum = oddParity($xdsList[5 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type eq "CH") {   # Channel Map Header
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      my $lo = $xdsList[2 - $XDSPosition{$type}] - 64; 
      my $hi = $xdsList[3 - $XDSPosition{$type}] - 64;
      my $channels = ($hi * 64) + $lo;
      $xds = $xds.sprintf(" %04d", $channels);
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      my $version = $xdsList[4 - $XDSPosition{$type}] - 64;
      $xds = $xds.sprintf(" v%02d", $version);
      # skip filler byte 5
    }
    if (scalar @xdsList + $XDSPosition{$type} > 6) {
      # byte 7 is checksum 
      my $checksum = oddParity($xdsList[7 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  
  if ($type eq "CM") {  # Channel Map
    my $position = 2;
    my $remapped = " ";
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      # User Channel
      my $lo = $xdsList[2 - $XDSPosition{$type}] - 64;
      my $hi = $xdsList[3 - $XDSPosition{$type}] - 64;
      if ($hi >= 32) {
        $remapped = "=";
        $hi -= 32;
      }
      my $userChannel = ($hi * 64) + $lo;
      $xds = $xds." ".$userChannel.$remapped;
    }
    $position += 2;
    if ($XDSSum{$type} == 1) {
      $remapped = "=";
      if ($XDSPosition{$type} == 2) {
        $xds = $xds." ";
      }
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      # Tune Channel is only used if remapping
      if ($remapped eq "=") {
        $lo = $xdsList[4 - $XDSPosition{$type}] - 64;
        $hi = $xdsList[5 - $XDSPosition{$type}] - 64;
        my $tuneChannel = ($hi * 64) + $lo;
        $xds = $xds.$tuneChannel;
      }
    }
    if ($remapped eq "=") {
      $position += 2;
    }
    #print $position.".".$XDSPosition{$type}.".".(scalar @xdsList).".";
    if (scalar @xdsList + $XDSPosition{$type} > $position + 2) {
      $xds = $xds." ";
      # optional Channel ID
      while (($xdsList[$position - $XDSPosition{$type}] != 15) and
         ($position - $XDSPosition{$type} < scalar @xdsList)) {
        if (($xdsList[$position - $XDSPosition{$type}] > 0x1f)
            && ($xdsList[$position - $XDSPosition{$type}] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position - $XDSPosition{$type}]);
        }
        $position++;
      }
    }
    if (scalar @xdsList + $XDSPosition{$type} > $position) {
      my $checksum = oddParity($xdsList[$position + 1 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
      $XDSSum{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
      # use $XDSSum to temporarily store $remapped
      if ($remapped eq "=") {
        $XDSSum{$type} = 1;
      } else {
        $XDSSum{$type} = 0;
      }	
    }
  }
  
  if ($type eq "WB") {  # National Weather Service Bulletin
    my $position;
    if (($XDSPosition{$type} + 2 < 4) and (scalar @xdsList + $XDSPosition{$type} > 2)) {
      $xds = $xds." ";
      # Event Category
      $xds = $xds.disChar($xdsList[2 - $XDSPosition{$type}]);
      $xds = $xds.disChar($xdsList[3 - $XDSPosition{$type}]);
    }
    if (($XDSPosition{$type} + 2 < 6) and (scalar @xdsList + $XDSPosition{$type} > 4)) {
      $xds = $xds.disChar($xdsList[4 - $XDSPosition{$type}]);
      $xds = $xds." ";
      # State FIPS
      $xds = $xds.disChar($xdsList[5 - $XDSPosition{$type}]);
    }
    if (($XDSPosition{$type} + 2 < 8) and (scalar @xdsList + $XDSPosition{$type} > 6)) {
      $xds = $xds.disChar($xdsList[6 - $XDSPosition{$type}]);
      $xds = $xds.disChar($xdsList[7 - $XDSPosition{$type}]);
    }
    if (($XDSPosition{$type} + 2 < 10) and (scalar @xdsList + $XDSPosition{$type} > 8)) {
      $xds = $xds." ";
      # County FIPS
      $xds = $xds.disChar($xdsList[8 - $XDSPosition{$type}]);
      $xds = $xds.disChar($xdsList[9 - $XDSPosition{$type}]);
    }
    if (($XDSPosition{$type} + 2 < 12) and (scalar @xdsList + $XDSPosition{$type} > 10)) {
      $xds = $xds.disChar($xdsList[10 - $XDSPosition{$type}]);
      # Duration (split awkwardly between byte pairs, so I have to resort to a trick)
      $XDSSum{$type} = $xdsList[11 - $XDSPosition{$type}] - 48;
    }
    if (($XDSPosition{$type} + 2 < 14) and (scalar @xdsList + $XDSPosition{$type} > 12)) {
      my $quarterHours = $XDSSum{$type} * 10 + ($xdsList[12 - $XDSPosition{$type}] - 48);
      $xds = $xds.sprintf(" %02d:%02d", $quarterHours / 4, ($quarterHours % 4) * 15);
      $XDSSum{$type} = 0;
      # Byte 15 is filler
    }
    if (scalar @xdsList + $XDSPosition{$type} > 14) {
      # byte 15 is checksum 
      my $checksum = oddParity($xdsList[15 - $XDSPosition{$type}]); 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  if ($type eq "WM") {  # National Weather Service Message
    $xds = $xds." ";
    my $position = 2;
    if (scalar @xdsList > 2) {
      while (($xdsList[$position] != 15) and ($position <= scalar @xdsList)) {
        if (($xdsList[$position] > 0x1f) && ($xdsList[$position] != 0x40)) {
          $xds = $xds.disChar($xdsList[$position]);
        }
        $position++;
      }
    }
    if (scalar @xdsList + $XDSPosition{$type} > $position) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }

  # if type is undefined, just output the bytes  
  if ($typeDefined == 0) {
    my $position = 2;
    while (($xdsList[$position] != 15) and ($position < scalar @xdsList)) {
      $xds = $xds.sprintf(" %02x",oddParity($xdsList[$position++]));
    }
    if (scalar @xdsList + $XDSPosition{$type} > $position) {
      my $checksum = oddParity($xdsList[$position + 1]); # last byte is checksum 
      $xds = $xds." \\C".sprintf("%02x", $checksum);
      $XDSPosition{$type} = 0;
    } else {
      # if checksum is not reached, this is an interrupted packet
      $XDSPosition{$type} = scalar @xdsList - 2;
    }
  }
  return $xds."}";
}

sub asCommand {
  my $command = shift(@_);
  if ($command =~ /^XDS/) {return asXDS($command);}
  my $word = "~"; # placeholder for no match
  SWITCH: for ($command) {
    /^reg$/ && do {$word = ($channel =~ /[13]/) ? "91b0" : "19b0"; last SWITCH;};
    /^o$/ && do {$word = ($channel =~ /[13]/) ? "9131" : "1931"; last SWITCH;};
    /^1\/2$/ && do {$word = ($channel =~ /[13]/) ? "9132" : "1932"; last SWITCH;};
    /^\?$/ && do {$word = ($channel =~ /[13]/) ? "91b3" : "19b3"; last SWITCH;};
    /^tm$/ && do {$word = ($channel =~ /[13]/) ? "9134" : "1934"; last SWITCH;};
    /^cent$/ && do {$word = ($channel =~ /[13]/) ? "91b5" : "19b5"; last SWITCH;};
    /^L$/ && do {$word = ($channel =~ /[13]/) ? "91b6" : "19b6"; last SWITCH;};
    /^note$/ && do {$word = ($channel =~ /[13]/) ? "9137" : "1937"; last SWITCH;};
    /^à$/ && do {$word = ($channel =~ /[13]/) ? "9138" : "1938"; last SWITCH;};
    /^ $/ && do {$word = ($channel =~ /[13]/) ? "91b9" : "19b9"; last SWITCH;};
    /^è$/ && do {$word = ($channel =~ /[13]/) ? "91ba" : "19ba"; last SWITCH;};
    /^â$/ && do {$word = ($channel =~ /[13]/) ? "913b" : "193b"; last SWITCH;};
    /^ê$/ && do {$word = ($channel =~ /[13]/) ? "91bc" : "19bc"; last SWITCH;};
    /^î$/ && do {$word = ($channel =~ /[13]/) ? "913d" : "193d"; last SWITCH;};
    /^ô$/ && do {$word = ($channel =~ /[13]/) ? "913e" : "193e"; last SWITCH;};
    /^û$/ && do {$word = ($channel =~ /[13]/) ? "91bf" : "19bf"; last SWITCH;};
    /^Á$/ && do {$word = ($channel =~ /[13]/) ? "9220" : "1a20"; last SWITCH;};
    /^É$/ && do {$word = ($channel =~ /[13]/) ? "92a1" : "1aa1"; last SWITCH;};
    /^Ó$/ && do {$word = ($channel =~ /[13]/) ? "92a2" : "1aa2"; last SWITCH;};
    /^Ú$/ && do {$word = ($channel =~ /[13]/) ? "9223" : "1a23"; last SWITCH;};
    /^Ü$/ && do {$word = ($channel =~ /[13]/) ? "92a4" : "1aa4"; last SWITCH;};
    /^ü$/ && do {$word = ($channel =~ /[13]/) ? "9225" : "1a25"; last SWITCH;};
    /^rsq$/ && do {$word = ($channel =~ /[13]/) ? "9226" : "1a26"; last SWITCH;};
    /^\!$/ && do {$word = ($channel =~ /[13]/) ? "92a7" : "1aa7"; last SWITCH;};
    /^\*$/ && do {$word = ($channel =~ /[13]/) ? "92a8" : "1aa8"; last SWITCH;};
    /^lsq$/ && do {$word = ($channel =~ /[13]/) ? "9229" : "1a29"; last SWITCH;};
    /^\-$/ && do {$word = ($channel =~ /[13]/) ? "922a" : "1a2a"; last SWITCH;};
    /^C$/ && do {$word = ($channel =~ /[13]/) ? "92ab" : "1aab"; last SWITCH;};
    /^sm$/ && do {$word = ($channel =~ /[13]/) ? "922c" : "1a2c"; last SWITCH;};
    /^\.$/ && do {$word = ($channel =~ /[13]/) ? "92ad" : "1aad"; last SWITCH;};
    /^rdq$/ && do {$word = ($channel =~ /[13]/) ? "92ae" : "1aae"; last SWITCH;};
    /^ldq$/ && do {$word = ($channel =~ /[13]/) ? "922f" : "1a2f"; last SWITCH;};
    /^À$/ && do {$word = ($channel =~ /[13]/) ? "92b0" : "1ab0"; last SWITCH;};
    /^Â$/ && do {$word = ($channel =~ /[13]/) ? "9231" : "1a31"; last SWITCH;};
    /^Ç$/ && do {$word = ($channel =~ /[13]/) ? "9232" : "1a32"; last SWITCH;};
    /^È$/ && do {$word = ($channel =~ /[13]/) ? "92b3" : "1ab3"; last SWITCH;};
    /^Ê$/ && do {$word = ($channel =~ /[13]/) ? "9234" : "1a34"; last SWITCH;};
    /^Ë$/ && do {$word = ($channel =~ /[13]/) ? "92b5" : "1ab5"; last SWITCH;};
    /^ë$/ && do {$word = ($channel =~ /[13]/) ? "92b6" : "1ab6"; last SWITCH;};
    /^Î$/ && do {$word = ($channel =~ /[13]/) ? "9237" : "1a37"; last SWITCH;};
    /^Ï$/ && do {$word = ($channel =~ /[13]/) ? "9238" : "1a38"; last SWITCH;};
    /^ï$/ && do {$word = ($channel =~ /[13]/) ? "92b9" : "1ab9"; last SWITCH;};
    /^Ô$/ && do {$word = ($channel =~ /[13]/) ? "92ba" : "1aba"; last SWITCH;};
    /^Ù$/ && do {$word = ($channel =~ /[13]/) ? "923b" : "1a3b"; last SWITCH;};
    /^ù$/ && do {$word = ($channel =~ /[13]/) ? "92bc" : "1abc"; last SWITCH;};
    /^Û$/ && do {$word = ($channel =~ /[13]/) ? "923d" : "1a3d"; last SWITCH;};
    /^\<\<$/ && do {$word = ($channel =~ /[13]/) ? "923e" : "1a3e"; last SWITCH;};
    /^\>\>$/ && do {$word = ($channel =~ /[13]/) ? "92bf" : "1abf"; last SWITCH;};
    /^Ã$/ && do {$word = ($channel =~ /[13]/) ? "1320" : "9b20"; last SWITCH;};
    /^ã$/ && do {$word = ($channel =~ /[13]/) ? "13a1" : "9ba1"; last SWITCH;};
    /^Í$/ && do {$word = ($channel =~ /[13]/) ? "13a2" : "9ba2"; last SWITCH;};
    /^Ì$/ && do {$word = ($channel =~ /[13]/) ? "1323" : "9b23"; last SWITCH;};
    /^ì$/ && do {$word = ($channel =~ /[13]/) ? "13a4" : "9ba4"; last SWITCH;};
    /^Ò$/ && do {$word = ($channel =~ /[13]/) ? "1325" : "9b25"; last SWITCH;};
    /^ò$/ && do {$word = ($channel =~ /[13]/) ? "1326" : "9b26"; last SWITCH;};
    /^Õ$/ && do {$word = ($channel =~ /[13]/) ? "13a7" : "9ba7"; last SWITCH;};
    /^õ$/ && do {$word = ($channel =~ /[13]/) ? "13a8" : "9ba8"; last SWITCH;};
    /^rb$/ && do {$word = ($channel =~ /[13]/) ? "1329" : "9b29"; last SWITCH;};
    /^lb$/ && do {$word = ($channel =~ /[13]/) ? "132a" : "9b2a"; last SWITCH;};
    /^\\$/ && do {$word = ($channel =~ /[13]/) ? "13ab" : "9bab"; last SWITCH;};
    /^\^$/ && do {$word = ($channel =~ /[13]/) ? "132c" : "9b2c"; last SWITCH;};
    /^\_$/ && do {$word = ($channel =~ /[13]/) ? "13ad" : "9bad"; last SWITCH;};
    /^\|$/ && do {$word = ($channel =~ /[13]/) ? "13ae" : "9bae"; last SWITCH;};
    /^\~$/ && do {$word = ($channel =~ /[13]/) ? "132f" : "9b2f"; last SWITCH;};
    /^Ä$/ && do {$word = ($channel =~ /[13]/) ? "13b0" : "9bb0"; last SWITCH;};
    /^ä$/ && do {$word = ($channel =~ /[13]/) ? "1331" : "9b31"; last SWITCH;};
    /^Ö$/ && do {$word = ($channel =~ /[13]/) ? "1332" : "9b32"; last SWITCH;};
    /^ö$/ && do {$word = ($channel =~ /[13]/) ? "13b3" : "9bb3"; last SWITCH;};
    /^ß$/ && do {$word = ($channel =~ /[13]/) ? "1334" : "9b34"; last SWITCH;};
    /^yen$/ && do {$word = ($channel =~ /[13]/) ? "13b5" : "9bb5"; last SWITCH;};
    /^x$/ && do {$word = ($channel =~ /[13]/) ? "13b6" : "9bb6"; last SWITCH;};
    /^bar$/ && do {$word = ($channel =~ /[13]/) ? "1337" : "9b37"; last SWITCH;};
    /^Å$/ && do {$word = ($channel =~ /[13]/) ? "1338" : "9b38"; last SWITCH;};
    /^å$/ && do {$word = ($channel =~ /[13]/) ? "13b9" : "9bb9"; last SWITCH;};
    /^Ø$/ && do {$word = ($channel =~ /[13]/) ? "13ba" : "9bba"; last SWITCH;};
    /^ø$/ && do {$word = ($channel =~ /[13]/) ? "133b" : "9b3b"; last SWITCH;};
    /^ul$/ && do {$word = ($channel =~ /[13]/) ? "13bc" : "9bbc"; last SWITCH;};
    /^ur$/ && do {$word = ($channel =~ /[13]/) ? "133d" : "9b3d"; last SWITCH;};
    /^ll$/ && do {$word = ($channel =~ /[13]/) ? "133e" : "9b3e"; last SWITCH;};
    /^lr$/ && do {$word = ($channel =~ /[13]/) ? "13bf" : "9bbf"; last SWITCH;};
    /^01Wh$/ && do {$word = ($channel =~ /[13]/) ? "9140" : "1940"; last SWITCH;};
    /^01WhU$/ && do {$word = ($channel =~ /[13]/) ? "91c1" : "19c1"; last SWITCH;};
    /^01Gr$/ && do {$word = ($channel =~ /[13]/) ? "91c2" : "19c2"; last SWITCH;};
    /^01GrU$/ && do {$word = ($channel =~ /[13]/) ? "9143" : "1943"; last SWITCH;};
    /^01Bl$/ && do {$word = ($channel =~ /[13]/) ? "91c4" : "19c4"; last SWITCH;};
    /^01BlU$/ && do {$word = ($channel =~ /[13]/) ? "9145" : "1945"; last SWITCH;};
    /^01Cy$/ && do {$word = ($channel =~ /[13]/) ? "9146" : "1946"; last SWITCH;};
    /^01CyU$/ && do {$word = ($channel =~ /[13]/) ? "91c7" : "19c7"; last SWITCH;};
    /^01R$/ && do {$word = ($channel =~ /[13]/) ? "91c8" : "19c8"; last SWITCH;};
    /^01RU$/ && do {$word = ($channel =~ /[13]/) ? "9149" : "1949"; last SWITCH;};
    /^01Y$/ && do {$word = ($channel =~ /[13]/) ? "914a" : "194a"; last SWITCH;};
    /^01YU$/ && do {$word = ($channel =~ /[13]/) ? "91cb" : "19cb"; last SWITCH;};
    /^01Ma$/ && do {$word = ($channel =~ /[13]/) ? "914c" : "194c"; last SWITCH;};
    /^01MaU$/ && do {$word = ($channel =~ /[13]/) ? "91cd" : "19cd"; last SWITCH;};
    /^01WhI$/ && do {$word = ($channel =~ /[13]/) ? "91ce" : "19ce"; last SWITCH;};
    /^01WhIU$/ && do {$word = ($channel =~ /[13]/) ? "914f" : "194f"; last SWITCH;};
    /^0100$/ && do {$word = ($channel =~ /[13]/) ? "91d0" : "19d0"; last SWITCH;};
    /^0100U$/ && do {$word = ($channel =~ /[13]/) ? "9151" : "1951"; last SWITCH;};
    /^0104$/ && do {$word = ($channel =~ /[13]/) ? "9152" : "1952"; last SWITCH;};
    /^0104U$/ && do {$word = ($channel =~ /[13]/) ? "91d3" : "19d3"; last SWITCH;};
    /^0108$/ && do {$word = ($channel =~ /[13]/) ? "9154" : "1954"; last SWITCH;};
    /^0108U$/ && do {$word = ($channel =~ /[13]/) ? "91d5" : "19d5"; last SWITCH;};
    /^0112$/ && do {$word = ($channel =~ /[13]/) ? "91d6" : "19d6"; last SWITCH;};
    /^0112U$/ && do {$word = ($channel =~ /[13]/) ? "9157" : "1957"; last SWITCH;};
    /^0116$/ && do {$word = ($channel =~ /[13]/) ? "9158" : "1957"; last SWITCH;};
    /^0116U$/ && do {$word = ($channel =~ /[13]/) ? "91d9" : "19d9"; last SWITCH;};
    /^0120$/ && do {$word = ($channel =~ /[13]/) ? "91da" : "19da"; last SWITCH;};
    /^0120U$/ && do {$word = ($channel =~ /[13]/) ? "915b" : "195b"; last SWITCH;};
    /^0124$/ && do {$word = ($channel =~ /[13]/) ? "91dc" : "19dc"; last SWITCH;};
    /^0124U$/ && do {$word = ($channel =~ /[13]/) ? "915d" : "195d"; last SWITCH;};
    /^0128$/ && do {$word = ($channel =~ /[13]/) ? "915e" : "195e"; last SWITCH;};
    /^0128U$/ && do {$word = ($channel =~ /[13]/) ? "91df" : "19df"; last SWITCH;};
    /^02Wh$/ && do {$word = ($channel =~ /[13]/) ? "91e0" : "19e0"; last SWITCH;};
    /^02WhU$/ && do {$word = ($channel =~ /[13]/) ? "9161" : "1961"; last SWITCH;};
    /^02Gr$/ && do {$word = ($channel =~ /[13]/) ? "9162" : "1962"; last SWITCH;};
    /^02GrU$/ && do {$word = ($channel =~ /[13]/) ? "91e3" : "19e3"; last SWITCH;};
    /^02Bl$/ && do {$word = ($channel =~ /[13]/) ? "9164" : "1964"; last SWITCH;};
    /^02BlU$/ && do {$word = ($channel =~ /[13]/) ? "91e5" : "19e5"; last SWITCH;};
    /^02Cy$/ && do {$word = ($channel =~ /[13]/) ? "91e6" : "19e6"; last SWITCH;};
    /^02CyU$/ && do {$word = ($channel =~ /[13]/) ? "9167" : "1967"; last SWITCH;};
    /^02R$/ && do {$word = ($channel =~ /[13]/) ? "9168" : "1968"; last SWITCH;};
    /^02RU$/ && do {$word = ($channel =~ /[13]/) ? "91e9" : "19e9"; last SWITCH;};
    /^02Y$/ && do {$word = ($channel =~ /[13]/) ? "91ea" : "19ea"; last SWITCH;};
    /^02YU$/ && do {$word = ($channel =~ /[13]/) ? "916b" : "196b"; last SWITCH;};
    /^02Ma$/ && do {$word = ($channel =~ /[13]/) ? "91ec" : "19ec"; last SWITCH;};
    /^02MaU$/ && do {$word = ($channel =~ /[13]/) ? "916d" : "196d"; last SWITCH;};
    /^02WhI$/ && do {$word = ($channel =~ /[13]/) ? "916e" : "196e"; last SWITCH;};
    /^02WhIU$/ && do {$word = ($channel =~ /[13]/) ? "91ef" : "19ef"; last SWITCH;};
    /^0200$/ && do {$word = ($channel =~ /[13]/) ? "9170" : "1970"; last SWITCH;};
    /^0200U$/ && do {$word = ($channel =~ /[13]/) ? "91f1" : "19f1"; last SWITCH;};
    /^0204$/ && do {$word = ($channel =~ /[13]/) ? "91f2" : "19f2"; last SWITCH;};
    /^0204U$/ && do {$word = ($channel =~ /[13]/) ? "9173" : "1973"; last SWITCH;};
    /^0208$/ && do {$word = ($channel =~ /[13]/) ? "91f4" : "19f4"; last SWITCH;};
    /^0208U$/ && do {$word = ($channel =~ /[13]/) ? "9175" : "1975"; last SWITCH;};
    /^0212$/ && do {$word = ($channel =~ /[13]/) ? "9176" : "1976"; last SWITCH;};
    /^0212U$/ && do {$word = ($channel =~ /[13]/) ? "91f7" : "19f7"; last SWITCH;};
    /^0216$/ && do {$word = ($channel =~ /[13]/) ? "91f8" : "19f7"; last SWITCH;};
    /^0216U$/ && do {$word = ($channel =~ /[13]/) ? "9179" : "1979"; last SWITCH;};
    /^0220$/ && do {$word = ($channel =~ /[13]/) ? "917a" : "197a"; last SWITCH;};
    /^0220U$/ && do {$word = ($channel =~ /[13]/) ? "91fb" : "19fb"; last SWITCH;};
    /^0224$/ && do {$word = ($channel =~ /[13]/) ? "917c" : "197c"; last SWITCH;};
    /^0224U$/ && do {$word = ($channel =~ /[13]/) ? "91fd" : "19fd"; last SWITCH;};
    /^0228$/ && do {$word = ($channel =~ /[13]/) ? "91fe" : "19fe"; last SWITCH;};
    /^0228U$/ && do {$word = ($channel =~ /[13]/) ? "917f" : "197f"; last SWITCH;};
    /^03Wh$/ && do {$word = ($channel =~ /[13]/) ? "9240" : "1a40"; last SWITCH;};
    /^03WhU$/ && do {$word = ($channel =~ /[13]/) ? "92c1" : "1ac1"; last SWITCH;};
    /^03Gr$/ && do {$word = ($channel =~ /[13]/) ? "92c2" : "1ac2"; last SWITCH;};
    /^03GrU$/ && do {$word = ($channel =~ /[13]/) ? "9243" : "1a43"; last SWITCH;};
    /^03Bl$/ && do {$word = ($channel =~ /[13]/) ? "92c4" : "1ac4"; last SWITCH;};
    /^03BlU$/ && do {$word = ($channel =~ /[13]/) ? "9245" : "1a45"; last SWITCH;};
    /^03Cy$/ && do {$word = ($channel =~ /[13]/) ? "9246" : "1a46"; last SWITCH;};
    /^03CyU$/ && do {$word = ($channel =~ /[13]/) ? "92c7" : "1ac7"; last SWITCH;};
    /^03R$/ && do {$word = ($channel =~ /[13]/) ? "92c8" : "1ac8"; last SWITCH;};
    /^03RU$/ && do {$word = ($channel =~ /[13]/) ? "9249" : "1a49"; last SWITCH;};
    /^03Y$/ && do {$word = ($channel =~ /[13]/) ? "924a" : "1a4a"; last SWITCH;};
    /^03YU$/ && do {$word = ($channel =~ /[13]/) ? "92cb" : "1acb"; last SWITCH;};
    /^03Ma$/ && do {$word = ($channel =~ /[13]/) ? "924c" : "1a4c"; last SWITCH;};
    /^03MaU$/ && do {$word = ($channel =~ /[13]/) ? "92cd" : "1acd"; last SWITCH;};
    /^03WhI$/ && do {$word = ($channel =~ /[13]/) ? "92ce" : "1ace"; last SWITCH;};
    /^03WhIU$/ && do {$word = ($channel =~ /[13]/) ? "924f" : "1a4f"; last SWITCH;};
    /^0300$/ && do {$word = ($channel =~ /[13]/) ? "92d0" : "1ad0"; last SWITCH;};
    /^0300U$/ && do {$word = ($channel =~ /[13]/) ? "9251" : "1a51"; last SWITCH;};
    /^0304$/ && do {$word = ($channel =~ /[13]/) ? "9252" : "1a52"; last SWITCH;};
    /^0304U$/ && do {$word = ($channel =~ /[13]/) ? "92d3" : "1ad3"; last SWITCH;};
    /^0308$/ && do {$word = ($channel =~ /[13]/) ? "9254" : "1a54"; last SWITCH;};
    /^0308U$/ && do {$word = ($channel =~ /[13]/) ? "92d5" : "1ad5"; last SWITCH;};
    /^0312$/ && do {$word = ($channel =~ /[13]/) ? "92d6" : "1ad6"; last SWITCH;};
    /^0312U$/ && do {$word = ($channel =~ /[13]/) ? "9257" : "1a57"; last SWITCH;};
    /^0316$/ && do {$word = ($channel =~ /[13]/) ? "9258" : "1a57"; last SWITCH;};
    /^0316U$/ && do {$word = ($channel =~ /[13]/) ? "92d9" : "1ad9"; last SWITCH;};
    /^0320$/ && do {$word = ($channel =~ /[13]/) ? "92da" : "1ada"; last SWITCH;};
    /^0320U$/ && do {$word = ($channel =~ /[13]/) ? "925b" : "1a5b"; last SWITCH;};
    /^0324$/ && do {$word = ($channel =~ /[13]/) ? "92dc" : "1adc"; last SWITCH;};
    /^0324U$/ && do {$word = ($channel =~ /[13]/) ? "925d" : "1a5d"; last SWITCH;};
    /^0328$/ && do {$word = ($channel =~ /[13]/) ? "925e" : "1a5e"; last SWITCH;};
    /^0328U$/ && do {$word = ($channel =~ /[13]/) ? "92df" : "1adf"; last SWITCH;};
    /^04Wh$/ && do {$word = ($channel =~ /[13]/) ? "92e0" : "1ae0"; last SWITCH;};
    /^04WhU$/ && do {$word = ($channel =~ /[13]/) ? "9261" : "1a61"; last SWITCH;};
    /^04Gr$/ && do {$word = ($channel =~ /[13]/) ? "9262" : "1a62"; last SWITCH;};
    /^04GrU$/ && do {$word = ($channel =~ /[13]/) ? "92e3" : "1ae3"; last SWITCH;};
    /^04Bl$/ && do {$word = ($channel =~ /[13]/) ? "9264" : "1a64"; last SWITCH;};
    /^04BlU$/ && do {$word = ($channel =~ /[13]/) ? "92e5" : "1ae5"; last SWITCH;};
    /^04Cy$/ && do {$word = ($channel =~ /[13]/) ? "92e6" : "1ae6"; last SWITCH;};
    /^04CyU$/ && do {$word = ($channel =~ /[13]/) ? "9267" : "1a67"; last SWITCH;};
    /^04R$/ && do {$word = ($channel =~ /[13]/) ? "9268" : "1a68"; last SWITCH;};
    /^04RU$/ && do {$word = ($channel =~ /[13]/) ? "92e9" : "1ae9"; last SWITCH;};
    /^04Y$/ && do {$word = ($channel =~ /[13]/) ? "92ea" : "1aea"; last SWITCH;};
    /^04YU$/ && do {$word = ($channel =~ /[13]/) ? "926b" : "1a6b"; last SWITCH;};
    /^04Ma$/ && do {$word = ($channel =~ /[13]/) ? "92ec" : "1aec"; last SWITCH;};
    /^04MaU$/ && do {$word = ($channel =~ /[13]/) ? "926d" : "1a6d"; last SWITCH;};
    /^04WhI$/ && do {$word = ($channel =~ /[13]/) ? "926e" : "1a6e"; last SWITCH;};
    /^04WhIU$/ && do {$word = ($channel =~ /[13]/) ? "92ef" : "1aef"; last SWITCH;};
    /^0400$/ && do {$word = ($channel =~ /[13]/) ? "9270" : "1a70"; last SWITCH;};
    /^0400U$/ && do {$word = ($channel =~ /[13]/) ? "92f1" : "1af1"; last SWITCH;};
    /^0404$/ && do {$word = ($channel =~ /[13]/) ? "92f2" : "1af2"; last SWITCH;};
    /^0404U$/ && do {$word = ($channel =~ /[13]/) ? "9273" : "1a73"; last SWITCH;};
    /^0408$/ && do {$word = ($channel =~ /[13]/) ? "92f4" : "1af4"; last SWITCH;};
    /^0408U$/ && do {$word = ($channel =~ /[13]/) ? "9275" : "1a75"; last SWITCH;};
    /^0412$/ && do {$word = ($channel =~ /[13]/) ? "9276" : "1a76"; last SWITCH;};
    /^0412U$/ && do {$word = ($channel =~ /[13]/) ? "92f7" : "1af7"; last SWITCH;};
    /^0416$/ && do {$word = ($channel =~ /[13]/) ? "92f8" : "1af7"; last SWITCH;};
    /^0416U$/ && do {$word = ($channel =~ /[13]/) ? "9279" : "1a79"; last SWITCH;};
    /^0420$/ && do {$word = ($channel =~ /[13]/) ? "927a" : "1a7a"; last SWITCH;};
    /^0420U$/ && do {$word = ($channel =~ /[13]/) ? "92fb" : "1afb"; last SWITCH;};
    /^0424$/ && do {$word = ($channel =~ /[13]/) ? "927c" : "1a7c"; last SWITCH;};
    /^0424U$/ && do {$word = ($channel =~ /[13]/) ? "92fd" : "1afd"; last SWITCH;};
    /^0428$/ && do {$word = ($channel =~ /[13]/) ? "92fe" : "1afe"; last SWITCH;};
    /^0428U$/ && do {$word = ($channel =~ /[13]/) ? "927f" : "1a7f"; last SWITCH;};
    /^05Wh$/ && do {$word = ($channel =~ /[13]/) ? "1540" : "9d40"; last SWITCH;};
    /^05WhU$/ && do {$word = ($channel =~ /[13]/) ? "15c1" : "9dc1"; last SWITCH;};
    /^05Gr$/ && do {$word = ($channel =~ /[13]/) ? "15c2" : "9dc2"; last SWITCH;};
    /^05GrU$/ && do {$word = ($channel =~ /[13]/) ? "1543" : "9d43"; last SWITCH;};
    /^05Bl$/ && do {$word = ($channel =~ /[13]/) ? "15c4" : "9dc4"; last SWITCH;};
    /^05BlU$/ && do {$word = ($channel =~ /[13]/) ? "1545" : "9d45"; last SWITCH;};
    /^05Cy$/ && do {$word = ($channel =~ /[13]/) ? "1546" : "9d46"; last SWITCH;};
    /^05CyU$/ && do {$word = ($channel =~ /[13]/) ? "15c7" : "9dc7"; last SWITCH;};
    /^05R$/ && do {$word = ($channel =~ /[13]/) ? "15c8" : "9dc8"; last SWITCH;};
    /^05RU$/ && do {$word = ($channel =~ /[13]/) ? "1549" : "9d49"; last SWITCH;};
    /^05Y$/ && do {$word = ($channel =~ /[13]/) ? "154a" : "9d4a"; last SWITCH;};
    /^05YU$/ && do {$word = ($channel =~ /[13]/) ? "15cb" : "9dcb"; last SWITCH;};
    /^05Ma$/ && do {$word = ($channel =~ /[13]/) ? "154c" : "9d4c"; last SWITCH;};
    /^05MaU$/ && do {$word = ($channel =~ /[13]/) ? "15cd" : "9dcd"; last SWITCH;};
    /^05WhI$/ && do {$word = ($channel =~ /[13]/) ? "15ce" : "9dce"; last SWITCH;};
    /^05WhIU$/ && do {$word = ($channel =~ /[13]/) ? "154f" : "9d4f"; last SWITCH;};
    /^0500$/ && do {$word = ($channel =~ /[13]/) ? "15d0" : "9dd0"; last SWITCH;};
    /^0500U$/ && do {$word = ($channel =~ /[13]/) ? "1551" : "9d51"; last SWITCH;};
    /^0504$/ && do {$word = ($channel =~ /[13]/) ? "1552" : "9d52"; last SWITCH;};
    /^0504U$/ && do {$word = ($channel =~ /[13]/) ? "15d3" : "9dd3"; last SWITCH;};
    /^0508$/ && do {$word = ($channel =~ /[13]/) ? "1554" : "9d54"; last SWITCH;};
    /^0508U$/ && do {$word = ($channel =~ /[13]/) ? "15d5" : "9dd5"; last SWITCH;};
    /^0512$/ && do {$word = ($channel =~ /[13]/) ? "15d6" : "9dd6"; last SWITCH;};
    /^0512U$/ && do {$word = ($channel =~ /[13]/) ? "1557" : "9d57"; last SWITCH;};
    /^0516$/ && do {$word = ($channel =~ /[13]/) ? "1558" : "9d57"; last SWITCH;};
    /^0516U$/ && do {$word = ($channel =~ /[13]/) ? "15d9" : "9dd9"; last SWITCH;};
    /^0520$/ && do {$word = ($channel =~ /[13]/) ? "15da" : "9dda"; last SWITCH;};
    /^0520U$/ && do {$word = ($channel =~ /[13]/) ? "155b" : "9d5b"; last SWITCH;};
    /^0524$/ && do {$word = ($channel =~ /[13]/) ? "15dc" : "9ddc"; last SWITCH;};
    /^0524U$/ && do {$word = ($channel =~ /[13]/) ? "155d" : "9d5d"; last SWITCH;};
    /^0528$/ && do {$word = ($channel =~ /[13]/) ? "155e" : "9d5e"; last SWITCH;};
    /^0528U$/ && do {$word = ($channel =~ /[13]/) ? "15df" : "9ddf"; last SWITCH;};
    /^06Wh$/ && do {$word = ($channel =~ /[13]/) ? "15e0" : "9de0"; last SWITCH;};
    /^06WhU$/ && do {$word = ($channel =~ /[13]/) ? "1561" : "9d61"; last SWITCH;};
    /^06Gr$/ && do {$word = ($channel =~ /[13]/) ? "1562" : "9d62"; last SWITCH;};
    /^06GrU$/ && do {$word = ($channel =~ /[13]/) ? "15e3" : "9de3"; last SWITCH;};
    /^06Bl$/ && do {$word = ($channel =~ /[13]/) ? "1564" : "9d64"; last SWITCH;};
    /^06BlU$/ && do {$word = ($channel =~ /[13]/) ? "15e5" : "9de5"; last SWITCH;};
    /^06Cy$/ && do {$word = ($channel =~ /[13]/) ? "15e6" : "9de6"; last SWITCH;};
    /^06CyU$/ && do {$word = ($channel =~ /[13]/) ? "1567" : "9d67"; last SWITCH;};
    /^06R$/ && do {$word = ($channel =~ /[13]/) ? "1568" : "9d68"; last SWITCH;};
    /^06RU$/ && do {$word = ($channel =~ /[13]/) ? "15e9" : "9de9"; last SWITCH;};
    /^06Y$/ && do {$word = ($channel =~ /[13]/) ? "15ea" : "9dea"; last SWITCH;};
    /^06YU$/ && do {$word = ($channel =~ /[13]/) ? "156b" : "9d6b"; last SWITCH;};
    /^06Ma$/ && do {$word = ($channel =~ /[13]/) ? "15ec" : "9dec"; last SWITCH;};
    /^06MaU$/ && do {$word = ($channel =~ /[13]/) ? "156d" : "9d6d"; last SWITCH;};
    /^06WhI$/ && do {$word = ($channel =~ /[13]/) ? "156e" : "9d6e"; last SWITCH;};
    /^06WhIU$/ && do {$word = ($channel =~ /[13]/) ? "15ef" : "9def"; last SWITCH;};
    /^0600$/ && do {$word = ($channel =~ /[13]/) ? "1570" : "9d70"; last SWITCH;};
    /^0600U$/ && do {$word = ($channel =~ /[13]/) ? "15f1" : "9df1"; last SWITCH;};
    /^0604$/ && do {$word = ($channel =~ /[13]/) ? "15f2" : "9df2"; last SWITCH;};
    /^0604U$/ && do {$word = ($channel =~ /[13]/) ? "1573" : "9d73"; last SWITCH;};
    /^0608$/ && do {$word = ($channel =~ /[13]/) ? "15f4" : "9df4"; last SWITCH;};
    /^0608U$/ && do {$word = ($channel =~ /[13]/) ? "1575" : "9d75"; last SWITCH;};
    /^0612$/ && do {$word = ($channel =~ /[13]/) ? "1576" : "9d76"; last SWITCH;};
    /^0612U$/ && do {$word = ($channel =~ /[13]/) ? "15f7" : "9df7"; last SWITCH;};
    /^0616$/ && do {$word = ($channel =~ /[13]/) ? "15f8" : "9df7"; last SWITCH;};
    /^0616U$/ && do {$word = ($channel =~ /[13]/) ? "1579" : "9d79"; last SWITCH;};
    /^0620$/ && do {$word = ($channel =~ /[13]/) ? "157a" : "9d7a"; last SWITCH;};
    /^0620U$/ && do {$word = ($channel =~ /[13]/) ? "15fb" : "9dfb"; last SWITCH;};
    /^0624$/ && do {$word = ($channel =~ /[13]/) ? "157c" : "9d7c"; last SWITCH;};
    /^0624U$/ && do {$word = ($channel =~ /[13]/) ? "15fd" : "9dfd"; last SWITCH;};
    /^0628$/ && do {$word = ($channel =~ /[13]/) ? "15fe" : "9dfe"; last SWITCH;};
    /^0628U$/ && do {$word = ($channel =~ /[13]/) ? "157f" : "9d7f"; last SWITCH;};
    /^07Wh$/ && do {$word = ($channel =~ /[13]/) ? "1640" : "9e40"; last SWITCH;};
    /^07WhU$/ && do {$word = ($channel =~ /[13]/) ? "16c1" : "9ec1"; last SWITCH;};
    /^07Gr$/ && do {$word = ($channel =~ /[13]/) ? "16c2" : "9ec2"; last SWITCH;};
    /^07GrU$/ && do {$word = ($channel =~ /[13]/) ? "1643" : "9e43"; last SWITCH;};
    /^07Bl$/ && do {$word = ($channel =~ /[13]/) ? "16c4" : "9ec4"; last SWITCH;};
    /^07BlU$/ && do {$word = ($channel =~ /[13]/) ? "1645" : "9e45"; last SWITCH;};
    /^07Cy$/ && do {$word = ($channel =~ /[13]/) ? "1646" : "9e46"; last SWITCH;};
    /^07CyU$/ && do {$word = ($channel =~ /[13]/) ? "16c7" : "9ec7"; last SWITCH;};
    /^07R$/ && do {$word = ($channel =~ /[13]/) ? "16c8" : "9ec8"; last SWITCH;};
    /^07RU$/ && do {$word = ($channel =~ /[13]/) ? "1649" : "9e49"; last SWITCH;};
    /^07Y$/ && do {$word = ($channel =~ /[13]/) ? "164a" : "9e4a"; last SWITCH;};
    /^07YU$/ && do {$word = ($channel =~ /[13]/) ? "16cb" : "9ecb"; last SWITCH;};
    /^07Ma$/ && do {$word = ($channel =~ /[13]/) ? "164c" : "9e4c"; last SWITCH;};
    /^07MaU$/ && do {$word = ($channel =~ /[13]/) ? "16cd" : "9ecd"; last SWITCH;};
    /^07WhI$/ && do {$word = ($channel =~ /[13]/) ? "16ce" : "9ece"; last SWITCH;};
    /^07WhIU$/ && do {$word = ($channel =~ /[13]/) ? "164f" : "9e4f"; last SWITCH;};
    /^0700$/ && do {$word = ($channel =~ /[13]/) ? "16d0" : "9ed0"; last SWITCH;};
    /^0700U$/ && do {$word = ($channel =~ /[13]/) ? "1651" : "9e51"; last SWITCH;};
    /^0704$/ && do {$word = ($channel =~ /[13]/) ? "1652" : "9e52"; last SWITCH;};
    /^0704U$/ && do {$word = ($channel =~ /[13]/) ? "16d3" : "9ed3"; last SWITCH;};
    /^0708$/ && do {$word = ($channel =~ /[13]/) ? "1654" : "9e54"; last SWITCH;};
    /^0708U$/ && do {$word = ($channel =~ /[13]/) ? "16d5" : "9ed5"; last SWITCH;};
    /^0712$/ && do {$word = ($channel =~ /[13]/) ? "16d6" : "9ed6"; last SWITCH;};
    /^0712U$/ && do {$word = ($channel =~ /[13]/) ? "1657" : "9e57"; last SWITCH;};
    /^0716$/ && do {$word = ($channel =~ /[13]/) ? "1658" : "9e57"; last SWITCH;};
    /^0716U$/ && do {$word = ($channel =~ /[13]/) ? "16d9" : "9ed9"; last SWITCH;};
    /^0720$/ && do {$word = ($channel =~ /[13]/) ? "16da" : "9eda"; last SWITCH;};
    /^0720U$/ && do {$word = ($channel =~ /[13]/) ? "165b" : "9e5b"; last SWITCH;};
    /^0724$/ && do {$word = ($channel =~ /[13]/) ? "16dc" : "9edc"; last SWITCH;};
    /^0724U$/ && do {$word = ($channel =~ /[13]/) ? "165d" : "9e5d"; last SWITCH;};
    /^0728$/ && do {$word = ($channel =~ /[13]/) ? "165e" : "9e5e"; last SWITCH;};
    /^0728U$/ && do {$word = ($channel =~ /[13]/) ? "16df" : "9edf"; last SWITCH;};
    /^08Wh$/ && do {$word = ($channel =~ /[13]/) ? "16e0" : "9ee0"; last SWITCH;};
    /^08WhU$/ && do {$word = ($channel =~ /[13]/) ? "1661" : "9e61"; last SWITCH;};
    /^08Gr$/ && do {$word = ($channel =~ /[13]/) ? "1662" : "9e62"; last SWITCH;};
    /^08GrU$/ && do {$word = ($channel =~ /[13]/) ? "16e3" : "9ee3"; last SWITCH;};
    /^08Bl$/ && do {$word = ($channel =~ /[13]/) ? "1664" : "9e64"; last SWITCH;};
    /^08BlU$/ && do {$word = ($channel =~ /[13]/) ? "16e5" : "9ee5"; last SWITCH;};
    /^08Cy$/ && do {$word = ($channel =~ /[13]/) ? "16e6" : "9ee6"; last SWITCH;};
    /^08CyU$/ && do {$word = ($channel =~ /[13]/) ? "1667" : "9e67"; last SWITCH;};
    /^08R$/ && do {$word = ($channel =~ /[13]/) ? "1668" : "9e68"; last SWITCH;};
    /^08RU$/ && do {$word = ($channel =~ /[13]/) ? "16e9" : "9ee9"; last SWITCH;};
    /^08Y$/ && do {$word = ($channel =~ /[13]/) ? "16ea" : "9eea"; last SWITCH;};
    /^08YU$/ && do {$word = ($channel =~ /[13]/) ? "166b" : "9e6b"; last SWITCH;};
    /^08Ma$/ && do {$word = ($channel =~ /[13]/) ? "16ec" : "9eec"; last SWITCH;};
    /^08MaU$/ && do {$word = ($channel =~ /[13]/) ? "166d" : "9e6d"; last SWITCH;};
    /^08WhI$/ && do {$word = ($channel =~ /[13]/) ? "166e" : "9e6e"; last SWITCH;};
    /^08WhIU$/ && do {$word = ($channel =~ /[13]/) ? "16ef" : "9eef"; last SWITCH;};
    /^0800$/ && do {$word = ($channel =~ /[13]/) ? "1670" : "9e70"; last SWITCH;};
    /^0800U$/ && do {$word = ($channel =~ /[13]/) ? "16f1" : "9ef1"; last SWITCH;};
    /^0804$/ && do {$word = ($channel =~ /[13]/) ? "16f2" : "9ef2"; last SWITCH;};
    /^0804U$/ && do {$word = ($channel =~ /[13]/) ? "1673" : "9e73"; last SWITCH;};
    /^0808$/ && do {$word = ($channel =~ /[13]/) ? "16f4" : "9ef4"; last SWITCH;};
    /^0808U$/ && do {$word = ($channel =~ /[13]/) ? "1675" : "9e75"; last SWITCH;};
    /^0812$/ && do {$word = ($channel =~ /[13]/) ? "1676" : "9e76"; last SWITCH;};
    /^0812U$/ && do {$word = ($channel =~ /[13]/) ? "16f7" : "9ef7"; last SWITCH;};
    /^0816$/ && do {$word = ($channel =~ /[13]/) ? "16f8" : "9ef7"; last SWITCH;};
    /^0816U$/ && do {$word = ($channel =~ /[13]/) ? "1679" : "9e79"; last SWITCH;};
    /^0820$/ && do {$word = ($channel =~ /[13]/) ? "167a" : "9e7a"; last SWITCH;};
    /^0820U$/ && do {$word = ($channel =~ /[13]/) ? "16fb" : "9efb"; last SWITCH;};
    /^0824$/ && do {$word = ($channel =~ /[13]/) ? "167c" : "9e7c"; last SWITCH;};
    /^0824U$/ && do {$word = ($channel =~ /[13]/) ? "16fd" : "9efd"; last SWITCH;};
    /^0828$/ && do {$word = ($channel =~ /[13]/) ? "16fe" : "9efe"; last SWITCH;};
    /^0828U$/ && do {$word = ($channel =~ /[13]/) ? "167f" : "9e7f"; last SWITCH;};
    /^09Wh$/ && do {$word = ($channel =~ /[13]/) ? "9740" : "1f40"; last SWITCH;};
    /^09WhU$/ && do {$word = ($channel =~ /[13]/) ? "97c1" : "1fc1"; last SWITCH;};
    /^09Gr$/ && do {$word = ($channel =~ /[13]/) ? "97c2" : "1fc2"; last SWITCH;};
    /^09GrU$/ && do {$word = ($channel =~ /[13]/) ? "9743" : "1f43"; last SWITCH;};
    /^09Bl$/ && do {$word = ($channel =~ /[13]/) ? "97c4" : "1fc4"; last SWITCH;};
    /^09BlU$/ && do {$word = ($channel =~ /[13]/) ? "9745" : "1f45"; last SWITCH;};
    /^09Cy$/ && do {$word = ($channel =~ /[13]/) ? "9746" : "1f46"; last SWITCH;};
    /^09CyU$/ && do {$word = ($channel =~ /[13]/) ? "97c7" : "1fc7"; last SWITCH;};
    /^09R$/ && do {$word = ($channel =~ /[13]/) ? "97c8" : "1fc8"; last SWITCH;};
    /^09RU$/ && do {$word = ($channel =~ /[13]/) ? "9749" : "1f49"; last SWITCH;};
    /^09Y$/ && do {$word = ($channel =~ /[13]/) ? "974a" : "1f4a"; last SWITCH;};
    /^09YU$/ && do {$word = ($channel =~ /[13]/) ? "97cb" : "1fcb"; last SWITCH;};
    /^09Ma$/ && do {$word = ($channel =~ /[13]/) ? "974c" : "1f4c"; last SWITCH;};
    /^09MaU$/ && do {$word = ($channel =~ /[13]/) ? "97cd" : "1fcd"; last SWITCH;};
    /^09WhI$/ && do {$word = ($channel =~ /[13]/) ? "97ce" : "1fce"; last SWITCH;};
    /^09WhIU$/ && do {$word = ($channel =~ /[13]/) ? "974f" : "1f4f"; last SWITCH;};
    /^0900$/ && do {$word = ($channel =~ /[13]/) ? "97d0" : "1fd0"; last SWITCH;};
    /^0900U$/ && do {$word = ($channel =~ /[13]/) ? "9751" : "1f51"; last SWITCH;};
    /^0904$/ && do {$word = ($channel =~ /[13]/) ? "9752" : "1f52"; last SWITCH;};
    /^0904U$/ && do {$word = ($channel =~ /[13]/) ? "97d3" : "1fd3"; last SWITCH;};
    /^0908$/ && do {$word = ($channel =~ /[13]/) ? "9754" : "1f54"; last SWITCH;};
    /^0908U$/ && do {$word = ($channel =~ /[13]/) ? "97d5" : "1fd5"; last SWITCH;};
    /^0912$/ && do {$word = ($channel =~ /[13]/) ? "97d6" : "1fd6"; last SWITCH;};
    /^0912U$/ && do {$word = ($channel =~ /[13]/) ? "9757" : "1f57"; last SWITCH;};
    /^0916$/ && do {$word = ($channel =~ /[13]/) ? "9758" : "1f57"; last SWITCH;};
    /^0916U$/ && do {$word = ($channel =~ /[13]/) ? "97d9" : "1fd9"; last SWITCH;};
    /^0920$/ && do {$word = ($channel =~ /[13]/) ? "97da" : "1fda"; last SWITCH;};
    /^0920U$/ && do {$word = ($channel =~ /[13]/) ? "975b" : "1f5b"; last SWITCH;};
    /^0924$/ && do {$word = ($channel =~ /[13]/) ? "97dc" : "1fdc"; last SWITCH;};
    /^0924U$/ && do {$word = ($channel =~ /[13]/) ? "975d" : "1f5d"; last SWITCH;};
    /^0928$/ && do {$word = ($channel =~ /[13]/) ? "975e" : "1f5e"; last SWITCH;};
    /^0928U$/ && do {$word = ($channel =~ /[13]/) ? "97df" : "1fdf"; last SWITCH;};
    /^10Wh$/ && do {$word = ($channel =~ /[13]/) ? "97e0" : "1fe0"; last SWITCH;};
    /^10WhU$/ && do {$word = ($channel =~ /[13]/) ? "9761" : "1f61"; last SWITCH;};
    /^10Gr$/ && do {$word = ($channel =~ /[13]/) ? "9762" : "1f62"; last SWITCH;};
    /^10GrU$/ && do {$word = ($channel =~ /[13]/) ? "97e3" : "1fe3"; last SWITCH;};
    /^10Bl$/ && do {$word = ($channel =~ /[13]/) ? "9764" : "1f64"; last SWITCH;};
    /^10BlU$/ && do {$word = ($channel =~ /[13]/) ? "97e5" : "1fe5"; last SWITCH;};
    /^10Cy$/ && do {$word = ($channel =~ /[13]/) ? "97e6" : "1fe6"; last SWITCH;};
    /^10CyU$/ && do {$word = ($channel =~ /[13]/) ? "9767" : "1f67"; last SWITCH;};
    /^10R$/ && do {$word = ($channel =~ /[13]/) ? "9768" : "1f68"; last SWITCH;};
    /^10RU$/ && do {$word = ($channel =~ /[13]/) ? "97e9" : "1fe9"; last SWITCH;};
    /^10Y$/ && do {$word = ($channel =~ /[13]/) ? "97ea" : "1fea"; last SWITCH;};
    /^10YU$/ && do {$word = ($channel =~ /[13]/) ? "976b" : "1f6b"; last SWITCH;};
    /^10Ma$/ && do {$word = ($channel =~ /[13]/) ? "97ec" : "1fec"; last SWITCH;};
    /^10MaU$/ && do {$word = ($channel =~ /[13]/) ? "976d" : "1f6d"; last SWITCH;};
    /^10WhI$/ && do {$word = ($channel =~ /[13]/) ? "976e" : "1f6e"; last SWITCH;};
    /^10WhIU$/ && do {$word = ($channel =~ /[13]/) ? "97ef" : "1fef"; last SWITCH;};
    /^1000$/ && do {$word = ($channel =~ /[13]/) ? "9770" : "1f70"; last SWITCH;};
    /^1000U$/ && do {$word = ($channel =~ /[13]/) ? "97f1" : "1ff1"; last SWITCH;};
    /^1004$/ && do {$word = ($channel =~ /[13]/) ? "97f2" : "1ff2"; last SWITCH;};
    /^1004U$/ && do {$word = ($channel =~ /[13]/) ? "9773" : "1f73"; last SWITCH;};
    /^1008$/ && do {$word = ($channel =~ /[13]/) ? "97f4" : "1ff4"; last SWITCH;};
    /^1008U$/ && do {$word = ($channel =~ /[13]/) ? "9775" : "1f75"; last SWITCH;};
    /^1012$/ && do {$word = ($channel =~ /[13]/) ? "9776" : "1f76"; last SWITCH;};
    /^1012U$/ && do {$word = ($channel =~ /[13]/) ? "97f7" : "1ff7"; last SWITCH;};
    /^1016$/ && do {$word = ($channel =~ /[13]/) ? "97f8" : "1ff7"; last SWITCH;};
    /^1016U$/ && do {$word = ($channel =~ /[13]/) ? "9779" : "1f79"; last SWITCH;};
    /^1020$/ && do {$word = ($channel =~ /[13]/) ? "977a" : "1f7a"; last SWITCH;};
    /^1020U$/ && do {$word = ($channel =~ /[13]/) ? "97fb" : "1ffb"; last SWITCH;};
    /^1024$/ && do {$word = ($channel =~ /[13]/) ? "977c" : "1f7c"; last SWITCH;};
    /^1024U$/ && do {$word = ($channel =~ /[13]/) ? "97fd" : "1ffd"; last SWITCH;};
    /^1028$/ && do {$word = ($channel =~ /[13]/) ? "97fe" : "1ffe"; last SWITCH;};
    /^1028U$/ && do {$word = ($channel =~ /[13]/) ? "977f" : "1f7f"; last SWITCH;};
    /^11Wh$/ && do {$word = ($channel =~ /[13]/) ? "1040" : "9840"; last SWITCH;};
    /^11WhU$/ && do {$word = ($channel =~ /[13]/) ? "10c1" : "98c1"; last SWITCH;};
    /^11Gr$/ && do {$word = ($channel =~ /[13]/) ? "10c2" : "98c2"; last SWITCH;};
    /^11GrU$/ && do {$word = ($channel =~ /[13]/) ? "1043" : "9843"; last SWITCH;};
    /^11Bl$/ && do {$word = ($channel =~ /[13]/) ? "10c4" : "98c4"; last SWITCH;};
    /^11BlU$/ && do {$word = ($channel =~ /[13]/) ? "1045" : "9845"; last SWITCH;};
    /^11Cy$/ && do {$word = ($channel =~ /[13]/) ? "1046" : "9846"; last SWITCH;};
    /^11CyU$/ && do {$word = ($channel =~ /[13]/) ? "10c7" : "98c7"; last SWITCH;};
    /^11R$/ && do {$word = ($channel =~ /[13]/) ? "10c8" : "98c8"; last SWITCH;};
    /^11RU$/ && do {$word = ($channel =~ /[13]/) ? "1049" : "9849"; last SWITCH;};
    /^11Y$/ && do {$word = ($channel =~ /[13]/) ? "104a" : "984a"; last SWITCH;};
    /^11YU$/ && do {$word = ($channel =~ /[13]/) ? "10cb" : "98cb"; last SWITCH;};
    /^11Ma$/ && do {$word = ($channel =~ /[13]/) ? "104c" : "984c"; last SWITCH;};
    /^11MaU$/ && do {$word = ($channel =~ /[13]/) ? "10cd" : "98cd"; last SWITCH;};
    /^11WhI$/ && do {$word = ($channel =~ /[13]/) ? "10ce" : "98ce"; last SWITCH;};
    /^11WhIU$/ && do {$word = ($channel =~ /[13]/) ? "104f" : "984f"; last SWITCH;};
    /^1100$/ && do {$word = ($channel =~ /[13]/) ? "10d0" : "98d0"; last SWITCH;};
    /^1100U$/ && do {$word = ($channel =~ /[13]/) ? "1051" : "9851"; last SWITCH;};
    /^1104$/ && do {$word = ($channel =~ /[13]/) ? "1052" : "9852"; last SWITCH;};
    /^1104U$/ && do {$word = ($channel =~ /[13]/) ? "10d3" : "98d3"; last SWITCH;};
    /^1108$/ && do {$word = ($channel =~ /[13]/) ? "1054" : "9854"; last SWITCH;};
    /^1108U$/ && do {$word = ($channel =~ /[13]/) ? "10d5" : "98d5"; last SWITCH;};
    /^1112$/ && do {$word = ($channel =~ /[13]/) ? "10d6" : "98d6"; last SWITCH;};
    /^1112U$/ && do {$word = ($channel =~ /[13]/) ? "1057" : "9857"; last SWITCH;};
    /^1116$/ && do {$word = ($channel =~ /[13]/) ? "1058" : "9857"; last SWITCH;};
    /^1116U$/ && do {$word = ($channel =~ /[13]/) ? "10d9" : "98d9"; last SWITCH;};
    /^1120$/ && do {$word = ($channel =~ /[13]/) ? "10da" : "98da"; last SWITCH;};
    /^1120U$/ && do {$word = ($channel =~ /[13]/) ? "105b" : "985b"; last SWITCH;};
    /^1124$/ && do {$word = ($channel =~ /[13]/) ? "10dc" : "98dc"; last SWITCH;};
    /^1124U$/ && do {$word = ($channel =~ /[13]/) ? "105d" : "985d"; last SWITCH;};
    /^1128$/ && do {$word = ($channel =~ /[13]/) ? "105e" : "985e"; last SWITCH;};
    /^1128U$/ && do {$word = ($channel =~ /[13]/) ? "10df" : "98df"; last SWITCH;};
    /^12Wh$/ && do {$word = ($channel =~ /[13]/) ? "1340" : "9b40"; last SWITCH;};
    /^12WhU$/ && do {$word = ($channel =~ /[13]/) ? "13c1" : "9bc1"; last SWITCH;};
    /^12Gr$/ && do {$word = ($channel =~ /[13]/) ? "13c2" : "9bc2"; last SWITCH;};
    /^12GrU$/ && do {$word = ($channel =~ /[13]/) ? "1343" : "9b43"; last SWITCH;};
    /^12Bl$/ && do {$word = ($channel =~ /[13]/) ? "13c4" : "9bc4"; last SWITCH;};
    /^12BlU$/ && do {$word = ($channel =~ /[13]/) ? "1345" : "9b45"; last SWITCH;};
    /^12Cy$/ && do {$word = ($channel =~ /[13]/) ? "1346" : "9b46"; last SWITCH;};
    /^12CyU$/ && do {$word = ($channel =~ /[13]/) ? "13c7" : "9bc7"; last SWITCH;};
    /^12R$/ && do {$word = ($channel =~ /[13]/) ? "13c8" : "9bc8"; last SWITCH;};
    /^12RU$/ && do {$word = ($channel =~ /[13]/) ? "1349" : "9b49"; last SWITCH;};
    /^12Y$/ && do {$word = ($channel =~ /[13]/) ? "134a" : "9b4a"; last SWITCH;};
    /^12YU$/ && do {$word = ($channel =~ /[13]/) ? "13cb" : "9bcb"; last SWITCH;};
    /^12Ma$/ && do {$word = ($channel =~ /[13]/) ? "134c" : "9b4c"; last SWITCH;};
    /^12MaU$/ && do {$word = ($channel =~ /[13]/) ? "13cd" : "9bcd"; last SWITCH;};
    /^12WhI$/ && do {$word = ($channel =~ /[13]/) ? "13ce" : "9bce"; last SWITCH;};
    /^12WhIU$/ && do {$word = ($channel =~ /[13]/) ? "134f" : "9b4f"; last SWITCH;};
    /^1200$/ && do {$word = ($channel =~ /[13]/) ? "13d0" : "9bd0"; last SWITCH;};
    /^1200U$/ && do {$word = ($channel =~ /[13]/) ? "1351" : "9b51"; last SWITCH;};
    /^1204$/ && do {$word = ($channel =~ /[13]/) ? "1352" : "9b52"; last SWITCH;};
    /^1204U$/ && do {$word = ($channel =~ /[13]/) ? "13d3" : "9bd3"; last SWITCH;};
    /^1208$/ && do {$word = ($channel =~ /[13]/) ? "1354" : "9b54"; last SWITCH;};
    /^1208U$/ && do {$word = ($channel =~ /[13]/) ? "13d5" : "9bd5"; last SWITCH;};
    /^1212$/ && do {$word = ($channel =~ /[13]/) ? "13d6" : "9bd6"; last SWITCH;};
    /^1212U$/ && do {$word = ($channel =~ /[13]/) ? "1357" : "9b57"; last SWITCH;};
    /^1216$/ && do {$word = ($channel =~ /[13]/) ? "1358" : "9b57"; last SWITCH;};
    /^1216U$/ && do {$word = ($channel =~ /[13]/) ? "13d9" : "9bd9"; last SWITCH;};
    /^1220$/ && do {$word = ($channel =~ /[13]/) ? "13da" : "9bda"; last SWITCH;};
    /^1220U$/ && do {$word = ($channel =~ /[13]/) ? "135b" : "9b5b"; last SWITCH;};
    /^1224$/ && do {$word = ($channel =~ /[13]/) ? "13dc" : "9bdc"; last SWITCH;};
    /^1224U$/ && do {$word = ($channel =~ /[13]/) ? "135d" : "9b5d"; last SWITCH;};
    /^1228$/ && do {$word = ($channel =~ /[13]/) ? "135e" : "9b5e"; last SWITCH;};
    /^1228U$/ && do {$word = ($channel =~ /[13]/) ? "13df" : "9bdf"; last SWITCH;};
    /^13Wh$/ && do {$word = ($channel =~ /[13]/) ? "13e0" : "9be0"; last SWITCH;};
    /^13WhU$/ && do {$word = ($channel =~ /[13]/) ? "1361" : "9b61"; last SWITCH;};
    /^13Gr$/ && do {$word = ($channel =~ /[13]/) ? "1362" : "9b62"; last SWITCH;};
    /^13GrU$/ && do {$word = ($channel =~ /[13]/) ? "13e3" : "9be3"; last SWITCH;};
    /^13Bl$/ && do {$word = ($channel =~ /[13]/) ? "1364" : "9b64"; last SWITCH;};
    /^13BlU$/ && do {$word = ($channel =~ /[13]/) ? "13e5" : "9be5"; last SWITCH;};
    /^13Cy$/ && do {$word = ($channel =~ /[13]/) ? "13e6" : "9be6"; last SWITCH;};
    /^13CyU$/ && do {$word = ($channel =~ /[13]/) ? "1367" : "9b67"; last SWITCH;};
    /^13R$/ && do {$word = ($channel =~ /[13]/) ? "1368" : "9b68"; last SWITCH;};
    /^13RU$/ && do {$word = ($channel =~ /[13]/) ? "13e9" : "9be9"; last SWITCH;};
    /^13Y$/ && do {$word = ($channel =~ /[13]/) ? "13ea" : "9bea"; last SWITCH;};
    /^13YU$/ && do {$word = ($channel =~ /[13]/) ? "136b" : "9b6b"; last SWITCH;};
    /^13Ma$/ && do {$word = ($channel =~ /[13]/) ? "13ec" : "9bec"; last SWITCH;};
    /^13MaU$/ && do {$word = ($channel =~ /[13]/) ? "136d" : "9b6d"; last SWITCH;};
    /^13WhI$/ && do {$word = ($channel =~ /[13]/) ? "136e" : "9b6e"; last SWITCH;};
    /^13WhIU$/ && do {$word = ($channel =~ /[13]/) ? "13ef" : "9bef"; last SWITCH;};
    /^1300$/ && do {$word = ($channel =~ /[13]/) ? "1370" : "9b70"; last SWITCH;};
    /^1300U$/ && do {$word = ($channel =~ /[13]/) ? "13f1" : "9bf1"; last SWITCH;};
    /^1304$/ && do {$word = ($channel =~ /[13]/) ? "13f2" : "9bf2"; last SWITCH;};
    /^1304U$/ && do {$word = ($channel =~ /[13]/) ? "1373" : "9b73"; last SWITCH;};
    /^1308$/ && do {$word = ($channel =~ /[13]/) ? "13f4" : "9bf4"; last SWITCH;};
    /^1308U$/ && do {$word = ($channel =~ /[13]/) ? "1375" : "9b75"; last SWITCH;};
    /^1312$/ && do {$word = ($channel =~ /[13]/) ? "1376" : "9b76"; last SWITCH;};
    /^1312U$/ && do {$word = ($channel =~ /[13]/) ? "13f7" : "9bf7"; last SWITCH;};
    /^1316$/ && do {$word = ($channel =~ /[13]/) ? "13f8" : "9bf7"; last SWITCH;};
    /^1316U$/ && do {$word = ($channel =~ /[13]/) ? "1379" : "9b79"; last SWITCH;};
    /^1320$/ && do {$word = ($channel =~ /[13]/) ? "137a" : "9b7a"; last SWITCH;};
    /^1320U$/ && do {$word = ($channel =~ /[13]/) ? "13fb" : "9bfb"; last SWITCH;};
    /^1324$/ && do {$word = ($channel =~ /[13]/) ? "137c" : "9b7c"; last SWITCH;};
    /^1324U$/ && do {$word = ($channel =~ /[13]/) ? "13fd" : "9bfd"; last SWITCH;};
    /^1328$/ && do {$word = ($channel =~ /[13]/) ? "13fe" : "9bfe"; last SWITCH;};
    /^1328U$/ && do {$word = ($channel =~ /[13]/) ? "137f" : "9b7f"; last SWITCH;};
    /^14Wh$/ && do {$word = ($channel =~ /[13]/) ? "9440" : "1c40"; last SWITCH;};
    /^14WhU$/ && do {$word = ($channel =~ /[13]/) ? "94c1" : "1cc1"; last SWITCH;};
    /^14Gr$/ && do {$word = ($channel =~ /[13]/) ? "94c2" : "1cc2"; last SWITCH;};
    /^14GrU$/ && do {$word = ($channel =~ /[13]/) ? "9443" : "1c43"; last SWITCH;};
    /^14Bl$/ && do {$word = ($channel =~ /[13]/) ? "94c4" : "1cc4"; last SWITCH;};
    /^14BlU$/ && do {$word = ($channel =~ /[13]/) ? "9445" : "1c45"; last SWITCH;};
    /^14Cy$/ && do {$word = ($channel =~ /[13]/) ? "9446" : "1c46"; last SWITCH;};
    /^14CyU$/ && do {$word = ($channel =~ /[13]/) ? "94c7" : "1cc7"; last SWITCH;};
    /^14R$/ && do {$word = ($channel =~ /[13]/) ? "94c8" : "1cc8"; last SWITCH;};
    /^14RU$/ && do {$word = ($channel =~ /[13]/) ? "9449" : "1c49"; last SWITCH;};
    /^14Y$/ && do {$word = ($channel =~ /[13]/) ? "944a" : "1c4a"; last SWITCH;};
    /^14YU$/ && do {$word = ($channel =~ /[13]/) ? "94cb" : "1ccb"; last SWITCH;};
    /^14Ma$/ && do {$word = ($channel =~ /[13]/) ? "944c" : "1c4c"; last SWITCH;};
    /^14MaU$/ && do {$word = ($channel =~ /[13]/) ? "94cd" : "1ccd"; last SWITCH;};
    /^14WhI$/ && do {$word = ($channel =~ /[13]/) ? "94ce" : "1cce"; last SWITCH;};
    /^14WhIU$/ && do {$word = ($channel =~ /[13]/) ? "944f" : "1c4f"; last SWITCH;};
    /^1400$/ && do {$word = ($channel =~ /[13]/) ? "94d0" : "1cd0"; last SWITCH;};
    /^1400U$/ && do {$word = ($channel =~ /[13]/) ? "9451" : "1c51"; last SWITCH;};
    /^1404$/ && do {$word = ($channel =~ /[13]/) ? "9452" : "1c52"; last SWITCH;};
    /^1404U$/ && do {$word = ($channel =~ /[13]/) ? "94d3" : "1cd3"; last SWITCH;};
    /^1408$/ && do {$word = ($channel =~ /[13]/) ? "9454" : "1c54"; last SWITCH;};
    /^1408U$/ && do {$word = ($channel =~ /[13]/) ? "94d5" : "1cd5"; last SWITCH;};
    /^1412$/ && do {$word = ($channel =~ /[13]/) ? "94d6" : "1cd6"; last SWITCH;};
    /^1412U$/ && do {$word = ($channel =~ /[13]/) ? "9457" : "1c57"; last SWITCH;};
    /^1416$/ && do {$word = ($channel =~ /[13]/) ? "9458" : "1c57"; last SWITCH;};
    /^1416U$/ && do {$word = ($channel =~ /[13]/) ? "94d9" : "1cd9"; last SWITCH;};
    /^1420$/ && do {$word = ($channel =~ /[13]/) ? "94da" : "1cda"; last SWITCH;};
    /^1420U$/ && do {$word = ($channel =~ /[13]/) ? "945b" : "1c5b"; last SWITCH;};
    /^1424$/ && do {$word = ($channel =~ /[13]/) ? "94dc" : "1cdc"; last SWITCH;};
    /^1424U$/ && do {$word = ($channel =~ /[13]/) ? "945d" : "1c5d"; last SWITCH;};
    /^1428$/ && do {$word = ($channel =~ /[13]/) ? "945e" : "1c5e"; last SWITCH;};
    /^1428U$/ && do {$word = ($channel =~ /[13]/) ? "94df" : "1cdf"; last SWITCH;};
    /^15Wh$/ && do {$word = ($channel =~ /[13]/) ? "94e0" : "1ce0"; last SWITCH;};
    /^15WhU$/ && do {$word = ($channel =~ /[13]/) ? "9461" : "1c61"; last SWITCH;};
    /^15Gr$/ && do {$word = ($channel =~ /[13]/) ? "9462" : "1c62"; last SWITCH;};
    /^15GrU$/ && do {$word = ($channel =~ /[13]/) ? "94e3" : "1ce3"; last SWITCH;};
    /^15Bl$/ && do {$word = ($channel =~ /[13]/) ? "9464" : "1c64"; last SWITCH;};
    /^15BlU$/ && do {$word = ($channel =~ /[13]/) ? "94e5" : "1ce5"; last SWITCH;};
    /^15Cy$/ && do {$word = ($channel =~ /[13]/) ? "94e6" : "1ce6"; last SWITCH;};
    /^15CyU$/ && do {$word = ($channel =~ /[13]/) ? "9467" : "1c67"; last SWITCH;};
    /^15R$/ && do {$word = ($channel =~ /[13]/) ? "9468" : "1c68"; last SWITCH;};
    /^15RU$/ && do {$word = ($channel =~ /[13]/) ? "94e9" : "1ce9"; last SWITCH;};
    /^15Y$/ && do {$word = ($channel =~ /[13]/) ? "94ea" : "1cea"; last SWITCH;};
    /^15YU$/ && do {$word = ($channel =~ /[13]/) ? "946b" : "1c6b"; last SWITCH;};
    /^15Ma$/ && do {$word = ($channel =~ /[13]/) ? "94ec" : "1cec"; last SWITCH;};
    /^15MaU$/ && do {$word = ($channel =~ /[13]/) ? "946d" : "1c6d"; last SWITCH;};
    /^15WhI$/ && do {$word = ($channel =~ /[13]/) ? "946e" : "1c6e"; last SWITCH;};
    /^15WhIU$/ && do {$word = ($channel =~ /[13]/) ? "94ef" : "1cef"; last SWITCH;};
    /^1500$/ && do {$word = ($channel =~ /[13]/) ? "9470" : "1c70"; last SWITCH;};
    /^1500U$/ && do {$word = ($channel =~ /[13]/) ? "94f1" : "1cf1"; last SWITCH;};
    /^1504$/ && do {$word = ($channel =~ /[13]/) ? "94f2" : "1cf2"; last SWITCH;};
    /^1504U$/ && do {$word = ($channel =~ /[13]/) ? "9473" : "1c73"; last SWITCH;};
    /^1508$/ && do {$word = ($channel =~ /[13]/) ? "94f4" : "1cf4"; last SWITCH;};
    /^1508U$/ && do {$word = ($channel =~ /[13]/) ? "9475" : "1c75"; last SWITCH;};
    /^1512$/ && do {$word = ($channel =~ /[13]/) ? "9476" : "1c76"; last SWITCH;};
    /^1512U$/ && do {$word = ($channel =~ /[13]/) ? "94f7" : "1cf7"; last SWITCH;};
    /^1516$/ && do {$word = ($channel =~ /[13]/) ? "94f8" : "1cf7"; last SWITCH;};
    /^1516U$/ && do {$word = ($channel =~ /[13]/) ? "9479" : "1c79"; last SWITCH;};
    /^1520$/ && do {$word = ($channel =~ /[13]/) ? "947a" : "1c7a"; last SWITCH;};
    /^1520U$/ && do {$word = ($channel =~ /[13]/) ? "94fb" : "1cfb"; last SWITCH;};
    /^1524$/ && do {$word = ($channel =~ /[13]/) ? "947c" : "1c7c"; last SWITCH;};
    /^1524U$/ && do {$word = ($channel =~ /[13]/) ? "94fd" : "1cfd"; last SWITCH;};
    /^1528$/ && do {$word = ($channel =~ /[13]/) ? "94fe" : "1cfe"; last SWITCH;};
    /^1528U$/ && do {$word = ($channel =~ /[13]/) ? "947f" : "1c7f"; last SWITCH;};
    /^Wh$/ && do {$word = ($channel =~ /[13]/) ? "9120" : "1920"; last SWITCH;};
    /^WhU$/ && do {$word = ($channel =~ /[13]/) ? "91a1" : "19a1"; last SWITCH;};
    /^Gr$/ && do {$word = ($channel =~ /[13]/) ? "91a2" : "19a2"; last SWITCH;};
    /^GrU$/ && do {$word = ($channel =~ /[13]/) ? "9123" : "1923"; last SWITCH;};
    /^Bl$/ && do {$word = ($channel =~ /[13]/) ? "91a4" : "19a4"; last SWITCH;};
    /^BlU$/ && do {$word = ($channel =~ /[13]/) ? "9125" : "1925"; last SWITCH;};
    /^Cy$/ && do {$word = ($channel =~ /[13]/) ? "9126" : "1926"; last SWITCH;};
    /^CyU$/ && do {$word = ($channel =~ /[13]/) ? "91a7" : "19a7"; last SWITCH;};
    /^R$/ && do {$word = ($channel =~ /[13]/) ? "91a8" : "19a8"; last SWITCH;};
    /^RU$/ && do {$word = ($channel =~ /[13]/) ? "9129" : "1929"; last SWITCH;};
    /^Y$/ && do {$word = ($channel =~ /[13]/) ? "912a" : "192a"; last SWITCH;};
    /^YU$/ && do {$word = ($channel =~ /[13]/) ? "91ab" : "19ab"; last SWITCH;};
    /^Ma$/ && do {$word = ($channel =~ /[13]/) ? "912c" : "192c"; last SWITCH;};
    /^MaU$/ && do {$word = ($channel =~ /[13]/) ? "91ad" : "19ad"; last SWITCH;};
    /^I$/ && do {$word = ($channel =~ /[13]/) ? "91ae" : "19ae"; last SWITCH;};
    /^IU$/ && do {$word = ($channel =~ /[13]/) ? "912f" : "192f"; last SWITCH;};
    /^BWh$/ && do {$word = ($channel =~ /[13]/) ? "1020" : "9820"; last SWITCH;};
    /^BWhS$/ && do {$word = ($channel =~ /[13]/) ? "10a1" : "98a1"; last SWITCH;};
    /^BGr$/ && do {$word = ($channel =~ /[13]/) ? "10a2" : "98a2"; last SWITCH;};
    /^BGrS$/ && do {$word = ($channel =~ /[13]/) ? "1023" : "9823"; last SWITCH;};
    /^BBl$/ && do {$word = ($channel =~ /[13]/) ? "10a4" : "98a4"; last SWITCH;};
    /^BBlS$/ && do {$word = ($channel =~ /[13]/) ? "1025" : "9825"; last SWITCH;};
    /^BCy$/ && do {$word = ($channel =~ /[13]/) ? "1026" : "9826"; last SWITCH;};
    /^BCyS$/ && do {$word = ($channel =~ /[13]/) ? "10a7" : "98a7"; last SWITCH;};
    /^BR$/ && do {$word = ($channel =~ /[13]/) ? "10a8" : "98a8"; last SWITCH;};
    /^BRS$/ && do {$word = ($channel =~ /[13]/) ? "1029" : "9829"; last SWITCH;};
    /^BY$/ && do {$word = ($channel =~ /[13]/) ? "102a" : "982a"; last SWITCH;};
    /^BYS$/ && do {$word = ($channel =~ /[13]/) ? "10ab" : "98ab"; last SWITCH;};
    /^BMa$/ && do {$word = ($channel =~ /[13]/) ? "102c" : "982c"; last SWITCH;};
    /^BMaS$/ && do {$word = ($channel =~ /[13]/) ? "10ad" : "98ad"; last SWITCH;};
    /^BBk$/ && do {$word = ($channel =~ /[13]/) ? "10ae" : "98ae"; last SWITCH;};
    /^BBkS$/ && do {$word = ($channel =~ /[13]/) ? "102f" : "982f"; last SWITCH;};
    /^BT$/ && do {$word = ($channel =~ /[13]/) ? "97ad" : "1fad"; last SWITCH;};
    /^RCL$/ && do {$word = ($channel =~ /[13]/) ? "9420" : "1c20"; $mode = "CC"; last SWITCH;};
    /^BS$/ && do {$word = ($channel =~ /[13]/) ? "94a1" : "1ca1"; last SWITCH;};
    /^AOF$/ && do {
      if ($channel == 1) { $word = "9423"; }
      if ($channel == 2) { $word = "1c23"; }
      if ($channel == 3) { $word = "1523"; }
      if ($channel == 4) { $word = "9d23"; }
      last SWITCH;
    };
    /^AON$/ && do {
      if ($channel == 1) { $word = "94a2"; }
      if ($channel == 2) { $word = "1ca2"; }
      if ($channel == 3) { $word = "15a2"; }
      if ($channel == 4) { $word = "9da2"; }
      last SWITCH;
    };
    /^DER$/ && do {
      if ($channel == 1) { $word = "94a4"; }
      if ($channel == 2) { $word = "1ca4"; }
      if ($channel == 3) { $word = "15a4"; }
      if ($channel == 4) { $word = "9da4"; }
      last SWITCH;
    };
    /^RU2$/ && do {
      if ($channel == 1) { $word = "9425"; }
      if ($channel == 2) { $word = "1c25"; }
      if ($channel == 3) { $word = "1525"; }
      if ($channel == 4) { $word = "9d25"; }
      last SWITCH;
    };
    /^RU3$/ && do {
      if ($channel == 1) { $word = "9426"; }
      if ($channel == 2) { $word = "1c26"; }
      if ($channel == 3) { $word = "1526"; }
      if ($channel == 4) { $word = "9d26"; }
      last SWITCH;
    };
    /^RU4$/ && do {
      if ($channel == 1) { $word = "94a7"; }
      if ($channel == 2) { $word = "1ca7"; }
      if ($channel == 3) { $word = "15a7"; }
      if ($channel == 4) { $word = "9da7"; }
      last SWITCH;
    };
    /^FON$/ && do {
      if ($channel == 1) { $word = "94a8"; }
      if ($channel == 2) { $word = "1ca8"; }
      if ($channel == 3) { $word = "15a8"; }
      if ($channel == 4) { $word = "9da8"; }
      last SWITCH;
    };
    /^RDC$/ && do {
      if ($channel == 1) { $word = "9429"; }
      if ($channel == 2) { $word = "1c29"; }
      if ($channel == 3) { $word = "1529"; }
      if ($channel == 4) { $word = "9d29"; }
      last SWITCH;
    };
    /^TR$/ && do {
      $mode = "Text";
      if ($channel == 1) { $word = "942a"; }
      if ($channel == 2) { $word = "1c2a"; $mode = "ITV"; }
      if ($channel == 3) { $word = "152a"; }
      if ($channel == 4) { $word = "9d2a"; }
      last SWITCH;
    };
    /^RTD$/ && do {
      $mode = "Text";
      if ($channel == 1) { $word = "94ab"; }
      if ($channel == 2) { $word = "1cab"; $mode = "ITV"; }
      if ($channel == 3) { $word = "15ab"; }
      if ($channel == 4) { $word = "9dab"; }
      last SWITCH;
    };
    /^EDM$/ && do {
      if ($channel == 1) { $word = "942c"; }
      if ($channel == 2) { $word = "1c2c"; }
      if ($channel == 3) { $word = "152c"; }
      if ($channel == 4) { $word = "9d2c"; }
      last SWITCH;
    };
    /^CR$/ && do {
      if ($channel == 1) { $word = "94ad"; }
      if ($channel == 2) { $word = "1cad"; }
      if ($channel == 3) { $word = "15ad"; }
      if ($channel == 4) { $word = "9dad"; }
      last SWITCH;
    };
    /^ENM$/ && do {
      if ($channel == 1) { $word = "94ae"; }
      if ($channel == 2) { $word = "1cae"; }
      if ($channel == 3) { $word = "15ae"; }
      if ($channel == 4) { $word = "9dae"; }
      last SWITCH;
    };
    /^EOC$/ && do {
      if ($channel == 1) { $word = "942f"; }
      if ($channel == 2) { $word = "1c2f"; }
      if ($channel == 3) { $word = "152f"; }
      if ($channel == 4) { $word = "9d2f"; }
      last SWITCH;
    };
    /^TO1$/ && do {$word = ($channel =~ /[13]/) ? "97a1" : "1fa1"; last SWITCH;};
    /^TO2$/ && do {$word = ($channel =~ /[13]/) ? "97a2" : "1fa2"; last SWITCH;};
    /^TO3$/ && do {$word = ($channel =~ /[13]/) ? "9723" : "1f23"; last SWITCH;};
    /^CSS$/ && do {$word = ($channel =~ /[13]/) ? "97a4" : "1fa4"; last SWITCH;};
    /^CSD$/ && do {$word = ($channel =~ /[13]/) ? "9725" : "1f25"; last SWITCH;};
    /^CS1$/ && do {$word = ($channel =~ /[13]/) ? "9726" : "1f26"; last SWITCH;};
    /^CS2$/ && do {$word = ($channel =~ /[13]/) ? "97a7" : "1fa7"; last SWITCH;};
    /^CSC$/ && do {$word = ($channel =~ /[13]/) ? "97a8" : "1fa8"; last SWITCH;};
    /^CSK$/ && do {$word = ($channel =~ /[13]/) ? "9729" : "1f29"; last SWITCH;};
    /^CGU$/ && do {$word = ($channel =~ /[13]/) ? "972a" : "1f2a"; last SWITCH;};
    /^\?\?$/ && do {die "Unknown command {??} in line $. of $input, stopped";};
    /^$/ && do {$word = "8080"; last SWITCH;};
  }
  if ($word eq "~") {
    die "Invalid command {".$command."} in line $. of $input, stopped";
  }
  return $word;
}

sub asXDS {
  my $line = shift(@_);
  my @xdslist = (-1) x 32; # up to 32 values, using -1 for no value
  my $position = 4; # first four characters are "XDS "
  my $counter = 2; # steps through position in @xdslist
  my $class = substr $line, $position, 2;
  my $typeDefined = 1; # flag for undefined type
  SWITCH: for ($class) {
    /Cs/ && do {$xdslist[0] = 0x01; last SWITCH;}; # Current start
    /Cc/ && do {$xdslist[0] = 0x02; last SWITCH;}; # Current continue
    /Fs/ && do {$xdslist[0] = 0x03; last SWITCH;}; # Future start         
    /Fc/ && do {$xdslist[0] = 0x04; last SWITCH;}; # Future continue
    /Hs/ && do {$xdslist[0] = 0x05; last SWITCH;}; # Channel start
    /Hc/ && do {$xdslist[0] = 0x06; last SWITCH;}; # Channel continue
    /Ms/ && do {$xdslist[0] = 0x07; last SWITCH;}; # Miscellaneous start
    /Mc/ && do {$xdslist[0] = 0x08; last SWITCH;}; # Miscellaneous continue
    /Ps/ && do {$xdslist[0] = 0x09; last SWITCH;}; # Public service start
    /Pc/ && do {$xdslist[0] = 0x0a; last SWITCH;}; # Public service continue
    # the remaining classes have no defined types
    /Rs/ && do {$xdslist[0] = 0x0b; $typeDefined = 0; last SWITCH;}; # Reserved start
    /Rc/ && do {$xdslist[0] = 0x0c; $typeDefined = 0; last SWITCH;}; # Reserved continue
    /Us/ && do {$xdslist[0] = 0x0d; $typeDefined = 0; last SWITCH;}; # Undefined start
    /Uc/ && do {$xdslist[0] = 0x0e; $typeDefined = 0; last SWITCH;}; # Undefined continue
    # if none of the above, then there was a typo
    die "Invalid class code ".$class.", stopped";
  }
  $position += 3;
  my $type = substr $line, $position, 2;
  $position += 3;
  if ($class =~ /.c$/) {
    $position += $XDSPosition{$type};
  }
  my %MonthCode = ( 'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 'May' => 5, 'Jun' => 6,
                    'Jul' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12 );
  my %LanguageCode = ( 'Unknown' => 0, 'English' => 1, 'Español' => 2, 'Français' => 3, 
                       'Deutsch' => 4, 'Italiano' => 5, 'Other' => 6, 'None' => 7,
                       'Espanol' => 2, 'Francais' => 3 );
  SWITCH: for (substr $class, 0, 1) {
    /[CF]/ && do {
      SWITCH2: for ($type) {
        /ST/ && do {                        # Start Time/Program ID
          $xdslist[1] = 0x01;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          if (($position == 10) and (length($line) - $XDSPosition{$type} > 15)) {
            my $hr = substr $line, 10 - $XDSPosition{$type}, 2;
            my $mi = substr $line, 13 - $XDSPosition{$type}, 2;
            my $d = substr $line, 15 - $XDSPosition{$type}, 1;
            # byte 2
            $xdslist[$counter++] = $mi + 64;
            # byte 3
            $xdslist[$counter] = $hr + 64;
            if ($d eq "D") {
              $xdslist[$counter] += 32;
            }
            $position = 17;
            $counter++;
          }
          if (($position == 17) and (length($line) - $XDSPosition{$type} > 26)) {
            my $mo = substr $line, 21 - $XDSPosition{$type}, 3;
            my $dy = substr $line, 25 - $XDSPosition{$type}, 2;
            my $z = substr $line, 17 - $XDSPosition{$type}, 1;
            my $t = substr $line, 18 - $XDSPosition{$type}, 1;
            my $l = substr $line, 19 - $XDSPosition{$type}, 1;
            # byte 4
            $xdslist[$counter] = $dy + 64;
            if ($l eq "L") {
              $xdslist[$counter] += 32;
            }
            $counter++;
            # byte 5
            $xdslist[$counter] = $MonthCode{$mo} + 64;
            if ($z eq "Z") {
              $xdslist[$counter] += 32;
            }
            if ($t eq "T") {
              $xdslist[$counter] += 16;
            }
            $counter++;
          }
          $position = 28;
          # checksum flag is byte 6, checksum is byte 7
          last SWITCH2;
        };
        /PL/ && do {                        # Program Length/Time in Show
          $xdslist[1] = 0x02;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my $hr;
          my $mi;
          if (($position == 10) and (length($line) - $XDSPosition{$type} > 14)) {
            # byte 2
            $hr = substr $line, 10 - $XDSPosition{$type}, 2;
            # byte 3
            $mi = substr $line, 13 - $XDSPosition{$type}, 2;
            $xdslist[$counter++] = $mi + 64;
            $xdslist[$counter++] = $hr + 64;
            $position = 16;
          }
          # remaining fields are optional up to checksum
          if (($position == 16) and (length($line) - $XDSPosition{$type} > 20)) {
            if (substr($line, 16 - $XDSPosition{$type}, 1) ne "\\") {
              $hr = substr $line, 16 - $XDSPosition{$type}, 2;
              $mi = substr $line, 19 - $XDSPosition{$type}, 2;
              # byte 4
              $xdslist[$counter++] = $mi + 64;
              # byte 5
              $xdslist[$counter++] = $hr + 64;
              $position = 22;
            }
          }
          # seconds are optional even when other optional fields are present
          if (($position == 22) and (length($line) - $XDSPosition{$type} > 23)) {
            if (substr($line, 22 - $XDSPosition{$type}, 1) ne "\\") {
              my $se = substr $line, 22 - $XDSPosition{$type}, 2;
              # byte 6
              $xdslist[$counter++] = $se + 64;
              # byte 7
              $xdslist[$counter++] = 64;
              $position = 25;
            }
          }
          last SWITCH2;
        };
        /PN/ && do {                        # Program Name
          $xdslist[1] = 0x03;
          while ((substr($line, $position - $XDSPosition{$type}, 1) ne "\\") and
             ($position - $XDSPosition{$type} < length($line))) {
            $xdslist[$counter++] = hex asChar(substr $line, $position - $XDSPosition{$type}, 1);
            $position++;
          }
          if (substr($line, $position - $XDSPosition{$type}, 1) eq "\\") {
            # need to back out last space
            $counter--;
          }
          last SWITCH2;
        };
        /PT/ && do {                        # Program Types
          $xdslist[1] = 0x04;
          my %ProgramCode = ('Education' => 0, 'Entertainment' => 1, 'Movie' => 2, 'News' => 3,
                             'Religious' => 4, 'Sports' => 5, 'Other' => 6, 'Action' => 7,
                             'Advertisement' => 8, 'Animated' => 9, 'Anthology' => 10, 'Automobile' => 11,
                             'Awards' => 12, 'Baseball' => 13, 'Basketball' => 14, 'Bulletin' => 15,
                             'Business' => 16, 'Classical' => 17, 'College' => 18, 'Combat' => 19,
                             'Comedy' => 20, 'Commentary' => 21, 'Concert' => 22, 'Consumer' => 23,
                             'Contemporary' => 24, 'Crime' => 25, 'Dance' => 26, 'Documentary' => 27,
                             'Drama' => 28, 'Elementary' => 29, 'Erotica' => 30, 'Exercise' => 31,
                             'Fantasy' => 32, 'Farm' => 33, 'Fashion' => 34, 'Fiction' => 35,
                             'Food' => 36, 'Football' => 37, 'Foreign' => 38, 'Fund-Raiser' => 39,
                             'Game/Quiz' => 40, 'Garden' => 41, 'Golf' => 42, 'Government' => 43,
                             'Health' => 44, 'High_School' => 45, 'History' => 46, 'Hobby' => 47,
                             'Hockey' => 48, 'Home' => 49, 'Horror' => 50, 'Information' => 51,
                             'Instruction' => 52, 'International' => 53, 'Interview' => 54, 'Language' => 55,
                             'Legal' => 56, 'Live' => 57, 'Local' => 58, 'Math' => 59,
                             'Medical' => 60, 'Meeting' => 61, 'Military' => 62, 'Mini-Series' => 63,
                             'Music' => 64, 'Mystery' => 65, 'National' => 66, 'Nature' => 67,
                             'Police' => 68, 'Politics' => 69, 'Premiere' => 70, 'Pre-Recorded' => 71,
                             'Product' => 72, 'Professional' => 73, 'Public' => 74, 'Racing' => 75,
                             'Reading' => 76, 'Repair' => 77, 'Repeat' => 78, 'Review' => 79,
                             'Romance' => 80, 'Science' => 81, 'Series' => 82, 'Service' => 83,
                             'Shopping' => 84, 'Soap_Opera' => 85, 'Special' => 86, 'Suspense' => 87,
                             'Talk' => 88, 'Technical' => 89, 'Tennis' => 90, 'Travel' => 91,
                             'Variety' => 92, 'Video' => 93, 'Weather' => 94, 'Western' =>  95);
          my @keywordList = split(/ /, substr($line, $position));
          foreach my $keyword (@keywordList) {
            if (substr($keyword, 0, 1) ne "\\") {
              $xdslist[$counter++] = $ProgramCode{$keyword} + 32;
              $position += length($keyword) + 1;
            }
          }
          last SWITCH2;
        };
        /PR/ && do {                        # Program Rating
          $xdslist[1] = 0x05;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my @elements = split(/ /, substr($line, $position));
          my %RatingCode = ();
          SWITCH3: for ($elements[0]) { # Rating System:
            /MPAA/ && do {              #  Motion Picture Association of America
              %RatingCode = ('G' => 1, 'PG' => 2, 'PG-13' => 3, 'R' => 4,
                             'NC-17' => 5, 'X' => 6, 'NR' => 7);
              # byte 2
              $xdslist[$counter++] = $RatingCode{$elements[1]} + 64;
              # byte 3
              $xdslist[$counter++] = 64 + 0; # 0 for MPAA system
              last SWITCH3;
            };
            /TPG/ && do {               #  Television Parental Guidelines
              # byte 2
              $xdslist[$counter] = 64 + 8; # 8 for TPG system
              # TPG has the following additional advisories:
              if (substr ($elements[2], 0, 1) eq 'D') { # sexually-suggestive dialog
                $xdslist[$counter] += 32;
              }
              $counter++;
              %RatingCode = ('None' => 0, 'TV-Y' => 1, 'TV-Y7' => 2, 'TV-G' => 3,
                             'TV-PG' => 4, 'TV-14' => 5, 'TV-MA' => 6);
              # byte 3
              $xdslist[$counter] = $RatingCode{$elements[1]} + 64;
              if (substr ($elements[2], 1, 1) eq 'L') { # coarse language
                $xdslist[$counter] += 8;
              }
              if (substr ($elements[2], 2, 1) eq 'S') { # sexual situations
                $xdslist[$counter] += 16;
              }
              if (substr ($elements[2], 3, 1) eq 'V') { # violent content (fantasy violence for TV-Y)
                $xdslist[$counter] += 32;
              }
              $counter++;
              last SWITCH3;
            };
            /CE/ && do {                #  Canada English
              # byte 2
              $xdslist[$counter++] = 64 + 24; # 24 for CE system
              %RatingCode = ('E' => 0, 'C' => 1, 'C8+' => 2,
                             'G' => 3, 'PG' => 4, '14+' => 5, '18+' => 6);
              # byte 3
              $xdslist[$counter++] = $RatingCode{$elements[1]} + 64;
              last SWITCH3;
            };
            /CF/ && do {                #  Canada Français
              # byte 2
              $xdslist[$counter++] = 64 + 52; # 52 for CF system
              %RatingCode = ('E' => 0, 'G' => 1, '8+' => 2,
                             '13+' => 3, '16+' => 4, '18+' => 5);
              # byte 3
              $xdslist[$counter++] = $RatingCode{$elements[1]} + 64;
              last SWITCH3;
            };
          }
          foreach my $element (@elements)  {
            if (substr($element, 0, 1) ne "\\") {
              $position += length($element) + 1;
            }
          }
          last SWITCH2;
        };
        /AS/ && do {                        # Audio Streams Available
          $xdslist[1] = 0x06;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my @elements = split(/ /, substr($line, $position));
          my $element = "";
          my $elementCounter = 0;
          my %StreamCode = ();
          if ($position == 10) {
            %StreamCode = ('Unknown' => 0, 'Mono' => 1, 'Simulated' => 2, 'Stereo' => 3,
                           'Surround' => 4, 'Data' => 5, 'Other' => 6, 'None' => 7);
            # primary audio stream
            # byte 2
            $element = $elements[$elementCounter++];
            $xdslist[$counter] = $StreamCode{$element} + 64;
            $position += length($element) + 1;
            # byte 3
            $element = $elements[$elementCounter++];
            $xdslist[$counter++] += $LanguageCode{$element} * 8;
            $position += length($element) + 1;
          }
          if (($position > 10) and (substr($line, $position, 0) ne "\\")) {
            %StreamCode = ('Unknown' => 0, 'Mono' => 1, 'DAS' => 2, 'Non-Program' => 3,
                           'FX' => 4, 'Data' => 5, 'Other' => 6, 'None' => 7);
            # byte 4
            $element = $elements[$elementCounter++];
            $xdslist[$counter] = $StreamCode{$element} + 64;
            $position += length($element) + 1;
            # byte 5
            $element = $elements[$elementCounter++];
            $xdslist[$counter++] += $LanguageCode{$element} * 8;
            $position += length($element) + 1;
          }
          last SWITCH2;
        };
        /CS/ && do {                        # Caption Streams Available
          $xdslist[1] = 0x07;
          my @elements = split(/ /, substr($line, $position));
          push @elements, ("\\");
          my $elementCounter = 0;
          my $element = "";
          my %StreamCode = ('CC1' => 0, 'T1' => 1, 'CC2' => 2, 'T2' => 3,
                            'CC3' => 4, 'T3' => 5, 'CC4' => 6, 'T4' => 7);
          while (substr($elements[$elementCounter], 0, 1) ne "\\") {
            $element = $elements[$elementCounter++];
            $xdslist[$counter] = $StreamCode{$element} + 64;
            $position += length($element) + 1;
            $element = $elements[$elementCounter++];
            $xdslist[$counter++] += $LanguageCode{$element} * 8;
            $position += length($element) + 1;
          }
          last SWITCH2;
        };
        /CG/ && do {                        # Copy Generation Management System
          $xdslist[1] = 0x08;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          if ($position == 10) {
            my $dataformat = substr $line, 10, 1; # format is digital ("D") or analog ("A")
            my $sgms = substr $line, 11, 1;       # can copy unlimited times ("U"), never ("0"),
                                                  #  or only once ("1")
            my $mv = substr $line, 12, 1;         # no Macrovision or Colorstripe ("N"), Macrovision only ("M"),
                                                  #  Macrovision and 2-line Colorstripe ("2"), or
                                                  #  Macrovision and 4-line Colorstripe ("4")
            # byte 2
            $xdslist[$counter] = 64;
            if ($dataformat eq 'A') {
              $xdslist[$counter]++;
            }
            if ($mv eq 'M') {
              $xdslist[$counter] += 2;
            }
            if ($mv eq '2') {
              $xdslist[$counter] += 4;
            }
            if ($mv eq '3') {
              $xdslist[$counter] += 6;
            }
            if ($sgms eq '1') {
              $xdslist[$counter] += 16;
            }
            if ($sgms eq '0') {
              $xdslist[$counter] += 24;
            }
            $counter++;
            $xdslist[$counter++] = 64;      # filler
            $position = 14;
          }
          last SWITCH2;
        };
        /AR/ && do {                        # Aspect Ratio
          $xdslist[1] = 0x09;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my @elements = split(/ /, substr($line, $position));
          push @elements, ("\\");
          my $elementCounter = 0;
          my $element = "";
          if ($position == 10) {
            $element = $elements[$elementCounter++];
            # number of scanlines between top of visible screen
            #  and top of active video area
            # byte 2
            $xdslist[$counter++] = $element + 64; 
            $position += length($element) + 1;
            $element = $elements[$elementCounter++];
            # number of scanlines between bottom of active video area
            #  and bottom of visible screen
            # byte 3
            $xdslist[$counter++] = $element + 64; 
            $position += length($element) + 1;
          }
          # optional ratio argument (either "_" for 4:3 or "A" for 16:9)
          if ($position > 10) {
            $element = $elements[$elementCounter];
            if (substr($element, 0, 1) ne "\\") {
              # byte 4
              $xdslist[$counter] = 64;
              if ($element eq "A") {
                $xdslist[$counter]++;
              }
              $counter++;
              $xdslist[$counter++] = 64;    # filler
              $position += 2;
            }
          }
          last SWITCH2;
        };
        /PD/ && do {                        # Program Data (composite of PT, PR, PL, & PN)
          $xdslist[1] = 0x0c;
          # for the complex types, I need to redefine $position to be
          #   the elements array counter
          if ($position > 20) {
            $position -= 10;
          }
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my @elements = split(/ /, substr($line, 10));
          push @elements, ("\\");
          my $elementCounter = 0;
          if (($position >= 10) and ($position <= 14)) {
            # Program Types
            my %ProgramCode = ('Education' => 0, 'Entertainment' => 1, 'Movie' => 2, 'News' => 3,
                               'Religious' => 4, 'Sports' => 5, 'Other' => 6, 'Action' => 7,
                               'Advertisement' => 8, 'Animated' => 9, 'Anthology' => 10, 'Automobile' => 11,
                               'Awards' => 12, 'Baseball' => 13, 'Basketball' => 14, 'Bulletin' => 15,
                               'Business' => 16, 'Classical' => 17, 'College' => 18, 'Combat' => 19,
                               'Comedy' => 20, 'Commentary' => 21, 'Concert' => 22, 'Consumer' => 23,
                               'Contemporary' => 24, 'Crime' => 25, 'Dance' => 26, 'Documentary' => 27,
                               'Drama' => 28, 'Elementary' => 29, 'Erotica' => 30, 'Exercise' => 31,
                               'Fantasy' => 32, 'Farm' => 33, 'Fashion' => 34, 'Fiction' => 35,
                               'Food' => 36, 'Football' => 37, 'Foreign' => 38, 'Fund-Raiser' => 39,
                               'Game/Quiz' => 40, 'Garden' => 41, 'Golf' => 42, 'Government' => 43,
                               'Health' => 44, 'High_School' => 45, 'History' => 46, 'Hobby' => 47,
                               'Hockey' => 48, 'Home' => 49, 'Horror' => 50, 'Information' => 51,
                               'Instruction' => 52, 'International' => 53, 'Interview' => 54, 'Language' => 55,
                               'Legal' => 56, 'Live' => 57, 'Local' => 58, 'Math' => 59,
                               'Medical' => 60, 'Meeting' => 61, 'Military' => 62, 'Mini-Series' => 63,
                               'Music' => 64, 'Mystery' => 65, 'National' => 66, 'Nature' => 67,
                               'Police' => 68, 'Politics' => 69, 'Premiere' => 70, 'Pre-Recorded' => 71,
                               'Product' => 72, 'Professional' => 73, 'Public' => 74, 'Racing' => 75,
                               'Reading' => 76, 'Repair' => 77, 'Repeat' => 78, 'Review' => 79,
                               'Romance' => 80, 'Science' => 81, 'Series' => 82, 'Service' => 83,
                               'Shopping' => 84, 'Soap_Opera' => 85, 'Special' => 86, 'Suspense' => 87,
                               'Talk' => 88, 'Technical' => 89, 'Tennis' => 90, 'Travel' => 91,
                               'Variety' => 92, 'Video' => 93, 'Weather' => 94, 'Western' =>  95);
            while (($position < 15) and ($elementCounter < scalar(@elements) - 1)) {
              # bytes 2 - 6
              $xdslist[$counter++] = $ProgramCode{$elements[$elementCounter++]} + 32;
              $position++;
            }
          }
          if (($position == 15) and ($elementCounter < scalar(@elements) - 1)) {
            # Program Rating (MPAA)
            my %RatingCode = ('G' => 1, 'PG' => 2, 'PG-13' => 3, 'R' => 4,
                              'NC-17' => 5, 'X' => 6, 'NR' => 7);
            # byte 7
            $xdslist[$counter++] = $RatingCode{$elements[$elementCounter++]} + 64;
            $position++;
          }
          my @timeElements = ();
          if (($position == 16) and ($elementCounter < scalar(@elements) - 1)) {
            # Program Length
            @timeElements = split(/:/, $elements[$elementCounter++]);
            $xdslist[$counter++] = $timeElements[1] + 64;
            $xdslist[$counter++] = $timeElements[0] + 64;
            $position++;
          }
          if (($position == 17) and ($elementCounter < scalar(@elements) - 1)) {
            # optional Time Elapsed
            if (substr($elements[$elementCounter], 2, 1) eq ":") {
              @timeElements = split(/:/, $elements[$elementCounter++]);
              $xdslist[$counter++] = $timeElements[1] + 64;
              $xdslist[$counter++] = $timeElements[0] + 64;
            }
            $position++;
          }
          if (($position == 18) and ($elementCounter < scalar(@elements) - 1)) {
            # Program Name
            my @characters;
            my $char;
            while (substr($elements[$elementCounter], 0, 1) ne "\\") {
              @characters = split(//, $elements[$elementCounter++]);
              foreach $char (@characters) {
                $xdslist[$counter++] = hex asChar($char);
              }
              $xdslist[$counter++] = hex asChar(' ');
            }
            if (substr($elements[$elementCounter], 0, 1) eq "\\") {
              # need to back out last space
              $counter--;
              # finally able to get $position back to normal
              $XDSPosition{$type} = 9;
              $position = length($line) - 4 + $XDSPosition{$type};
            }
          }
          last SWITCH2;
        };
        /MD/ && do {                        # Miscellaneous Data (composite of ST, AS, CS, & NC)
          # Start Time/Program ID
          $xdslist[1] = 0x0d;
          # for the complex types, I need to redefine $position to be
          #   the elements array counter
          if ($position > 20) {
            $position -= 10;
          }
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my @elements = split(/ /, substr($line, 10));
          push @elements, ("\\");
          my $elementCounter = 0;
          if ($position == 10) {
            # start time
            my @timecodeElements = split(/:/, $elements[$elementCounter++]);
            my $hr = $timecodeElements[0];
            my $mi = $timecodeElements[1];
            # byte 2
            $xdslist[$counter++] = $mi + 64;
            # byte 3
            $xdslist[$counter++] = $hr + 64;
            $position = 11;
          }
          if (($position == 11) and ($elementCounter < scalar(@elements) - 1)) {
            # Delay
            my $t = $elements[$elementCounter++];
            # Start Date
            my $mo = $elements[$elementCounter++];
            my $dy = $elements[$elementCounter++];
            # byte 4
            $xdslist[$counter++] = $dy + 64;
            # byte 5
            $xdslist[$counter] = $MonthCode{$mo} + 64;
            if ($t eq "T") {
              $xdslist[$counter] += 16;
            }
            $counter++;
            $position = 12;
          }
          my %StreamCode = ();
          if (($position == 12) and ($elementCounter < scalar(@elements) - 1)) {
            # Audio Streams
            %StreamCode = ('Unknown' => 0, 'Mono' => 1, 'Simulated' => 2, 'Stereo' => 3,
                           'Surround' => 4, 'Data' => 5, 'Other' => 6, 'None' => 7);
            # primary audio stream
            # byte 6
            $xdslist[$counter] = $StreamCode{$elements[$elementCounter++]} + 64; 
            $xdslist[$counter++] += $LanguageCode{$elements[$elementCounter++]} * 8;
            %StreamCode = ('Unknown' => 0, 'Mono' => 1, 'DAS' => 2, 'Non-Program' => 3,
                           'FX' => 4, 'Data' => 5, 'Other' => 6, 'None' => 7);
            # secondary audio stream
            # byte 7
            $xdslist[$counter] = $StreamCode{$elements[$elementCounter++]} + 64; 
            $xdslist[$counter++] += $LanguageCode{$elements[$elementCounter++]} * 8;
            $position = 13;
          }
          # Caption Streams
          if (($position == 13) and ($elementCounter < scalar(@elements) - 1)) {
            %StreamCode = ('CC1' => 0, 'T1' => 1, 'CC2' => 2, 'T2' => 3,
                           'CC3' => 4, 'T3' => 5, 'CC4' => 6, 'T4' => 7);
            # byte 8
            $xdslist[$counter] = $StreamCode{$elements[$elementCounter++]} + 64; 
            $xdslist[$counter++] += $LanguageCode{$elements[$elementCounter++]} * 8;
            # byte 9
            $xdslist[$counter] = $StreamCode{$elements[$elementCounter++]} + 64; 
            $xdslist[$counter++] += $LanguageCode{$elements[$elementCounter++]} * 8;
            $position = 14;
          }
          # Network Call Letters
          my @characters;
          if (($position > 13) and ($elementCounter < scalar(@elements) - 1)) {
            while (substr($elements[$elementCounter], 0, 1) ne "\\") {
              @characters = split(//, $elements[$elementCounter++]);
              foreach my $character (@characters) {
                if ($character eq '_') {
                  $character = ' ';
                }
                $xdslist[$counter++] = hex asChar($character);
              }
            }
            if (substr($elements[$elementCounter], 0, 1) eq "\\") {
              # finally able to get $position back to normal
              $XDSPosition{$type} = 9;
              $position = length($line) - 4 + $XDSPosition{$type};
            }
          }
          last SWITCH2;
        };
        /D1/ && do {                        # Program Description Line 1
          $xdslist[1] = 0x10;
        };
        /D2/ && do {                        # Program Description Line 2
          $xdslist[1] = 0x11;
        };
        /D3/ && do {                        # Program Description Line 3
          $xdslist[1] = 0x12;
        };
        /D4/ && do {                        # Program Description Line 4
          $xdslist[1] = 0x13;
        };
        /D5/ && do {                        # Program Description Line 5
          $xdslist[1] = 0x14;
        };
        /D6/ && do {                        # Program Description Line 6
          $xdslist[1] = 0x15;
        };
        /D7/ && do {                        # Program Description Line 7
          $xdslist[1] = 0x16;
        };
        /D8/ && do {                        # Program Description Line 8
          $xdslist[1] = 0x17;
        };
        /D[1-8]/ && do {                    # Program Description
          while ((substr($line, $position - $XDSPosition{$type}, 1) ne "\\") and
             ($position - $XDSPosition{$type} < length($line))) {
            $xdslist[$counter++] = hex asChar(substr $line, $position - $XDSPosition{$type}, 1);
            $position++;
          }
          if (substr($line, $position - $XDSPosition{$type}, 1) eq "\\") {
            # need to back out last space
            $counter--;
          }
          last SWITCH2;
        };
        # if you got here, then this is an undefined Current/Future type
        $typeDefined = 0;
      }
      last SWITCH;
    };
    /H/ && do {
      SWITCH2: for ($type) {
        /NN/ && do {                        # Network Name
          $xdslist[1] = 0x01;
          while ((substr($line, $position - $XDSPosition{$type}, 1) ne "\\") and
             ($position - $XDSPosition{$type} < length($line))) {
            $xdslist[$counter++] = hex asChar(substr $line, $position - $XDSPosition{$type}, 1);
            $position++;
          }
          if (substr($line, $position - $XDSPosition{$type}, 1) eq "\\") {
            # need to back out last space
            $counter--;
          }
          last SWITCH2;
        };
        /NC/ && do {                        # Network Call Letters
          $xdslist[1] = 0x02;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          # Call Letters
          if ($position == 10) {
            # byte 2
            $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
            # byte 3
            $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
          }
          if (($position == 12) and ($position < length($line))) {
            # byte 4
            $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
            # byte 5
            $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
            $position += 1;
          }
          # optional Channel Number
          if (($position == 15) and ($position < length($line))) {
            if (substr($line, $position, 1) ne "\\") {
              # byte 6
              $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
              # byte 7
              $xdslist[$counter++] = hex asChar(substr $line, $position++, 1);
              $position += 1;
            }
            
          }
          last SWITCH2;
        };
        /TD/ && do {                        # Channel Tape Delay
          $xdslist[1] = 0x03;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          if ($position == 10) {
            my $hr = substr $line, 10, 2;
            my $mi = substr $line, 13, 2;
            # byte 2
            $xdslist[$counter++] = $mi + 64;
            # byte 3
            $xdslist[$counter++] = $hr + 64;
            $position = 16;
          }
          last SWITCH2;
        };
        /TS/ && do {                        # Transmission Signal Identifier
          $xdslist[1] = 0x04;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          # digits are output in reverse order
          # this gets tricky, as the value could be split between packets
          my $digit;
          if ($position == 10) {
            $digit = substr $line, 13, 1;
            if ($digit ne "_") {
              # byte 2
              $xdslist[$counter++] = hex($digit) + 64;
            }
            $digit = substr $line, 12, 1;
            if ($digit ne "_") {
              # byte 3
              $xdslist[$counter++] = hex($digit) + 64;
            }
            $digit = substr $line, 11, 1;
            if ($digit ne "_") {
              # byte 4
              $xdslist[$counter++] = hex($digit) + 64;
            }
            $digit = substr $line, 10, 1;
            if ($digit ne "_") {
              # byte 5
              $xdslist[$counter++] = hex($digit) + 64;
              $position = 15;
            }
          }
          last SWITCH2;
        };
        # if you got here, then this is an undefined cHannel type
        $typeDefined = 0;
      }
      last SWITCH;
    };
    /M/ && do {
      SWITCH2: for ($type) {
        /TM/ && do {                        # Time of Day
          $xdslist[1] = 0x01;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          if ($position == 10) {
            # time
            my $hr = substr $line, 10, 2;
            my $mi = substr $line, 13, 2;
            # daylight savings time ("D") or standard time ("S")
            my $d = substr $line, 15, 1; 
            # byte 2
            $xdslist[$counter++] = $mi + 64;
            # byte 3
            $xdslist[$counter] = $hr + 64;
            # flags
            if ($d eq 'D') {
              $xdslist[$counter] += 32;
            }
            $counter++;
            $position = 17;
          }
          if (($position == 17) and ($position < length($line))) {
            my $z = substr $line, 17, 1;
            my $t = substr $line, 18, 1; # tape is delayed ("T") or simulcast ("S")
            my $l = substr $line, 19, 1; # this is February 29th ("L"eap day) or not ("A")
            # date
            my $mo = substr $line, 21, 3;
            my $dy = substr $line, 25, 2;
            # byte 4
            $xdslist[$counter] = $dy + 64;
            if ($l eq 'L') {
              $xdslist[$counter] += 32;
            }
            $counter++;
            # byte 5
            $xdslist[$counter] = $MonthCode{$mo} + 64;
            if ($z eq 'Z') {
              $xdslist[$counter] += 32;
            }
            if ($t eq 'T') {
              $xdslist[$counter] += 16;
            }
            $counter++;
            $position = 28;
          }
          if (($position == 28) and ($position < length($line))) {
            my $yr = substr $line, 28, 4;
            my %WeekdayCode = ('Sun' => 1, 'Mon' => 2, 'Tue' => 3, 'Wed' => 4,
                               'Thu' => 5, 'Fri' => 6, 'Sat' => 7);
            # byte 6
            $xdslist[$counter++] = $WeekdayCode{substr $line, 33, 3} + 64;
            # byte 7
            # year stored is offset from 1990
            $xdslist[$counter++] = $yr - 1990 + 64;  
            $position = 37;
          }
          last SWITCH2;
        };
        /IC/ && do {                        # Impulse Capture ID
          $xdslist[1] = 0x02;
          if (substr($line, 10, 1) eq "\\") {
            last SWITCH2;
          }
          my $hr;
          my $mi;
          if ($position == 10) {
            # time
            $hr = substr $line, 10, 2;
            $mi = substr $line, 13, 2;
            # daylight savings time ("D") or standard time ("S")
            my $d = substr $line, 15, 1; 
            # byte 2
            $xdslist[$counter++] = $mi + 64;
            # byte 3
            $xdslist[$counter] = $hr + 64;
            # flags
            if ($d eq 'D') {
              $xdslist[$counter] += 32;
            }
            $counter++;
            $position = 17;
          }
          if (($position == 17) and ($position < length($line))) {
            my $z = substr $line, 17, 1;
            my $t = substr $line, 18, 1; # tape is delayed ("T") or simulcast ("S")
            my $l = substr $line, 19, 1; # this is February 29th ("L"eap day) or not ("A")
            # date
            my $mo = substr $line, 21, 3;
            my $dy = substr $line, 25, 2;
            # byte 4
            $xdslist[$counter] = $dy + 64;
            if ($l eq 'L') {
              $xdslist[$counter] += 32;
            }
            $counter++;
            # byte 5
            $xdslist[$counter] = $MonthCode{$mo} + 64;
            if ($z eq 'Z') {
              $xdslist[$counter] += 32;
            }
            if ($t eq 'T') {
              $xdslist[$counter] += 16;
            }
            $counter++;
            $position = 28;
          }
          if (($position == 28) and ($position < length($line))) {
            # program length
            $hr = substr $line, 28, 2;
            $mi = substr $line, 31, 2;
            # byte 6
            $xdslist[$counter++] = $mi + 64;
            # byte 7
            $xdslist[$counter++] = $hr + 64; 
            $position = 34;
          }
          last SWITCH2;
        };
        /SD/ && do {                        # Supplemental Data Location
          $xdslist[1] = 0x03;
          my @elements = split(/ /, substr($line, $position));
          push @elements, ("\\");
          my $location;
          foreach $location (@elements) {
            if (substr($location, 0, 1) ne "\\") {
              # scanline, from 10 to 20
              $xdslist[$counter] = (substr $location, 0, 2) + 64; 
              # field can be 1 or 2
              if (substr($location, 3, 1) == 2) { 
                $xdslist[$counter] += 32;
              }
              $counter++;
              $position += 5;
            }
          }
          last SWITCH2;
        };
        /TZ/ && do {                        # Local Time Zone
          $xdslist[1] = 0x04;
          if ($position == 10) {
            # hours broadcast is off from UTC in London
            my $tz = substr $line, 10, 3; 
            # byte 2
            $xdslist[$counter] = $tz + 24 + 64;
            my $d = substr $line, 13, 1; # daylight savings time ("D") or standard time ("S")
            if ($d eq 'D') {
              $xdslist[$counter] += 32;
            }
            $counter++;
            # byte 3 is filler
            $xdslist[$counter++] = 64;
            $position = 15;
          }
          last SWITCH2;
        };
        /OB/ && do {                        # Out of Band Channel
          $xdslist[1] = 0x40;
          if ($position == 10) {
            # channel is stored as high and low bytes
            my $channel = substr $line, 10, 4; 
            my $hi = sprintf("%d", $channel / 64); 
            my $lo = $channel % 64;
            # byte 2
            $xdslist[$counter++] = $lo + 64;
            # byte 3
            $xdslist[$counter++] = $hi + 64;
            $position = 15;
          }
          last SWITCH2;
        };
        /CP/ && do {                        # Channel Map Pointer
          $xdslist[1] = 0x41;
          if ($position == 10) {
            # channel is stored as high and low bytes
            my $channel = substr $line, 10, 4; 
            my $hi = sprintf("%d", $channel / 64); 
            my $lo = $channel % 64;
            # byte 2
            $xdslist[$counter++] = $lo + 64;
            # byte 3
            $xdslist[$counter++] = $hi + 64;
            $position = 15;
          }
          last SWITCH2;
        };
        /CH/ && do {                        # Channel Map Header
          $xdslist[1] = 0x42;
          my $hi, $lo;
          if ($position == 10) {
            # channel is stored as high and low bytes
            my $channel = substr $line, 10, 4; 
            $hi = sprintf("%d", $channel / 64); 
            $lo = $channel % 64;
            # byte 2
            $xdslist[$counter++] = $lo + 64;
            # byte 3
            $xdslist[$counter++] = $hi + 64;
            $position = 15;
          }
          # version
          if (($position == 15) and ($position - $XDSPosition{$type} < length($line))) {
            if (substr($line, $position - $XDSPosition{$type}, 1) eq "v") {
              $position++;
              my $version = substr($line, $position - $XDSPosition{$type}, 2);
              # byte 4
              $xdslist[$counter++] = $version + 64;
              # byte 5 is filler
              $xdslist[$counter++] = 64;
              $position += 3;
            }
          }
          last SWITCH2;
        };
        /CM/ && do {                        # Channel Map
          $xdslist[1] = 0x43;
          # since this type has lots of optional elements,
          #  $XDSPosition{$type} will be used to count fields
          if ($position > 20) {
            $position -= 10;
          }
          my @elements = split(/ /, substr($line, 10));
          push @elements, ("\\");
          my $element;
          my $elementCounter = 0;
          if ($position == 10) {
            # user channel/tune channel
            my $channel = $elements[$elementCounter++];
            my $userChannel = "";
            my $tuneChannel = "";
            my $hi, $lo;
            my $remappedFactor = 0;
            # optional remapping and tune channel
            if ($channel =~ /=/) {
              ($userChannel, $tuneChannel) = split(/=/, $channel);
              $remappedFactor = 32;
            } else {
              if ($elementCounter >= scalar(@elements)) {
                $userChannel = $channel; 
              } else {
                $tuneChannel = $channel;
              }
            }
            if ($userChannel ne "") {
              $hi = sprintf("%d", $userChannel / 64);
              $lo = $userChannel % 64;
              # byte 2 (or maybe 4)
              $xdslist[$counter++] = $lo + 64;
              # byte 3 (or maybe 5)
              $xdslist[$counter++] = $hi + 64 + $remappedFactor;
            }
            if ($tuneChannel ne "") {
              $hi = sprintf("%d", $tuneChannel / 64);
              $lo = $tuneChannel % 64;
              # byte 4
              $xdslist[$counter++] = $lo + 64;
              # byte 5
              $xdslist[$counter++] = $hi + 64;
              $position = 11;
            }
          }
          if (($position == 11) and ($elementCounter < scalar(@elements) - 1)) {
            if (substr($elements[$elementCounter], 0, 1) ne "\\") {
              my @channelID = split(//, $elements[$elementCounter++]);
              foreach my $character (@channelID) {
                $xdslist[$counter++] = hex asChar($character);
              }
              $position = 12;
            }
            # time to fix position
            $XDSPosition{$type} = 9;
            $position = length($line) - 4 + $XDSPosition{$type};
          }
          last SWITCH2;
        };
        # if you got here, then this is an undefined Miscellaneous type
        $typeDefined = 0;
      }
      last SWITCH;
    };
    /P/ && do {
      SWITCH2: for ($type) {
        /WB/ && do {                        # Weather Service Bulletin
          $xdslist[1] = 0x01;
          # most of this type converts as characters:
          # bytes 2 - 4: Event Category
          # bytes 5 - 7: State FIPS
          # bytes 8 - 10: County FIPS
          my @elements = split(/ /, substr($line, 10));
          foreach my $element (@elements) {
            if ($position < 22) {
              my @characters = split(//, $element);
              foreach my $character (@characters) {
                $xdslist[$counter++] = hex asChar($character);
                $position++;
              }
              $position++;
            } else {
              if (substr($element, 0, 1) ne "\\") { 
                # duration
                my $hr = substr($element, 0, 2);
                my $mi = substr($element, 3, 2);
                my $quarterHours = sprintf("%d", $mi / 15);
                $quarterHours += $hr * 4;
                # adding 48 converts digit into digit character
                # byte 11
                $xdslist[$counter++] = sprintf("%d", $quarterHours / 10) + 48;
                # byte 12
                $xdslist[$counter++] = ($quarterHours % 10) + 48;
                $position = 28;
              }
            }
          }
          last SWITCH2;
        };
        /WM/ && do {                          # Weather Service Message
          $xdslist[1] = 0x02;
          while ((substr($line, $position - $XDSPosition{$type}, 1) ne "\\") and
             ($position - $XDSPosition{$type} < length($line))) {
            $xdslist[$counter++] = hex asChar(substr $line, $position - $XDSPosition{$type}, 1);
            $position++;
          }
          if (substr($line, $position - $XDSPosition{$type}, 1) eq "\\") {
            # need to back out last space
            $counter--;
          }
          last SWITCH2;
        };
        # if you got here, then this is an undefined Public type
        $typeDefined = 0;
      };
      last SWITCH;
    };
  }
  # undefined types just have space-delimited hex data
  if ($typeDefined == 0) {
    $counter = 1;
    for ($position = 7; $position < (length ($line) - 4); $position += 3) {
      $xdslist[$counter++] = hex (substr $line, $position, 2);
    }
  }
  # at this point, @xdslist contains all the values to output and $counter is the next @xdslist index
  if ($counter % 2 == 1) {
    $xdslist[$counter++] = 64;  # filler byte
  }
  my $sum;
  if (substr($class, 1, 1) eq "s") {
    $sum = $xdslist[0] + $xdslist[1];
  } else {
    $sum = $XDSSum{$type};
  }
  for (my $i = 2; $i < $counter; $i++) {
    $sum += $xdslist[$i];
  }
  if (substr($line, $position - $XDSPosition{$type}, 1) eq "\\") {
    # 15 is the code to indicate the checksum is next
    $xdslist[$counter++] = 15;
    $sum += 15;
    # calculate checksum, the value necessary
    #  to make the sum evenly-divisible by 128
    $xdslist[$counter++] = 128 - ($sum % 128); 
    $XDSPosition{$type} = 0;
    $XDSSum{$type} = 0;
  } else {
    $XDSPosition{$type} = $position;
    $XDSSum{$type} = $sum;
  }
  # now to convert this list into a string of odd-parity hexidecimal pairs
  my $xdsOut = '';
  for (my $i = 0; $i < $counter; $i+= 2) {
    # print $xdslist[$i]." ".$xdslist[$i+1]." ";
    $xdsOut = $xdsOut.sprintf(" %02x%02x", oddParity($xdslist[$i]), oddParity($xdslist[$i+1]));
  }
  # print "\n";
  return (substr $xdsOut, 1, 90);
}

sub asChar {
  my $char = shift(@_);
  my $byte = "~"; # placeholder for failed match
  SWITCH: for ($char) {
    /_/ && do {$byte = "00"; last SWITCH;};
    / / && do {$byte = "20"; last SWITCH;};
    /\!/ && do {$byte = "21"; last SWITCH;};
    /\"/ && do {$byte = "22"; last SWITCH;};
    /\#/ && do {$byte = "23"; last SWITCH;};
    /\$/ && do {$byte = "24"; last SWITCH;};
    /%/ && do {$byte = "25"; last SWITCH;};
    /&/ && do {$byte = "26"; last SWITCH;};
    /\'/ && do {$byte = "27"; last SWITCH;};
    /\(/ && do {$byte = "28"; last SWITCH;};
    /\)/ && do {$byte = "29"; last SWITCH;};
    /[á\*]/ && do {$byte = "2a"; last SWITCH;};
    /\+/ && do {$byte = "2b"; last SWITCH;};
    /\,/ && do {$byte = "2c"; last SWITCH;};
    /\-/ && do {$byte = "2d"; last SWITCH;};
    /\./ && do {$byte = "2e"; last SWITCH;};
    /\// && do {$byte = "2f"; last SWITCH;};
    /0/ && do {$byte = "30"; last SWITCH;};
    /1/ && do {$byte = "31"; last SWITCH;};
    /2/ && do {$byte = "32"; last SWITCH;};
    /3/ && do {$byte = "33"; last SWITCH;};
    /4/ && do {$byte = "34"; last SWITCH;};
    /5/ && do {$byte = "35"; last SWITCH;};
    /6/ && do {$byte = "36"; last SWITCH;};
    /7/ && do {$byte = "37"; last SWITCH;};
    /8/ && do {$byte = "38"; last SWITCH;};
    /9/ && do {$byte = "39"; last SWITCH;};
    /\:/ && do {$byte = "3a"; last SWITCH;};
    /;/ && do {$byte = "3b"; last SWITCH;};
    /</ && do {$byte = "3c"; last SWITCH;};
    /=/ && do {$byte = "3d"; last SWITCH;};
    />/ && do {$byte = "3e"; last SWITCH;};
    /\?/ && do {$byte = "3f"; last SWITCH;};
    /@/ && do {$byte = "40"; last SWITCH;};
    /A/ && do {$byte = "41"; last SWITCH;};
    /B/ && do {$byte = "42"; last SWITCH;};
    /C/ && do {$byte = "43"; last SWITCH;};
    /D/ && do {$byte = "44"; last SWITCH;};
    /E/ && do {$byte = "45"; last SWITCH;};
    /F/ && do {$byte = "46"; last SWITCH;};
    /G/ && do {$byte = "47"; last SWITCH;};
    /H/ && do {$byte = "48"; last SWITCH;};
    /I/ && do {$byte = "49"; last SWITCH;};
    /J/ && do {$byte = "4a"; last SWITCH;};
    /K/ && do {$byte = "4b"; last SWITCH;};
    /L/ && do {$byte = "4c"; last SWITCH;};
    /M/ && do {$byte = "4d"; last SWITCH;};
    /N/ && do {$byte = "4e"; last SWITCH;};
    /O/ && do {$byte = "4f"; last SWITCH;};
    /P/ && do {$byte = "50"; last SWITCH;};
    /Q/ && do {$byte = "51"; last SWITCH;};
    /R/ && do {$byte = "52"; last SWITCH;};
    /S/ && do {$byte = "53"; last SWITCH;};
    /T/ && do {$byte = "54"; last SWITCH;};
    /U/ && do {$byte = "55"; last SWITCH;};
    /V/ && do {$byte = "56"; last SWITCH;};
    /W/ && do {$byte = "57"; last SWITCH;};
    /X/ && do {$byte = "58"; last SWITCH;};
    /Y/ && do {$byte = "59"; last SWITCH;};
    /Z/ && do {$byte = "5a"; last SWITCH;};
    /\[/ && do {$byte = "5b"; last SWITCH;};
    /[é\\]/ && do {$byte = "5c"; last SWITCH;};
    /\]/ && do {$byte = "5d"; last SWITCH;};
    /[í\^]/ && do {$byte = "5e"; last SWITCH;};
    /[ó_]/ && do {$byte = "5f"; last SWITCH;};
    /[ú`]/ && do {$byte = "60"; last SWITCH;};
    /a/ && do {$byte = "61"; last SWITCH;};
    /b/ && do {$byte = "62"; last SWITCH;};
    /c/ && do {$byte = "63"; last SWITCH;};
    /d/ && do {$byte = "64"; last SWITCH;};
    /e/ && do {$byte = "65"; last SWITCH;};
    /f/ && do {$byte = "66"; last SWITCH;};
    /g/ && do {$byte = "67"; last SWITCH;};
    /h/ && do {$byte = "68"; last SWITCH;};
    /i/ && do {$byte = "69"; last SWITCH;};
    /j/ && do {$byte = "6a"; last SWITCH;};
    /k/ && do {$byte = "6b"; last SWITCH;};
    /l/ && do {$byte = "6c"; last SWITCH;};
    /m/ && do {$byte = "6d"; last SWITCH;};
    /n/ && do {$byte = "6e"; last SWITCH;};
    /o/ && do {$byte = "6f"; last SWITCH;};
    /p/ && do {$byte = "70"; last SWITCH;};
    /q/ && do {$byte = "71"; last SWITCH;};
    /r/ && do {$byte = "72"; last SWITCH;};
    /s/ && do {$byte = "73"; last SWITCH;};
    /t/ && do {$byte = "74"; last SWITCH;};
    /u/ && do {$byte = "75"; last SWITCH;};
    /v/ && do {$byte = "76"; last SWITCH;};
    /w/ && do {$byte = "77"; last SWITCH;};
    /x/ && do {$byte = "78"; last SWITCH;};
    /y/ && do {$byte = "79"; last SWITCH;};
    /z/ && do {$byte = "7a"; last SWITCH;};
    /[ç\{]/ && do {$byte = "7b"; last SWITCH;};
    /[÷\|]/ && do {$byte = "7c"; last SWITCH;};
    /[Ñ\}]/ && do {$byte = "7d"; last SWITCH;};
    /[ñ~]/ && do {$byte = "7e"; last SWITCH;};
    /\|/ && do {$byte = "7f"; last SWITCH;};
    /£/ && do {die "Unknown character £ in line $. of $input, stopped";};
  }
  if ($byte eq "~") {
    die "Invalid character {".$char."} in line $. of $input, stopped";
  }
  if ($mode ne "ITV") { # ITV doesn't use odd parity
    $byte = sprintf("%02x", oddParity(hex $byte));
  }
  return $byte;
}

