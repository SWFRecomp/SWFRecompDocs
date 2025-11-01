# ABC Parser Implementation Guide

**Version:** 1.0

**Date:** October 31, 2025

**Purpose:** Step-by-step guide for implementing the ABC parser in SWFRecomp

---

## Table of Contents

1. [Overview](#overview)
2. [Available Resources](#available-resources)
3. [Project Setup](#project-setup)
4. [Implementation Roadmap](#implementation-roadmap)
5. [Step-by-Step Implementation](#step-by-step-implementation)
6. [Codebase Integration](#codebase-integration)
7. [Testing Strategy](#testing-strategy)
8. [Code Patterns](#code-patterns)
9. [Next Steps](#next-steps)

---

## Overview

### What You're Building

The ABC (ActionScript Byte Code) parser is the **first component** for AS3 support in SWFRecomp. It reads binary ABC format from DoABC tags and extracts:

- **Constant pools** - strings, numbers, namespaces, multinames
- **Method signatures** - parameter types, return types, flags
- **Class definitions** - inheritance, traits, slots
- **Method bodies** - bytecode, exception handlers, stack sizes
- **Scripts** - initialization code

### Why C++ for the Parser?

The ABC parser is a **build-time tool** that runs during recompilation, not at runtime. C++ is appropriate because:

- It doesn't affect runtime performance
- STL containers simplify parsing (vectors, maps, strings)
- Exception handling makes error reporting easier
- It integrates with the existing SWFRecomp C++ codebase

The parsed data will later be used to **generate C runtime code** in Phase 2.

### Implementation Flow

```
SWF file (binary)
    ↓
DoABC tag extraction (existing SWF parser)
    ↓
ABC binary data
    ↓
ABC Parser (THIS PHASE) ← YOU ARE HERE
    ↓
ABCFile structure (in-memory)
    ↓
Code Generator (Phase 2 - future)
    ↓
Generated C code
```

### Success Criteria

✅ **Parser can successfully parse:**
- Minimal ABC file (test case)
- Hello World AS3 SWF
- Multiple classes with inheritance
- Methods with bytecode

✅ **Output includes:**
- Class names and hierarchy
- Method signatures
- Constant pool contents
- Bytecode (raw bytes for now)

✅ **Code quality:**
- No memory leaks
- Proper error handling
- Clean separation of concerns
- Well-commented

---

## Available Resources

### Downloaded Documentation

**Location:** `docs/specs/` directory in SWFRecomp

1. **`swf-spec-19.txt`** (370 KB)
   - Official Adobe SWF File Format Specification Version 19
   - Contains DoABC tag format (ActionScript 3 chapter)
   - Source: https://open-flash.github.io/mirrors/swf-spec-19.pdf

2. **`abc-format-46-16.txt`** (8.2 KB)
   - Official Adobe ABC File Format Specification
   - Version 46.16 (Flash Player 9+)
   - Source: https://github.com/adobe-flash/avmplus/blob/master/doc/abcFormat-46-16.txt

3. **`opcodes.as`** (15 KB)
   - ActionScript 3 opcode table generator
   - Shows opcode metadata structure
   - Source: https://github.com/adobe-flash/avmplus/blob/master/utils/opcodes.as

4. **`avm2_opcodes_raw.txt`** (258 lines)
   - Extracted opcode table from Interpreter.cpp
   - Maps 0x00-0xFF to instruction handlers

### Reference Implementations

**Use these for verification and design guidance:**

1. **Ruffle (Rust Implementation)** ⭐ **Recommended**
   - Repository: https://github.com/ruffle-rs/ruffle
   - ABC Parser: `swf/src/avm2/read.rs`
   - License: MIT/Apache 2.0 ✅ **Compatible**
   - Use: Translation reference and design guidance

2. **avmplus (C++ Implementation)**
   - Repository: https://github.com/adobe-flash/avmplus
   - ABC Interpreter: `core/Interpreter.cpp`
   - License: MPL 2.0 ⚠️ File-level copyleft
   - Use: Authoritative reference only (don't copy code directly)

3. **RABCDAsm (D Language)**
   - Repository: https://github.com/CyberShadow/RABCDAsm
   - Opcode Info: `abcfile.d`
   - License: GPL v3+ ❌ **Incompatible**
   - Use: Reference for opcode operand types only

### Planning Documents

**Location:** SWFRecompDocs directory

- **`reference/abc-format.md`** - Complete ABC format technical reference
- **`guides/abc-parser-implementation.md`** - This document
- **`guides/as3-implementation.md`** - Full AS3 support roadmap

### Test Resources

- **SWFRecomp/tests/**: 50+ existing test SWF files
- **Seedling project**: AS3 source code (compile to get test SWF)
- **Online resources**: Flash game archives, simple AS3 examples

### License Considerations for Reference Implementations

When using reference implementations, understand licensing implications:

**✅ Safe to Use:**
- **Ruffle** (MIT/Apache 2.0): Can translate code directly, fully compatible with SWFRecomp's MIT license
- **avmplus** (MPL 2.0): Compatible but must track modified files separately

**❌ Avoid:**
- **Lightspark** (GPL/LGPL): Incompatible with MIT, cannot use code
- **RABCDAsm** (GPL v3+): Incompatible, use only as external tool for testing

**Recommendation:** Use Ruffle as primary reference for translation to C++. The Rust code is clean, well-structured, and can be directly translated to C++ without licensing concerns. For verification, compare against avmplus behavior but avoid copying MPL-licensed code directly.

---

## Project Setup

### Directory Structure

Create the following structure in SWFRecomp:

```
SWFRecomp/
├── src/
│   └── abc/                    ⭐ CREATE THIS
│       ├── abc_reader.cpp
│       ├── abc_parser.cpp
│       └── abc_codegen.cpp     (Phase 2 - future)
├── include/
│   └── abc/                    ⭐ CREATE THIS
│       ├── abc_types.h
│       ├── abc_reader.h
│       └── abc_parser.h
└── tests/
    └── abc/                    ⭐ CREATE THIS (optional)
        └── abc_test.cpp
```

### CMakeLists.txt Integration

Add ABC files to the build:

```cmake
# In CMakeLists.txt

set(SOURCES
    src/main.cpp
    src/config.cpp
    src/recompilation.cpp
    src/swf.cpp
    src/tag.cpp
    src/field.cpp
    src/action/action.cpp
    src/abc/abc_reader.cpp      # ADD
    src/abc/abc_parser.cpp      # ADD
    # src/abc/abc_codegen.cpp   # ADD in Phase 2
)

target_include_directories(${PROJECT_NAME} PRIVATE
    include
    include/action
    include/abc                 # ADD
    # ... other includes
)
```

### Initial Files to Create

**Step 1: Create directories**
```bash
mkdir -p src/abc include/abc tests/abc
```

**Step 2: Create header files**

`include/abc/abc_types.h` - Data structures (see below)
`include/abc/abc_reader.h` - Binary reading utilities
`include/abc/abc_parser.h` - Parser interface

**Step 3: Create implementation files**

`src/abc/abc_reader.cpp` - Binary reader implementation
`src/abc/abc_parser.cpp` - Parser implementation

---

## Implementation Roadmap

### Phase 1: Setup and Binary Reader (1-2 days)

**Goal:** Create project structure and basic binary reading

**Tasks:**
1. Create directories and files
2. Add files to CMakeLists.txt
3. Define basic types in `abc_types.h`
4. Implement ABCReader class:
   - `read_u8()`, `read_u16()`
   - `read_u30()` - **Critical: variable-length encoding**
   - `read_s32()`, `read_d64()`
   - `read_string()`

**Deliverable:** Compiling project with basic ABC reading utilities

**Test:** Unit test for u30 encoding/decoding

### Phase 2: Constant Pools (3-4 days)

**Goal:** Parse all constant pools

**Tasks:**
1. Parse ABC header (version)
2. Parse integer pool
3. Parse unsigned integer pool
4. Parse double pool
5. Parse string pool (UTF-8, variable length)
6. Parse namespace pool (7 kinds)
7. Parse namespace set pool
8. Parse multiname pool (9 kinds!)
9. Handle index 0 special cases
10. Add validation (bounds checking)

**Deliverable:** Working constant pool parser with tests

**Test:** Parse minimal ABC file with simple constant pools

### Phase 3: Methods and Classes (3-4 days)

**Goal:** Parse method signatures and class definitions

**Tasks:**
1. Parse method_info array:
   - Parameter types and return type
   - Flags (8 different flags)
   - Optional parameters
   - Parameter names (debug info)
2. Parse metadata_info array (can skip initially)
3. Parse instance_info and class_info:
   - Class name and superclass
   - Flags (sealed, final, interface, protected)
   - Interfaces
   - Constructors (iinit, cinit)
   - Traits (see Phase 4)

**Deliverable:** Complete method and class structure parsing

**Test:** Parse ABC with simple class hierarchy

### Phase 4: Traits (2-3 days)

**Goal:** Implement trait parsing (complex but critical)

**Tasks:**
1. Understand 7 trait kinds:
   - Slot, Method, Getter, Setter, Class, Function, Const
2. Parse trait header (name, kind, attributes)
3. Parse kind-specific data:
   - Slot/Const: type, value index
   - Method/Getter/Setter: dispatch ID, method index
   - Class: slot ID, class index
   - Function: slot ID, method index
4. Parse metadata references
5. Handle attribute flags (final, override, metadata)

**Deliverable:** Complete trait parsing for all types

**Test:** Parse class with mixed trait types

### Phase 5: Scripts and Method Bodies (3-4 days)

**Goal:** Parse bytecode and finalize parser

**Tasks:**
1. Parse script_info array:
   - Init method index
   - Script traits
2. Parse method_body_info array:
   - Method index reference
   - Stack sizes (max_stack, max_regs)
   - Scope depths
   - **Bytecode** (store as raw bytes for now)
   - Exception handlers
   - Body traits
3. Add comprehensive validation:
   - Index bounds checking
   - Structural consistency
   - Version checking

**Deliverable:** Complete ABC parser

**Test:** Parse real AS3 SWF file

### Phase 6: Integration (2-3 days)

**Goal:** Integrate with existing SWF parser

**Tasks:**
1. Locate DoABC tag handler in `swf.cpp` (around line 889)
2. Uncomment and implement DoABC case:
   - Read flags (U32)
   - Read name (null-terminated string)
   - Calculate ABC data size
   - Call ABC parser
3. Store parsed ABC in SWF structure
4. Add error handling
5. Add debug output option

**Deliverable:** SWFRecomp can parse DoABC tags

**Test:** Run SWFRecomp on AS3 SWF file, verify parsing

### Phase 7: Testing and Documentation (2-3 days)

**Goal:** Verify correctness and document usage

**Tasks:**
1. Create test cases:
   - Minimal ABC file
   - Hello World AS3
   - Class inheritance
   - Interface implementation
   - Exception handling
2. Test with real files:
   - Simple AS3 programs
   - Seedling.swf
   - Flash games
3. Compare against RABCDAsm output (for verification)
4. Add debug utilities:
   - `print_abc_info()` - Summary
   - `print_class_info()` - Class details
   - `print_method_body()` - Bytecode dump
5. Document API usage

**Deliverable:** Tested, documented ABC parser

**Total Estimated Time:** 2-3 weeks

---

## Step-by-Step Implementation

### Step 1: ABCReader Class

Create the binary reading utility class:

**`include/abc/abc_reader.h`:**

```cpp
#ifndef ABC_READER_H
#define ABC_READER_H

#include <cstdint>
#include <string>
#include <stdexcept>

class ABCReader {
public:
    ABCReader(const uint8_t* data, size_t size);

    // Basic reads
    uint8_t read_u8();
    uint16_t read_u16();
    uint32_t read_u30();
    int32_t read_s32();
    double read_d64();
    std::string read_string();

    // Position management
    size_t position() const { return ptr_ - data_; }
    size_t remaining() const { return end_ - ptr_; }
    bool eof() const { return ptr_ >= end_; }

private:
    const uint8_t* data_;
    const uint8_t* ptr_;
    const uint8_t* end_;
};

#endif // ABC_READER_H
```

**`src/abc/abc_reader.cpp`:**

```cpp
#include "abc_reader.h"
#include <cstring>

ABCReader::ABCReader(const uint8_t* data, size_t size)
    : data_(data), ptr_(data), end_(data + size) {
}

uint8_t ABCReader::read_u8() {
    if (ptr_ >= end_) {
        throw std::runtime_error("ABC read past end of file");
    }
    return *ptr_++;
}

uint16_t ABCReader::read_u16() {
    if (ptr_ + 2 > end_) {
        throw std::runtime_error("ABC read past end of file");
    }
    uint16_t value = *((const uint16_t*)ptr_);
    ptr_ += 2;
    return value;  // Little-endian
}

uint32_t ABCReader::read_u30() {
    uint32_t result = 0;
    int shift = 0;

    for (int i = 0; i < 5; i++) {
        if (ptr_ >= end_) {
            throw std::runtime_error("ABC read past end of file");
        }

        uint8_t byte = *ptr_++;
        result |= (byte & 0x7F) << shift;

        if (!(byte & 0x80)) {  // No continuation bit
            break;
        }

        shift += 7;
    }

    return result;
}

int32_t ABCReader::read_s32() {
    uint32_t value = read_u30();
    // Sign-extend if needed
    if (value & 0x80000000) {
        return (int32_t)(value | 0xFFFFFFFF);
    }
    return (int32_t)value;
}

double ABCReader::read_d64() {
    if (ptr_ + 8 > end_) {
        throw std::runtime_error("ABC read past end of file");
    }
    double value;
    memcpy(&value, ptr_, 8);
    ptr_ += 8;
    return value;  // Little-endian IEEE 754
}

std::string ABCReader::read_string() {
    uint32_t length = read_u30();
    if (length == 0) {
        return "";
    }

    if (ptr_ + length > end_) {
        throw std::runtime_error("ABC string read past end of file");
    }

    std::string result((const char*)ptr_, length);
    ptr_ += length;
    return result;
}
```

### Step 2: ABC Data Structures

**`include/abc/abc_types.h`:**

```cpp
#ifndef ABC_TYPES_H
#define ABC_TYPES_H

#include <cstdint>
#include <vector>
#include <string>

// Namespace kinds
enum NamespaceKind {
    NAMESPACE = 0x08,
    PACKAGE_NAMESPACE = 0x16,
    PACKAGE_INTERNAL_NS = 0x17,
    PROTECTED_NAMESPACE = 0x18,
    EXPLICIT_NAMESPACE = 0x19,
    STATIC_PROTECTED_NS = 0x1A,
    PRIVATE_NS = 0x05,
};

// Multiname kinds
enum MultinameKind {
    QNAME = 0x07,
    QNAME_A = 0x0D,
    RTQNAME = 0x0F,
    RTQNAME_A = 0x10,
    RTQNAME_L = 0x11,
    RTQNAME_LA = 0x12,
    MULTINAME = 0x09,
    MULTINAME_A = 0x0E,
    MULTINAME_L = 0x1B,
    MULTINAME_LA = 0x1C,
    TYPENAME = 0x1D,
};

// Method flags
enum MethodFlags {
    NEED_ARGUMENTS = 0x01,
    NEED_ACTIVATION = 0x02,
    NEED_REST = 0x04,
    HAS_OPTIONAL = 0x08,
    IGNORE_REST = 0x10,
    EXPLICIT = 0x20,
    SET_DXNS = 0x40,
    HAS_PARAM_NAMES = 0x80,
};

// Class flags
enum ClassFlags {
    CLASS_SEALED = 0x01,
    CLASS_FINAL = 0x02,
    CLASS_INTERFACE = 0x04,
    CLASS_PROTECTED_NS = 0x08,
};

// Trait kinds
enum TraitKind {
    TRAIT_SLOT = 0,
    TRAIT_METHOD = 1,
    TRAIT_GETTER = 2,
    TRAIT_SETTER = 3,
    TRAIT_CLASS = 4,
    TRAIT_FUNCTION = 5,
    TRAIT_CONST = 6,
};

// Trait attributes
enum TraitAttributes {
    ATTR_FINAL = 0x10,
    ATTR_OVERRIDE = 0x20,
    ATTR_METADATA = 0x40,
};

// Structures

struct Namespace {
    NamespaceKind kind;
    uint32_t name_index;
};

struct NamespaceSet {
    std::vector<uint32_t> namespace_indices;
};

struct Multiname {
    MultinameKind kind;
    uint32_t ns_index;
    uint32_t name_index;
    uint32_t ns_set_index;
    std::vector<uint32_t> type_params;
};

struct OptionDetail {
    uint32_t value_index;
    uint8_t value_kind;
};

struct MethodInfo {
    uint32_t param_count;
    uint32_t return_type;
    std::vector<uint32_t> param_types;
    uint32_t name_index;
    uint8_t flags;
    std::vector<OptionDetail> options;
    std::vector<uint32_t> param_names;
};

struct MetadataItem {
    uint32_t key_index;
    uint32_t value_index;
};

struct MetadataInfo {
    uint32_t name_index;
    std::vector<MetadataItem> items;
};

struct Trait {
    uint32_t name_index;
    uint8_t kind;
    uint8_t attributes;

    // For TRAIT_SLOT, TRAIT_CONST
    uint32_t slot_id;
    uint32_t type_name;
    uint32_t vindex;
    uint8_t vkind;

    // For TRAIT_METHOD, TRAIT_GETTER, TRAIT_SETTER, TRAIT_FUNCTION
    uint32_t disp_id;
    uint32_t method_index;

    // For TRAIT_CLASS
    uint32_t class_index;

    std::vector<uint32_t> metadata_indices;
};

struct InstanceInfo {
    uint32_t name_index;
    uint32_t super_name_index;
    uint8_t flags;
    uint32_t protected_ns_index;
    std::vector<uint32_t> interface_indices;
    uint32_t iinit_index;
    std::vector<Trait> traits;
};

struct ClassInfo {
    uint32_t cinit_index;
    std::vector<Trait> traits;
};

struct ScriptInfo {
    uint32_t init_index;
    std::vector<Trait> traits;
};

struct ExceptionInfo {
    uint32_t from;
    uint32_t to;
    uint32_t target;
    uint32_t exc_type_index;
    uint32_t var_name_index;
};

struct MethodBodyInfo {
    uint32_t method_index;
    uint32_t max_stack;
    uint32_t max_regs;
    uint32_t scope_depth;
    uint32_t max_scope_depth;
    std::vector<uint8_t> code;
    std::vector<ExceptionInfo> exceptions;
    std::vector<Trait> traits;
};

struct ABCFile {
    // Header
    uint16_t minor_version;
    uint16_t major_version;

    // Constant pools
    std::vector<int32_t> int_pool;
    std::vector<uint32_t> uint_pool;
    std::vector<double> double_pool;
    std::vector<std::string> string_pool;
    std::vector<Namespace> namespace_pool;
    std::vector<NamespaceSet> ns_set_pool;
    std::vector<Multiname> multiname_pool;

    // Method info
    std::vector<MethodInfo> method_info;

    // Metadata
    std::vector<MetadataInfo> metadata_info;

    // Class definitions
    std::vector<InstanceInfo> instance_info;
    std::vector<ClassInfo> class_info;

    // Scripts
    std::vector<ScriptInfo> script_info;

    // Method bodies
    std::vector<MethodBodyInfo> method_body_info;
};

#endif // ABC_TYPES_H
```

### Step 3: Parser Implementation

**`include/abc/abc_parser.h`:**

```cpp
#ifndef ABC_PARSER_H
#define ABC_PARSER_H

#include "abc_types.h"
#include "abc_reader.h"
#include <cstddef>

// Main parsing function
ABCFile* parse_abc_file(const uint8_t* data, size_t size);

// Validation
void validate_abc(const ABCFile* abc);

// Debug utilities
void print_abc_info(const ABCFile* abc);
void print_class_info(const ABCFile* abc, size_t class_index);
void print_method_body(const ABCFile* abc, size_t body_index);

// Cleanup
void free_abc(ABCFile* abc);

#endif // ABC_PARSER_H
```

**`src/abc/abc_parser.cpp`** (outline - you'll fill in details):

```cpp
#include "abc_parser.h"
#include <iostream>
#include <stdexcept>
#include <cmath>

// Forward declarations
static void parse_header(ABCReader& reader, ABCFile* abc);
static void parse_constant_pools(ABCReader& reader, ABCFile* abc);
static void parse_method_info(ABCReader& reader, ABCFile* abc);
static void parse_metadata(ABCReader& reader, ABCFile* abc);
static void parse_classes(ABCReader& reader, ABCFile* abc);
static void parse_scripts(ABCReader& reader, ABCFile* abc);
static void parse_method_bodies(ABCReader& reader, ABCFile* abc);
static void parse_traits(ABCReader& reader, std::vector<Trait>& traits);

ABCFile* parse_abc_file(const uint8_t* data, size_t size) {
    ABCFile* abc = new ABCFile();
    ABCReader reader(data, size);

    try {
        parse_header(reader, abc);
        parse_constant_pools(reader, abc);
        parse_method_info(reader, abc);
        parse_metadata(reader, abc);
        parse_classes(reader, abc);
        parse_scripts(reader, abc);
        parse_method_bodies(reader, abc);
        validate_abc(abc);
        return abc;
    } catch (const std::exception& e) {
        delete abc;
        throw;
    }
}

static void parse_header(ABCReader& reader, ABCFile* abc) {
    abc->minor_version = reader.read_u16();
    abc->major_version = reader.read_u16();

    if (abc->major_version != 46 && abc->major_version != 47) {
        throw std::runtime_error("Unsupported ABC version: " +
            std::to_string(abc->major_version) + "." +
            std::to_string(abc->minor_version));
    }
}

static void parse_constant_pools(ABCReader& reader, ABCFile* abc) {
    // Integer pool
    uint32_t int_count = reader.read_u30();
    abc->int_pool.push_back(0);  // Index 0 implicit
    for (uint32_t i = 1; i < int_count; i++) {
        abc->int_pool.push_back(reader.read_s32());
    }

    // Unsigned integer pool
    uint32_t uint_count = reader.read_u30();
    abc->uint_pool.push_back(0);  // Index 0 implicit
    for (uint32_t i = 1; i < uint_count; i++) {
        abc->uint_pool.push_back(reader.read_u30());
    }

    // Double pool
    uint32_t double_count = reader.read_u30();
    abc->double_pool.push_back(NAN);  // Index 0 implicit
    for (uint32_t i = 1; i < double_count; i++) {
        abc->double_pool.push_back(reader.read_d64());
    }

    // String pool
    uint32_t string_count = reader.read_u30();
    abc->string_pool.push_back("");  // Index 0 implicit
    for (uint32_t i = 1; i < string_count; i++) {
        abc->string_pool.push_back(reader.read_string());
    }

    // Namespace pool
    uint32_t ns_count = reader.read_u30();
    abc->namespace_pool.push_back({NAMESPACE, 0});  // Index 0 implicit
    for (uint32_t i = 1; i < ns_count; i++) {
        Namespace ns;
        ns.kind = (NamespaceKind)reader.read_u8();
        ns.name_index = reader.read_u30();
        abc->namespace_pool.push_back(ns);
    }

    // Namespace set pool
    uint32_t ns_set_count = reader.read_u30();
    abc->ns_set_pool.push_back({});  // Index 0 implicit
    for (uint32_t i = 1; i < ns_set_count; i++) {
        NamespaceSet ns_set;
        uint32_t ns_count = reader.read_u30();
        for (uint32_t j = 0; j < ns_count; j++) {
            ns_set.namespace_indices.push_back(reader.read_u30());
        }
        abc->ns_set_pool.push_back(ns_set);
    }

    // Multiname pool
    uint32_t mn_count = reader.read_u30();
    abc->multiname_pool.push_back({});  // Index 0 implicit
    for (uint32_t i = 1; i < mn_count; i++) {
        Multiname mn = {};
        mn.kind = (MultinameKind)reader.read_u8();

        switch (mn.kind) {
            case QNAME:
            case QNAME_A:
                mn.ns_index = reader.read_u30();
                mn.name_index = reader.read_u30();
                break;

            case RTQNAME:
            case RTQNAME_A:
                mn.name_index = reader.read_u30();
                break;

            case RTQNAME_L:
            case RTQNAME_LA:
                // No data
                break;

            case MULTINAME:
            case MULTINAME_A:
                mn.name_index = reader.read_u30();
                mn.ns_set_index = reader.read_u30();
                break;

            case MULTINAME_L:
            case MULTINAME_LA:
                mn.ns_set_index = reader.read_u30();
                break;

            case TYPENAME: {
                mn.name_index = reader.read_u30();
                uint32_t param_count = reader.read_u30();
                for (uint32_t j = 0; j < param_count; j++) {
                    mn.type_params.push_back(reader.read_u30());
                }
                break;
            }
        }

        abc->multiname_pool.push_back(mn);
    }
}

static void parse_method_info(ABCReader& reader, ABCFile* abc) {
    uint32_t count = reader.read_u30();

    for (uint32_t i = 0; i < count; i++) {
        MethodInfo method = {};

        method.param_count = reader.read_u30();
        method.return_type = reader.read_u30();

        for (uint32_t j = 0; j < method.param_count; j++) {
            method.param_types.push_back(reader.read_u30());
        }

        method.name_index = reader.read_u30();
        method.flags = reader.read_u8();

        if (method.flags & HAS_OPTIONAL) {
            uint32_t option_count = reader.read_u30();
            for (uint32_t j = 0; j < option_count; j++) {
                OptionDetail opt;
                opt.value_index = reader.read_u30();
                opt.value_kind = reader.read_u8();
                method.options.push_back(opt);
            }
        }

        if (method.flags & HAS_PARAM_NAMES) {
            for (uint32_t j = 0; j < method.param_count; j++) {
                method.param_names.push_back(reader.read_u30());
            }
        }

        abc->method_info.push_back(method);
    }
}

static void parse_metadata(ABCReader& reader, ABCFile* abc) {
    uint32_t count = reader.read_u30();

    for (uint32_t i = 0; i < count; i++) {
        MetadataInfo meta;
        meta.name_index = reader.read_u30();

        uint32_t item_count = reader.read_u30();
        for (uint32_t j = 0; j < item_count; j++) {
            MetadataItem item;
            item.key_index = reader.read_u30();
            item.value_index = reader.read_u30();
            meta.items.push_back(item);
        }

        abc->metadata_info.push_back(meta);
    }
}

static void parse_traits(ABCReader& reader, std::vector<Trait>& traits) {
    uint32_t count = reader.read_u30();

    for (uint32_t i = 0; i < count; i++) {
        Trait trait = {};

        trait.name_index = reader.read_u30();
        uint8_t kind_and_attrs = reader.read_u8();

        trait.kind = kind_and_attrs & 0x0F;
        trait.attributes = (kind_and_attrs >> 4) & 0x0F;

        switch (trait.kind) {
            case TRAIT_SLOT:
            case TRAIT_CONST:
                trait.slot_id = reader.read_u30();
                trait.type_name = reader.read_u30();
                trait.vindex = reader.read_u30();
                if (trait.vindex != 0) {
                    trait.vkind = reader.read_u8();
                }
                break;

            case TRAIT_METHOD:
            case TRAIT_GETTER:
            case TRAIT_SETTER:
                trait.disp_id = reader.read_u30();
                trait.method_index = reader.read_u30();
                break;

            case TRAIT_CLASS:
                trait.slot_id = reader.read_u30();
                trait.class_index = reader.read_u30();
                break;

            case TRAIT_FUNCTION:
                trait.slot_id = reader.read_u30();
                trait.method_index = reader.read_u30();
                break;
        }

        if (trait.attributes & ATTR_METADATA) {
            uint32_t metadata_count = reader.read_u30();
            for (uint32_t j = 0; j < metadata_count; j++) {
                trait.metadata_indices.push_back(reader.read_u30());
            }
        }

        traits.push_back(trait);
    }
}

static void parse_classes(ABCReader& reader, ABCFile* abc) {
    uint32_t count = reader.read_u30();

    // Parse instance info
    for (uint32_t i = 0; i < count; i++) {
        InstanceInfo inst = {};

        inst.name_index = reader.read_u30();
        inst.super_name_index = reader.read_u30();
        inst.flags = reader.read_u8();

        if (inst.flags & CLASS_PROTECTED_NS) {
            inst.protected_ns_index = reader.read_u30();
        }

        uint32_t interface_count = reader.read_u30();
        for (uint32_t j = 0; j < interface_count; j++) {
            inst.interface_indices.push_back(reader.read_u30());
        }

        inst.iinit_index = reader.read_u30();
        parse_traits(reader, inst.traits);

        abc->instance_info.push_back(inst);
    }

    // Parse class info
    for (uint32_t i = 0; i < count; i++) {
        ClassInfo cls = {};
        cls.cinit_index = reader.read_u30();
        parse_traits(reader, cls.traits);
        abc->class_info.push_back(cls);
    }
}

static void parse_scripts(ABCReader& reader, ABCFile* abc) {
    uint32_t count = reader.read_u30();

    for (uint32_t i = 0; i < count; i++) {
        ScriptInfo script;
        script.init_index = reader.read_u30();
        parse_traits(reader, script.traits);
        abc->script_info.push_back(script);
    }
}

static void parse_method_bodies(ABCReader& reader, ABCFile* abc) {
    uint32_t count = reader.read_u30();

    for (uint32_t i = 0; i < count; i++) {
        MethodBodyInfo body = {};

        body.method_index = reader.read_u30();
        body.max_stack = reader.read_u30();
        body.max_regs = reader.read_u30();
        body.scope_depth = reader.read_u30();
        body.max_scope_depth = reader.read_u30();

        uint32_t code_length = reader.read_u30();
        body.code.resize(code_length);
        for (uint32_t j = 0; j < code_length; j++) {
            body.code[j] = reader.read_u8();
        }

        uint32_t exception_count = reader.read_u30();
        for (uint32_t j = 0; j < exception_count; j++) {
            ExceptionInfo ex;
            ex.from = reader.read_u30();
            ex.to = reader.read_u30();
            ex.target = reader.read_u30();
            ex.exc_type_index = reader.read_u30();
            ex.var_name_index = reader.read_u30();
            body.exceptions.push_back(ex);
        }

        parse_traits(reader, body.traits);

        abc->method_body_info.push_back(body);
    }
}

void validate_abc(const ABCFile* abc) {
    // Validate version
    if (abc->major_version < 46 || abc->major_version > 47) {
        throw std::runtime_error("Invalid ABC version");
    }

    // Validate class count matches
    if (abc->instance_info.size() != abc->class_info.size()) {
        throw std::runtime_error("Mismatch between instance and class count");
    }

    // TODO: Add more validation
}

void print_abc_info(const ABCFile* abc) {
    std::cout << "ABC Version: " << abc->major_version << "."
              << abc->minor_version << std::endl;
    std::cout << "Strings: " << abc->string_pool.size() << std::endl;
    std::cout << "Methods: " << abc->method_info.size() << std::endl;
    std::cout << "Classes: " << abc->instance_info.size() << std::endl;
    std::cout << "Scripts: " << abc->script_info.size() << std::endl;
    std::cout << "Method Bodies: " << abc->method_body_info.size() << std::endl;

    std::cout << "\nClasses:" << std::endl;
    for (size_t i = 0; i < abc->instance_info.size(); i++) {
        const InstanceInfo& inst = abc->instance_info[i];
        const Multiname& mn = abc->multiname_pool[inst.name_index];
        const std::string& name = abc->string_pool[mn.name_index];
        std::cout << "  - " << name << std::endl;
    }
}

void free_abc(ABCFile* abc) {
    delete abc;
}
```

---

## Codebase Integration

### DoABC Tag Handler Location

**File:** `src/swf.cpp`

**Line:** Around 889-894

**Current code (commented out):**
```cpp
//~ case SWF_TAG_DO_ABC:
//~ {
//~     cur_pos += tag.length;
//~     break;
//~ }
```

**Replacement:**
```cpp
case SWF_TAG_DO_ABC:
{
    // DoABC tag format:
    // - U32 flags
    // - STRING name (null-terminated)
    // - ABC data (remaining bytes)

    const uint8_t* tag_start = cur_pos;

    uint32_t flags = *((uint32_t*)cur_pos);
    cur_pos += 4;

    // Read null-terminated name
    std::string name = (const char*)cur_pos;
    cur_pos += name.length() + 1;

    // Calculate ABC data size
    size_t abc_size = tag.length - (cur_pos - tag_start);

    // Parse ABC file
    try {
        ABCFile* abc = parse_abc_file((const uint8_t*)cur_pos, abc_size);

        // Debug output (optional)
        std::cout << "Parsed ABC block: " << name << std::endl;
        print_abc_info(abc);

        // Store ABC for later code generation
        // TODO: Add abc_files vector to SWF structure
        // swf->abc_files.push_back(abc);

        // For now, just free it
        free_abc(abc);

    } catch (const std::exception& e) {
        std::cerr << "Error parsing ABC: " << e.what() << std::endl;
        // Continue parsing other tags
    }

    cur_pos = tag_start + tag.length;
    break;
}
```

### SWF Structure Extension

Add ABC storage to SWF structure:

**`include/swf.hpp`:**
```cpp
#include "abc/abc_types.h"

struct SWF {
    // ... existing fields ...

    std::vector<ABCFile*> abc_files;  // ADD THIS
};
```

---

## Testing Strategy

### Unit Tests

**Test u30 encoding:**
```cpp
void test_u30_encoding() {
    // Single byte (0-127)
    uint8_t data1[] = {0x7F};
    ABCReader r1(data1, 1);
    assert(r1.read_u30() == 127);

    // Two bytes (128+)
    uint8_t data2[] = {0x80, 0x01};
    ABCReader r2(data2, 2);
    assert(r2.read_u30() == 128);

    // Larger value
    uint8_t data3[] = {0xFF, 0x7F};
    ABCReader r3(data3, 2);
    assert(r3.read_u30() == 16383);
}
```

**Test string pool:**
```cpp
void test_string_pool() {
    // Simple string pool
    uint8_t data[] = {
        0x02,              // 2 strings (index 0 implicit)
        0x05,              // Length 5
        'h','e','l','l','o'
    };

    ABCReader reader(data, sizeof(data));
    ABCFile abc;

    uint32_t count = reader.read_u30();
    abc.string_pool.push_back("");  // Index 0
    for (uint32_t i = 1; i < count; i++) {
        abc.string_pool.push_back(reader.read_string());
    }

    assert(abc.string_pool.size() == 2);
    assert(abc.string_pool[0] == "");
    assert(abc.string_pool[1] == "hello");
}
```

### Integration Tests

**Test minimal ABC file:**
```cpp
void test_minimal_abc() {
    uint8_t data[] = {
        0x10, 0x00,  // Minor 16
        0x2E, 0x00,  // Major 46
        0x01,        // 1 int (implicit 0)
        0x01,        // 1 uint (implicit 0)
        0x01,        // 1 double (implicit NaN)
        0x01,        // 1 string (implicit "")
        0x01,        // 1 namespace (implicit any)
        0x01,        // 1 ns set (implicit empty)
        0x01,        // 1 multiname (implicit any)
        0x00,        // 0 methods
        0x00,        // 0 metadata
        0x00,        // 0 classes
        0x01,        // 1 script
        0x00,        // Init method 0
        0x00,        // 0 traits
        0x00,        // 0 method bodies
    };

    ABCFile* abc = parse_abc_file(data, sizeof(data));

    assert(abc->major_version == 46);
    assert(abc->minor_version == 16);
    assert(abc->string_pool.size() == 1);

    free_abc(abc);
}
```

### Testing Against Real Files

**Use RABCDAsm for verification:**
```bash
# Extract ABC from SWF
abcexport test.swf

# Disassemble with RABCDAsm
rabcdasm test-0.abc

# Parse with your implementation
./SWFRecomp --dump-abc test.swf

# Compare outputs
diff -u rabcdasm_output.txt swfrecomp_output.txt
```

**Expected output format:**

Your parser output should match RABCDAsm on these key metrics:
- Class count should match
- String pool size should match
- Method signature counts should match
- Constant pool sizes should match
- Namespace and multiname counts should match

**Example comparison:**
```
RABCDAsm output:
  Classes: 5
  Methods: 23
  Strings: 127
  Integers: 8
  Doubles: 3

Your parser output should show:
  Classes: 5
  Methods: 23
  String pool size: 127
  Integer pool size: 8
  Double pool size: 3
```

If counts don't match, check:
1. Are you handling index 0 correctly (implicit values)?
2. Are you reading pool counts as U30?
3. Are you parsing all sections in the correct order?

---

## Code Patterns

### Error Handling Pattern

From existing SWFRecomp codebase:

```cpp
#define EXC(str) fprintf(stderr, str); throw std::exception();
#define EXC_ARG(str, arg) fprintf(stderr, str, arg); throw std::exception();

// Usage:
if (abc->major_version != 46 && abc->major_version != 47) {
    EXC_ARG("Unsupported ABC version: %d\n", abc->major_version);
}
```

### Memory Management Pattern

```cpp
// Use std::vector for collections (automatic cleanup)
std::vector<std::string> string_pool;

// Use new/delete for large structures
ABCFile* abc = new ABCFile();
// ... use abc ...
delete abc;
```

### Binary Reading Pattern

```cpp
// Pointer arithmetic with bounds checking
const uint8_t* ptr = data;
const uint8_t* end = data + size;

if (ptr + sizeof(uint32_t) > end) {
    throw std::runtime_error("Read past end");
}

uint32_t value = *((uint32_t*)ptr);
ptr += sizeof(uint32_t);
```

---

## Frequently Asked Questions

### Q: Do I need to implement all 256 opcodes in Phase 1?

**A:** No! Phase 1 (ABC Parser) only stores bytecode as raw bytes in `method_body.code`. You do NOT need to interpret or understand opcodes yet. The parser just reads the bytecode length and copies the bytes into a vector.

Opcode interpretation happens in Phase 2 (Code Generator) when you convert ABC bytecode to C code.

### Q: What if I can't find AS3 test SWF files?

**A:** Several options:

1. **Compile with Apache Flex SDK:**
   ```bash
   # Install Apache Flex SDK (or FlashDevelop on Windows)
   mxmlc HelloWorld.as -o test.swf
   ```

2. **Use online Flash archives:**
   - Newgrounds game downloads
   - Internet Archive Flash collection
   - Simple AS3 tutorial files

3. **Create minimal ABC files manually:**
   - Use the minimal ABC test case from this guide
   - Build unit tests from scratch using hex bytes

4. **Start with existing tests:**
   - Use SWFRecomp's existing test SWF files
   - Compile the Seedling project if available

### Q: How do I handle DoABC vs DoABC2 tags?

**A:** Both tags (82 and 86) use identical ABC format:

```cpp
case SWF_TAG_DO_ABC:    // Tag 82
case SWF_TAG_DO_ABC2:   // Tag 86 (same format)
{
    // Same parsing code for both
    uint32_t flags = read_u32(ptr);
    std::string name = read_string(ptr);
    // Parse ABC data...
}
```

The only difference is the tag ID. The ABC data inside is identical.

### Q: Should I worry about ABC version 47.x?

**A:** Focus on version 46.16 first. Here's the strategy:

1. **Accept versions 46.16, 46.17, and 47.x** in your version check
2. **Parse them all the same way** (differences are minor)
3. **Warn on unknown versions** but try to parse anyway
4. **Reject versions < 46 or > 47**

Most AS3 content uses 46.16. Version 47 content is rare and mostly experimental.

### Q: What's the difference between DoABC and DoAction tags?

**A:** Completely different ActionScript versions:

- **DoAction (Tag 12)**: ActionScript 1.0/2.0 bytecode (Flash Player 6-8)
  - Already handled in SWFRecomp's `action/action.cpp`
  - Different bytecode format, simpler VM

- **DoABC (Tag 82)**: ActionScript 3.0 bytecode (Flash Player 9+)
  - This is what you're implementing now
  - Much more complex, class-based, typed

Don't confuse them - they're entirely separate systems!

### Q: My parser works but values look wrong. What's the issue?

**A:** Check these common mistakes:

1. **Index 0 handling**: Did you add implicit values to pools?
2. **Loop bounds**: Starting at 0 instead of 1 for pools?
3. **Data types**: Reading U8 as U30 or vice versa?
4. **Endianness**: ABC is little-endian for fixed-width types
5. **String encoding**: Strings are UTF-8, NOT null-terminated

Enable debug output showing pool sizes and compare against RABCDAsm.

---

## Next Steps

### After Parser Completion

1. **Verify Parsing**
   - Successfully parse Seedling.swf
   - Extract and validate all ABC data
   - Compare against RABCDAsm output

2. **Add Debug Output**
   - Implement detailed print functions
   - Add hex dump utilities for bytecode
   - Create class hierarchy visualization

3. **Prepare for Phase 2**
   - Document parsed structures
   - Identify code generation requirements
   - Plan bytecode interpreter or compiler

### Moving to Code Generation (Phase 2)

The next phase will involve:
- Interpreting ABC bytecode
- Generating equivalent C code
- Implementing AVM2 runtime in C
- Integrating generated code with recompiled SWF

---

## Troubleshooting

### Common Issues

**Issue: "Read past end of file"**
- Check pool count encoding (count includes implicit index 0)
- Verify variable-length encoding implementation
- Add debug output to track read position

**Issue: Invalid multiname kind**
- Check for all 11 multiname kinds (including TYPENAME)
- Verify kind value is read as U8, not U30

**Issue: Class/instance count mismatch**
- Instance info and class info must have same count
- Parse all instances before parsing classes

**Issue: Trait parsing fails**
- Remember: kind is low 4 bits, attributes are high 4 bits
- Different trait kinds have different data layouts

### Debug Techniques

**Add position tracking:**
```cpp
std::cout << "Position: " << reader.position()
          << " / " << size << std::endl;
```

**Hex dump unknown data:**
```cpp
void hex_dump(const uint8_t* data, size_t size) {
    for (size_t i = 0; i < size; i++) {
        printf("%02X ", data[i]);
        if ((i + 1) % 16 == 0) printf("\n");
    }
    printf("\n");
}
```

### Common Pitfalls

#### Index 0 Confusion
❌ **Wrong:** Reading n entries when count=n
```cpp
uint32_t count = reader.read_u30();
for (uint32_t i = 0; i < count; i++) {  // WRONG!
    strings.push_back(reader.read_string());
}
```

✅ **Correct:** Reading n-1 entries (index 0 is implicit)
```cpp
uint32_t count = reader.read_u30();
strings.push_back("");  // Index 0 = implicit empty string
for (uint32_t i = 1; i < count; i++) {  // Start at 1!
    strings.push_back(reader.read_string());
}
```

#### Pool Count Off-by-One
The count **includes** the implicit index 0:
- Count = 5 means indices 0, 1, 2, 3, 4
- But only 4 entries in file (indices 1-4)
- Index 0 is the implicit special value

#### Multiname Kind Reading
❌ **Wrong:** Reading kind as U30
```cpp
mn.kind = reader.read_u30();  // WRONG!
```

✅ **Correct:** Reading kind as U8
```cpp
mn.kind = (MultinameKind)reader.read_u8();  // Correct
```

#### Trait Kind/Attributes Packing
Remember: Low 4 bits = kind, high 4 bits = attributes

❌ **Wrong:**
```cpp
trait.kind = reader.read_u8();  // Includes attributes!
```

✅ **Correct:**
```cpp
uint8_t kind_and_attrs = reader.read_u8();
trait.kind = kind_and_attrs & 0x0F;        // Low 4 bits
trait.attributes = (kind_and_attrs >> 4);  // High 4 bits
```

---

## References

### Essential Reading

1. **ABC Format Reference**: `reference/abc-format.md`
2. **Official ABC Spec**: `docs/specs/abc-format-46-16.txt`
3. **SWF Spec v19**: `docs/specs/swf-spec-19.txt`

### Implementation References

- **Ruffle ABC parser**: `github.com/ruffle-rs/ruffle/blob/master/swf/src/avm2/read.rs`
- **avmplus Interpreter**: `github.com/adobe-flash/avmplus/blob/master/core/Interpreter.cpp`

---

**Document Status:** Complete implementation guide

**Last Updated:** October 31, 2025

**Next Document:** Phase 2 - ABC Code Generator (to be created)
