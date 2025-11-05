# Claude Code Instance Prompt Template

This template is used to assign a specific opcode implementation task to a Claude Code web instance.

---

## Prompt Template

```
Please read the implementation guide at SWFRecompDocs/parallel-opcode-implementation-guide.md.

Your task is to implement support for the AS2 opcode: **{OPCODE_NAME}**

## Opcode Specification

**Opcode Name**: {OPCODE_NAME}
**Hex Value**: 0x{HEX_VALUE}
**Category**: {CATEGORY}
**Estimated Complexity**: {SIMPLE|MEDIUM|COMPLEX}

**Description**: {BRIEF_DESCRIPTION}

**Operation**: {STACK_OPERATION_DESCRIPTION}

**Expected Behavior**:
{DETAILED_BEHAVIOR_FROM_SPEC}

## Your Task

Implement this opcode following the 7-step workflow:

1. **Define Enum** - Add to `SWFRecomp/include/action/action.hpp`
2. **Add Translation** - Add case to `SWFRecomp/src/action/action.cpp`
3. **Declare API** - Add to `SWFModernRuntime/include/actionmodern/action.h`
4. **Implement Runtime** - Implement in `SWFModernRuntime/src/actionmodern/action.c`
5. **Create Test SWF** - Create ActionScript test and compile to SWF
6. **Setup Test Directory** - Create `SWFRecomp/tests/{test_name}_swf_4/`
7. **Build and Verify** - Compile and verify output matches expected

## Test Cases

Your implementation should handle these test cases:

{TEST_CASE_1}
Expected output: {EXPECTED_OUTPUT_1}

{TEST_CASE_2}
Expected output: {EXPECTED_OUTPUT_2}

{TEST_CASE_3} (Edge case)
Expected output: {EXPECTED_OUTPUT_3}

## Implementation Hints

{CATEGORY_SPECIFIC_HINTS}

Similar implemented opcodes to reference:
- {SIMILAR_OPCODE_1}
- {SIMILAR_OPCODE_2}

## Documentation

Create or update these files as you work:
- `SWFRecomp/tests/{test_name}_swf_4/README.md` - Test description and expected output
- Update this file with your progress notes and any issues encountered

## Success Criteria

Your implementation is complete when:
- [ ] All 7 steps completed
- [ ] Test produces correct output for all test cases
- [ ] No build errors or warnings
- [ ] Full test suite still passes: `cd SWFRecomp/tests && bash all_tests.sh`
- [ ] Edge cases handled correctly
- [ ] Documentation created

Please work autonomously to complete this implementation. Test incrementally and document any issues or design decisions you encounter.
```

---

## Example: MODULO Opcode

```
Please read the implementation guide at SWFRecompDocs/parallel-opcode-implementation-guide.md.

Your task is to implement support for the AS2 opcode: **MODULO**

## Opcode Specification

**Opcode Name**: MODULO
**Hex Value**: 0x3F
**Category**: Arithmetic
**Estimated Complexity**: SIMPLE

**Description**: Computes the remainder of dividing two numbers (modulo operation).

**Operation**: Pop two numbers from stack, compute first % second, push result.

**Expected Behavior**:
- Pop value `a` from stack (divisor)
- Pop value `b` from stack (dividend)
- Compute `result = b % a`
- Push `result` onto stack
- Both operands are converted to numbers if needed
- Result is a floating-point number

## Your Task

Implement this opcode following the 7-step workflow:

1. **Define Enum** - Add to `SWFRecomp/include/action/action.hpp`
2. **Add Translation** - Add case to `SWFRecomp/src/action/action.cpp`
3. **Declare API** - Add to `SWFModernRuntime/include/actionmodern/action.h`
4. **Implement Runtime** - Implement in `SWFModernRuntime/src/actionmodern/action.c`
5. **Create Test SWF** - Create ActionScript test and compile to SWF
6. **Setup Test Directory** - Create `SWFRecomp/tests/modulo_swf_4/`
7. **Build and Verify** - Compile and verify output matches expected

## Test Cases

Test Case 1: Basic modulo
```actionscript
trace(10 % 3);
```
Expected output: 1

Test Case 2: Floating point modulo
```actionscript
trace(7.5 % 2.0);
```
Expected output: 1.5

Test Case 3: Zero divisor (edge case)
```actionscript
trace(5 % 0);
```
Expected output: NaN

## Implementation Hints

**Pattern**: This is a binary arithmetic operation, similar to ADD, SUBTRACT, MULTIPLY, DIVIDE.

Reference these similar opcodes:
- `actionDivide` in `SWFModernRuntime/src/actionmodern/action.c`
- `actionMultiply` in `SWFModernRuntime/src/actionmodern/action.c`

**Implementation outline**:
```c
void actionModulo(char* stack, u32* sp)
{
    // Convert and pop divisor
    convertFloat(stack, sp);
    ActionVar a;
    popVar(stack, sp, &a);

    // Convert and pop dividend
    convertFloat(stack, sp);
    ActionVar b;
    popVar(stack, sp, &b);

    // Compute modulo using fmod() from math.h
    float result = fmod(b.value.f32, a.value.f32);

    // Push result
    PUSH(ACTION_STACK_VALUE_F32, VAL(u32, &result));
}
```

**Note**: Use `fmod()` from `<math.h>` for floating-point modulo.

## Documentation

Create or update these files as you work:
- `SWFRecomp/tests/modulo_swf_4/README.md` - Test description and expected output
- Update this file with your progress notes and any issues encountered

## Success Criteria

Your implementation is complete when:
- [ ] All 7 steps completed
- [ ] Test produces correct output for all test cases
- [ ] No build errors or warnings
- [ ] Full test suite still passes: `cd SWFRecomp/tests && bash all_tests.sh`
- [ ] Edge cases handled correctly (division by zero)
- [ ] Documentation created

Please work autonomously to complete this implementation. Test incrementally and document any issues or design decisions you encounter.
```

---

## Template Variables Reference

### Required Variables

- `{OPCODE_NAME}` - Human-readable opcode name (e.g., "MODULO", "STRING_SUBSTRING")
- `{HEX_VALUE}` - Hex value without 0x prefix (e.g., "3F", "0A")
- `{CATEGORY}` - One of: Arithmetic, Comparison, Logic, String, Stack, Control, Variables, Special
- `{SIMPLE|MEDIUM|COMPLEX}` - Choose one based on complexity estimate
- `{BRIEF_DESCRIPTION}` - One sentence description
- `{STACK_OPERATION_DESCRIPTION}` - Description of stack operations (push/pop pattern)
- `{DETAILED_BEHAVIOR_FROM_SPEC}` - Detailed behavior from SWF specification
- `{test_name}` - Test directory name (e.g., "modulo", "string_substring")
- `{TEST_CASE_N}` - ActionScript code for test case
- `{EXPECTED_OUTPUT_N}` - Expected output for test case
- `{CATEGORY_SPECIFIC_HINTS}` - Implementation hints based on category
- `{SIMILAR_OPCODE_N}` - Names of similar already-implemented opcodes to reference

### Category-Specific Hints

#### Arithmetic
```
This is a binary arithmetic operation. Reference actionAdd, actionSubtract, actionMultiply, or actionDivide.
Pattern: convertFloat → pop → convertFloat → pop → compute → push
```

#### Comparison
```
This is a comparison operation. Reference actionEquals, actionLess.
Pattern: convert → pop → convert → pop → compare → push boolean (0.0 or 1.0)
```

#### Logic
```
This is a logical operation. Reference actionAnd, actionOr, actionNot.
Pattern: Convert to boolean/integer → operate → push result
```

#### String
```
This is a string operation. Reference actionStringLength, actionStringAdd, actionStringEquals.
Pattern: peek/pop string → process → push result
May need str_buffer parameter for result string.
```

#### Stack
```
This is a stack manipulation operation. Reference actionPop, actionPush.
Pattern: Careful stack pointer management, peek/copy as needed
```

#### Control
```
This is a control flow operation. Reference actionJump, actionIf.
May require special handling for instruction pointer or jump tables.
```

#### Variables
```
This is a variable operation. Reference actionGetVariable, actionSetVariable.
May require variable storage lookup/update.
```

---

## Unimplemented Opcodes (Candidates for Assignment)

### Simple Arithmetic/Logic
- 0x3F - MODULO
- 0x47 - INCREMENT
- 0x48 - DECREMENT
- 0x60 - BIT_AND
- 0x61 - BIT_OR
- 0x62 - BIT_XOR
- 0x63 - BIT_LSHIFT
- 0x64 - BIT_RSHIFT
- 0x65 - BIT_URSHIFT

### Simple Comparison
- 0x48 - GREATER (SWF 5+)
- 0x66 - STRICT_EQUALS

### String Operations
- 0x31 - CHAR_TO_ASCII
- 0x32 - ASCII_TO_CHAR
- 0x33 - MB_CHAR_TO_ASCII
- 0x34 - MB_ASCII_TO_CHAR
- 0x35 - MB_STRING_LENGTH

### Stack Operations
- 0x4B - STACK_SWAP
- 0x4C - RANDOM_NUMBER
- 0x3D - DUPLICATE

### Type Operations
- 0x18 - TO_INTEGER
- 0x4A - TO_NUMBER
- 0x4B - TO_STRING
- 0x3C - TYPEOF

### More Complex (Medium)
- 0x3E - RETURN
- 0x9E - CALL_FUNCTION
- 0x9F - CALL_METHOD
- 0x52 - NEW_OBJECT
- 0x53 - NEW_METHOD
- 0x42 - INIT_ARRAY
- 0x43 - INIT_OBJECT
- 0x4E - GET_MEMBER
- 0x4F - SET_MEMBER
- 0x55 - ENUMERATE
- 0x5A - DELETE
- 0x5B - DELETE2

---

## Notes for Prompt Generation

1. **Check specification** for accurate hex values and behavior
2. **Verify no conflicts** with already-implemented opcodes
3. **Choose appropriate test cases** that cover basic and edge cases
4. **Reference similar opcodes** to guide implementation
5. **Set realistic complexity** estimate (Simple: 1-2h, Medium: 2-4h, Complex: 4-8h)
6. **Include edge cases** in test scenarios (divide by zero, null, empty string, etc.)

## Generating Prompts

To generate a prompt for a specific opcode:

1. Look up opcode in `SWFRecompDocs/specs/swf-spec-19.txt`
2. Fill in template variables
3. Choose 2-3 similar already-implemented opcodes as references
4. Create 3+ test cases (basic, typical, edge case)
5. Add category-specific hints
6. Save as `opcode-{name}-task.md` for assignment
