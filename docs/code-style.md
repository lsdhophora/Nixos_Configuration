# Code Style

This file defines the code style for this repository. All code, comments, commit messages, and documentation must follow these rules.

## Writing Standard (STE)

Use Simplified Technical English (STE) per the ASD-STE100 specification:

- Use only approved words with a single meaning (one word, one meaning).
- Keep sentences short: max 20 words for procedural text, max 25 words for descriptive text.
- Use the active voice by default. Use passive voice only when permitted by the STE rules.
- Do not use contractions (for example "don't" → "do not").
- Do not use -ing forms as nouns (gerunds). Use the base form instead.
- Do not use long noun clusters (max 3 nouns in a row).
- Write instructions in the imperative mood.
- Use articles ("a", "an", "the") correctly.
- Use only the approved verb tenses: simple present, simple past, present perfect.

## Required Skills

Apply these skills when their trigger conditions match:

- **equational-reasoning** — Use this skill when you simplify, refactor, optimize, fuse, or derive code. It applies to any language: Common Lisp, C, TypeScript, Swift, Haskell, Nix. Examples: merge loops, fuse map/filter/reduce chains, convert recursion, clean try-catch / promise chains, separate pure logic from effects, verify that a refactor preserves behavior, derive an efficient implementation from a naive one.
- **hoare-logic** — Use this skill when you must verify, derive, or reason about imperative programs. Examples: prove correctness, find loop invariants, verify pre/postconditions, calculate weakest preconditions.

## Style Rules

### Nix

- Prefer lib functions over builtins (for example `lib.hasSuffix`, `lib.mapAttrs`, `lib.concatStringsSep`). lib can evolve; builtins cannot.
- Use data-driven configuration. Generate config from tables and attrsets (for example `tmux.nix` bindKeys, `kde.nix` kdePatches).
- Keep one source of truth for each value (shared palette in lib, version constants, derived names).
- Remove dead code: no dead parameters, no tautological conditions, no empty indirection layers.
- Prefer declarative wrappers (`wrapProgram`, `makeWrapper`) over hand-written shell scripts.
- Use `lib.mkDefault` in reusable modules. Assign values directly in host configs.
- Keep modules flat. Import them from the host menu.
- Keep `stateVersion` values as independent facts. Never change them after the initial install.

### All Languages

- Use consistent indentation (2 spaces).
- Keep lines short.
- Type your code explicitly. Do not erase type information.
- Write comments in STE English (ASCII characters only). The
  `english-comments` check enforces this.
- Match the style of the surrounding code.
- Do not copy-paste. Extract shared helpers into lib.

## Commit Messages

Use the GNU commit message format. The Emacs CONTRIBUTE file and the
GNU Coding Standards define this format.

- Start with a single unindented summary line.
- Keep the summary under 50 characters when possible.
- Do not end the summary line with a period.
- Use the imperative mood and the present tense.
- Add an empty line after the summary.
- Add ChangeLog-style entries after the empty line.
- Start each entry with `* <file> (<function>): <description>`.
- End each entry with a period.
- Keep lines under 78 characters.
- Describe what the change does, not what the change did.
- Do not add `Signed-off-by` lines.
- Write the entries in STE English.

Example:

```
Use GNU commit message format

Switch the repository to the GNU commit message format.
* AGENTS.md (Commands): Document the new commit command.
* docs/code-style.md (Commit Messages): Replace the old format.
```

## Review Checklist

Before you commit, check:

1. No dead code or dead parameters.
2. No duplicated literals (use lib constants).
3. Data-driven generation where tables exist.
4. `dry-build` passes.
5. The two required skills were applied when their triggers matched.
