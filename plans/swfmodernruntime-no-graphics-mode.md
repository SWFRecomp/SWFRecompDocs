# SWFModernRuntime NO_GRAPHICS Mode

**Date:** 2025-11-04

**Purpose:** Add headless/console-only mode to SWFModernRuntime for WASM builds without graphics

**Status:** Planning Phase

**Priority:** High (blocks WASM test deployment)

---

## Executive Summary

Currently, **SWFModernRuntime is tightly coupled to SDL3/Vulkan** for graphics rendering. This prevents using it for:
- Simple console-only tests (trace, arithmetic, variables)
- WASM builds (SDL3/WebGPU not yet integrated)
- Headless testing/CI environments
- Quick prototyping

This document proposes adding a **`NO_GRAPHICS`** compilation mode that:
- ✅ Keeps all ActionScript VM functionality (stack, operations, variables)
- ✅ Provides stub implementations for tag functions (tagShowFrame, etc.)
- ✅ Works in both native and WASM builds
- ✅ Allows ~40+ simple tests to build for WASM immediately
- 🔮 Can be upgraded to full graphics later (Phase 2/3)

---

## Problem Statement

### Current Situation

**Attempted WASM build fails at:**
```c
// SWFModernRuntime/src/libswf/swf.c:5
#include <flashbang.h>

// SWFModernRuntime/include/flashbang/flashbang.h:3
#include <SDL3/SDL.h>
```

**Build error:**
```
fatal error: 'SDL3/SDL.h' file not found
```

**Why this blocks us:**
- SDL3 is a native windowing/graphics library
- Not available in Emscripten by default
- Would require SDL3→WebGPU port (future work)
- Graphics rendering is complex (Vulkan/WebGPU shaders, etc.)

### What We Actually Need

**For 40+ simple tests, we only need:**
- ✅ ActionScript VM (PUSH, POP, operations)
- ✅ Variable storage (HashMap-based)
- ✅ Stack operations (24-byte typed entries)
- ✅ Console output (actionTrace)
- ✅ Basic tag stubs (tagShowFrame → no-op)

**We DON'T need:**
- ❌ Window management (SDL3)
- ❌ GPU rendering (Vulkan/WebGPU)
- ❌ Shape drawing
- ❌ Bitmap loading
- ❌ Input handling

---

## Proposed Solution: Conditional Compilation

### Design Principle

Use `#ifndef NO_GRAPHICS` guards to separate console-only functionality from graphics rendering:

```c
// Core ActionScript VM - always included
void actionAdd(char* stack, u32* sp) { ... }
void actionTrace(char* stack, u32* sp) { ... }
void pushVar(...) { ... }

#ifndef NO_GRAPHICS
// Graphics-dependent code - only when graphics enabled
void tagPlaceObject(...) { ... }
void renderFrame(...) { ... }
#endif
```

### Build Modes

**Mode 1: Full Graphics (default, existing behavior)**
```bash
# Native with SDL3/Vulkan
gcc *.c -lSDL3 -lvulkan -o swf_viewer

# Future: WASM with WebGPU
emcc *.c -sUSE_SDL=3 -sUSE_WEBGPU=1 -o swf_viewer.js
```

**Mode 2: NO_GRAPHICS (new mode for simple tests)**
```bash
# Native headless
gcc *.c -DNO_GRAPHICS -o swf_test

# WASM console-only
emcc *.c -DNO_GRAPHICS -o swf_test.js
```

---

## Implementation Plan

### Phase 1: Core Changes to SWFModernRuntime

#### 1.1 Add NO_GRAPHICS Guards to Headers

**File:** `include/libswf/swf.h`

```c
#pragma once

#include <stackvalue.h>

// Core definitions - always included
typedef void (*frame_func)();
extern frame_func frame_funcs[];

typedef struct SWFAppContext
{
    frame_func* frame_funcs;

#ifndef NO_GRAPHICS
    // Graphics-specific fields
    int width;
    int height;
    const float* stage_to_ndc;
    size_t bitmap_count;
    size_t bitmap_highest_w;
    size_t bitmap_highest_h;
    char* shape_data;
    size_t shape_data_size;
    char* transform_data;
    size_t transform_data_size;
    char* color_data;
    size_t color_data_size;
    char* uninv_mat_data;
    size_t uninv_mat_data_size;
    char* gradient_data;
    size_t gradient_data_size;
    char* bitmap_data;
    size_t bitmap_data_size;
#endif
} SWFAppContext;

// Core runtime variables
extern char* stack;
extern u32 sp;
extern u32 oldSP;
extern int quit_swf;
extern size_t next_frame;
extern int manual_next_frame;

#ifndef NO_GRAPHICS
// Graphics-specific exports
extern Character* dictionary;
extern DisplayObject* display_list;
extern size_t max_depth;
#endif

void swfStart(SWFAppContext* app_context);
```

**File:** `include/libswf/tag.h`

```c
#pragma once

#include <common.h>

// Tag function declarations
void tagInit();
void tagShowFrame();
void tagSetBackgroundColor(u8 r, u8 g, u8 b);

#ifndef NO_GRAPHICS
// Graphics tag functions
void tagPlaceObject(u16 char_id, u16 depth, u32 transform_id);
void tagRemoveObject(u16 depth);
void tagDefineShape(/* ... */);
void tagDefineBitmap(/* ... */);
// ... more graphics tags ...
#endif
```

#### 1.2 Separate Implementation Files

**File:** `src/libswf/swf.c` - Split into two files

**New: `src/libswf/swf_core.c`** (console-only functionality)
```c
#include <recomp.h>
#include <swf.h>
// NO flashbang.h dependency!

// Core runtime state
char* stack = NULL;
u32 sp = 0;
u32 oldSP = 0;
int quit_swf = 0;
size_t next_frame = 0;
int manual_next_frame = 0;

// Console-only swfStart
void swfStart(SWFAppContext* app_context)
{
    printf("=== SWF Execution Started ===\n");

    // Initialize stack
    if (!stack) {
        stack = malloc(INITIAL_STACK_SIZE);
        if (!stack) {
            fprintf(stderr, "Failed to allocate stack\n");
            return;
        }
    }
    sp = INITIAL_STACK_SIZE;

    // Initialize variable system
    initializeMap();
    initTime();
    tagInit();

    // Run frames
    size_t current_frame = 0;
    frame_func* funcs = app_context->frame_funcs;

    while (!quit_swf && current_frame < 10000) {
        printf("\n[Frame %zu]\n", current_frame);

        if (funcs[current_frame]) {
            funcs[current_frame]();
        } else {
            printf("No function for frame %zu, stopping.\n", current_frame);
            break;
        }

        if (manual_next_frame) {
            current_frame = next_frame;
            manual_next_frame = 0;
        } else {
            current_frame++;
        }
    }

    printf("\n=== SWF Execution Completed ===\n");

    // Cleanup
    freeMap();
    free(stack);
}
```

**Keep: `src/libswf/swf.c`** (graphics functionality)
```c
#ifndef NO_GRAPHICS

#include <recomp.h>
#include <swf.h>
#include <flashbang.h>  // OK to include here

// Graphics-specific globals
Character* dictionary = NULL;
DisplayObject* display_list = NULL;
size_t max_depth = 0;

// Graphics swfStart implementation
void swfStart_graphics(SWFAppContext* app_context)
{
    // Full graphics initialization
    // SDL3 window creation
    // Vulkan/WebGPU setup
    // Render loop with frame callbacks
    // ... existing implementation ...
}

#endif // NO_GRAPHICS
```

#### 1.3 Tag Stub Implementations

**File:** `src/libswf/tag_stubs.c` (new file)

```c
#include <recomp.h>
#include <tag.h>

#ifdef NO_GRAPHICS

// Stub implementations for console-only mode
void tagInit()
{
    // Nothing to initialize for console mode
}

void tagShowFrame()
{
    printf("[Tag] ShowFrame()\n");
}

void tagSetBackgroundColor(u8 r, u8 g, u8 b)
{
    printf("[Tag] SetBackgroundColor(%d, %d, %d)\n", r, g, b);
}

// Stubs for graphics tags (no-op)
void tagPlaceObject(u16 char_id, u16 depth, u32 transform_id)
{
    printf("[Tag] PlaceObject(char=%d, depth=%d) [ignored in NO_GRAPHICS mode]\n",
           char_id, depth);
}

void tagRemoveObject(u16 depth)
{
    printf("[Tag] RemoveObject(depth=%d) [ignored]\n", depth);
}

#endif // NO_GRAPHICS
```

**Note:** Real graphics implementations stay in `src/libswf/tag.c` (only compiled when graphics enabled)

---

### Phase 2: Build System Updates

#### 2.1 CMake Changes

**File:** `SWFModernRuntime/CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.16)
project(SWFModernRuntime C)

# Option to disable graphics
option(NO_GRAPHICS "Build without graphics support (console-only)" OFF)

# Core sources (always included)
set(CORE_SOURCES
    src/actionmodern/action.c
    src/actionmodern/variables.c
    src/utils.c
    src/libswf/swf_core.c
    lib/c-hashmap/map.c
)

if(NO_GRAPHICS)
    # Console-only mode
    add_definitions(-DNO_GRAPHICS)
    set(TAG_SOURCES src/libswf/tag_stubs.c)
else()
    # Full graphics mode
    set(TAG_SOURCES src/libswf/tag.c)
    set(GRAPHICS_SOURCES
        src/libswf/swf.c
        src/flashbang/flashbang.c
    )

    # Find SDL3
    find_package(SDL3 REQUIRED)
    list(APPEND EXTRA_LIBS SDL3::SDL3)

    # Find Vulkan
    find_package(Vulkan REQUIRED)
    list(APPEND EXTRA_LIBS Vulkan::Vulkan)
endif()

# Create library
add_library(SWFModernRuntime STATIC
    ${CORE_SOURCES}
    ${TAG_SOURCES}
    ${GRAPHICS_SOURCES}
)

target_include_directories(SWFModernRuntime PUBLIC
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_SOURCE_DIR}/include/actionmodern
    ${CMAKE_SOURCE_DIR}/include/libswf
    ${CMAKE_SOURCE_DIR}/lib/c-hashmap
)

if(NOT NO_GRAPHICS)
    target_include_directories(SWFModernRuntime PUBLIC
        ${CMAKE_SOURCE_DIR}/include/flashbang
    )
    target_link_libraries(SWFModernRuntime ${EXTRA_LIBS})
endif()

# Build examples
set(NO_GRAPHICS_EXAMPLES
    examples/console_trace
    examples/console_math
    examples/console_variables
)

foreach(example ${NO_GRAPHICS_EXAMPLES})
    add_executable(${example} ${example}.c)
    target_link_libraries(${example} SWFModernRuntime)
endforeach()
```

#### 2.2 Build Commands

**Console-only build:**
```bash
cd SWFModernRuntime
mkdir build_no_graphics && cd build_no_graphics
cmake .. -DNO_GRAPHICS=ON
make
# Creates: libSWFModernRuntime.a (no SDL3/Vulkan dependency)
```

**Full graphics build (default):**
```bash
cd SWFModernRuntime
mkdir build && cd build
cmake ..
make
# Creates: libSWFModernRuntime.a (with SDL3/Vulkan)
```

---

### Phase 3: Test Integration

#### 3.1 Update SWFRecomp Build Scripts

**File:** `SWFRecomp/scripts/build_test.sh`

Add before the emcc command:
```bash
if [ "$TARGET" == "wasm" ]; then
    # WASM builds use NO_GRAPHICS mode
    DEFINES="-DNO_GRAPHICS"

    # Exclude graphics-only source files
    rm -f "${BUILD_DIR}/swf.c"  # Remove full graphics version
    rm -f "${BUILD_DIR}/flashbang.c"

    # Copy tag stubs instead
    cp "${SWFMODERN_SRC}/libswf/tag_stubs.c" "${BUILD_DIR}/"
    cp "${SWFMODERN_SRC}/libswf/swf_core.c" "${BUILD_DIR}/"
fi

emcc \
    *.c \
    $DEFINES \
    -I. \
    -I"${SWFMODERN_INC}" \
    ...
```

#### 3.2 Test Categories

**Tier 1: Console-only tests (NO_GRAPHICS mode)**
- All trace tests (trace_swf_4, etc.)
- All arithmetic tests (add_floats, multiply, divide, etc.)
- All string tests (string_add, string_concat, etc.)
- All variable tests (float_vars, dyna_string_vars, etc.)
- **Estimated:** ~40 tests

**Tier 2: Graphics tests (require full graphics)**
- Shape drawing tests
- Bitmap tests
- MovieClip tests
- Transform/matrix tests
- **Estimated:** ~16 tests
- **Status:** Future work (Phase 2/3 with WebGPU)

---

## Benefits

### Immediate Benefits (Console-only Mode)

**For Development:**
- ✅ Fast iteration (no graphics dependencies to build)
- ✅ Headless CI/CD testing
- ✅ Easier debugging (console output only)
- ✅ Cross-platform (works anywhere C works)

**For WASM:**
- ✅ ~40 tests can build for WASM immediately
- ✅ No SDL3/WebGPU complexity yet
- ✅ Smaller WASM file sizes (~20-50 KB vs 500KB+ with graphics)
- ✅ Faster load times in browser

**For Testing:**
- ✅ Validate ActionScript VM correctness
- ✅ Test variable storage implementation
- ✅ Verify stack operations
- ✅ Check memory management

### Future Benefits (When Graphics Added)

**Graphics tests can:**
- ✅ Use same SWFModernRuntime codebase
- ✅ Just remove `-DNO_GRAPHICS` flag
- ✅ Automatically get WebGPU rendering (when implemented)
- ✅ No code regeneration needed

---

## Migration Path

### Step 1: Implement NO_GRAPHICS in SWFModernRuntime

**Week 1:**
- [ ] Add `#ifndef NO_GRAPHICS` guards to headers
- [ ] Create `swf_core.c` (console-only swfStart)
- [ ] Create `tag_stubs.c` (stub implementations)
- [ ] Update CMakeLists.txt with NO_GRAPHICS option
- [ ] Test native builds (both modes)

**Validation:**
```bash
# Build with graphics
cmake .. && make
./test_trace_with_graphics

# Build without graphics
cmake .. -DNO_GRAPHICS=ON && make
./test_trace_no_graphics

# Both should produce same console output
```

### Step 2: Update Test Build Scripts

**Week 2:**
- [ ] Update `SWFRecomp/scripts/build_test.sh` to use NO_GRAPHICS for WASM
- [ ] Test with trace_swf_4
- [ ] Test with arithmetic tests (add_floats, etc.)
- [ ] Test with variable tests (dyna_string_vars, etc.)

**Validation:**
```bash
./scripts/build_test.sh trace_swf_4 wasm
# Should build successfully without SDL3 errors
```

### Step 3: Batch Enable WASM for Console Tests

**Week 3:**
- [ ] Identify all console-only tests (grep test names)
- [ ] Build all in batch: `./scripts/build_all_examples.sh`
- [ ] Deploy to `SWFRecompDocs/docs/examples/`
- [ ] Create index page listing all examples

**Result:** ~40 interactive WASM demos live on documentation site

### Step 4: Graphics Support (Future)

**Month 2-3 (separate project):**
- [ ] Port SDL3 to Emscripten (or use SDL3 Emscripten port when available)
- [ ] Implement WebGPU rendering backend
- [ ] Build graphics tests for WASM
- [ ] Remove `-DNO_GRAPHICS` flag from graphics tests
- [ ] Deploy graphics demos

---

## Technical Details

### Stack Allocation

**Console-only mode:**
```c
// Allocate 8MB stack on heap
stack = malloc(INITIAL_STACK_SIZE);  // 8388608 bytes
sp = INITIAL_STACK_SIZE;
```

**Why 8MB?**
- SWFModernRuntime uses downward-growing stack
- Complex SWFs with many variables need space
- WASM allows dynamic memory growth

**Alternative for simple tests:**
```c
#ifdef NO_GRAPHICS
#define INITIAL_STACK_SIZE 1048576  // 1MB for console tests
#else
#define INITIAL_STACK_SIZE 8388608  // 8MB for graphics
#endif
```

### File Organization

**Before (current):**
```
SWFModernRuntime/src/
├── actionmodern/          # Core VM
├── flashbang/             # Graphics (SDL3/Vulkan)
└── libswf/
    ├── swf.c              # BOTH core + graphics mixed
    └── tag.c              # BOTH tag stubs + graphics
```

**After (proposed):**
```
SWFModernRuntime/src/
├── actionmodern/          # Core VM (always)
├── flashbang/             # Graphics (only without NO_GRAPHICS)
└── libswf/
    ├── swf_core.c         # Core runtime (always)
    ├── swf.c              # Graphics runtime (only without NO_GRAPHICS)
    ├── tag_stubs.c        # Tag stubs (only with NO_GRAPHICS)
    └── tag.c              # Tag graphics (only without NO_GRAPHICS)
```

### Conditional Compilation Summary

**Headers** (`.h` files):
- Use `#ifndef NO_GRAPHICS` around graphics-specific declarations
- Keep core functionality always visible

**Implementation** (`.c` files):
- **Option A:** Use `#ifndef NO_GRAPHICS` within files
- **Option B:** Separate files entirely (cleaner, recommended)

**Build system:**
- CMake selectively compiles based on NO_GRAPHICS option
- Shell scripts pass `-DNO_GRAPHICS` flag to compiler

---

## Testing Strategy

### Unit Tests

**Test:** Console-only mode works correctly
```c
// test_no_graphics.c
#include <recomp.h>
#include <swf.h>

frame_func test_frames[] = {
    test_frame_0,
    NULL
};

void test_frame_0() {
    PUSH_STR_ID("Hello, NO_GRAPHICS!", 18, 0);
    actionTrace(stack, &sp);
    quit_swf = 1;
}

int main() {
    SWFAppContext ctx = {
        .frame_funcs = test_frames
    };
    swfStart(&ctx);
    return 0;
}
```

**Expected output:**
```
=== SWF Execution Started ===

[Frame 0]
Hello, NO_GRAPHICS!

=== SWF Execution Completed ===
```

### Integration Tests

**Build Matrix:**
| Platform | Mode | Tool | Expected Result |
|----------|------|------|-----------------|
| Linux | NO_GRAPHICS | gcc | ✅ Builds & runs |
| Linux | Graphics | gcc + SDL3 | ✅ Builds & runs |
| macOS | NO_GRAPHICS | clang | ✅ Builds & runs |
| WASM | NO_GRAPHICS | emcc | ✅ Builds & runs |
| WASM | Graphics | emcc + WebGPU | 🔮 Future |

### Validation Criteria

**For NO_GRAPHICS mode:**
- ✅ Compiles without SDL3/Vulkan
- ✅ All ActionScript operations work
- ✅ Variable storage works
- ✅ Stack operations correct
- ✅ Console output matches expected
- ✅ Binary size <100KB for simple tests

---

## Related Documents

- **Test Compatibility:** `plans/swfmodernruntime-test-compatibility.md`
- **Graphics Roadmap:** `reference/trace-swf4-wasm-generation.md` (Phase 1/2/3)
- **Architecture:** `deprecated/2025-11-01/swfrecomp-vs-swfmodernruntime-separation.md`

---

## Success Metrics

### Phase 1 Complete When:
- [ ] `cmake -DNO_GRAPHICS=ON` builds successfully
- [ ] Native console tests run with NO_GRAPHICS mode
- [ ] All ActionScript operations work (trace, math, variables)
- [ ] No SDL3/flashbang.h dependencies in console-only build

### Phase 2 Complete When:
- [ ] WASM builds work with NO_GRAPHICS mode
- [ ] `./scripts/build_test.sh trace_swf_4 wasm` succeeds
- [ ] Browser displays correct output
- [ ] 40+ tests deployed to docs/examples/

### Long-term Success:
- [ ] Graphics mode still works (backward compatible)
- [ ] Easy to switch between modes (CMake option)
- [ ] Clear separation between core VM and graphics
- [ ] Foundation ready for WebGPU integration (Phase 3)

---

## Conclusion

Adding NO_GRAPHICS support to SWFModernRuntime:

1. **Unblocks WASM deployment** for ~40 console-only tests
2. **Maintains clean architecture** (separation of concerns)
3. **Enables headless testing** (CI/CD, unit tests)
4. **Prepares for future graphics** (Phase 2/3 WebGPU)
5. **Low risk** (new code, doesn't break existing functionality)

**Recommended approach:** Separate files (`swf_core.c`, `tag_stubs.c`) rather than heavy use of `#ifdef` within files - cleaner and easier to maintain.

**Next steps:**
1. Create PR in SWFModernRuntime repository
2. Implement Phase 1 (console-only mode)
3. Test with native builds
4. Update SWFRecomp build scripts
5. Deploy WASM examples
