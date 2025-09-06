# YYC2SWP 
## Y|yukichigai's Caption to Subtitle (with positioning!)

This is a command line Perl script which can convert Closed Captions (Scenarist or [Grid 608](https://github.com/CCExtractor/ccextractor/blob/master/docs/G608.TXT) format) to more accessible subtitle formats (SubStation, Advanced Substation, Timed Text Markup Language, WebVTT) while preserving subtitle positioning. This tool is a fork of/based on CCASDI by McPoodle, part of the discontinued [SCC Tools](http://www.theneitherworld.com/mcpoodle/SCC_TOOLS/DOCS/SCC_TOOLS.HTML) project.

# Requirements

yyC2Swp currently requires you have Perl installed on your system, what with it being an uncompiled Perl script and all. Your Perl installation must also support UTF-8 (if you somehow disabled that).

## Windows
yyC2Swp is tested on Windows using [Strawberry Perl](https://strawberryperl.com/). While most versions of Perl for Windows should work, Strawberry Perl will (mostly) ensure you're using the same environment I was during development.

## Linux

yyC2Swp uses Courier New as the target font for generated subtitles, so proper display during playback requires a compatible monospace font. John August's [Courier Prime](https://johnaugust.com/2013/introducing-courier-prime) matches the size and spacing of Courier New exactly and is freely available. It is present in several major package managers, and once installed many distros will automatically use Courier Prime when Courier New is called for.

# Usage

```
perl yyC2Swp.pl [-cCC3] [-a] [-o01:00:00:00] [-td] infile.scc [outfile.ass]
```
-c (OPTIONAL): Channel to convert to subtitle. SCC input only. (CC1 default, CC2, CC3, CC4, T1, T2, T3 and T4 are other choices)

-r (OPTIONAL): Output roll-up subtitles in roll-up format, instead of one line at a time

-a (OPTIONAL): Adjust timecodes to be start time for SCC and display time for dissassembly

-o (OPTIONAL): Offset to apply to timecodes, in HH:MM:SS:FF format (DEFAULT: 00:00:00:00, negative values are permitted)

-f (OPTIONAL): Number of frames per second (range 12 - 60) (DEFAULT: 29.97)

-t (OPTIONAL; automatically sets fps to 29.97): NTSC timebase: d (dropframe) or n (non-dropframe) (DEFAULT: n)

NOTE: outfile argument is optional (name.scc/g608 -> name.ass). Format is controlled by outfile suffix: .vtt WebVTT, .smi/.sami SAMI, .ssa SubStation Alpha, .ttml/.dfxp Timed Text Markup Language, .xml SMPTE-TT, .qt.txt QuickTime Caption, .ttxt GPAC Timed Text, .stl Spruce Technologies Language, .ass Advanced SubStation (default), or .ccd SCC Disassembly (SCC input only)

# Notes
Captions are converted assuming a non-anamorphic 4:3 NTSC display resolution (640x480 in square pixels) and padded for overscan. I intend to add options for overriding the target resolution, aspect ratio, and overscan at a later date.

Certain SCC extraction tools (or versions of those tools) produce formatting inconsistencies (depending on the source media) which this script is not (yet) capable of accounting for. These same tools (or versions) usually support extraction to Grid 608 (G608) format and do not produce the same inconsistencies when outputting to that format. Grid 608 is also much easier to visually spot-check. If you are encountering undesired results when converting extracted SCC files you may want to extract to Grid 608 and convert from that instead. (Note that Grid 608 does not preserve background color, background alpha, or flashing text style effects)

Captions which contain styling options (e.g. color changes, background alpha) that are unsupported by the output format will be converted with those styles removed. A warning will be printed to the console for each caption that could not be converted with all styling intact.

## Current conversion options
Advanced SubStation (ASS) produces the most consistent output for commonly used players and decoding libraries (VLC, MPC, MPV, Jellyfin, FFMPEG). It supports all CEA-608 features other than flashing text, and scales properly regardless of differences in resolution and/or aspect ratio between subtitle specifications and the actual media it is used with. Overall it is the most compatible yet accurate format for non-commercial/non-professional use, thus why it is the default.

SubStation Alpha (SSA) output is just as accurate as Advanced SubStation for positioning and text color, but does not support background color and alpha effects (which are rarely used). SSA also technically does not support underlined text, though most players will render it regardless. Generally most players that support SSA will also support ASS, and there are no inherent technical advantages to SSA over ASS. The format should only be used for specific situations where Advanced SubStation is not supported... or if your captions have very little styling and you don't want them showing up as "ASS".

Timed Text Markup Language (TTML/DFXP) is unsupported by most players (MPC, MPV) and imperfectly supported by others (VLC supports almost all effects but has issues maintaining consistent line spacing). However, it is one of the most accurate human-readable conversion formats available for CEA-608 captions, particularly in terms of positioning and font sizing since it uses an almost identical grid-based text sizing and positioning system by default. It has better support overall than any other format among web-based players and professional authoring software.

SMPTE-TT (XML) is an extension of TTML designed to retain all CEA-608 content, styling, and appearance (e.g. program information, the solid color background behind text), and is one of the formats recommended for Closed Caption/CEA-608 preservation by PBS. SMPTE-TT is designed to be somehow even more accurate than TTML, albeit mostly in ways that are only relevant to broadcast, commercial, or other professional considerations. Due to the high accuracy of content preservation its file sizes are almost always larger than TTML. Support is for the most part the same as TTML, and most compatible software players will not show any significantly different output than standard TTML, other than displaying a black background behind most text. The format is best used for archival or professional purposes.

WebVTT (VTT) output is very accurate for web-based players, but styling support is spotty at best for most software (e.g. VLC does not process left/right positioning, MPV and MPC do not process positioning at all). It is a preferred subtitle upload format for many video hosting platforms (e.g. YouTube), though some of those platforms also support SCC files directly (e.g. also YouTube).

Spruce Technologies Language (STL) is an older format originating from Spruce's discontinued DVD Maestro software. It is used primarily in professional authoring applications, mostly on Apple/iOS systems. It supports most caption features including positioning, but only basic styling changes (italic/underline) are able to be applied on a per-character basis. In other words color and background effects must apply to the whole subtitle, so yyC2Swp does not implement those features when converting to the format. Conventional player support is all but nonexistent: VLC cannot correctly parse the format (though it tries), while other players (MPC, MPV) have no support at all. The format should only be used when needed for specific software that does not support any other human-readable position-preserving subtitle format (e.g. Final Cut Studio, DVD Studio Pro). It should not be confused with EBU-STL, a binary format which uses the same extension.

GPAC Timed Text (TTXT) is functional for positioning but has almost no conventional player support. Styling features (italics, color, etc.) are not yet implemented due to the complexity of the styling syntax. The format is not capable of background color or alpha changes, but supports all other CEA-608 styling features including flashing text (though again, styling is not currently implemented). Its intended use is conversion via [GPAC](https://github.com/gpac/gpac) to MPEG-4 Part 17 (TX3G) muxed into MP4 or 3GPP files, which has not been fully tested. The format should be considered a work in progress.

SAMI output includes basic color and italic/underline effects, and theoretically preserves positioning information; finding something which processes it is a different matter entirely. Almost all conventional players (MPC, MPV, VLC) and common libraries (FFMPEG) process only text and basic styling (color, italic, underline, bold, strikethrough) and discard all other tags, including positioning. Header information is also ignored. Due to this I cannot add any more features or functionality to SAMI output... at least until I find a player that definitively supports all SAMI features. If you know of one, please let me know. (I hear SAMI is/was popular for Korean translations, so perhaps that's a place to look?)

QuickTime Caption (QT.TXT) output is currently untested. It also should be considered a work in progress, and may be dropped in the future.

# Credits
This script is modified from CCASDI by McPoodle. Almost all of the caption parsing and SCC <-> CCD conversion logic is their work.

Thanks to Emulgator on Doom9 for their analysis of the output from the [Zilog z86229 Closed Caption Decoder chip](https://www.zilog.com/docs/tv/z86229.pdf), which was used as the basis for the caption positioning and overscan compensation logic.

Thanks also to bbgdzxng1 for sharing the lost version 3.8 of CCASDI.

# Changelog

0.9 Add Spruce Technologies Language (STL) support (not to be confused with EBU-STL). Only supports positioning and basic styling (italic/underline) since color effects must be applied to the entire subtitle. Modify QT.TXT, SAMI, and TTXT output to omit screen blanking commands (end of subtitle) when the next subtitle starts within 0.5 seconds of the end of the last. Add "null-stuffing" (blank sub at frame 0) to those same formats. Modify SMPTE-TT header generation to properly note source caption channel (when specified) per SMPTE-TT spec. Further refinements to SAMI output to maximize compatibility with modern players and libraries (mostly FFMPEG). Add background color support to QuickTime Caption.

0.8 Split SMPTE-TT from TTML/DFXP. SMPTE-TT now can be output using the extension .xml. Change output of some caption characters to more appropriate Unicode characters, e.g. Full Block (U+2588), which was previously "|".

0.7 Add in code changes from the "lost" CCASDI version 3.8; thanks to bbgdzxng1 for finding this. Change TTML and WebVTT generation to prevent inaccuracies with nested styling changes (color, italic, etc). Change TTML generation to be SMPTE-TT specification compliant (I think) per documentation from PBS. Add initial, largely untested support for Quicktime Caption (QT.TXT) from 3.8 and GPAC Timed Text (TTXT). Add warning messages when captions with certain styling are converted to formats which do not support them (e.g. background color in SSA).

0.6 Improve WebVTT output, add more formatting support to TTML. Add warning for WebVTT and TTML when multiple formatting changes are present in a subtitle due to possible inaccuracies in conversion. WebVTT output is technically accurate for web, but less so for VLC/MPC.

0.5 Add TTML/DFXP support. Output is less accurate than SSA/ASS but mostly correct.

0.4 Initial release. SubStation and Advanced SubStation output mostly correct, SAMI and WebVTT lacking.
