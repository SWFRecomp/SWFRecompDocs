# SWFModernRuntime Test Compatibility Plan

**Date:** 2025-11-04

**Purpose:** Align test build system to use SWFModernRuntime instead of stub runtimes

**Status:** Planning Phase

---

## Executive Summary

Currently, the two WASM-enabled tests (`trace_swf_4` and `dyna_string_vars_swf_4`) use **stub runtimes** (~150 lines) in their `runtime/` directories. However, the **intended architecture** is for all tests to link against **SWFModernRuntime**, a production-quality library with:

- Sophisticated 24-byte typed stack entries
- String list optimizations
- Variable storage with HashMap
- Full ActionScript operation support

This document outlines how to:
1. ✅ Use SWFModernRuntime for both native and WASM builds
2. ✅ Eliminate duplicated stub runtimes
3. ✅ Maintain consistency with the existing CMake-based tests
4. ✅ Enable easy WASM deployment for all ~50 tests

---

## Current State Analysis

### Existing Architecture (CMake Tests)

The **CMakeLists.txt** in tests already shows the intended design:

```cmake
# tests/trace_swf_4/CMakeLists.txt
set(RUNTIME_INCLUDES
    ${CMAKE_SOURCE_DIR}/../SWFModernRuntime/include
    ${CMAKE_SOURCE_DIR}/../SWFModernRuntime/include/actionmodern
    ${CMAKE_SOURCE_DIR}/../SWFModernRuntime/include/libswf
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    RecompiledTags
    RecompiledScripts
    ${PROJECT_SOURCE_DIR}/SWFModernRuntime.lib  # ← Links against full runtime!
)
```

### The Problem: Stub Runtimes for WASM

Only 2 tests have WASM support, and they use **stub runtimes**:

```
tests/trace_swf_4/runtime/
├── native/
│   ├── main.c          (28 lines)
│   ├── runtime.c       (76 lines)
│   └── include/
│       ├── recomp.h    (63 lines)
│       └── stackvalue.h
└── wasm/
    ├── main.c          (28 lines)
    ├── runtime.c       (76 lines)
    ├── recomp.h        (63 lines)
    ├── stackvalue.h
    └── index.html      (200 lines)
```

**Total duplication:** ~700 lines per test with WASM support

**Issues with stub runtimes:**
1. ❌ Different stack architecture (grows UP vs DOWN)
2. ❌ Different stack entry size (variable vs 24 bytes)
3. ❌ No type tags (can't distinguish string vs float)
4. ❌ Limited ActionScript support (trace only)
5. ❌ No variable storage
6. ❌ Incompatible with SWFRecomp's intended output

---

## Stack Architecture Comparison

### Stub Runtime Stack

```
Stack Layout (Simple):
┌─────────────────────────────────────┐
│ Byte 0-13: "sup from SWF 4"         │  ← String data
│ Byte 14:   '\0'                      │  ← Null terminator
│ sp = 15                              │  ← Stack pointer
└─────────────────────────────────────┘

Size: 4 KB (4096 bytes)
Growth: UP (sp starts at 0, increases)
Type info: NONE
```

**PUSH_STR macro (stub):**
```c
#define PUSH_STR(str, len) do { \
    memcpy(stack + (*sp), str, len);  // Copy bytes
    (*sp) += len;                      // Advance sp
    stack[(*sp)++] = '\0';            // Null terminate
} while(0)
```

### SWFModernRuntime Stack

```
Stack Layout (Production):
┌─────────────────────────────────────┐
│ 8MB (top)                            │
│ sp = 8388584 (after push)            │
│ ┌───────────────────────────────────┤
│ │ [0]:  Type = 0 (STRING)           │  ← 1 byte
│ │ [1-3]: Padding                    │  ← 3 bytes
│ │ [4-7]: Old SP = 8388608           │  ← 4 bytes (linked list)
│ │ [8-11]: String length = 14        │  ← 4 bytes
│ │ [12-15]: String ID = 0            │  ← 4 bytes
│ │ [16-23]: Pointer to "sup..."      │  ← 8 bytes (u64)
│ └───────────────────────────────────┤
│ ... (rest of stack)                  │
│ 0 (bottom)                           │
└─────────────────────────────────────┘

Size: 8 MB (8388608 bytes)
Growth: DOWN (sp starts at 8MB, decreases)
Type info: Type byte + typed union
Entry size: 24 bytes (aligned to 8)
```

**PUSH_STR_ID macro (SWFModernRuntime):**
```c
#define PUSH_STR_ID(v, n, id) \
    oldSP = *sp; \
    *sp -= 4 + 4 + 8 + 8;              // Allocate 24 bytes
    *sp &= ~7;                          // Align to 8 bytes
    stack[*sp] = ACTION_STACK_VALUE_STRING;  // Type = 0
    VAL(u32, &stack[*sp + 4]) = id;    // String ID (optimization)
    VAL(u32, &stack[*sp + 8]) = n;     // Length
    VAL(char*, &stack[*sp + 16]) = v;  // Pointer
```

---

## SWFRecomp Code Generation Analysis

### What SWFRecomp Actually Generates

Looking at `SWFRecomp/src/action/action.cpp`, the code generation is **already designed for SWFModernRuntime**:

```cpp
// Line 278: Push string with ID
out_script << "\t" << "PUSH_STR_ID(str_" << to_string(str_id) << ", "
           << push_str_len << ", " << str_id << ");" << endl;

// Line 294: Push float
out_script << "\t" << "PUSH(ACTION_STACK_VALUE_F32, " << hex_float << ");" << endl;
```

**Generated code example (RecompiledScripts/script_0.c):**
```c
void script_0(char* stack, u32* sp)
{
    // Push (String)
    PUSH_STR_ID(str_0, 14, 0);  // ← Uses SWFModernRuntime macro!
    // Trace
    actionTrace(stack, sp);     // ← Calls SWFModernRuntime function!
}
```

### The Incompatibility

The stub runtime defines **different macros**:
```c
// Stub runtime: Simple byte copy
#define PUSH_STR(str, len) memcpy(stack + (*sp), str, len); ...
```

SWFModernRuntime defines **typed stack entries**:
```c
// SWFModernRuntime: 24-byte typed entry with ID optimization
#define PUSH_STR_ID(v, n, id) *sp -= 24; stack[*sp] = TYPE_STRING; ...
```

When you compile generated code with stub runtime headers, **it compiles** because the macros exist, but the **runtime behavior is wrong** because the stack layouts are incompatible.

---

## Root Cause: Historical Development

Based on the documentation, here's what happened:

1. **Original Design (Correct):**
   - SWFRecomp generates code using SWFModernRuntime macros
   - Tests link against `SWFModernRuntime.lib`
   - CMakeLists.txt shows this intent

2. **WASM Prototyping (Divergence):**
   - Someone needed WASM builds quickly
   - Created stub runtimes to avoid Emscripten complexity
   - Stub runtimes "worked" for simple tests (trace only)
   - Never migrated back to full runtime

3. **Current State (Technical Debt):**
   - 2 tests use stub runtimes (WASM-enabled)
   - ~48 tests use CMake + SWFModernRuntime (native only)
   - Stack incompatibility exists but hidden by simple tests
   - Can't use advanced features (variables, complex ActionScript)

---

## Solution: Use SWFModernRuntime Everywhere

### Design Principle

**Tests should not contain runtime code.** Tests should only contain:
- `test.swf` (input)
- `config.toml` (SWFRecomp configuration)
- `main.c` (minimal entry point, if needed)
- Generated code (RecompiledScripts/*, RecompiledTags/*)

All runtime logic lives in **SWFModernRuntime**.

### Proposed Architecture

```
SWFModernRuntime/                     # Production runtime (shared)
├── src/actionmodern/
│   ├── action.c                      # All ActionScript operations
│   └── variables.c                   # Variable storage + HashMap
├── include/
│   ├── actionmodern/
│   │   ├── action.h                  # Stack macros: PUSH, POP, etc.
│   │   └── variables.h               # Variable API
│   └── libswf/
│       └── recomp.h                  # Main runtime header
└── build/
    └── libSWFModernRuntime.a         # Pre-built static library

SWFRecomp/
├── wasm_wrappers/                    # NEW: Minimal WASM glue code
│   ├── main.c                        # Entry point with Emscripten exports
│   └── index_template.html           # HTML template for browser
├── scripts/
│   ├── build_test.sh                 # Unified build script
│   ├── deploy_example.sh             # Deployment script
│   └── build_all_examples.sh         # Batch build
└── tests/
    ├── trace_swf_4/
    │   ├── test.swf                  # Test input
    │   ├── config.toml               # Configuration
    │   ├── main.c                    # Optional entry point
    │   ├── RecompiledScripts/        # Generated by SWFRecomp
    │   ├── RecompiledTags/           # Generated by SWFRecomp
    │   └── build/
    │       ├── native/               # Native build (gcc + libSWFModernRuntime.a)
    │       └── wasm/                 # WASM build (emcc + SWFModernRuntime sources)
    └── [48 other tests]/             # Same structure
```

---

## Implementation Options

### Option 1: Compile SWFModernRuntime Sources Directly (Recommended)

**For WASM builds:**
- Copy SWFModernRuntime source files to build directory
- Compile everything with Emscripten
- No need for pre-built WASM library

**Advantages:**
- ✅ Simpler build process
- ✅ No library versioning issues
- ✅ Easier to debug (all source available)
- ✅ Emscripten can optimize across all files

**Build command:**
```bash
emcc \
    main.c \
    action.c variables.c utils.c \          # SWFModernRuntime sources
    map.c \                                  # HashMap library
    tagMain.c constants.c draws.c \          # Generated SWF code
    script_0.c script_defs.c \               # Generated scripts
    -I${SWFMODERN_INC} \                     # SWFModernRuntime headers
    -I${SWFMODERN_INC}/actionmodern \
    -I${SWFMODERN_INC}/libswf \
    -o test.js \
    -s WASM=1 \
    -O2
```

### Option 2: Pre-Build SWFModernRuntime for WASM

**Build SWFModernRuntime once:**
```bash
cd SWFModernRuntime
emcc src/**/*.c -o build/libSWFModernRuntime.wasm.a
```

**Link tests against it:**
```bash
emcc test_files.c -lSWFModernRuntime.wasm.a -o test.js
```

**Advantages:**
- ✅ Faster incremental builds
- ✅ Runtime built once, reused many times

**Disadvantages:**
- ❌ More complex setup
- ❌ Need to rebuild library when runtime changes
- ❌ Library versioning complexity

**Recommendation:** Use **Option 1** for simplicity.

---

## Build Script Design

### Unified Build Script

**File:** `SWFRecomp/scripts/build_test.sh`

```bash
#!/bin/bash
# Usage: ./scripts/build_test.sh <test_name> [native|wasm]

set -e

TEST_NAME=$1
TARGET=${2:-wasm}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWFRECOMP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${SWFRECOMP_ROOT}/tests/${TEST_NAME}"
BUILD_DIR="${TEST_DIR}/build/${TARGET}"

# Setup paths
SWFMODERN_ROOT="${SWFRECOMP_ROOT}/../SWFModernRuntime"
SWFMODERN_SRC="${SWFMODERN_ROOT}/src"
SWFMODERN_INC="${SWFMODERN_ROOT}/include"

# Run SWFRecomp if needed
if [ ! -d "${TEST_DIR}/RecompiledScripts" ]; then
    echo "Running SWFRecomp..."
    cd "${TEST_DIR}"
    "${SWFRECOMP_ROOT}/build/SWFRecomp" config.toml
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

if [ "$TARGET" == "wasm" ]; then
    # Copy WASM wrapper
    cp "${SWFRECOMP_ROOT}/wasm_wrappers/main.c" "${BUILD_DIR}/"
    cp "${SWFRECOMP_ROOT}/wasm_wrappers/index_template.html" "${BUILD_DIR}/index.html"
    sed -i "s/{{TEST_NAME}}/${TEST_NAME}/g" "${BUILD_DIR}/index.html"

    # Copy SWFModernRuntime sources
    cp "${SWFMODERN_SRC}/actionmodern/action.c" "${BUILD_DIR}/"
    cp "${SWFMODERN_SRC}/actionmodern/variables.c" "${BUILD_DIR}/"
    cp "${SWFMODERN_SRC}/utils.c" "${BUILD_DIR}/"
    cp "${SWFMODERN_ROOT}/lib/c-hashmap/map.c" "${BUILD_DIR}/"

    # Copy generated files
    cp "${TEST_DIR}/RecompiledScripts"/*.c "${BUILD_DIR}/" 2>/dev/null || true
    cp "${TEST_DIR}/RecompiledScripts"/*.h "${BUILD_DIR}/" 2>/dev/null || true
    cp "${TEST_DIR}/RecompiledTags"/*.c "${BUILD_DIR}/" 2>/dev/null || true
    cp "${TEST_DIR}/RecompiledTags"/*.h "${BUILD_DIR}/" 2>/dev/null || true

    # Build with Emscripten
    cd "${BUILD_DIR}"
    emcc \
        *.c \
        -I. \
        -I"${SWFMODERN_INC}" \
        -I"${SWFMODERN_INC}/actionmodern" \
        -I"${SWFMODERN_INC}/libswf" \
        -I"${SWFMODERN_ROOT}/lib/c-hashmap" \
        -o "${TEST_NAME}.js" \
        -s WASM=1 \
        -s EXPORTED_FUNCTIONS='["_main","_runSWF"]' \
        -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \
        -s ALLOW_MEMORY_GROWTH=1 \
        -s INITIAL_MEMORY=16MB \
        -O2

    echo "✅ WASM build complete: ${BUILD_DIR}/${TEST_NAME}.wasm"

else
    # Native build: use existing CMake or link against libSWFModernRuntime.a
    cd "${TEST_DIR}"
    if [ -f "CMakeLists.txt" ]; then
        mkdir -p build/native
        cd build/native
        cmake ../..
        make
        echo "✅ Native build complete: ${BUILD_DIR}/${PROJECT_NAME}"
    else
        echo "❌ No CMakeLists.txt found for native build"
        exit 1
    fi
fi
```

---

## Required Changes

### Phase 1: Update SWFModernRuntime (If Needed)

**Check current state of SWFModernRuntime:**

1. **Verify headers exist:**
   - `include/actionmodern/action.h` - Defines PUSH_STR_ID, PUSH, POP macros
   - `include/actionmodern/variables.h` - Defines ActionVar, variable functions
   - `include/libswf/recomp.h` - Main header that includes others

2. **Verify source files exist:**
   - `src/actionmodern/action.c` - Implements actionTrace, actionAdd, etc.
   - `src/actionmodern/variables.c` - Implements variable storage

3. **Check for missing functionality:**
   - String ownership in variables (see swfrecomp-vs-swfmodernruntime-separation.md)
   - Proper cleanup in freeMap()

**If SWFModernRuntime is incomplete:** Follow the implementation plan in `swfrecomp-vs-swfmodernruntime-separation.md` to add string ownership.

### Phase 2: Create WASM Wrappers

**File:** `SWFRecomp/wasm_wrappers/main.c`

```c
#include <recomp.h>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>

EMSCRIPTEN_KEEPALIVE
void runSWF() {
    printf("Starting SWF execution from JavaScript...\n");
    swfStart(frame_funcs);
}
#endif

int main() {
    printf("WASM SWF Runtime Loaded!\n");
    printf("This is a recompiled Flash SWF running in WebAssembly.\n\n");

#ifndef __EMSCRIPTEN__
    swfStart(frame_funcs);
#else
    printf("Call runSWF() from JavaScript to execute the SWF.\n");
#endif

    return 0;
}
```

**File:** `SWFRecomp/wasm_wrappers/index_template.html`

(Use existing HTML template from trace_swf_4/runtime/wasm/index.html with `{{TEST_NAME}}` placeholders)

### Phase 3: Create Build Scripts

1. **build_test.sh** - Build single test (native or WASM)
2. **deploy_example.sh** - Deploy WASM build to docs/examples/
3. **build_all_examples.sh** - Batch build all tests

(See "Build Script Design" section above for implementation)

### Phase 4: Test Migration

**For each test (starting with trace_swf_4):**

1. ✅ Verify test has CMakeLists.txt that references SWFModernRuntime
2. ✅ Run SWFRecomp to regenerate code
3. ✅ Test native build with CMake
4. ✅ Test WASM build with new script: `./scripts/build_test.sh trace_swf_4 wasm`
5. ✅ Compare output with existing WASM build (should be identical behavior)
6. ✅ Deploy to docs: `./scripts/deploy_example.sh trace_swf_4`
7. ✅ Remove old `runtime/` directory (if exists)
8. ✅ Update test README

### Phase 5: Enable WASM for All Tests

Once the system is proven with trace_swf_4:

```bash
# Build all tests
./scripts/build_all_examples.sh

# This will:
# 1. Iterate through all tests in tests/
# 2. Run SWFRecomp if needed
# 3. Build WASM with SWFModernRuntime
# 4. Deploy to docs/examples/
```

---

## Migration Strategy

### Step-by-Step Migration

**Week 1: Foundation**
- [ ] Audit SWFModernRuntime completeness
- [ ] Add missing string ownership (if needed)
- [ ] Create wasm_wrappers/ directory
- [ ] Create build scripts

**Week 2: Proof of Concept**
- [ ] Migrate trace_swf_4 to use SWFModernRuntime
- [ ] Test native build (should already work via CMake)
- [ ] Test WASM build with new script
- [ ] Verify output matches expected behavior
- [ ] Deploy to docs/examples/trace_swf_4/

**Week 3: Validation**
- [ ] Migrate dyna_string_vars_swf_4 (complex test with variables)
- [ ] Verify variable storage works correctly
- [ ] Test string concatenation + storage
- [ ] Compare performance (stub runtime vs full runtime)

**Week 4: Batch Migration**
- [ ] Enable WASM for 10-20 simple tests (trace, arithmetic)
- [ ] Deploy all to docs/examples/
- [ ] Create index page listing all examples

**Week 5: Cleanup**
- [ ] Remove all stub runtime/ directories
- [ ] Update documentation
- [ ] Add CI/CD pipeline for automatic WASM builds

---

## Testing Strategy

### Test Cases

1. **Simple trace test:**
   ```actionscript
   trace("Hello, World!");
   ```
   **Expected:** Output "Hello, World!" in console

2. **String concatenation:**
   ```actionscript
   trace("Hello" + "World");
   ```
   **Expected:** Output "HelloWorld" (test STR_LIST handling)

3. **Variable storage:**
   ```actionscript
   x = "test";
   trace(x);
   ```
   **Expected:** Output "test" (test variable storage)

4. **Complex arithmetic:**
   ```actionscript
   x = 1 + 2 * 3;
   trace(x);
   ```
   **Expected:** Output "7" (test operator precedence)

5. **Float operations:**
   ```actionscript
   trace(1.5 + 2.5);
   ```
   **Expected:** Output "4" (test float arithmetic)

### Validation Criteria

**For each migrated test:**
- ✅ Native build compiles without errors
- ✅ WASM build compiles without errors
- ✅ WASM file size is reasonable (<100 KB for simple tests)
- ✅ Browser execution produces expected output
- ✅ No console errors in browser
- ✅ Stack operations work correctly
- ✅ Variable storage works correctly (if test uses variables)

---

## Benefits of Migration

### Before (Current State)

- ❌ Stub runtimes duplicated in each WASM test (~700 lines each)
- ❌ Only 2/50 tests have WASM support
- ❌ Incompatible stack architectures
- ❌ Limited ActionScript support (trace only in stubs)
- ❌ No variable storage in WASM builds
- ❌ Manual setup required for each new WASM test

### After (With SWFModernRuntime)

- ✅ Zero runtime code in test directories
- ✅ Single source of truth (SWFModernRuntime)
- ✅ Consistent stack architecture
- ✅ Full ActionScript support (all operations)
- ✅ Variable storage works in WASM
- ✅ One command to enable WASM for any test
- ✅ All ~50 tests can have WASM demos
- ✅ Easier to maintain and debug

---

## Risk Mitigation

### Potential Issues

1. **WASM Binary Size**
   - **Risk:** Full runtime increases WASM size
   - **Mitigation:** Use Emscripten optimization flags (-O2, -Os)
   - **Mitigation:** Strip unused functions with --gc-sections
   - **Expected:** ~20-50 KB per test (acceptable)

2. **Stack Size**
   - **Risk:** 8 MB stack might be excessive for browser
   - **Mitigation:** Emscripten's ALLOW_MEMORY_GROWTH=1 handles this
   - **Mitigation:** Actual usage depends on test complexity
   - **Expected:** Simple tests use <1 KB of stack

3. **Performance**
   - **Risk:** Complex stack layout might be slower
   - **Mitigation:** WASM JIT compilation is very fast
   - **Mitigation:** 24-byte stack entries are cache-friendly
   - **Expected:** No noticeable performance difference for simple tests

4. **Compatibility Issues**
   - **Risk:** Some generated code might not work with full runtime
   - **Mitigation:** SWFRecomp already generates compatible code
   - **Mitigation:** Test incrementally (one test at a time)
   - **Expected:** Should work with minimal/no changes

---

## Success Metrics

### Quantitative Goals

- ✅ All ~50 tests build for WASM without errors
- ✅ All tests produce expected output in browser
- ✅ WASM binary size <100 KB per test
- ✅ Build time <30 seconds per test
- ✅ Zero lines of runtime code in test directories

### Qualitative Goals

- ✅ Developers can add WASM support with one command
- ✅ Documentation clearly explains the architecture
- ✅ Codebase is easier to maintain
- ✅ New ActionScript features work automatically in all tests

---

## Related Documents

- **Architecture:** `deprecated/2025-11-01/swfrecomp-vs-swfmodernruntime-separation.md`
- **WASM Process:** `reference/trace-swf4-wasm-generation.md`
- **String Variables:** `deprecated/2025-11-01/string-variable-storage-summary.md`
- **Test Streamlining:** `plans/streamline-test-builds.md`

---

## Conclusion

The test build system should use **SWFModernRuntime** for both native and WASM builds. The stub runtimes were a prototyping shortcut that created technical debt. By migrating to the full runtime:

1. **Tests align with intended architecture** (CMakeLists.txt already expects this)
2. **SWFRecomp generates compatible code** (already uses PUSH_STR_ID, etc.)
3. **Eliminates duplication** (no more stub runtimes)
4. **Enables advanced features** (variables, complex ActionScript)
5. **Simplifies maintenance** (single source of truth)

The migration can be done **incrementally** with low risk, starting with simple tests and validating each step.

**Next steps:**
1. Audit SWFModernRuntime completeness
2. Create wasm_wrappers/ and build scripts
3. Migrate trace_swf_4 as proof of concept
4. Batch-migrate remaining tests
5. Remove stub runtimes and document new process
