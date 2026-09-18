# Code Style

This file defines the style for this repository. All code, comments,
commit messages, and documentation follow these rules.

## Writing Standard (STE)

Use Simplified Technical English (ASD-STE100):

- Use approved words with a single meaning (one word, one meaning).
- Keep sentences short: at most 20 words for procedural text, 25 for
  descriptive text.
- Use the active voice. Use the passive voice only where STE permits.
- Do not use contractions (write "do not", not "don't").
- Do not use -ing forms as nouns. Use the base form.
- Do not use long noun clusters (at most 3 nouns in a row).
- Write instructions in the imperative mood.
- Use the articles ("a", "an", "the") correctly.
- Use the approved tenses only: simple present, simple past, present
  perfect.

## Required Skills

Apply these skills when their triggers match:

- **equational-reasoning** — for a simplification, refactor, optimization,
  fusion or derivation, in any language (Common Lisp, C, TypeScript,
  Swift, Haskell, Nix). Examples: merge loops, fuse map/filter/reduce
  chains, convert recursion, clean try-catch and promise chains, separate
  pure logic from effects, verify that a refactor preserves behavior,
  derive an efficient implementation from a naive one.
- **hoare-logic** — to verify, derive or reason about imperative programs.
  Examples: prove correctness, find loop invariants, verify
  pre/postconditions, calculate weakest preconditions.

## Style Rules

### Nix

- Prefer lib functions over builtins (for example `lib.hasSuffix`,
  `lib.mapAttrs`, `lib.concatStringsSep`). lib can evolve; builtins
  cannot.
- Use data-driven configuration. Generate config from tables and attrsets
  (for example the `tmux.nix` bindKeys and the `kde.nix` kdePatches).
- Keep one source of truth for each value (the shared palette in lib,
  version constants, derived names).
- Remove dead code: no dead parameters, no tautological conditions, no
  empty indirection layers.
- Prefer declarative wrappers (`wrapProgram`, `makeWrapper`) over
  hand-written shell scripts.
- Use `lib.mkDefault` in reusable modules. Assign values directly in host
  configs.
- Keep modules flat. Import them from the host menu.
- Keep `stateVersion` values as independent facts. Never change them after
  the initial install.

### All Languages

- Use consistent indentation (2 spaces).
- Keep lines short.
- Type your code explicitly. Do not erase type information.
- Write comments in STE English (ASCII only). The `english-comments` check
  enforces this.
- Match the style of the surrounding code.
- Do not copy-paste. Extract shared helpers into lib.

## Commit Messages

Use the GNU commit message format (the Emacs CONTRIBUTE file and the GNU
Coding Standards define it).

- Start with a single unindented summary line, under 50 characters when
  possible, in the imperative mood and the present tense.
- Do not end the summary line with a period.
- Add an empty line after the summary.
- Add ChangeLog-style entries after the empty line, each starting with
  `* <file> (<function>): <description>` and ending with a period.
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
