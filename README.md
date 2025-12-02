# YYC2SWP 
## Y|yukichigai's Caption to Subtitle (with positioning!)

This is a command line Perl script which can convert Closed Captions (Scenarist or [Grid 608](https://github.com/CCExtractor/ccextractor/blob/master/docs/G608.TXT) format) to more accessible subtitle formats (SubStation, Advanced Substation, Timed Text Markup Language, WebVTT) while preserving subtitle positioning. This tool is a fork of/based on CCASDI by McPoodle, part of the discontinued [SCC Tools](http://www.theneitherworld.com/mcpoodle/SCC_TOOLS/DOCS/SCC_TOOLS.HTML) project.

# Requirements

For non-Windows OSes yyC2Swp currently requires you have Perl installed on your system, what with it being an uncompiled Perl script and all. Your Perl installation must also support UTF-8 (if you somehow disabled that).

## Windows
While there is a standalone executable version of yyC2Swp available, you may want to run the Perl script version directly, if for no reason other than it being a tenth the size of the EXE. yyC2Swp is tested on Windows using [Strawberry Perl](https://strawberryperl.com/). While most versions of Perl for Windows should work, Strawberry Perl will (mostly) ensure you're using the same environment I was during development.

## Linux

yyC2Swp uses Courier New as the target font for generated subtitles, so proper display during playback requires a compatible monospace font. John August's [Courier Prime](https://johnaugust.com/2013/introducing-courier-prime) matches the size and spacing of Courier New exactly and is freely available. It is present in several major package managers, and once installed many distros will automatically use Courier Prime when Courier New is called for.

# Usage

```
perl yyC2Swp.pl [-ec] [-cCC3] [-a] [-o01:00:00:00] [-td] [-x768] [-y576] [-fs36] [-fnCourier_Prime] [-nobold] [-lDeutsch] [-lDE] infile.scc [outfile.ass]
```
-ec (OPTIONAL): Correct errors in input files when possible, rather than halting conversion entirely. Errors will still be written to console. (DEFAULT: off)

-c (OPTIONAL): Channel to convert to subtitle. SCC input only. (CC1 default, CC2, CC3, CC4, T1, T2, T3 and T4 are other choices)

-r (OPTIONAL): Output roll-up subtitles in roll-up format, instead of one line at a time

-a (OPTIONAL): Adjust timecodes to be start time for SCC and display time for dissassembly

-o (OPTIONAL): Offset to apply to timecodes, in HH:MM:SS:FF format (DEFAULT: 00:00:00:00, negative values are permitted)

-f (OPTIONAL): Number of frames per second (range 12 - 60) (DEFAULT: 29.97)

-t (OPTIONAL; automatically sets fps to 29.97): NTSC timebase: d (dropframe) or n (non-dropframe) (DEFAULT: n)

-x (OPTIONAL): Horizontal resolution for converted subtitles. Not used by E608, G608, SMPTE-TT, TTML, or VTT. (DEFAULT: 720 for STL, 640 for others)

-y (OPTIONAL): Vertical resolution for converted subtitles. Not used by E608, G608, SMPTE-TT, TTML, or VTT. (DEFAULT: 480)

-xr (OPTIONAL): Portion of the width of the video to display subtitles in. A value of 8/10 would position subtitles within the center 80% of the video width and leave a "safe zone" of 10% on the left and right. Can be specified as a ratio (4:5) or a fraction (3/4). Negative values will be interpreted the same as 1:1, i.e. 100%. (DEFAULT: 2/3)

-yr (OPTIONAL): Portion of the height of the video to display subtitles in. A value of 8/10 would position subtitles within the center 80% of the video height and leave a "safe zone" of 10% on the top and bottom. Can be specified as a ratio (7:8) or a fraction (4/5). Negative values will be interpreted the same as 1:1, i.e. 100%. (DEFAULT: 13/16)

-l (OPTIONAL): Language or Language Code for subtitles. Two character values will be stored as the Language Code, longer will be stored as the Language. If only a Language is specified, the first two characters will become the Language Code. Only used by SAMI, SMPTE-TT, and TTML subtitles. (DEFAULT: English, EN)

-fn (OPTIONAL): Font name to use in generated subtitles. Spaces in the name must be replaced with underscore (_) e.g. \"Courier_Prime\" for Courier Prime. Not used by E608, G608, and SMPTE-TT. (DEFAULT: Courier_New)

-fs (OPTIONAL): Font size to use in generated subtitles. Non-numeric values are allowed but may produce undesired results. Value is in points (pt). Value reduced to 80% for STL subtitles. Not used by E608, G608, SMPTE-TT, TTML. (DEFAULT: 30)

-nobold (OPTIONAL): Text in generated subtitles will normal font weight instead of bold. Not used by E608, G608, QuickTime, and STL. (DEFAULT: off/bold text enabled)

NOTE: outfile argument is optional (name.scc/g608/e608 -> name.ass). Format is controlled by outfile suffix: .ass Advanced SubStation (default), .ccd SCC Disassembly (SCC input only), .e608 Extended Grid 608, .g608 Grid 608, .qt.txt QuickTime Caption, .smi/.sami SAMI, .ssa SubStation Alpha, .stl Spruce Technologies Language, .ttml/.dfxp Timed Text Markup Language, .ttxt GPAC Timed Text, .vtt WebVTT, or .xml SMPTE-TT.

# Notes
Captions which contain styling options (e.g. color changes, background alpha) that are unsupported by the output format will be converted with those styles removed. A warning will be printed to the console for each caption that could not be converted with all styling intact.

Converted captions do not include the default black background for text, except for the SMPTE-TT format. Other background colors are preserved in formats with per-character background color support. Advanced SubStation currently will display these as changes to the text border color rather than a solid background color. An option to retain the default solid background will be added at a later date.

## Known Issues
yyC2Swp assumes input files are for CEA-608 captions. Conversion of files containing EIA-708 captions may produce inconsistent or inaccurate results. At a minimum subtitles will be placed incorrectly, if not partially or fully off the screen.

Depending on the source media, certain SCC extraction tools (or versions of those tools) produce differences in formatting which this script is not (yet) capable of accounting for. These same tools usually support extraction to Grid 608 (G608) format and produce consistent results when outputting to that format. Grid 608 is also much easier to visually spot-check. If you are encountering undesired results when converting extracted SCC files you may want to extract to Grid 608 and convert from that instead. (Note that Grid 608 does not preserve background color, background alpha, or flashing text style effects)

Full styling support is not yet implemented for some subtitle formats. Flashing text is not currently implemented for any subtitle format.

## Current conversion options
**Advanced SubStation (ASS)** produces the most consistent output for commonly used players and decoding libraries (VLC, MPC, MPV, Jellyfin, FFMPEG). It supports all CEA-608 features other than flashing text, and scales properly regardless of differences in resolution and/or aspect ratio between subtitle specifications and the actual media it is used with. Overall it is the most compatible yet accurate format for non-commercial/non-professional use, thus why it is the default.

**SubStation Alpha (SSA)** output is just as accurate as Advanced SubStation for positioning and text color, but does not support background color and alpha effects (which are rarely used). SSA also *technically* does not support underlined text, though most players will render it regardless. Generally most players that support SSA will also support ASS, and there are no inherent technical advantages to SSA over ASS. That said, captions converted to SubStation Alpha are positioned by adjusting margins rather than using Advanced SubStation's "pos" tag, which can produce more (or less) desirable results with certain software. The format should only be used for specific situations where Advanced SubStation will not do the job... or if your captions have very little styling and you don't want them showing up as "ASS".

**Timed Text Markup Language (TTML/DFXP)** is unsupported by most players (MPC, MPV) and imperfectly supported by others (VLC supports almost all effects but has issues maintaining consistent line spacing). However, it is one of the most accurate human-readable conversion formats available for CEA-608 captions, particularly in terms of positioning and font sizing since it uses an almost identical grid-based text sizing and positioning system by default. It is the format with the best overall support and accuracy among web-based players and professional authoring software.

**SMPTE-TT (XML)** is an extension of TTML designed to retain all CEA-608 content, styling, and appearance (e.g. program information, the solid color background behind text), and is one of the formats recommended for Closed Caption/CEA-608 preservation by PBS. SMPTE-TT is designed to be somehow even more accurate than TTML, albeit mostly in ways that are only relevant to broadcast, commercial, or other professional considerations. Due to the high accuracy of content preservation its file sizes are almost always larger than TTML. Support is for the most part the same as TTML, and most compatible software players will not show any significantly different output than standard TTML, other than the font (which is simply set to "monospace" for compatibility reasons) and displaying a black background behind most text. Storage of extended data (XDS) - like program information and rating - is supported by the format but not yet implemented by yyC2Swp. The format is best used for archival or professional purposes.

**WebVTT (VTT)** output is very accurate for web-based players, but advanced styling support is sparse for most software (e.g. VLC does not process left/right positioning, MPV and MPC do not process positioning at all). Despite that nearly all modern players, libraries, and authoring software have basic support for WebVTT and will display text, italic/underline, and color effects correctly, effectively treating them as SubRip (SRT) subtitles. WebVTT is a preferred subtitle upload format for many video hosting platforms (e.g. YouTube), though some of those platforms also support SCC files directly (e.g. also YouTube).

**Spruce Technologies Language (STL)** is an older format originating from Spruce's discontinued DVDMaestro software; it should not be confused with EBU-STL, a binary format which uses the same extension. It is used primarily in professional authoring applications, mostly on Apple/iOS systems. It supports most caption features including positioning, but only basic styling changes (italic/underline) are able to be applied on a per-character basis. In other words color and background effects must apply to the whole subtitle, so yyC2Swp does not implement those features when converting to the format. Conventional player support is all but nonexistent: VLC cannot correctly parse the format (though it tries), while other players have no support at all. Positioning and caption placement is *generally* correct, though individual lines within converted captions may be positioned somewhat differently due to how the format handles special characters and text alignment. In particular, captions containing two or more blocks of text separated horizontally by whitespace may not be positioned as expected, requiring further editing after conversion. The format should only be used when needed for specific software that does not support any other text-based position-preserving subtitle format (e.g. Final Cut Studio, DVD Studio Pro).

**GPAC Timed Text (TTXT)** is functional for positioning but has almost no conventional player support. Styling features (italics, color, etc.) are not yet implemented due to the complexity of the styling syntax. The format is not capable of background color or alpha changes, but supports all other CEA-608 styling features including flashing text (though again, styling is not currently implemented). Its intended use is conversion via [GPAC](https://github.com/gpac/gpac) to MPEG-4 Part 17 (TX3G) muxed into MP4 or 3GPP files, which has not been fully tested. The format should be considered a work in progress.

**SAMI (SAMI/SMI)** output includes basic color and italic/underline effects, and theoretically preserves positioning information; finding something which processes it is a different matter entirely. All commonly available players and libraries process only text and basic styling (color, italic, underline, bold, strikethrough) and discard all other tags, including positioning. Header information (which includes font selection and sizing) is also ignored. Due to this I cannot add any more features or functionality to SAMI output... at least until I find a player that definitively supports all SAMI features. If you know of one, please let me know. (I hear SAMI is/was popular for Korean translations, so perhaps that's a place to look?)

**Grid 608 (G608)** is a format created by the developers of CCExtractor, somewhat based on the SubRip (SRT) subtitle format. Timecode and subtitle numbering syntax is identical to SubRip, but the subtitle text itself is stored in a 32-character-by-15-line grid which serves to perfectly retain the positioning of the text. To the right of this text is another 32x15 grid containing the text color information for each character (stored as integers 0-9) and another 32x15 grid indicating the styling of each character (Underline, Italic, Both, or Regular). The format is designed to be very easy to visually inspect, check, and even edit using nothing more than a basic text editor. However it is completely unsupported by any known players or playback libraries. As far as I know the only software that supports the format at all is CCExtractor and this conversion script. That said, it is an *excellent* intermediary format to use when converting captions using yyC2Swp or CCExtractor, as the structure of the format very closely matches the internal variable structure used by both CCExtractor and yyC2Swp.

**Extended Grid 608 (E608)** is an extension of the Grid 608 format developed by me for use with yyC2Swp. The structure and syntax is largely identical to Grid 608 with two significant differences. First, the styling grid supports storing the Flashing Text (F) tag in addition to the existing Underline/Italic/Both/Regular tags. Second, there is an additional character grid used to store background color and alpha information: single characters for background color, lowercase indicating a half-transparent color, uppercase indicating a fully opaque color (and T for Transparent). The format also allows for a Byte Order Mark to be included in the beginning of the file (though it is not required). Further features *may* be added at a later date, such as support for manually indicating display modes (roll-up, paint-on) or overriding the usual 32x15 grid size. Literally nothing supports this format except yyC2Swp since I created it for this script, but I would certainly be happy if other developers decided to add support for it. As with Grid 608 it is an excellent intermediary format for conversion, and can be used to store *or create* captions which contain rarely used features that do not convert well to more conventional formats (i.e. flashing text, background color and alpha changes). The format also is technically a work in progress, though the core functionality should not change.

**QuickTime Caption (QT.TXT)** output is currently untested. The conversion is based on existing code from CCASDI version 3.8 and archived reference documentation from Apple. Support for the format seems to have been dropped in an earlier version of QuickTime 7 (specific sub-version depending on the OS), and no modern players appear to support it. The format will remain available for conversion as it is theoretically capable of preserving caption positioning, but no further changes will be made to the output until-and-if someone digs up a player for me to test it with.

# Credits
This script is modified from CCASDI by McPoodle. Almost all of the caption parsing and SCC <-> CCD conversion logic is their work.

Thanks to Emulgator on Doom9 for their analysis of the output from the [Zilog z86229 Closed Caption Decoder chip](https://www.zilog.com/docs/tv/z86229.pdf), which was used as the basis for the caption positioning and overscan compensation logic.

Thanks also to bbgdzxng1 for sharing the lost version 3.8 of CCASDI.

# Changelog

1.2 Add option to disable bold for generated subtitles. Add option to override font used for subtitles. Font designation must use _ instead of space due to parsing, e.g. Courier Prime would be specified with "-fnCourier_Prime". Fix an issue with TTML/SMPTE-TT generation which could cause an infinite loop when generating multi-line subtitles. Allow conversion to continue when detecting a negative time code in input file when the Error Correction option is enabled. Add option to override font size in generated subtitles (-fsXX, e.g. ""-fs32")

1.1 Modify SCC parsing to account for blank lines that have more than just a newline to ensure default channel detection functions correctly. Also change SCC parsing to account for byte pairs sperated by multiple spaces. Add parsing of Flashing Text Tag to SCC decoding (whoops). Add Error Correction command line option to correct or ignore errors in input files and continue processing when possible.

1.0.2 Adjustments to numeric versus string comparison operators. Change how trailing tags are stripped from ASS and SSA subtitles.

1.0.1 Fix error with some variable names (double use of $) which caused crashes when converting some SCC files.

1.0 Add Grid 608 (G608) and Extended Grid 608 (E608) output. Extended Grid 608 is similar to Grid 608, but with an additional 32x15 block for indicating background color and alpha. The format also notes the Flashing Text tag (F) in the styling block (the B, I, R, U characters). The format may be expanded further at a later date, e.g. to add notation for roll-up or paint-on caption effects. Fix some issues with STL output that caused incorrect rendering when imported into DVD Studio Pro 4, and alter output to change horizontal alignment as needed to better preserve positioning. Correct SCC decoding of certain text styling flags (like flashing). Correct a bug which left trailing newlines on some subtitles. Modify headers in TTML/SMPTE-TT and SSA/ASS to follow compatibility and best practices recommendations for those formats. Add support for semi-transparent background colors to WebVTT. Add command line options for resolution, language, and display/safe area.

0.9 Add Spruce Technologies Language (STL) support (not to be confused with EBU-STL). Only supports positioning and basic styling (italic/underline) since color effects must be applied to the entire subtitle. Modify QT.TXT, SAMI, and TTXT output to omit screen blanking commands (end of subtitle) when the next subtitle starts within 0.5 seconds of the end of the last. Add "null-stuffing" (blank sub at frame 0) to those same formats. Modify SMPTE-TT header generation to properly note source caption channel (when specified) per SMPTE-TT spec. Further refinements to SAMI output to maximize compatibility with modern players and libraries (mostly FFMPEG). Add background color support to QuickTime Caption.

0.8 Split SMPTE-TT from TTML/DFXP. SMPTE-TT now can be output using the extension .xml. Change output of some caption characters to more appropriate Unicode characters, e.g. Full Block (U+2588), which was previously "|".

0.7 Add in code changes from the "lost" CCASDI version 3.8; thanks to bbgdzxng1 for finding this. Change TTML and WebVTT generation to prevent inaccuracies with nested styling changes (color, italic, etc). Change TTML generation to be SMPTE-TT specification compliant (I think) per documentation from PBS. Add initial, largely untested support for Quicktime Caption (QT.TXT) from 3.8 and GPAC Timed Text (TTXT). Add warning messages when captions with certain styling are converted to formats which do not support them (e.g. background color in SSA).

0.6 Improve WebVTT output, add more formatting support to TTML. Add warning for WebVTT and TTML when multiple formatting changes are present in a subtitle due to possible inaccuracies in conversion. WebVTT output is technically accurate for web, but less so for VLC/MPC.

0.5 Add TTML/DFXP support. Output is less accurate than SSA/ASS but mostly correct.

0.4 Initial release. SubStation and Advanced SubStation output mostly correct, SAMI and WebVTT lacking.
