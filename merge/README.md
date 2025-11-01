# Merge Documentation

This directory contains branch merge analysis documents for the SWFRecomp project repositories.

## Purpose

Merge analysis documents provide:
- Comprehensive comparison between branches
- Detailed change summaries
- Merge strategy recommendations
- Risk assessment
- Pre/post-merge verification steps
- Conflict resolution guidance

## Files

### Active Merge Analyses

- **[swfrecomp-wasm-support-merge-analysis.md](swfrecomp-wasm-support-merge-analysis.md)** - Merge analysis for SWFRecomp wasm-support → master
- **[swfmodernruntime-wasm-support-merge-analysis.md](swfmodernruntime-wasm-support-merge-analysis.md)** - Merge analysis for SWFModernRuntime wasm-support → master

### Key Features in These Analyses

Both documents analyze the string variable storage and optimization implementation:

**swfrecomp-wasm-support-merge-analysis.md (SWFRecomp):**
- 16 commits, 62 files modified
- Compiler-side: string ID generation and deduplication
- WASM build infrastructure
- Test framework additions

**swfmodernruntime-wasm-support-merge-analysis.md (SWFModernRuntime):**
- 7 commits, 30 files modified
- Runtime-side: variable storage and memory management
- String ID optimization (O(1) access)
- Comprehensive test suite (24 tests)

## Related Documentation

- **[../status/](../status/)** - Implementation status and summaries
- **[../status/2025-11-01-string-variable-implementation.md](../status/2025-11-01-string-variable-implementation.md)** - Consolidated implementation summary
- **[../deprecated/2025-11-01/](../deprecated/2025-11-01/)** - Archived individual documentation files
