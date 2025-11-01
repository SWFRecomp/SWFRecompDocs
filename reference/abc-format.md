# ABC File Format Reference

**Version:** 1.0
**Date:** October 31, 2025
**Purpose:** Technical reference for the ActionScript Byte Code (ABC) file format

---

## Table of Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Data Types](#data-types)
4. [Constant Pools](#constant-pools)
5. [Methods](#methods)
6. [Classes](#classes)
7. [Traits](#traits)
8. [Scripts](#scripts)
9. [Method Bodies](#method-bodies)
10. [AVM2 Opcode Reference](#avm2-opcode-reference)

---

## Overview

### ABC Format Versions

| Major Version | Minor Version | Flash Player | Description |
|--------------|---------------|--------------|-------------|
| 46 | 16 | 9+ | Initial AS3 release |
| 46 | 17 | 10.3+ | Added generic type support |
| 47 | x | 11+ | Experimental features |

Most AS3 content uses version **46.16**.

### Version History Details

| Version | Flash Player | Release | Notable Features |
|---------|--------------|---------|------------------|
| 46.16 | 9.0 | 2006 | Initial AS3 release, class-based OOP |
| 46.17 | 10.3 | 2011 | Generic types (Vector.<T>) via TYPENAME multiname |
| 47.x | 11.0+ | 2011 | Experimental features, rarely used in production |

**Compatibility Notes:**
- Most AS3 content uses 46.16
- 46.17 is backward compatible (only adds TYPENAME multiname kind)
- 47.x content is rare (experimental VM features)
- **Parser Implementation:** Accept versions 46.16, 46.17, 47.x; warn on unknown versions; reject < 46 or > 47

### Official Specifications

- **Adobe ABC Format 46.16**: `github.com/adobe-flash/avmplus/blob/master/doc/abcFormat-46-16.txt`
- **SWF File Format Spec v19**: DoABC/DoABC2 tag formats
- **AVM2 Overview**: Official Adobe specification (archived)

### Quick Reference

**Common Lookups:**
- U30 encoding: Variable-length, 7 bits/byte, continuation bit in bit 7
- Index 0: Always implicit (empty string, wildcard namespace, NaN, etc.)
- String format: U30 length + UTF-8 bytes (NOT null-terminated)
- Multiname kinds: 11 total (QNAME, MULTINAME, RTQNAME, TYPENAME, etc.)
- Trait kinds: 7 total (Slot, Method, Getter, Setter, Class, Function, Const)
- Method flags: 8 flags (NEED_ARGUMENTS, HAS_OPTIONAL, HAS_PARAM_NAMES, etc.)

**Critical Rules:**
- Parse in exact order (cannot skip ahead or reorder sections)
- Pool counts include implicit index 0 (count=5 means indices 0-4, but only 4 in file)
- Trait kind is low 4 bits, attributes are high 4 bits of kind byte
- Jump offsets are relative to instruction AFTER the jump
- All multi-byte integers are little-endian

---

## File Structure

### Complete ABC File Layout

```
ABC File:
├── Header
│   ├── minor_version (U16)
│   └── major_version (U16)
├── Constant Pools
│   ├── Integer pool (S32[])
│   ├── Unsigned integer pool (U32[])
│   ├── Double pool (D64[])
│   ├── String pool (UTF-8 strings)
│   ├── Namespace pool
│   ├── Namespace set pool
│   └── Multiname pool
├── Method Info Array
├── Metadata Info Array
├── Class Definitions
│   ├── Instance Info Array (instance members, inheritance)
│   └── Class Info Array (static members)
├── Script Info Array
└── Method Body Array (bytecode, exception handlers)
```

### Parsing Order

The ABC file **must** be parsed in this exact order:

1. Header (minor_version, major_version)
2. Integer pool
3. Unsigned integer pool
4. Double pool
5. String pool
6. Namespace pool
7. Namespace set pool
8. Multiname pool
9. Method info array
10. Metadata info array
11. Instance info array
12. Class info array
13. Script info array
14. Method body info array

---

## Data Types

### Variable-Length Encoding

#### U30 Encoding

Unsigned 30-bit integer using variable-length encoding:

- **1 byte**: Values 0-127 (0x00-0x7F)
- **2 bytes**: Values 128-16383 (0x80-0x3FFF)
- **3-5 bytes**: Larger values up to 2^30-1

**Format:**
- Each byte: 7 data bits + 1 continuation bit
- Continuation bit (bit 7): 1 = more bytes follow, 0 = last byte
- Little-endian bit order

**Examples:**

| Value | Hex Bytes | Binary |
|-------|-----------|--------|
| 0 | `00` | `0000000` |
| 127 | `7F` | `01111111` |
| 128 | `80 01` | `10000000 00000001` |
| 255 | `FF 01` | `11111111 00000001` |
| 16383 | `FF 7F` | `11111111 01111111` |

**Visual Encoding Examples:**

**Value 0:**
```
Bytes: 00
Binary: 0|0000000
         ↑ stop bit (0 = last byte)

Values 0-127: single byte
```

**Value 128:**
```
Bytes: 80 01
Binary: 1|0000000 0|0000001
         ↑ continue  ↑ stop

Decode: (0x00) | (0x01 << 7) = 0 + 128 = 128
```

**Value 16383 (0x3FFF):**
```
Bytes: FF 7F
Binary: 1|1111111 0|1111111
         ↑ continue  ↑ stop

Decode: (0x7F) | (0x7F << 7) = 127 + 16256 = 16383
```

**Decoding Algorithm:**
```cpp
uint32_t result = 0;
int shift = 0;
for (int i = 0; i < 5; i++) {
    uint8_t byte = *ptr++;
    result |= (byte & 0x7F) << shift;
    if (!(byte & 0x80)) break;  // Stop bit not set
    shift += 7;
}
```

#### S32 Encoding

Signed 32-bit integer using same variable-length encoding as U30, with sign extension applied to the final value.

#### U16 (Fixed)

Unsigned 16-bit integer, little-endian, 2 bytes.

#### U8 (Fixed)

Unsigned 8-bit integer, 1 byte.

#### D64 (Fixed)

64-bit IEEE 754 double-precision float, little-endian, 8 bytes.

### Index 0 Special Values

**All constant pools** use index 0 as a special implicit value that is **not stored in the file**:

| Pool Type | Index 0 Value | Meaning | Usage |
|-----------|---------------|---------|-------|
| Integer pool | `0` | Zero | Default int value |
| Unsigned integer pool | `0` | Zero | Default uint value |
| Double pool | `NaN` | Not a Number | Uninitialized Number |
| String pool | `""` | Empty string | No name / anonymous |
| Namespace pool | `*` | Any namespace | Public wildcard |
| Namespace set pool | `[]` | Empty set | No namespace filter |
| Multiname pool | `*` | Any name | Dynamic property |

**Pool Count Encoding:**

If count is `n`, the file contains `n-1` explicit entries (indices 1 through n-1), with index 0 being implicit.

**Example:**
```
String pool count: 0x05 (5)
This means:
- Index 0: "" (implicit, not in file)
- Index 1-4: Stored in file (4 entries)
- Total pool size: 5 strings

When parsing:
pool.push_back("");  // Add index 0
for (i = 1; i < count; i++) {
    pool.push_back(read_string());  // Read indices 1-4
}
```

**Common Mistake:**
❌ Reading `count` entries (would read past end of file)
✅ Reading `count - 1` entries (correct)

---

## Constant Pools

### Integer Pool

**Format:**
```
U30 count
S32 entries[count-1]
```

Stores signed 32-bit integers. Index 0 represents value `0`.

### Unsigned Integer Pool

**Format:**
```
U30 count
U32 entries[count-1]
```

Stores unsigned 32-bit integers. Index 0 represents value `0`.

### Double Pool

**Format:**
```
U30 count
D64 entries[count-1]
```

Stores 64-bit IEEE 754 doubles. Index 0 represents `NaN`.

### String Pool

**Format:**
```
U30 count
String entries[count-1]

String:
├── U30 length (bytes, not characters)
└── UTF-8 data[length]
```

Strings are UTF-8 encoded, **not** null-terminated. Index 0 represents empty string `""`.

### Namespace Pool

**Format:**
```
U30 count
Namespace entries[count-1]

Namespace:
├── U8 kind
└── U30 name_index (into string pool)
```

#### Namespace Kinds

| Constant | Hex Value | Description |
|----------|-----------|-------------|
| `NAMESPACE` | `0x08` | General namespace |
| `PACKAGE_NAMESPACE` | `0x16` | Package namespace |
| `PACKAGE_INTERNAL_NS` | `0x17` | Package-internal namespace |
| `PROTECTED_NAMESPACE` | `0x18` | Protected namespace |
| `EXPLICIT_NAMESPACE` | `0x19` | Explicit namespace |
| `STATIC_PROTECTED_NS` | `0x1A` | Static protected namespace |
| `PRIVATE_NS` | `0x05` | Private namespace |

### Namespace Set Pool

**Format:**
```
U30 count
NamespaceSet entries[count-1]

NamespaceSet:
├── U30 ns_count
└── U30 namespace_indices[ns_count]
```

Namespace sets are arrays of namespace indices used for multiname resolution.

### Multiname Pool

**Format:**
```
U30 count
Multiname entries[count-1]

Multiname:
└── U8 kind
    └── [kind-specific data]
```

#### Multiname Kinds

| Constant | Hex Value | Data Fields |
|----------|-----------|-------------|
| `QNAME` | `0x07` | U30 ns_index, U30 name_index |
| `QNAME_A` | `0x0D` | U30 ns_index, U30 name_index (attribute) |
| `RTQNAME` | `0x0F` | U30 name_index (runtime namespace) |
| `RTQNAME_A` | `0x10` | U30 name_index (runtime ns, attribute) |
| `RTQNAME_L` | `0x11` | (no data - both runtime) |
| `RTQNAME_LA` | `0x12` | (no data - both runtime, attribute) |
| `MULTINAME` | `0x09` | U30 name_index, U30 ns_set_index |
| `MULTINAME_A` | `0x0E` | U30 name_index, U30 ns_set_index (attr) |
| `MULTINAME_L` | `0x1B` | U30 ns_set_index (late-bound name) |
| `MULTINAME_LA` | `0x1C` | U30 ns_set_index (late-bound, attribute) |
| `TYPENAME` | `0x1D` | U30 name_index, U30 param_count, U30 params[] |

**Notes:**
- `_A` suffix indicates attribute access (e.g., `@attribute`)
- `RT` prefix indicates runtime-resolved namespace
- `_L` suffix indicates late-bound (runtime-resolved name)
- `TYPENAME` is for generic types like `Vector.<int>`

---

## Methods

### Method Info

**Format:**
```
U30 method_count
MethodInfo methods[method_count]

MethodInfo:
├── U30 param_count
├── U30 return_type (multiname index, 0 = any)
├── U30 param_types[param_count]
├── U30 name_index (debug name, 0 = anonymous)
├── U8 flags
├── [if HAS_OPTIONAL] OptionDetail options[]
└── [if HAS_PARAM_NAMES] U30 param_names[param_count]
```

#### Method Flags

| Flag | Hex Value | Description |
|------|-----------|-------------|
| `NEED_ARGUMENTS` | `0x01` | Method needs `arguments` object |
| `NEED_ACTIVATION` | `0x02` | Method needs activation object |
| `NEED_REST` | `0x04` | Method has rest parameter (`...rest`) |
| `HAS_OPTIONAL` | `0x08` | Method has optional parameters |
| `IGNORE_REST` | `0x10` | Ignore rest arguments |
| `EXPLICIT` | `0x20` | Method is explicit (not dynamic) |
| `SET_DXNS` | `0x40` | Method sets default XML namespace |
| `HAS_PARAM_NAMES` | `0x80` | Parameter names present (debug info) |

#### Optional Parameters

**Format:**
```
U30 option_count
OptionDetail options[option_count]

OptionDetail:
├── U30 value_index (into appropriate constant pool)
└── U8 value_kind (constant pool type)
```

**Value Kinds:**

| Value | Constant Pool | Description |
|-------|---------------|-------------|
| `0x00` | - | Undefined |
| `0x01` | String | String value |
| `0x03` | Integer | Integer value |
| `0x04` | Unsigned int | Unsigned integer value |
| `0x05` | Private ns | Private namespace |
| `0x06` | Double | Double value |
| `0x08` | Namespace | Namespace value |
| `0x0A` | False | Boolean false |
| `0x0B` | True | Boolean true |
| `0x0C` | Null | Null value |

---

## Classes

### Instance Info

**Format:**
```
U30 class_count
InstanceInfo instances[class_count]

InstanceInfo:
├── U30 name_index (multiname)
├── U30 super_name_index (multiname, 0 = Object)
├── U8 flags
├── [if CLASS_PROTECTED_NS] U30 protected_ns_index
├── U30 interface_count
├── U30 interface_indices[interface_count]
├── U30 iinit_index (instance constructor method)
└── Trait traits[]
```

#### Class Flags

| Flag | Hex Value | Description |
|------|-----------|-------------|
| `CLASS_SEALED` | `0x01` | Class is sealed (not dynamic) |
| `CLASS_FINAL` | `0x02` | Class is final (cannot be extended) |
| `CLASS_INTERFACE` | `0x04` | This is an interface |
| `CLASS_PROTECTED_NS` | `0x08` | Class has protected namespace |

### Class Info

**Format:**
```
ClassInfo classes[class_count]

ClassInfo:
├── U30 cinit_index (class constructor method)
└── Trait traits[]
```

The class info array must have the same length as the instance info array, with corresponding indices.

---

## Traits

### Trait Format

**Format:**
```
U30 trait_count
Trait traits[trait_count]

Trait:
├── U30 name_index (multiname)
├── U8 kind_and_attributes
│   ├── Low 4 bits: trait kind (0x0F)
│   └── High 4 bits: attributes (0xF0)
├── [kind-specific data]
└── [if ATTR_METADATA] U30 metadata_indices[]
```

#### Trait Kinds

| Kind | Value | Description | Data Fields |
|------|-------|-------------|-------------|
| `TRAIT_SLOT` | `0` | Variable slot | slot_id, type_name, vindex, vkind |
| `TRAIT_METHOD` | `1` | Method | disp_id, method_index |
| `TRAIT_GETTER` | `2` | Getter function | disp_id, method_index |
| `TRAIT_SETTER` | `3` | Setter function | disp_id, method_index |
| `TRAIT_CLASS` | `4` | Class reference | slot_id, class_index |
| `TRAIT_FUNCTION` | `5` | Function closure | slot_id, method_index |
| `TRAIT_CONST` | `6` | Constant slot | slot_id, type_name, vindex, vkind |

#### Trait Attributes

| Attribute | Hex Value | Description |
|-----------|-----------|-------------|
| `ATTR_FINAL` | `0x10` | Trait is final |
| `ATTR_OVERRIDE` | `0x20` | Trait overrides parent |
| `ATTR_METADATA` | `0x40` | Trait has metadata |

#### Trait Data by Kind

**TRAIT_SLOT / TRAIT_CONST:**
```
U30 slot_id
U30 type_name (multiname index)
U30 vindex (value index into constant pool)
[if vindex != 0] U8 vkind (constant pool type)
```

**TRAIT_METHOD / TRAIT_GETTER / TRAIT_SETTER:**
```
U30 disp_id (dispatch ID)
U30 method_index
```

**TRAIT_CLASS:**
```
U30 slot_id
U30 class_index
```

**TRAIT_FUNCTION:**
```
U30 slot_id
U30 method_index
```

---

## Scripts

### Script Info

**Format:**
```
U30 script_count
ScriptInfo scripts[script_count]

ScriptInfo:
├── U30 init_index (script initialization method)
└── Trait traits[]
```

Scripts represent top-level code execution units. The init method is called when the script is loaded.

---

## Method Bodies

### Method Body Info

**Format:**
```
U30 body_count
MethodBodyInfo bodies[body_count]

MethodBodyInfo:
├── U30 method_index (which method this body is for)
├── U30 max_stack (maximum stack depth)
├── U30 max_regs (local register count)
├── U30 scope_depth (initial scope stack depth)
├── U30 max_scope_depth (maximum scope stack depth)
├── U30 code_length
├── U8 code[code_length] (bytecode)
├── U30 exception_count
├── ExceptionInfo exceptions[exception_count]
└── Trait traits[]
```

### Exception Info

**Format:**
```
ExceptionInfo:
├── U30 from (start PC of try block)
├── U30 to (end PC of try block)
├── U30 target (PC of catch/finally block)
├── U30 exc_type_index (multiname, 0 = catch all)
└── U30 var_name_index (multiname, exception variable name)
```

---

## AVM2 Opcode Reference

### Opcode Format

Opcodes are variable-length instructions:
```
U8 opcode
[operands based on opcode]
```

### Operand Types

| Type | Description | Encoding |
|------|-------------|----------|
| U8 | Unsigned 8-bit | 1 byte |
| U30 | Unsigned 30-bit | Variable-length (1-5 bytes) |
| S24 | Signed 24-bit | Variable-length (1-4 bytes) |

### Control Flow (0x10-0x1B)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `jump` | `0x10` | S24 offset | Unconditional jump |
| `iftrue` | `0x11` | S24 offset | Jump if true |
| `iffalse` | `0x12` | S24 offset | Jump if false |
| `ifeq` | `0x13` | S24 offset | Jump if equal |
| `ifne` | `0x14` | S24 offset | Jump if not equal |
| `iflt` | `0x15` | S24 offset | Jump if less than |
| `ifle` | `0x16` | S24 offset | Jump if less or equal |
| `ifgt` | `0x17` | S24 offset | Jump if greater than |
| `ifge` | `0x18` | S24 offset | Jump if greater or equal |
| `ifstricteq` | `0x19` | S24 offset | Jump if strict equal (===) |
| `ifstrictne` | `0x1A` | S24 offset | Jump if strict not equal (!==) |
| `lookupswitch` | `0x1B` | Complex | Switch statement |

**Note:** Jump offsets are relative to the instruction **after** the jump instruction.

### Stack Operations (0x20-0x2F)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `pushnull` | `0x20` | - | Push null |
| `pushundefined` | `0x21` | - | Push undefined |
| `pushbyte` | `0x24` | U8 value | Push signed byte |
| `pushshort` | `0x25` | U30 value | Push signed short |
| `pushtrue` | `0x26` | - | Push true |
| `pushfalse` | `0x27` | - | Push false |
| `pushnan` | `0x28` | - | Push NaN |
| `pop` | `0x29` | - | Pop stack |
| `dup` | `0x2A` | - | Duplicate top value |
| `swap` | `0x2B` | - | Swap top two values |
| `pushstring` | `0x2C` | U30 index | Push string from pool |
| `pushint` | `0x2D` | U30 index | Push int from pool |
| `pushuint` | `0x2E` | U30 index | Push uint from pool |
| `pushdouble` | `0x2F` | U30 index | Push double from pool |

### Local Variables (0x60-0x6F, 0xD0-0xD7)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `getlex` | `0x60` | U30 index | Find and get property |
| `getlocal` | `0x62` | U30 index | Get local variable |
| `setlocal` | `0x63` | U30 index | Set local variable |
| `getslot` | `0x6C` | U30 index | Get object slot |
| `setslot` | `0x6D` | U30 index | Set object slot |
| `getlocal_0` | `0xD0` | - | Get local 0 (optimized) |
| `getlocal_1` | `0xD1` | - | Get local 1 |
| `getlocal_2` | `0xD2` | - | Get local 2 |
| `getlocal_3` | `0xD3` | - | Get local 3 |
| `setlocal_0` | `0xD4` | - | Set local 0 (optimized) |
| `setlocal_1` | `0xD5` | - | Set local 1 |
| `setlocal_2` | `0xD6` | - | Set local 2 |
| `setlocal_3` | `0xD7` | - | Set local 3 |

### Property Access (0x61, 0x66, 0x68)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `setproperty` | `0x61` | U30 multiname | Set property |
| `getproperty` | `0x66` | U30 multiname | Get property |
| `initproperty` | `0x68` | U30 multiname | Initialize property |

### Method Calls (0x40-0x4F)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `newfunction` | `0x40` | U30 method | Create function closure |
| `call` | `0x41` | U30 arg_count | Call function |
| `construct` | `0x42` | U30 arg_count | Call constructor |
| `callsuper` | `0x45` | U30 mn, U30 count | Call super method |
| `callproperty` | `0x46` | U30 mn, U30 count | Call property |
| `returnvoid` | `0x47` | - | Return void |
| `returnvalue` | `0x48` | - | Return value |
| `constructsuper` | `0x49` | U30 arg_count | Call super constructor |
| `constructprop` | `0x4A` | U30 mn, U30 count | Construct property |
| `callsupervoid` | `0x4E` | U30 mn, U30 count | Call super (no return) |
| `callpropvoid` | `0x4F` | U30 mn, U30 count | Call property (no return) |

### Arithmetic Operations (0xA0-0xB0)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `add` | `0xA0` | - | Add (TOS-1 + TOS) |
| `subtract` | `0xA1` | - | Subtract |
| `multiply` | `0xA2` | - | Multiply |
| `divide` | `0xA3` | - | Divide |
| `modulo` | `0xA4` | - | Modulo |
| `lshift` | `0xA5` | - | Left shift |
| `rshift` | `0xA6` | - | Right shift (signed) |
| `urshift` | `0xA7` | - | Right shift (unsigned) |
| `bitand` | `0xA8` | - | Bitwise AND |
| `bitor` | `0xA9` | - | Bitwise OR |
| `bitxor` | `0xAA` | - | Bitwise XOR |
| `equals` | `0xAB` | - | Equals (==) |
| `strictequals` | `0xAC` | - | Strict equals (===) |
| `lessthan` | `0xAD` | - | Less than |
| `lessequals` | `0xAE` | - | Less or equal |
| `greaterthan` | `0xAF` | - | Greater than |
| `greaterequals` | `0xB0` | - | Greater or equal |

### Type Operations (0x80-0x95)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `coerce` | `0x80` | U30 multiname | Coerce to type |
| `coerce_a` | `0x82` | - | Coerce to any |
| `coerce_s` | `0x85` | - | Coerce to string |
| `astype` | `0x86` | U30 multiname | Cast to type |
| `astypelate` | `0x87` | - | Late cast |
| `negate` | `0x90` | - | Numeric negation |
| `increment` | `0x91` | - | Increment |
| `inclocal` | `0x92` | U30 index | Increment local |
| `decrement` | `0x93` | - | Decrement |
| `declocal` | `0x94` | U30 index | Decrement local |
| `typeof` | `0x95` | - | Get type name |

### Object Creation (0x55-0x5E)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `newobject` | `0x55` | U30 arg_count | Create object {} |
| `newarray` | `0x56` | U30 arg_count | Create array [] |
| `newactivation` | `0x57` | - | Create activation object |
| `newclass` | `0x58` | U30 class_index | Create class instance |
| `getdescendants` | `0x59` | U30 multiname | Get XML descendants |
| `newcatch` | `0x5A` | U30 catch_index | Create catch scope |
| `findpropstrict` | `0x5D` | U30 multiname | Find property (strict) |
| `findproperty` | `0x5E` | U30 multiname | Find property |

### Scope Management (0x1C, 0x1D, 0x30, 0x64, 0x65)

| Opcode | Hex | Operands | Description |
|--------|-----|----------|-------------|
| `pushwith` | `0x1C` | - | Push with scope |
| `popscope` | `0x1D` | - | Pop scope |
| `pushscope` | `0x30` | - | Push scope |
| `getscopeobject` | `0x64` | U8 index | Get scope object |
| `getouterscope` | `0x65` | U30 index | Get outer scope |

### Opcode Implementation Status

Of the 256 possible opcodes (0x00-0xFF), approximately **100 are implemented** in the reference AVM2 implementation. Unimplemented opcodes are typically reserved or deprecated.

---

## DoABC Tag Format

The ABC data is embedded in SWF files using DoABC tags.

### DoABC vs DoABC2 Tags

Both tags contain **identical** ABC data with the same format:

**DoABC (Tag 82):**
```
DoABC Tag (ID: 82):
├── U32 flags
├── STRING name (null-terminated)
└── ABC data (remaining bytes)
```

**DoABC2 (Tag 86):**
```
DoABC2 Tag (ID: 86):
├── U32 flags
├── STRING name (null-terminated)
└── ABC data (remaining bytes)
```

**Difference:** Only the tag ID differs (82 vs 86). The internal structure and ABC data format are **identical**.

### Tag Fields

**Flags:**
- `0x00`: Eager initialization - execute immediately when loaded
- `0x01`: Lazy initialization - defer execution until first use

**Name:**
- Debug name for the ABC block
- Often contains package name (e.g., "com.example.MyClass") or "frame1"
- Null-terminated string
- Used for debugging and identification

**ABC Data:**
- Complete ABC file as described in this document
- Starts with version header (U16 minor, U16 major)
- Followed by all constant pools, methods, classes, scripts, and method bodies

### Implementation Note

Parse both tags identically:
```cpp
case SWF_TAG_DO_ABC:    // Tag 82
case SWF_TAG_DO_ABC2:   // Tag 86
{
    // Same parsing code for both
    uint32_t flags = read_u32(ptr);
    std::string name = read_cstring(ptr);
    // Parse ABC data...
}
```

---

## Common ABC Patterns

### Typical Pool Sizes

**Simple "Hello World" AS3:**
- Strings: 20-30
- Namespaces: 5-10
- Multinames: 10-20
- Methods: 5-10
- Classes: 1-2
- Integers: 5-10
- Doubles: 0-3

**Medium Application:**
- Strings: 200-500
- Namespaces: 20-50
- Multinames: 100-300
- Methods: 50-200
- Classes: 10-50
- Integers: 20-100
- Doubles: 5-50

**Large Game/Application:**
- Strings: 1000+
- Namespaces: 100+
- Multinames: 500+
- Methods: 500+
- Classes: 100+

### Common Multiname Patterns

**Public property access:**
```
Kind: QNAME (0x07)
Namespace: Public package (kind=0x16, name="")
Name: Property name (e.g., "x", "visible", "width")

Example: obj.visible
```

**Private member:**
```
Kind: QNAME (0x07)
Namespace: Private (kind=0x05, unique generated name)
Name: Member name (e.g., "_internalData")

Example: this._internalData
```

**Package member:**
```
Kind: QNAME (0x07)
Namespace: Package (kind=0x16, name="com.example.myapp")
Name: Class or function name

Example: com.example.myapp.MyClass
```

**Dynamic property (bracket access):**
```
Kind: MULTINAME_L (0x1B)
Namespace Set: Public namespaces
Name: Runtime-resolved

Example: obj[propertyName]
```

**Generic type (Vector):**
```
Kind: TYPENAME (0x1D)
Name: "Vector" (base type)
Type params: [int, String, MyClass, etc.]

Example: Vector.<int>, Vector.<String>
```

### Common Method Signatures

**Simple function (no args, returns void):**
```
param_count: 0
return_type: 0 (any/void)
param_types: []
flags: 0x00
```

**Function with parameters:**
```
param_count: 2
return_type: multiname index (String, int, etc.)
param_types: [multiname1, multiname2]
flags: 0x00
```

**Constructor:**
```
param_count: varies
return_type: 0 (constructors return void)
param_types: [constructor params]
name_index: 0 (constructors are anonymous)
flags: 0x00 or 0x01 (NEED_ARGUMENTS)
```

**Getter property:**
```
Trait kind: TRAIT_GETTER (2)
Method signature:
  param_count: 0
  return_type: property type
  flags: 0x00
```

**Setter property:**
```
Trait kind: TRAIT_SETTER (3)
Method signature:
  param_count: 1
  return_type: 0 (void)
  param_types: [property type]
  flags: 0x00
```

**Function with optional parameters:**
```
param_count: 3
param_types: [String, int, Boolean]
flags: 0x08 (HAS_OPTIONAL)
options: [
  { value_index: 1, value_kind: 0x03 },  // int 0
  { value_index: 0, value_kind: 0x0A }   // false
]

Example: function test(name:String, count:int=0, flag:Boolean=false)
```

**Rest parameter function:**
```
param_count: 1
param_types: [String]
flags: 0x04 (NEED_REST)

Example: function log(message:String, ...args)
```

### Common Class Patterns

**Simple class:**
```
Instance:
  name: QName to class name
  super_name: QName to "Object" (or custom superclass)
  flags: 0x01 (SEALED)
  interfaces: []
  iinit: constructor method index
  traits: [properties, methods, getters, setters]

Class:
  cinit: class constructor method index
  traits: [static members]
```

**Final class:**
```
flags: 0x03 (SEALED | FINAL)
```

**Dynamic class:**
```
flags: 0x00 (not sealed, allows dynamic properties)
```

**Interface:**
```
flags: 0x04 (INTERFACE)
super_name: 0 (interfaces don't extend Object)
iinit: initialization method
traits: [method declarations only]
```

---

## References

### Official Documentation

- **Adobe ABC Format 46.16**: `github.com/adobe-flash/avmplus/blob/master/doc/abcFormat-46-16.txt`
- **SWF Specification v19**: `open-flash.github.io/mirrors/swf-spec-19.pdf`
- **Adobe AVM2 Overview**: `github.com/fallending/swfplayer-x/blob/master/doc/avm2overview.pdf` (archived)

### Reference Implementations

- **Ruffle**: `github.com/ruffle-rs/ruffle` (Rust, MIT/Apache 2.0)
- **Adobe avmplus**: `github.com/adobe-flash/avmplus` (C++, MPL 2.0)
- **RABCDAsm**: `github.com/CyberShadow/RABCDAsm` (D, GPL v3+)

---

**Document Status:** Complete technical reference
**Last Updated:** October 31, 2025
