# SWFRecomp Documentation

This repository contains documentation for the [SWFRecomp project](https://github.com/SWFRecomp/SWFRecomp), which aims to recompile Adobe Flash (SWF) content to C code.

**Live Demos:** [https://swfrecomp.github.io/SWFRecompDocs/](https://swfrecomp.github.io/SWFRecompDocs/) - See Flash running as WebAssembly!

## Documentation Structure

### Live Demos

Interactive WebAssembly demonstrations of recompiled Flash content (see [docs/](docs/) for source):

- **[trace_swf_4 Demo](https://swfrecomp.github.io/SWFRecompDocs/examples/trace-swf-test/)** - Console output demo showing SWF → C → WASM pipeline

### Implementation Guides

Step-by-step implementation guides for various components:

- **[as3-implementation.md](guides/as3-implementation.md)** - ActionScript 3 implementation guide
  - **[as3-seedling-implementation.md](guides/as3-seedling-implementation.md)** - An implementation guide for only the AS3 features required to run the game Seedling
  - **[abc-parser-implementation.md](guides/abc-parser-implementation.md)** - Phase 1: ABC Parser implementation
  - **[as3-test-swf-generation.md](guides/as3-test-swf-generation.md)** - Guide for generating AS3 test SWF files

- **[font-implementation.md](guides/font-implementation.md)** - Implementation guide for font handling in SWF files
  - **[font-phase1-implementation.md](guides/font-phase1-implementation.md)** - Phase 1: Basic font support implementation

### Plans

High-level project planning documents:

- **[wasm-project-plan.md](plans/wasm-project-plan.md)** - Overall WebAssembly project architecture and roadmap

### Status

Current project status and progress tracking (see [status/README.md](status/README.md) for details):

- **[project-status.md](status/project-status.md)** - Current status of the SWFRecomp project
- **[2025-11-01-string-variable-implementation.md](status/2025-11-01-string-variable-implementation.md)** - String variable storage and optimization implementation summary

### Merge Analyses

Branch merge documentation for coordinating updates across repositories (see [merge/README.md](merge/README.md) for details):

**Branch Comparison Documents:**
- **[swfrecomp-branch-differences.md](merge/swfrecomp-branch-differences.md)** - Complete diff analysis: SWFRecomp wasm-support vs master
- **[swfmodernruntime-branch-differences.md](merge/swfmodernruntime-branch-differences.md)** - Complete diff analysis: SWFModernRuntime wasm-support vs master

**Merge Analyses:**
- **[swfrecomp-wasm-support-merge-analysis.md](merge/swfrecomp-wasm-support-merge-analysis.md)** - SWFRecomp wasm-support → master merge analysis
- **[swfmodernruntime-wasm-support-merge-analysis.md](merge/swfmodernruntime-wasm-support-merge-analysis.md)** - SWFModernRuntime wasm-support → master merge analysis

### Reference

Manually compiled reference material, separate from the official specifications:

- **[trace-swf4-wasm-generation.md](reference/trace-swf4-wasm-generation.md)** - Complete walkthrough: SWF → C → WebAssembly pipeline
- **[abc-format.md](reference/abc-format.md)** - Technical reference for the ActionScript Byte Code (ABC) file format

### Specifications

Official Adobe Flash and ActionScript specifications (see [specs/README.md](specs/README.md) for detailed source information):

- **[swf-spec-19.txt](specs/swf-spec-19.txt)** - SWF File Format Specification (Version 19)
- **[abc-format-46-16.txt](specs/abc-format-46-16.txt)** - ActionScript Bytecode (ABC) format specification
- **[avm2overview.txt](specs/avm2overview.txt)** - ActionScript Virtual Machine 2 (AVM2) Overview
- **[avm2_opcodes_raw.txt](specs/avm2_opcodes_raw.txt)** - Raw AVM2 opcode reference
- **[opcodes.as](specs/opcodes.as)** - ActionScript opcode definitions
- **[pdf/](specs/pdf/)** - PDF versions of official specifications
- **[swf-spec-19-images/](specs/swf-spec-19-images/)** - Images referenced in SWF specification

### Deprecated

Older documentation that may still be useful for historical reference (see [deprecated/README.md](deprecated/README.md) for details):

- Various implementation plans and analyses that have been superseded by current approaches
- See [deprecated/](deprecated/) directory for full list

### Scripts

Maintenance utilities for the documentation repository (see [scripts/README.md](scripts/README.md) for details):

- **[fix-markdown-formatting.sh](scripts/fix-markdown-formatting.sh)** - Fix consecutive double-asterisk lines in markdown files

## License

See the main [SWFRecomp project](https://github.com/SWFRecomp/SWFRecomp) for licensing information.
