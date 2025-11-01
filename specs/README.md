# Adobe Flash and ActionScript Specifications

This directory contains official Adobe Flash SWF and ActionScript specifications used for the SWFRecomp project.

## Files

### SWF File Format Specification (Version 19)

- **[swf-spec-19.pdf](pdf/swf-spec-19.pdf)** (1.7 MB)
  - Official Adobe SWF File Format Specification, Version 19
  - Source: https://open-flash.github.io/mirrors/swf-spec-19.pdf
  - Mirror maintained by the Open Flash project

- **[swf-spec-19.txt](swf-spec-19.txt)** (370 KB)
  - Text version of the SWF specification, extracted from the PDF
  - Generated using: `pdftotext swf-spec-19.pdf swf-spec-19.txt`
  - Contains all the specification content in plain text format

- **[swf-spec-19-images/](swf-spec-19-images/)** (25 PNG files)
  - Charts and diagrams extracted from the SWF specification PDF
  - Generated using: `pdfimages -png swf-spec-19.pdf swf-spec-19-images/image`
  - Contains images image-000.png through image-024.png

### ActionScript Bytecode (ABC) Format Specification

- **[abc-format-46-16.txt](abc-format-46-16.txt)** (8.2 KB)
  - Official Adobe ABC File Format Specification
  - Version 46.16 (Flash Player 9+)
  - Source: https://github.com/adobe-flash/avmplus/blob/master/doc/abcFormat-46-16.txt
  - From Adobe's official avmplus repository

### AVM2 (ActionScript Virtual Machine 2) Overview

- **[avm2overview.pdf](pdf/avm2overview.pdf)** (401 KB)
  - Official Adobe ActionScript Virtual Machine 2 (AVM2) Overview
  - Published: May 2007
  - High-level overview of the AVM2 architecture and instruction set
  - Source: https://www.adobe.com/content/dam/acom/en/devnet/pdf/avm2overview.pdf

- **[avm2overview.txt](avm2overview.txt)** (150 KB)
  - Text version of the AVM2 Overview, extracted from the PDF
  - Generated using: `pdftotext avm2overview.pdf avm2overview.txt`
  - Contains all the specification content in plain text format

### AVM2 Opcode References

- **[opcodes.as](opcodes.as)** (15 KB)
  - ActionScript 3 opcode table generator
  - Shows opcode metadata structure used in the AVM2 virtual machine
  - Source: https://github.com/adobe-flash/avmplus/blob/master/utils/opcodes.as
  - From Adobe's official avmplus repository

- **[avm2_opcodes_raw.txt](avm2_opcodes_raw.txt)** (258 lines)
  - Extracted opcode table from avmplus Interpreter.cpp
  - Maps opcodes 0x00-0xFF to instruction handlers
  - Shows which opcodes are implemented vs XXX (unimplemented)
  - Source: Extracted from https://github.com/adobe-flash/avmplus/blob/master/core/Interpreter.cpp

## External References

- **Open Flash Project**: https://open-flash.github.io/
  - Maintains mirrors of Adobe Flash specifications
- **Adobe avmplus**: https://github.com/adobe-flash/avmplus
  - Official ActionScript Virtual Machine implementation (archived)
  - License: MPL 2.0
