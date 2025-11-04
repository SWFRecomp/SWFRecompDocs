# WASM Build Process with NO_GRAPHICS Mode

**Last Updated:** 2025-11-04

**Purpose:** Step-by-step guide for building SWF tests to WebAssembly using the NO_GRAPHICS runtime

---

## Overview

The WASM build process uses **SWFModernRuntime in NO_GRAPHICS mode**, enabling console-only tests to compile to WebAssembly without SDL3/Vulkan dependencies. This process generates three files:

- `<test_name>.wasm` - WebAssembly binary (~19 KB for simple tests)
- `<test_name>.js` - Emscripten JavaScript loader (~14 KB)
- `index.html` - Browser interface (~6 KB)

---

## Prerequisites

### 1. Install Emscripten SDK

**One-time setup:**

```bash
# Clone Emscripten SDK (if not already installed)
git clone https://github.com/emscripten-core/emsdk.git ~/tools/emsdk
cd ~/tools/emsdk

# Install latest version
./emsdk install latest
./emsdk activate latest
```

**Verify installation:**

```bash
source ~/tools/emsdk/emsdk_env.sh
emcc --version
```

**Expected output:**
```
emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 4.0.18
```

### 2. Build SWFRecomp (if not already built)

```bash
cd ~/projects/SWFRecomp
mkdir -p build && cd build
cmake ..
make
```

### 3. Directory Structure

Ensure projects are organized as sibling directories:

```
~/projects/
├── SWFRecomp/              # Recompiler tool
├── SWFModernRuntime/       # Runtime library
└── SWFRecompDocs/          # Documentation
```

---

## Quick Start: Building a Test

### Single Test Build

```bash
# 1. Activate Emscripten (required for each new shell session)
source ~/tools/emsdk/emsdk_env.sh

# 2. Navigate to SWFRecomp directory
cd ~/projects/SWFRecomp

# 3. Build test for WASM
./scripts/build_test.sh trace_swf_4 wasm
```

**Output:**
```
Setting up build directory...
Copying SWFModernRuntime sources...
Using NO_GRAPHICS mode for WASM build...
Copying generated files...
Building WASM with SWFModernRuntime...

✅ WASM build complete!
Output: /home/user/projects/SWFRecomp/tests/trace_swf_4/build/wasm/trace_swf_4.wasm

To test:
  cd /home/user/projects/SWFRecomp/tests/trace_swf_4/build/wasm
  python3 -m http.server 8000
  Open http://localhost:8000/index.html
```

### Test in Browser

```bash
# Navigate to build directory
cd ~/projects/SWFRecomp/tests/trace_swf_4/build/wasm

# Start local web server
python3 -m http.server 8000

# Open browser to:
# http://localhost:8000/index.html
```

---

## Detailed Build Process

### Step 1: Activate Emscripten

**Every shell session must activate Emscripten before building:**

```bash
source ~/tools/emsdk/emsdk_env.sh
```

**What this does:**
- Adds `emcc` compiler to PATH
- Sets environment variables (EMSDK, EMSDK_NODE)
- Configures Emscripten cache paths

**To suppress activation messages:**
```bash
EMSDK_QUIET=1 source ~/tools/emsdk/emsdk_env.sh
```

**To activate automatically on shell startup (optional):**

Add to `~/.bashrc` or `~/.zshrc`:
```bash
# Activate Emscripten automatically
source ~/tools/emsdk/emsdk_env.sh > /dev/null 2>&1
```

### Step 2: Run SWFRecomp (if needed)

If the test hasn't been recompiled yet, or you've modified the SWF:

```bash
cd ~/projects/SWFRecomp/tests/trace_swf_4
../../build/SWFRecomp config.toml
```

This generates:
- `RecompiledScripts/` - Translated ActionScript
- `RecompiledTags/` - Frame execution code

### Step 3: Build with build_test.sh

```bash
cd ~/projects/SWFRecomp
./scripts/build_test.sh trace_swf_4 wasm
```

**What the script does:**

1. **Validates inputs**
   - Checks test directory exists
   - Verifies Emscripten is available

2. **Sets up build directory**
   - Creates `tests/<test_name>/build/wasm/`
   - Cleans previous build (fresh start)

3. **Copies WASM wrapper files**
   - `wasm_wrappers/main.c` → Entry point with Emscripten exports
   - `wasm_wrappers/index_template.html` → Browser interface
   - Substitutes `{{TEST_NAME}}` with actual test name

4. **Copies SWFModernRuntime sources**
   - Core: `action.c`, `variables.c`, `utils.c`
   - NO_GRAPHICS: `swf_core.c`, `tag_stubs.c`
   - Dependencies: `map.c` (hashmap)

5. **Copies generated files**
   - From `RecompiledScripts/`: `script_*.c`
   - From `RecompiledTags/`: `tagMain.c`, `constants.c`, etc.

6. **Compiles with Emscripten**
   - Compiler: `emcc`
   - Flags: `-DNO_GRAPHICS`, `-O2`, `-s WASM=1`
   - Output: `<test_name>.wasm` + `<test_name>.js`

### Step 4: Generated Files

**Build output directory:**
```
tests/trace_swf_4/build/wasm/
├── trace_swf_4.wasm        # WebAssembly binary (19 KB)
├── trace_swf_4.js          # JavaScript loader (14 KB)
├── index.html              # Browser interface (6 KB)
└── *.c                     # Source files (for debugging)
```

---

## Build Modes: Native vs WASM

### Native Build (with graphics)

```bash
./scripts/build_test.sh trace_swf_4 native
```

**Compiles with:**
- Full graphics mode (SDL3/Vulkan)
- `swf.c` and `tag.c` (graphics implementations)
- `flashbang.c` (rendering backend)
- Uses gcc/clang

**Output:** Native executable for local testing

### WASM Build (console-only)

```bash
./scripts/build_test.sh trace_swf_4 wasm
```

**Compiles with:**
- NO_GRAPHICS mode (console-only)
- `swf_core.c` and `tag_stubs.c` (stub implementations)
- No flashbang/SDL3/Vulkan
- Uses emcc

**Output:** WebAssembly for browser deployment

---

## Understanding NO_GRAPHICS Mode

### What's Included

✅ **Full ActionScript VM:**
- Stack operations (PUSH, POP)
- Arithmetic (add, subtract, multiply, divide)
- String operations (concatenate, length)
- Variables (get, set)
- Control flow (if, goto)
- Trace output

✅ **Core Runtime:**
- 24-byte typed stack entries
- HashMap-based variable storage
- Array optimization for string IDs
- Proper memory management

✅ **Tag Stubs:**
- `tagShowFrame()` - Prints to console
- `tagSetBackgroundColor()` - Prints to console
- Other graphics tags ignored

### What's Excluded

❌ **Graphics Rendering:**
- No SDL3 window creation
- No Vulkan/WebGPU rendering
- No shape drawing
- No bitmap loading

❌ **Input Handling:**
- No keyboard input
- No mouse input
- No touch events

This makes the WASM binary **much smaller** and **faster to load**.

---

## Compilation Details

### Emscripten Flags Explained

```bash
emcc \
    *.c \                                        # All C source files
    -DNO_GRAPHICS \                              # Enable NO_GRAPHICS mode
    -I. \                                        # Include current directory
    -I"${SWFMODERN_INC}" \                       # SWFModernRuntime headers
    -I"${SWFMODERN_INC}/actionmodern" \          # ActionScript VM headers
    -I"${SWFMODERN_INC}/libswf" \                # Runtime headers
    -I"${SWFMODERN_ROOT}/lib/c-hashmap" \        # HashMap library headers
    -o "${TEST_NAME}.js" \                       # Output filename (.js + .wasm)
    -s WASM=1 \                                  # Enable WebAssembly output
    -s EXPORTED_FUNCTIONS='["_main","_runSWF"]' \  # Functions callable from JS
    -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap"]' \  # JS-C bridge methods
    -s ALLOW_MEMORY_GROWTH=1 \                   # Dynamic memory allocation
    -s INITIAL_MEMORY=16MB \                     # Starting memory size
    -O2                                          # Optimization level 2
```

**Key points:**

- `-DNO_GRAPHICS` - Conditional compilation flag
- `-s WASM=1` - Generate WebAssembly (not asm.js)
- `-s EXPORTED_FUNCTIONS` - Functions visible to JavaScript
- `-s ALLOW_MEMORY_GROWTH=1` - Memory can grow dynamically
- `-O2` - Balance between size and performance

### Optimization Levels

| Level | Size | Speed | Build Time | Use Case |
|-------|------|-------|------------|----------|
| `-O0` | Large | Slow | Fast | Debugging |
| `-O1` | Medium | Medium | Medium | Development |
| `-O2` | Small | Fast | Slow | **Production (default)** |
| `-O3` | Smallest | Fastest | Slowest | Performance critical |
| `-Os` | Smallest | Medium | Slow | Size critical |

**Recommendation:** Use `-O2` for production builds (current default).

---

## Testing the WASM Build

### Local Testing

**1. Start HTTP server:**

```bash
cd ~/projects/SWFRecomp/tests/trace_swf_4/build/wasm
python3 -m http.server 8000
```

**Alternative servers:**
```bash
# Node.js (if installed)
npx http-server -p 8000

# PHP (if installed)
php -S localhost:8000
```

**2. Open browser:**

Navigate to: `http://localhost:8000/index.html`

**3. Expected behavior:**

- Page loads with "WASM SWF Runtime Loaded!" message
- Click "Run SWF" button
- Output appears in console display area
- Should see: "sup from SWF 4" (for trace_swf_4 test)

### Browser Console

Open browser developer tools (F12) to see:

```
WASM SWF Runtime Loaded!
This is a recompiled Flash SWF running in WebAssembly.

Call runSWF() from JavaScript to execute the SWF.
Starting SWF execution from JavaScript...
=== SWF Execution Started (NO_GRAPHICS mode) ===

[Frame 0]
[Tag] SetBackgroundColor(255, 255, 255)
sup from SWF 4
[Tag] ShowFrame()

=== SWF Execution Completed ===
```

---

## Deployment

### Deploy to Documentation Site

```bash
cd ~/projects/SWFRecomp
./scripts/deploy_example.sh trace_swf_4 ../SWFRecompDocs/docs/examples
```

**What this does:**

1. Creates directory: `SWFRecompDocs/docs/examples/trace_swf_4/`
2. Copies WASM files:
   - `trace_swf_4.wasm`
   - `trace_swf_4.js`
   - `index.html`

**Result:** Live example at docs site

### Batch Deployment

To deploy multiple tests:

```bash
# Edit the test list in the script first
./scripts/build_all_examples.sh ../SWFRecompDocs/docs/examples
```

---

## Troubleshooting

### Common Issues

#### 1. Emscripten not found

**Error:**
```
Error: Emscripten (emcc) not found!
Run: source ~/tools/emsdk/emsdk_env.sh
```

**Solution:**
```bash
source ~/tools/emsdk/emsdk_env.sh
```

**Permanent fix:** Add to `~/.bashrc`

#### 2. SWFModernRuntime not found

**Error:**
```
Error: SWFModernRuntime not found at: /path/to/SWFModernRuntime
```

**Solution:** Verify directory structure:
```bash
ls ~/projects/SWFModernRuntime
```

Projects must be siblings: `SWFRecomp/` and `SWFModernRuntime/` in same parent directory.

#### 3. Build fails with SDL3 error

**Error:**
```
fatal error: 'SDL3/SDL.h' file not found
```

**Cause:** Old build artifacts or wrong source files

**Solution:**
```bash
# Clean build directory
rm -rf tests/<test_name>/build/wasm

# Rebuild
./scripts/build_test.sh <test_name> wasm
```

#### 4. WASM doesn't load in browser

**Error:** "Failed to fetch" or CORS error

**Cause:** Opening `index.html` directly (file://) instead of via HTTP server

**Solution:** Always use HTTP server:
```bash
python3 -m http.server 8000
```

#### 5. Output doesn't appear

**Check:**
1. Browser console (F12) for JavaScript errors
2. Network tab - verify .wasm file loads
3. Try clicking "Run SWF" button again
4. Clear browser cache and reload

---

## Advanced Usage

### Building with Different Optimization

```bash
# Edit build_test.sh temporarily, change:
-O2    # to
-O3    # or -Os for size optimization
```

### Custom Emscripten Flags

Add flags to the `emcc` command in `scripts/build_test.sh`:

```bash
emcc \
    *.c \
    -DNO_GRAPHICS \
    -s ASSERTIONS=1 \          # Add runtime assertions (debugging)
    -s SAFE_HEAP=1 \           # Memory safety checks (debugging)
    -g \                       # Include debug info
    --source-map-base ./ \     # Generate source maps
    -o "${TEST_NAME}.js"
```

### Debugging WASM

**With source maps:**
```bash
emcc *.c -DNO_GRAPHICS -g --source-map-base ./ -o test.js
```

Browser DevTools will show original C source.

**With assertions:**
```bash
emcc *.c -DNO_GRAPHICS -s ASSERTIONS=1 -s SAFE_HEAP=1 -o test.js
```

Catches memory errors and assertion failures.

---

## Build System Architecture

### Directory Flow

```
SWFRecomp/
├── tests/
│   └── trace_swf_4/
│       ├── test.swf              # Original Flash file
│       ├── config.toml           # SWFRecomp config
│       ├── RecompiledScripts/    # Generated by SWFRecomp
│       ├── RecompiledTags/       # Generated by SWFRecomp
│       └── build/
│           └── wasm/             # WASM build output
│               ├── *.c           # Source files (copied here)
│               ├── *.wasm        # WebAssembly binary
│               ├── *.js          # JavaScript loader
│               └── index.html    # Browser interface
├── wasm_wrappers/                # Shared WASM code
│   ├── main.c                    # Entry point
│   └── index_template.html       # HTML template
└── scripts/
    ├── build_test.sh             # Single test builder
    ├── build_all_examples.sh     # Batch builder
    └── deploy_example.sh         # Deployment script
```

### Source File Selection

**WASM builds use:**
- `SWFModernRuntime/src/actionmodern/` (always)
- `SWFModernRuntime/src/libswf/swf_core.c` (NO_GRAPHICS)
- `SWFModernRuntime/src/libswf/tag_stubs.c` (NO_GRAPHICS)
- `SWFModernRuntime/src/utils.c` (always)
- `SWFModernRuntime/lib/c-hashmap/map.c` (always)

**Native builds use:**
- `SWFModernRuntime/src/actionmodern/` (always)
- `SWFModernRuntime/src/libswf/swf.c` (graphics)
- `SWFModernRuntime/src/libswf/tag.c` (graphics)
- `SWFModernRuntime/src/flashbang/flashbang.c` (graphics)
- `SWFModernRuntime/src/utils.c` (always)

---

## Performance

### Build Times

| Test Complexity | Emscripten Compile | Total Build Time |
|----------------|-------------------|------------------|
| Simple (trace) | 1-2 seconds | 3-4 seconds |
| Medium (variables) | 2-3 seconds | 4-5 seconds |
| Complex (arithmetic) | 3-4 seconds | 5-6 seconds |

**Factors:**
- Number of ActionScript operations
- Variable usage
- String handling complexity

### WASM File Sizes

| Test Type | WASM Size | JS Size | Total |
|-----------|-----------|---------|-------|
| Simple trace | 15-20 KB | 12-15 KB | 30-35 KB |
| Variables | 18-22 KB | 13-16 KB | 35-40 KB |
| Complex math | 20-25 KB | 14-17 KB | 40-45 KB |

**Comparison:**
- Flash Player plugin: ~15-20 MB
- Our WASM runtime: ~30-45 KB
- **~500x smaller!**

### Load Times

**On typical broadband:**
- WASM binary: < 0.1 seconds
- JavaScript loader: < 0.1 seconds
- Total page load: < 0.5 seconds

**On mobile 4G:**
- WASM binary: < 0.2 seconds
- JavaScript loader: < 0.2 seconds
- Total page load: < 1 second

---

## Tests Compatible with NO_GRAPHICS Mode

### Fully Supported (~40 tests)

**Trace tests:**
- trace_swf_4
- trace_swf_5
- trace_multiple
- trace_empty
- trace_escape

**Arithmetic tests:**
- add_floats
- subtract_floats
- multiply_floats
- divide_floats
- modulo
- increment
- decrement
- negate
- bitwise_and
- bitwise_or
- bitwise_xor

**String tests:**
- string_add
- string_concat
- string_length
- string_equals
- string_less_than
- substring
- char_to_ascii
- ascii_to_char

**Variable tests:**
- float_vars
- dyna_string_vars_swf_4
- set_variable
- get_variable
- variable_scope
- undefined_variable

**Control flow tests:**
- if_statement
- goto
- loop_simple
- loop_complex

### Require Graphics Support (~16 tests)

These need WebGPU/Canvas rendering (future work):

**Shape tests:**
- define_shape
- draw_rectangle
- draw_circle
- fill_gradient

**MovieClip tests:**
- place_object
- remove_object
- movieclip_control

**Transform tests:**
- matrix_transform
- rotation
- scaling

---

## Next Steps

### After First Successful Build

1. **Test in browser** - Verify output is correct
2. **Deploy to docs** - Make example publicly available
3. **Build more tests** - Try other console-only tests
4. **Batch build** - Generate multiple examples

### Future Enhancements

**Phase 2: Canvas2D Rendering**
- Implement shape rendering
- Use HTML5 Canvas 2D API
- Remove NO_GRAPHICS flag for graphics tests

**Phase 3: WebGPU Rendering**
- Full graphics support
- GPU-accelerated rendering
- Feature parity with native builds

---

## Reference Commands

### Complete Build Workflow

```bash
# 1. Activate Emscripten
source ~/tools/emsdk/emsdk_env.sh

# 2. Build test
cd ~/projects/SWFRecomp
./scripts/build_test.sh trace_swf_4 wasm

# 3. Test locally
cd tests/trace_swf_4/build/wasm
python3 -m http.server 8000
# Open http://localhost:8000/index.html

# 4. Deploy to docs
cd ~/projects/SWFRecomp
./scripts/deploy_example.sh trace_swf_4 ../SWFRecompDocs/docs/examples
```

### Quick Rebuilds

```bash
# Clean and rebuild
rm -rf tests/<test_name>/build/wasm
./scripts/build_test.sh <test_name> wasm

# Build multiple tests
for test in trace_swf_4 add_floats string_concat; do
    ./scripts/build_test.sh $test wasm
done
```

---

## Related Documentation

- **Implementation Status:** `status/2025-11-04-no-graphics-mode-implementation.md`
- **Original Design:** `plans/swfmodernruntime-no-graphics-mode.md`
- **Build System Plan:** `plans/streamline-test-builds.md`
- **WASM Generation:** `reference/trace-swf4-wasm-generation.md`

---

## Summary

The WASM build process is now streamlined:

1. ✅ **One-time setup:** Install Emscripten
2. ✅ **Per-session:** Activate Emscripten with `source ~/tools/emsdk/emsdk_env.sh`
3. ✅ **Per-test:** Run `./scripts/build_test.sh <test_name> wasm`
4. ✅ **Test:** Start HTTP server and open in browser
5. ✅ **Deploy:** Run `./scripts/deploy_example.sh <test_name>`

**Key achievement:** Console-only tests now build to WASM without SDL3/Vulkan dependencies, enabling ~40 tests to run as interactive web demos.

**Build time:** ~4 seconds per test

**Output size:** ~30-45 KB per test

**Browser support:** All modern browsers with WebAssembly support
