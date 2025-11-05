# AS2 Opcode Implementation Guide: Parallel Development with Claude Code

This guide explains how to implement ActionScript 2 (AS2) opcodes in the SWFRecomp project using Claude Code's web interface for parallel execution.

## Overview

This workflow enables autonomous implementation of individual AS2 opcodes across multiple Claude Code instances. Each instance implements a specific opcode from specification through testing, working independently until completion.

## Project Structure

### The Three Repositories

**SWFRecomp** (C++ Recompiler)
- Translates SWF bytecode to C code at compile-time
- Location: `/SWFRecomp/`
- Key files:
  - `include/action/action.hpp` - Opcode enums
  - `src/action/action.cpp` - Translation logic

**SWFModernRuntime** (C Runtime Library)
- Executes the generated C code with GPU acceleration
- Location: `/SWFModernRuntime/`
- Key files:
  - `include/actionmodern/action.h` - API declarations
  - `src/actionmodern/action.c` - Opcode implementations

**SWFRecompDocs** (Documentation)
- Specifications and implementation guides
- Location: `/SWFRecompDocs/`
- Key files:
  - `specs/swf-spec-19.txt` - SWF specification with opcode values
  - `reference/trace-swf4-wasm-generation.md` - Architecture guide

### Repository Organization for Parallel Work

For Claude Code parallel execution, all three repositories are combined into a single workspace:
- `SWFRecomp/` - Recompiler code
- `SWFModernRuntime/` - Runtime code
- `SWFRecompDocs/` - Documentation

This eliminates the need to manage separate repositories and simplifies the build process.

## The Implementation Process

### Architecture Overview

```
SWF File (Flash bytecode)
    ↓
[SWFRecomp - Compile-time translation]
    ├─ Parse SWF and bytecode
    ├─ Translate opcodes to C function calls
    └─ Generate C source code
    ↓
Generated C Code
    ↓
[C Compiler - gcc/emcc]
    ├─ Compile generated code
    ├─ Link with SWFModernRuntime
    └─ Create executable
    ↓
[SWFModernRuntime - Execution]
    ├─ Stack-based execution
    ├─ Opcode implementations
    └─ Display output
```

### Stack-Based Execution Model

All AS2 operations use a runtime stack:

**Stack Structure** (8MB array, grows downward):
```
Each stack entry (24 bytes):
├─ Offset +0:  u8 type (ACTION_STACK_VALUE_F32, ACTION_STACK_VALUE_STRING, etc.)
├─ Offset +4:  u32 previous_sp (link to previous entry)
├─ Offset +8:  u32 length (for strings)
├─ Offset +16: u64 value (float, pointer, etc.)
```

**Key Macros**:
- `PUSH(type, value)` - Allocate new stack entry
- `POP()` - Move to previous entry
- `STACK_TOP_TYPE` - Read top entry type
- `STACK_TOP_VALUE` - Read top entry value
- `convertFloat(stack, sp)` - Convert top entry to float
- `convertString(stack, sp, buffer)` - Convert top entry to string

### The 7-Step Implementation Workflow

#### Step 1: Define Enum (SWFRecomp)

Add opcode to `SWFRecomp/include/action/action.hpp`:

```cpp
enum SWFActionType
{
    // ... existing opcodes ...
    SWF_ACTION_YOUR_OPCODE = 0xXX,  // Use hex value from specification
};
```

#### Step 2: Add Translation (SWFRecomp)

Add case to `SWFRecomp/src/action/action.cpp` in the `parseActions()` switch statement:

```cpp
case SWF_ACTION_YOUR_OPCODE:
{
    out_script << "\t" << "// Your Opcode Name" << endl
               << "\t" << "actionYourOpcode(stack, sp);" << endl;

    // If opcode has a length field (high bit 0x80 set):
    // action_buffer += length;

    break;
}
```

#### Step 3: Declare API (SWFModernRuntime)

Add function declaration to `SWFModernRuntime/include/actionmodern/action.h`:

```c
void actionYourOpcode(char* stack, u32* sp);
```

#### Step 4: Implement Runtime (SWFModernRuntime)

Implement function in `SWFModernRuntime/src/actionmodern/action.c`:

**Binary Operation Pattern**:
```c
void actionYourOpcode(char* stack, u32* sp)
{
    // Convert and pop second operand
    convertFloat(stack, sp);
    ActionVar a;
    popVar(stack, sp, &a);

    // Convert and pop first operand
    convertFloat(stack, sp);
    ActionVar b;
    popVar(stack, sp, &b);

    // Perform operation
    float result = b.value.f32 OP a.value.f32;

    // Push result
    PUSH(ACTION_STACK_VALUE_F32, VAL(u32, &result));
}
```

**Unary Operation Pattern**:
```c
void actionYourOpcode(char* stack, u32* sp)
{
    // Convert and pop operand
    convertFloat(stack, sp);
    ActionVar a;
    popVar(stack, sp, &a);

    // Perform operation
    float result = OPERATION(a.value.f32);

    // Push result
    PUSH(ACTION_STACK_VALUE_F32, VAL(u32, &result));
}
```

**String Operation Pattern**:
```c
void actionYourOpcode(char* stack, u32* sp, char* str_buffer)
{
    // Get string from stack
    ActionVar a;
    peekVar(stack, sp, &a);
    const char* str = (const char*) VAL(u64, &STACK_TOP_VALUE);

    // Process string
    // ... operation logic ...

    // Generate result
    snprintf(str_buffer, 17, "result");

    // Pop input and push result
    POP();
    PUSH_STR(str_buffer, strlen(str_buffer));
}
```

#### Step 5: Create Test SWF

Create an ActionScript test file that uses the opcode:

**Example test.as**:
```actionscript
// For arithmetic operation
trace(5 OPERATION 3);  // Replace OPERATION with your opcode's operator
```

Compile to SWF using Flex SDK or MTASC compiler. Verify the expected output manually.

#### Step 6: Setup Test Directory

```bash
# Create test directory
cd SWFRecomp/tests
mkdir your_opcode_swf_4

# Copy template files
cp -r trace_swf_4/runtime your_opcode_swf_4/
cp trace_swf_4/Makefile your_opcode_swf_4/
cp trace_swf_4/build_wasm.sh your_opcode_swf_4/
cp trace_swf_4/config.toml your_opcode_swf_4/

# Place your test.swf in the directory
# Edit config.toml to update paths if needed
```

**config.toml structure**:
```toml
[input]
path_to_swf = "test.swf"
output_tags_folder = "RecompiledTags"
output_scripts_folder = "RecompiledScripts"

[output]
do_recompile = true
```

#### Step 7: Build and Verify

```bash
# Navigate to test directory
cd SWFRecomp/tests/your_opcode_swf_4

# Run recompiler
../../build/SWFRecomp config.toml

# Build native executable
make

# Run test
./build/native/TestSWFRecompiled

# Verify output matches expected result
```

## Build System Details

### Building SWFRecomp

```bash
cd SWFRecomp
mkdir -p build && cd build
cmake ..
make
cd ../..
```

### Test Directory Structure

```
your_opcode_swf_4/
├── test.swf ..................... Input Flash file
├── config.toml .................. Recompiler configuration
├── runtime/
│   └── native/
│       ├── main.c ............... Entry point
│       ├── runtime.c ............ Stub implementations
│       └── include/
│           ├── recomp.h ......... Type definitions
│           └── stackvalue.h ..... Stack types/macros
├── Makefile ..................... Native build
├── build_wasm.sh ................ WebAssembly build
├── RecompiledScripts/ ........... Generated by SWFRecomp
└── RecompiledTags/ .............. Generated by SWFRecomp
```

### Running All Tests

```bash
cd SWFRecomp/tests
bash all_tests.sh
```

## Opcode Categories and Complexity

### Simple (1-2 hours)

**Arithmetic**: Modulo, Increment, Decrement
- Binary operations on two floats
- Simple math operations
- Pattern: convert → pop → pop → compute → push

**Comparison**: Greater, GreaterEquals, LessEquals
- Compare two values
- Return boolean (0.0 or 1.0)
- Pattern: convert → pop → pop → compare → push bool

### Medium (2-4 hours)

**String Operations**: Substring, CharAt, ToUpperCase, ToLowerCase
- String manipulation
- May require character iteration
- Pattern: peek/pop string → process → push result

**Logic**: XOR, ShiftLeft, ShiftRight
- Bitwise or boolean operations
- Type conversion considerations
- Pattern: convert to int → operate → push result

**Stack Operations**: Duplicate, Swap
- Stack manipulation without computation
- Careful with stack pointer management
- Pattern: peek/copy → rearrange → push

### Complex (4-8 hours)

**Control Flow**: Switch, Call, Return
- May require additional infrastructure
- Jump table management
- Call stack considerations

**Object/Array**: GetProperty, SetProperty, GetMember, SetMember
- Requires object model implementation
- Hash table or property storage
- Type system integration
- **IMPORTANT**: See "Object Allocation Model" section below

**Advanced**: InitArray, InitObject, Enumerate
- Complex data structure creation
- Memory management with reference counting
- Iterator patterns
- **IMPORTANT**: See "Object Allocation Model" section below

## Currently Implemented Opcodes (24 total)

| Opcode | Hex  | Name | Category |
|--------|------|------|----------|
| 0x00 | 0x00 | END_OF_ACTIONS | Control |
| 0x07 | 0x07 | STOP | Control |
| 0x0A | 0x0A | ADD | Arithmetic |
| 0x0B | 0x0B | SUBTRACT | Arithmetic |
| 0x0C | 0x0C | MULTIPLY | Arithmetic |
| 0x0D | 0x0D | DIVIDE | Arithmetic |
| 0x0E | 0x0E | EQUALS | Comparison |
| 0x0F | 0x0F | LESS | Comparison |
| 0x10 | 0x10 | AND | Logic |
| 0x11 | 0x11 | OR | Logic |
| 0x12 | 0x12 | NOT | Logic |
| 0x13 | 0x13 | STRING_EQUALS | String |
| 0x14 | 0x14 | STRING_LENGTH | String |
| 0x17 | 0x17 | POP | Stack |
| 0x1C | 0x1C | GET_VARIABLE | Variables |
| 0x1D | 0x1D | SET_VARIABLE | Variables |
| 0x21 | 0x21 | STRING_ADD | String |
| 0x26 | 0x26 | TRACE | Debug |
| 0x34 | 0x34 | GET_TIME | Special |
| 0x88 | 0x88 | CONSTANT_POOL | Special |
| 0x96 | 0x96 | PUSH | Stack |
| 0x99 | 0x99 | JUMP | Control |
| 0x9D | 0x9D | IF | Control |

## Object Allocation Model

### Overview

**IMPORTANT**: For opcodes that create or manipulate objects/arrays (InitObject, InitArray, GetMember, SetMember, etc.), the system uses **compile-time inlined reference counting** instead of runtime garbage collection.

### Design Philosophy

**Reference Counting at Recompiler Level**:
- SWFRecomp emits inline refcount increment/decrement operations
- Deterministic memory management (no GC pauses)
- Compiler can optimize refcount operations
- Runtime only provides allocation/deallocation primitives

**NOT using Runtime GC**:
- No garbage collector in SWFModernRuntime
- No stop-the-world pauses
- Predictable performance
- Lower memory overhead

### Implementation Strategy

When implementing object/array opcodes, follow this pattern:

#### 1. Runtime Provides Primitives (SWFModernRuntime)

```c
// Object allocation/deallocation primitives
typedef struct {
    u32 refcount;
    // ... object properties ...
} ASObject;

ASObject* allocObject();
void retainObject(ASObject* obj);  // Increment refcount
void releaseObject(ASObject* obj); // Decrement refcount, free if zero
```

#### 2. Recompiler Emits Inline Refcount Operations (SWFRecomp)

When translating object operations, emit refcount management:

```cpp
// Example: InitObject translation in SWFRecomp/src/action/action.cpp
case SWF_ACTION_INIT_OBJECT:
{
    out_script << "\t" << "// InitObject" << endl
               << "\t" << "ASObject* obj = allocObject();" << endl
               << "\t" << "obj->refcount = 1;  // Initial reference" << endl
               << "\t" << "PUSH(ACTION_STACK_VALUE_OBJECT, VAL(u64, obj));" << endl;
    break;
}

// Example: Setting a property (increments refcount)
case SWF_ACTION_SET_MEMBER:
{
    out_script << "\t" << "// SetMember - inline refcount management" << endl
               << "\t" << "actionSetMember(stack, sp);" << endl
               << "\t" << "// retainObject() called within actionSetMember" << endl;
    break;
}
```

#### 3. Reference Counting Rules

**When to Increment (`retainObject`)**:
- Storing object reference in a variable
- Adding object to an array/container
- Assigning object to a property
- Returning object from a function

**When to Decrement (`releaseObject`)**:
- Popping object from stack (if not stored elsewhere)
- Overwriting a variable that held an object
- Removing object from array
- Function/scope cleanup

**Compiler Optimizations**:
- Elide refcount operations when object lifetime is obvious
- Combine increment/decrement pairs that cancel out
- Use move semantics where possible

#### 4. Stack Interaction

Objects on the stack maintain refcounts:

```c
// Pushing object to stack
PUSH(ACTION_STACK_VALUE_OBJECT, VAL(u64, obj));
// obj->refcount already = 1 from allocation

// Popping object from stack
ASObject* obj = (ASObject*) VAL(u64, &STACK_TOP_VALUE);
POP();
// Don't release if transferring to variable/property
// Do release if discarding
```

#### 5. Example: InitObject Implementation

**SWFRecomp Translation** (action.cpp):
```cpp
case SWF_ACTION_INIT_OBJECT:
{
    // Number of properties is on stack
    out_script << "\t" << "u32 num_props;" << endl
               << "\t" << "popU32(stack, sp, &num_props);" << endl
               << "\t" << "ASObject* obj = allocObject(num_props);" << endl
               << "\t" << "for (u32 i = 0; i < num_props; i++) {" << endl
               << "\t" << "    initObjectProperty(stack, sp, obj);" << endl
               << "\t" << "}" << endl
               << "\t" << "PUSH(ACTION_STACK_VALUE_OBJECT, VAL(u64, obj));" << endl;
    break;
}
```

**SWFModernRuntime Implementation** (action.c):
```c
ASObject* allocObject(u32 num_properties)
{
    ASObject* obj = malloc(sizeof(ASObject) + num_properties * sizeof(ASProperty));
    obj->refcount = 1;  // Initial reference
    obj->num_properties = num_properties;
    return obj;
}

void initObjectProperty(char* stack, u32* sp, ASObject* obj)
{
    // Pop value
    ActionVar val;
    popVar(stack, sp, &val);

    // Pop property name
    const char* name = (const char*) VAL(u64, &STACK_TOP_VALUE);
    POP();

    // Store property (with refcount management if val is object)
    setProperty(obj, name, &val);
    if (val.type == ACTION_STACK_VALUE_OBJECT) {
        retainObject((ASObject*) val.value.u64);  // Retain when storing
    }
}

void releaseObject(ASObject* obj)
{
    if (obj == NULL) return;

    obj->refcount--;
    if (obj->refcount == 0) {
        // Release all property values
        for (u32 i = 0; i < obj->num_properties; i++) {
            if (obj->properties[i].value.type == ACTION_STACK_VALUE_OBJECT) {
                releaseObject((ASObject*) obj->properties[i].value.value.u64);
            }
        }
        free(obj);
    }
}
```

### Design Considerations

**Why Inline at Compile Time?**
- Compiler can see object lifetimes across multiple opcodes
- Can optimize away temporary references
- No runtime overhead for reference tracking
- Deterministic cleanup (no GC heuristics)

**Trade-offs**:
- ✅ Deterministic performance (no GC pauses)
- ✅ Simpler runtime (no GC implementation)
- ✅ Optimization opportunities (compiler sees full picture)
- ⚠️ Slightly larger generated code (refcount ops inlined)
- ⚠️ Must handle circular references (use weak references or explicit breaking)

### Circular Reference Handling

For circular references (rare in Flash AS2), use:
- **Weak references** for parent pointers
- **Explicit cleanup** in frame/scope exit
- **Cycle detection** for complex structures (optional, usually not needed)

### Testing Object Refcounts

Add assertions in debug builds:

```c
#ifdef DEBUG
void assertRefcount(ASObject* obj, u32 expected) {
    assert(obj->refcount == expected);
}
#endif
```

**IMPORTANT**: Before implementing any object/array opcodes, coordinate with the team to establish the base object model (ASObject structure, property storage, refcount primitives). These are shared infrastructure that multiple opcodes will use.

## Common Implementation Patterns

### Type Conversions

Flash has implicit type conversions that must be respected:

**String to Number**:
- Empty string → 0
- Numeric string → parsed value
- Non-numeric → NaN

**Number to String**:
- Format as decimal
- NaN → "NaN"
- Infinity → "Infinity"

**Boolean Context**:
- 0, NaN, null, undefined, "" → false
- Everything else → true

### Error Handling

Most opcodes should handle edge cases gracefully:
- Division by zero → Infinity or NaN
- Array out of bounds → undefined
- Null/undefined operations → type-specific defaults

### Stack Discipline

**Critical Rules**:
1. Every POP must have a matching previous PUSH
2. Every operation should leave the stack balanced
3. Type field must match value field
4. String pointers must remain valid

**Common Mistakes**:
- Forgetting to POP before PUSH in replacement operations
- Incorrect type in PUSH macro
- Not handling string buffer lifetime
- Stack pointer corruption from incorrect sp manipulation

## Testing Strategies

### Unit Testing

Each test should focus on one operation:
```actionscript
// Test basic case
trace(5 OP 3);

// Test edge cases
trace(0 OP 0);
trace(-1 OP 5);
trace(1.5 OP 2.5);
```

### Integration Testing

Test interactions between opcodes:
```actionscript
// Test compound expressions
trace((5 OP1 3) OP2 (8 OP3 2));

// Test with variables
var x = 5;
var y = 3;
trace(x OP y);
```

### Expected Output

Document expected output for verification:
```
Expected output:
8
0
4
3.75
```

## Debugging Tips

### Common Build Errors

**"Unimplemented action 0xXX"**
- Opcode not in enum (Step 1)
- Check `SWFRecomp/include/action/action.hpp`

**"undefined reference to actionXxx"**
- Missing declaration or implementation (Steps 3-4)
- Check `action.h` has declaration AND `action.c` has implementation

**"Type mismatch" errors**
- Incorrect stack macro usage
- Check PUSH/POP types match

### Runtime Debugging

**Wrong Output**:
1. Check ActionScript test produces expected SWF bytecode
2. Verify SWFRecomp generates correct C code
3. Add printf debugging in runtime implementation
4. Verify stack state before and after operation

**Crashes/Segfaults**:
1. Check stack pointer not corrupted
2. Verify string pointers are valid
3. Ensure proper POP/PUSH balance
4. Check array/buffer bounds

## Progress Tracking

As you implement each opcode, document:

**Implementation Checklist**:
- [ ] Opcode hex value confirmed from specification
- [ ] Enum added to action.hpp
- [ ] Translation case added to action.cpp
- [ ] Function declared in action.h
- [ ] Function implemented in action.c
- [ ] Test SWF created with known expected output
- [ ] Test directory created with all required files
- [ ] SWFRecomp builds successfully
- [ ] Test compiles successfully
- [ ] Test produces correct output
- [ ] Edge cases tested
- [ ] Integration with other opcodes verified

**Documentation**:
- Opcode name and hex value
- Expected behavior (from specification)
- Implementation notes
- Test cases and expected outputs
- Any edge cases or special considerations
- Integration points with other opcodes

## Autonomous Work Guidelines

When working autonomously on an opcode:

1. **Read the specification** to understand expected behavior
2. **Examine similar opcodes** already implemented
3. **Follow the 7-step workflow** systematically
4. **Test incrementally** after each major step
5. **Document issues** and solutions as you encounter them
6. **Verify edge cases** before marking complete
7. **Run the full test suite** to ensure no regressions

**Don't**:
- Skip steps in the workflow
- Assume behavior without checking specification
- Leave test failures unresolved
- Commit untested code
- Make changes to unrelated files

## Key Resources

**Specifications**:
- `SWFRecompDocs/specs/swf-spec-19.txt` - Complete SWF v4+ specification
- Official ActionScript 2.0 Language Reference

**Implementation Examples**:
- `SWFRecomp/tests/trace_swf_4/` - Simple working example
- `SWFRecomp/tests/add_floats_swf_4/` - Arithmetic operation example
- `SWFRecomp/tests/string_equals_swf_4/` - String operation example

**Build and Test**:
- `SWFRecomp/tests/all_tests.sh` - Run entire test suite
- `SWFRecomp/CMakeLists.txt` - Build configuration
- `SWFModernRuntime/` - Runtime implementation examples

## Success Criteria

An opcode implementation is complete when:

1. ✅ Builds without errors or warnings
2. ✅ Test produces correct output for basic cases
3. ✅ Edge cases handled correctly
4. ✅ No crashes or undefined behavior
5. ✅ All tests in test suite still pass
6. ✅ Code follows existing patterns and style
7. ✅ Documentation updated

## Working in Parallel

### Coordination Points

**Phase 1** (Serial - coordination required):
- Enum definitions in action.hpp
- Function declarations in action.h

**Phase 2** (Parallel - independent work):
- Translation cases in action.cpp
- Runtime implementations in action.c
- Test creation and verification

**Phase 3** (Serial - integration):
- Full test suite execution
- Regression testing
- Final verification

### Minimizing Conflicts

- Each worker implements different opcodes
- Enum additions are append-only
- Switch cases are independent
- Runtime functions are independent
- Tests are in separate directories

### Suggested Work Distribution

**Team 1 - Arithmetic**: 0x18 (StringExtract), 0x31 (Modulo), etc.

**Team 2 - Comparison**: Greater (0x67), StrictEquals (0x66)

**Team 3 - String Ops**: Substring (0x35), CharToAscii (0x32), AsciiToChar (0x33)

**Team 4 - Logic**: ToInteger (0x18), BitAnd (0x60), BitOr (0x61), BitXor (0x62)

**Team 5 - Stack Ops**: Duplicate, Swap, StackSwap (0x4B)

**Team 6 - Control Flow**: Call (0x9E), Return (0x3E)

## Conclusion

This systematic approach enables autonomous, parallel implementation of AS2 opcodes. Follow the 7-step workflow, test incrementally, and document thoroughly. Each opcode implementation should take 1-8 hours depending on complexity, with most simple operations completing in 1-3 hours.

The combined repository structure eliminates integration complexity, and the well-defined patterns make implementation straightforward. With proper testing and documentation, multiple teams can work simultaneously to rapidly expand opcode coverage.
