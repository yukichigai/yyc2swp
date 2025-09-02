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

NOTE: outfile argument is optional (name.scc/g608 -> name.ass). Format is controlled by outfile suffix: .vtt WebVTT, .smi/.sami SAMI, .ssa SubStation Alpha, .ttml/.dfxp Timed Text Markup Language, .ass Advanced SubStation (default), or .ccd SCC Disassembly (SCC input only)

# Notes
Captions are converted assuming a 4:3 NTSC display resolution (640x480 in square pixels) and padded for overscan. I intend to add options for overriding the target resolution, aspect ratio, and overscan at a later date.

## Current conversion quality
Advanced SubStation (ASS) produces the most consistent output for commonly used players (VLC, MPC, MPV, Jellyfin). It supports all Closed Caption features other than flashing text. Overall it is the most compatible and accurate format, thus why it is the default.

SubStation Alpha (SSA) output is just as accurate as ASS for positioning and text color, but does not support background color and alpha effects (which are rarely used). SSA also technically does not support Underlined text, though most players will render it regardless. Generally most players that support SSA will support ASS, so there is little reason to use it over the other format.

Timed Text Markup Language/SMPTE-TT (TTML/DFXP) is unsupported by some players (MPV, MPC) and produces less visually consistent results in others (VLC). However, on web-based players and professional authoring software it has better support and more accuracy than any other format.

WebVTT (VTT) output is very accurate for web-based players, but styling support is spotty at best for most software (e.g. VLC does not process left/right positioning, MPV and MPC do not process positioning at all).

GPAC Timed Text (TTXT) is functional but does not scale with resolution well, especially anamorphic content. Its primary use is conversion to TX3G, which has not been fully tested. The format should be considered a work in progress.

SAMI output is currently a hot mess (official term) and still in progress. I have yet to find a player that definitively supports all SAMI features to test with. The format may be dropped owing to poor feature support among most players.

Quicktime Caption (QT.TXT) output is currently untested. It also should be considered a work in progress, and may also be dropped in the future.

# Credits
This script is modified from CCASDI by McPoodle. Almost all of the caption parsing and SCC <-> CCD conversion logic is their work.

Thanks to Emulgator on Doom9 for their analysis of the output from the [Zilog z86229 Closed Caption Decoder chip](https://www.zilog.com/docs/tv/z86229.pdf), which was used as the basis for the caption positioning and overscan compensation logic.

Thanks also to bbgdzxng1 for sharing the lost version 3.8 of CCASDI.

# Changelog

0.7 Add in code changes from the "lost" CCASDI version 3.8; thanks to bbgdzxng1 for finding this. Change TTML and WebVTT generation to prevent inaccuracies with nested styling changes (color, italic, etc). Change TTML generation to be SMPTE-TT specification compliant (I think) per documentation from PBS. Add initial, largely untested support for Quicktime Caption (QT.TXT) from 3.8 and GPAC Timed Text (TTXT). Add warning messages when captions with certain styling are converted to formats which do not support them (e.g. background color in SSA).

0.6 Improve WebVTT output, add more formatting support to TTML. Add warning for WebVTT and TTML when multiple formatting changes are present in a subtitle due to possible inaccuracies in conversion. WebVTT output is technically accurate for web, but less so for VLC/MPC.

0.5 Add TTML/DFXP support. Output is less accurate than SSA/ASS but mostly correct.

0.4 Initial release. SubStation and Advanced SubStation output mostly correct, SAMI and WebVTT lacking.
