# Equational Reasoning — C

Load this when the source or target language is C (much applies to C++ and
unsafe Rust as well).

C has no closures and no list combinators, so _every_ scheme appears as a loop.
The recognition catalogue in SKILL.md applies directly; the calculation happens
entirely in scratch notation, and the translation back is always to loops. The
equational names map onto classic compiler optimizations — using both
vocabularies helps:

| Equational law                                     | Compiler-optimization name           |
| -------------------------------------------------- | ------------------------------------ |
| map/fold fusion                                    | loop fusion / deforestation          |
| hylomorphism fusion                                | loop fusion eliminating a temp array |
| banana split (pair accumulator)                    | loop fusion of two reductions        |
| hoisting a pure subexpression out of the fold body | loop-invariant code motion           |
| `map (k*) = (k*) . id` style regrouping            | strength reduction / distributivity  |
| `filter p . map f = map f . filter (p . f)`        | predicate hoisting                   |

You are doing by hand, with proof, what `-O2` does heuristically — which is
exactly why the side conditions matter: the compiler refuses reassociation of
floats and signed overflow for the same reasons you must.

## Idiom Recognition

| C idiom                                                   | Scheme                                   |
| --------------------------------------------------------- | ---------------------------------------- |
| `acc = z; for (i=0;i<n;i++) acc = f(acc, a[i]);`          | `foldl f z a`                            |
| `for (...) out[j++] = f(a[i]);`                           | `map f`                                  |
| `for (...) if (p(a[i])) out[j++] = a[i];`                 | `filter p` (j tracks output length)      |
| `for (...) { if (!p(a[i])) break; ... }`                  | fold over `takeWhile p`                  |
| `for (...) if (p(a[i])) return i;` `return -1;`           | `find` — short-circuiting                |
| `while (s != end) { emit(*s); s = s->next; }`             | `unfoldr` over the seed `s`              |
| pointer-walking loop building array consumed by next loop | hylomorphism — fuse, drop the temp array |
| two accumulators in one loop body                         | banana split, already fused              |
| `int rc; if ((rc = f()) != 0) return rc;` chains          | `Result`/Either bind chain               |
| `goto cleanup;` with cleanup label at function end        | `finally` block                          |
| output parameter + return code                            | `Either err val` in two channels         |

## Language-Specific Side Conditions

These bite hard in C; check each before fusing or reassociating.

- **Signed integer overflow is UB.** `(a + b) + c` and `a + (b + c)` are only
  interchangeable if _neither grouping_ overflows. A reassociation that is fine
  over ℤ can introduce UB (intermediate overflow) the original didn't have. For
  derivations over `int` accumulators, either (a) prove a range bound that
  covers both groupings, or (b) state the derivation is over ℤ and add a width
  check, or (c) use `unsigned`/explicit wraparound where `+` is genuinely
  associative (mod 2ⁿ is a ring — reassociation is safe, but the _meaning_ is
  modular).
- **Floating point is non-associative.** Reordering an FP accumulation changes
  the answer bitwise (and sometimes materially — cancellation). Banana-split
  fusion (same order, different bookkeeping) is safe; reassociation and
  parallel-tree reduction are not, without an accuracy argument.
- **Aliasing.** `map`-style loops writing `out[i]` while reading `in[i]` are
  only the pure `map` if `out` and `in` don't overlap. Fusion that turns two
  arrays into one in-place pass must check `restrict`-style non-aliasing; an
  in-place update where `f` reads neighbors (stencils) is _not_ a map at all —
  it's a scan or a fold with history, and naive fusion is wrong.
- **Sequence points / evaluation order.** Unsequenced side effects in an
  expression (`a[i++] = f(i)`) are outside the algebra entirely; rewrite to
  sequenced statements before reasoning.
- **`errno` and global state.** Any libc call that can set `errno` (math
  functions included) is effectful for commutation purposes. `strtol`, `malloc`,
  even `printf` order with respect to error checks is fixed.
- **Short-circuit `&&` order** in fused predicates: `q(x) && p(x)` keeps q's
  guard duty (e.g., `i < n && a[i] > 0` must not flip).
- **No closures.** A derived `foldr f z` with non-trivial `f` translates to an
  inlined loop body; "let s = ..." in the fold becomes a local variable in the
  loop. This is purely mechanical.

## Worked Example: Fusing Two Passes

```c
/* Original — temp array, two passes: */
double *sq = malloc(n * sizeof *sq);
for (size_t i = 0; i < n; i++)
    sq[i] = a[i] * a[i];               /* map (^2) */
double sum = 0.0;
for (size_t i = 0; i < n; i++)
    sum += sq[i];                       /* foldl (+) 0 */
free(sq);
```

```
  foldl (+) 0 (map sq a)
= { fold-map fusion: foldl f z . map g = foldl (\acc x -> f acc (g x)) z }
  foldl (\acc x -> acc + x*x) 0 a
```

Side conditions: same accumulation _order_ (i ascending) on both sides, so no FP
reassociation occurred — fusion here only eliminates the intermediate array.
`a[i]*a[i]` is pure given no aliasing with `sum` (none — `sum` is a local).
Safe.

```c
double sum = 0.0;
for (size_t i = 0; i < n; i++)
    sum += a[i] * a[i];
```

One pass, no allocation, bitwise-identical FP result (same order of adds).

## Worked Example: Early Exit (find as short-circuit fold)

```c
/* Original — flag variable, full traversal: */
int found = 0; size_t idx = 0;
for (size_t i = 0; i < n; i++) {
    if (!found && match(a[i], key)) { found = 1; idx = i; }
}
```

Recognize: this is `find`, encoded with a flag that freezes the accumulator
after first match. The flag-fold and the breaking loop satisfy the same
equations (universal property over the list, accumulator = `Maybe idx`; once
`Just`, every subsequent step is identity). Hence:

```c
size_t idx = n;                /* n = not found sentinel */
for (size_t i = 0; i < n; i++)
    if (match(a[i], key)) { idx = i; break; }
```

Semantic change to declare: the derived version calls `match` _fewer times_
(stops at first hit). If `match` is pure, the results are equal and the early
exit is a free optimization. If `match` logs or mutates, the two versions
perform different effects — then the transformation needs the user's sign-off,
not just algebra.

## Worked Example: goto-cleanup as finally

```c
int load(const char *path, blob_t *out) {
    int rc = 0;
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    if ((rc = read_header(f, out)) != 0) goto cleanup;
    if ((rc = read_body(f, out))   != 0) goto cleanup;
cleanup:
    fclose(f);
    return rc;
}
```

This is `try { header >>= body } finally { fclose }` with `Either int ()` in the
`rc` channel. The two `if/goto` checks are monadic bind; Kleisli associativity
says you may regroup the chain (e.g., factor `read_header >=>
read_body` into a
helper taking `f`) without changing behavior — but the `finally` law forbids
moving `fclose` relative to the reads, and bind ordering forbids reordering
header before body. Safe refactor target:

```c
static int read_all(FILE *f, blob_t *out) {      /* header >=> body */
    int rc = read_header(f, out);
    return rc != 0 ? rc : read_body(f, out);
}
int load(const char *path, blob_t *out) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    int rc = read_all(f, out);
    fclose(f);
    return rc;
}
```
