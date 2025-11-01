# Deprecated Documentation

This directory contains older documentation that has been superseded by current approaches but may still be useful for historical reference or understanding the evolution of the project.

## Why These Are Deprecated

The SWFRecomp project has evolved significantly, and the implementation approach has changed over time. The documents in this directory represent earlier planning and analysis that informed the current direction but are no longer the active implementation plans.

## Files

### String Variable Implementation (2025-11-01)

- **[2025-11-01/](2025-11-01/)** - Documentation from string variable storage and optimization implementation (deprecated in favor of consolidated status document)

### ActionScript 3 Implementation Plans

- **[as3-c-implementation-plan.md](as3-c-implementation-plan.md)** - Original AS3 implementation plan with time estimates (Pure C approach)
- **[as3-implementation-plan.md](as3-implementation-plan.md)** - Full AS3 implementation plan using C++

### ABC Parser

- **[abc-parser-implementation.md](abc-parser-implementation.md)** - Phase 1: ABC Parser implementation
- **[abc-implementation-info.md](abc-implementation-info.md)** - Comprehensive reference for ABC format support
- **[abc-parser-research.md](abc-parser-research.md)** - Research notes on ABC parser implementation

### Seedling Implementation Plans

The Seedling game was used as a reference implementation for ActionScript support:

- **[seedling-c-implementation-plan.md](seedling-c-implementation-plan.md)** - Original Seedling implementation plan with time estimates (C approach)
- **[seedling-implementation-plan.md](seedling-implementation-plan.md)** - Seedling implementation plan using C++
- **[seedling-manual-c-conversion.md](seedling-manual-c-conversion.md)** - Manual AS3→C conversion approach for Seedling
- **[seedling-manual-cpp-conversion.md](seedling-manual-cpp-conversion.md)** - Manual AS3→C++ conversion approach for Seedling

### Architecture Analysis

- **[c-vs-cpp-architecture.md](c-vs-cpp-architecture.md)** - Analysis of why SWFRecomp uses C++ for build tools and C for runtime code

### Synergy Analysis

- **[synergy-analysis.md](synergy-analysis.md)** - Analysis of how manual conversion and SWFRecomp can work together (C++ approach)
- **[synergy-analysis-c.md](synergy-analysis-c.md)** - Analysis of how manual C conversion and SWFRecomp can work together

## Current Documentation

For current implementation guides and plans, see:

- **Implementation Guides:** [../guides/](../guides/) - Current step-by-step implementation guides
- **Reference:** [../reference/](../reference/) - Technical reference material
- **Plans:** [../plans/](../plans/) - Current high-level project planning
- **Status:** [../status/](../status/) - Current project status

## Historical Context

These documents represent important decision points in the project's development:

1. **C vs C++** - Early debates about language choice for different components
2. **Manual vs Automatic** - Exploration of manual conversion approaches vs automated recompilation
3. **Phased Implementation** - Time estimates and milestone planning that helped scope the project
4. **Synergy Approaches** - How different implementation strategies could complement each other

While superseded, these documents provide valuable context for understanding why certain architectural decisions were made and what alternatives were considered.
