---
name: equational-reasoning
description: Use equational reasoning to simplify, refactor, optimize, fuse, or derive code in ANY language — Common Lisp, C, TypeScript, Swift, Haskell, or others. Use this skill whenever the user asks to simplify a loop or a chain of maps/filters/reduces, merge multiple passes into a single pass, refactor recursion, clean up try-catch / do-catch / handler-case / Promise chains, separate pure logic from effectful code (async, state, I/O), verify that a refactor preserves behavior, or derive an efficient implementation from a clear but naive one. Trigger even when the user just says "can this be one loop?", "is this refactor safe?", or "simplify this reduce".
---

# Equational Reasoning for Program Simplification

Equational reasoning treats programs as mathematical expressions and transforms
them by substituting equals for equals, each step justified by a named law.
Instead of rewriting code by intuition, you _derive_ the simplified form — so
the result is correct by construction and the reasoning is auditable.

The method is paradigm-agnostic. The functional notation below (`map`, `foldr`,
`.`) is **scratch-paper notation**, not a target language. The deliverable is
always idiomatic code in the user's language; the round trip is:

```
source code  →  recognize the scheme  →  calculate in equational notation
             →  translate back to idiomatic source-language code
```

Re-introducing mutation, loops, or early returns on the way back is fine and
often desirable — the derivation justifies the result even if the final code is
imperative.

## Per-Language References

After reading this file, load the reference for the target language — it has the
idiom recognition table, law side conditions, and worked examples specific to
that language:

- `references/common-lisp.md` — LOOP/DO forms, reduce, conditions & restarts,
  destructive ops
- `references/c.md` — loop fusion, overflow/UB, aliasing, errno, goto-cleanup
- `references/typescript.md` — array chains, Promise laws, async, generators,
  `?.`/`??`
- `references/swift.md` — lazy sequences, optionals, throws/Result,
  reduce(into:), CoW

For other languages, generalize from this file plus the closest reference (e.g.,
Rust ≈ Swift + C; Python ≈ TypeScript; Scheme/Clojure ≈ Common Lisp).

## Core Method: Calculate, Don't Guess

Never jump to the answer. Show each step and name the law that justifies it. If
a step feels like a big jump, break it down — the discipline is the point.

The single most powerful tool is the **universal property of fold**:

> `h` satisfies `h [] = z` and `h (x:xs) = f x (h xs)` **iff** `h = foldr f z`.

It works in two directions: (1) to _recognize_ that a recursive function or loop
is a fold, and (2) to _prove two expressions equal_ by showing both satisfy the
same fold equations. Example of direction 2:

```
-- Claim: sum (map (+1) xs) = sum xs + length xs
-- Let L xs = sum (map (+1) xs) and R xs = sum xs + length xs.
-- Show both satisfy the equations of foldr (\x a -> (x+1) + a) 0:

L []     = sum [] = 0
L (x:xs) = (x+1) + L xs                      { defn of map, sum }

R []     = 0 + 0 = 0
R (x:xs) = (x + sum xs) + (1 + length xs)    { defn of sum, length }
         = (x+1) + (sum xs + length xs)      { associativity/commutativity of + }
         = (x+1) + R xs

-- Both equal foldr (\x a -> (x+1)+a) 0, hence L = R.  ∎
```

Note the `+` reassociation step is _named and justified_ — in a language where
`+` is not associative (overflow, floats), this proof does not go through
unchanged. See "Side Conditions in Strict Languages" below.

## Step 0: Recognition — Imperative Idiom → Scheme

Before any law applies, you must recognize which scheme the source code
implements. This is usually the hard part. Catalogue:

| Imperative idiom                                        | Scheme                                                          |
| ------------------------------------------------------- | --------------------------------------------------------------- |
| `acc = z; for x in xs: acc = f(acc, x)`                 | `foldl f z xs`                                                  |
| `for x in xs: out.push(f(x))`                           | `map f xs`                                                      |
| `for x in xs: if p(x): out.push(x)`                     | `filter p xs`                                                   |
| `for x in xs: if p(x): out.push(f(x))`                  | `map f . filter p` (already fused)                              |
| `for x in xs: out.push_all(f(x))`                       | `concatMap f xs`                                                |
| loop with `break` on condition, returning a found item  | `find p xs`                                                     |
| loop with `break`, returning bool                       | `any p xs` / `all p xs`                                         |
| loop with `break`, accumulating until condition         | fold over `takeWhile p xs`                                      |
| `while (cond on seed): emit(a); seed = next(seed)`      | `unfoldr g seed`                                                |
| produce list with unfold, immediately consume with fold | hylomorphism — fuse, no list at all                             |
| loop carrying an index alongside elements               | fold over `zip [0..] xs`                                        |
| two accumulators updated in lockstep                    | fold with a pair accumulator (banana split — one pass, not two) |
| loop emitting running totals                            | `scanl f z xs`                                                  |
| nested loops over `xs`, `ys` building pairs/products    | fold over the cartesian/zip structure — name which              |
| recursion that pattern-matches a data structure         | fold (catamorphism) over that structure                         |
| `try { … } catch` / return-code checks chained          | `Either` / `Result` bind chain                                  |
| null/optional checks chained                            | `Maybe` bind chain                                              |

**Early exit deserves special care.** `find`, `any`, `takeWhile` and friends are
_short-circuiting_ folds. Fusing a short-circuiting consumer with a producer is
valid and great (it means the producer also stops early), but fusing it with an
_effectful_ producer changes how many effects run. Always note when a
transformation changes the number of iterations executed.

## Fundamental Laws

### Function Composition

```
(f . g) x   =  f (g x)
f . id      =  f  =  id . f
(f . g) . h =  f . (g . h)
```

### Map

```
map id          =  id
map f . map g   =  map (f . g)              -- fusion: eliminates intermediate list
map f (xs ++ ys) = map f xs ++ map f ys
map f . concat  =  concat . map (map f)
```

### Filter

```
filter p . filter q  =  filter (\x -> q x && p x)
  -- NB: q is tested first on both sides; do not flip to (p x && q x)
  -- if p assumes q already held, or if p/q have effects or can fail.
filter p . map f     =  map f . filter (p . f)
  -- side condition: f total (no exceptions/⊥). In strict languages the RHS
  -- applies f to fewer elements — fewer effects, fewer chances to trap.
```

### Fold

```
foldr f z []      =  z
foldr f z (x:xs)  =  f x (foldr f z xs)
foldr f z . map g =  foldr (f . g) z         -- fold-map fusion
foldr (:) []      =  id

foldl f z []      =  z
foldl f z (x:xs)  =  foldl f (f z x) xs
foldl f z xs      =  foldr (flip f) z (reverse xs)   -- unconditionally, finite xs
foldl f z xs      =  foldr f z xs
  -- ONLY when f is associative and z is its identity (e.g. +/0, */1, ++/[]),
  -- and f obeys that algebra in the actual machine semantics (see overflow).
```

### Unfold

```
unfoldr g seed = case g seed of
  Nothing      -> []
  Just (a, s') -> a : unfoldr g s'
```

Dual to fold. An unfold feeding a fold (hylomorphism) fuses into a single loop
with no intermediate structure — this is the equational name for "rewrite the
two loops as one `while`".

### Monad Laws (bind chains, do-notation, optional chains)

```
return a >>= f   =  f a
m >>= return     =  m
(m >>= f) >>= g  =  m >>= (\x -> f x >>= g)
```

Kleisli form, for pipelines of effectful functions:

```
(f >=> g) x          =  f x >>= g
(f >=> g) >=> h      =  f >=> (g >=> h)
return >=> f  =  f   =  f >=> return
```

Use Kleisli associativity to reassociate chains so that _pure_ stages cluster
(then fuse them with ordinary composition) while effectful stages stay in order.

### Exceptions (try-catch, do-catch, handler-case, Result)

Structured exception handling is the operational encoding of `Either E A`:
`try { e } catch (x) { h(x) }  ≅  either h id (toEither e)`. Lift, reason in
Either, lower back.

```
try { throw v } catch (x) { h(x) }   =  h(v)        -- throw-catch elimination
try { e } catch { h }                =  e            -- when e cannot throw
try { f() } catch (x) { throw x }    =  f()          -- catch-rethrow elimination
try { e } catch (_) { e }            =  e            -- ONLY when e is pure:
  -- if e performs effects before throwing, the LHS runs them twice.
```

Nested handler flattening (Either associativity):

```
try { try { a } catch (x) { b(x) } } catch (x) { c(x) }
  =  try { a } catch (x) { try { b(x) } catch (y) { c(y) } }
  =  try { a } catch (x) { b(x) }        -- additionally, when b cannot throw
```

`finally` is not a catch — it threads through both branches of the Either:

```
try { a } finally { b }   =   let r = toEither(a) in (b; fromEither(r))
```

Cleanup ordering is an effect; never commute `finally` blocks with each other or
with the handlers around them.

**Resumable conditions are not Either.** If the language allows handlers to
resume execution at the raise point (Common Lisp restarts, some signal systems),
the laws above apply only to the non-resuming subset (`handler-case`-style). See
the Common Lisp reference.

## Side Conditions in Strict Languages

Every target language here (CL, C, TS, Swift) is strict and eager. The laws
above are stated for a pure setting; check this table before applying one:

| Hazard                             | What breaks                                                                                                                    | Affected laws                       |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| Exceptions / traps / ⊥             | Fusion changes _which_ element is being processed when the failure occurs, and how many effects ran before it                  | all fusion laws                     |
| Machine integer overflow           | `+`, `*` not associative under trapping (Swift, C UB) or wraparound reasoning; reassociation can introduce or remove a trap/UB | foldl↔foldr, accumulator regrouping |
| Floating point                     | `+`, `*` not associative; reassociation changes the result bitwise                                                             | same                                |
| Short-circuit `&&`/`               |                                                                                                                                | ` ordering                          |
| Single-shot iterators / generators | "the list" can only be traversed once; banana-split (one pass, two accumulators) is _mandatory_, not optional                  | any law that traverses twice        |
| Aliasing / shared mutation         | writing the output can clobber the input mid-traversal                                                                         | map/fold over arrays in place       |
| Effect ordering is observable      | logging, I/O, audit order is part of the spec                                                                                  | any reordering                      |

Exceptions: Common Lisp integers are arbitrary precision, so integer `+` _is_
associative there — but floats are not, anywhere.

## Reasoning About Effectful Code

### Pure Core, Effectful Shell

Separate the code into a pure computation (where substitution is valid) and an
effectful boundary (left in order unless commutation is proven). Simplify the
core; reassemble.

```typescript
// Before:
async function process(ids: string[]) {
  const items = [];
  for (const id of ids) {
    const data = await (await fetch(`/api/${id}`)).json(); // effect
    const name = data.name.toUpperCase(); // pure
    if (name.length > 3) items.push(name); // pure
  }
  return items;
}
```

Pure core: `filter (len>3) . map (toUpper . name)` — one map-fusion step, then
filter-map fold into `flatMap`. The effectful part is `map fetchJson ids`,
_sequenced_. Two valid outcomes:

```typescript
// (a) Effects untouched — sequential, strictly equivalent:
async function process(ids: string[]) {
  const items: string[] = [];
  for (const id of ids) {
    const data = await (await fetch(`/api/${id}`)).json();
    const s = data.name.toUpperCase();
    if (s.length > 3) items.push(s);
  }
  return items;
}
// (the simplification here is conceptual: the pure logic is now one fused step)

// (b) Effects reordered — ONLY with an explicit commutation argument:
// "GETs to independent endpoints are read-only and commute; we accept
//  concurrent in-flight requests and fail-fast semantics of Promise.all."
async function process(ids: string[]) {
  const datas = await Promise.all(
    ids.map((id) => fetch(`/api/${id}`).then((r) => r.json())),
  );
  return datas.flatMap((d) => {
    const s = d.name.toUpperCase();
    return s.length > 3 ? [s] : [];
  });
}
```

Sequential→concurrent is a _semantic change_ (ordering, server load, behavior on
partial failure). It is often the right change — but it must be stated and
justified by commutation, never smuggled in as "simplification".

### State-Passing Transformation

Mutable state breaks substitution; recover it by making state explicit.
`s.f(); s.g()` becomes `let s1 = f(s0); let s2 = g(s1)` — now `f`, `g` are pure
functions of state and the laws apply. Translate back to mutation at the end if
that's idiomatic.

```
// count = 0; sum = 0; for x: count += 1; sum += x; return sum / count
=  let (c, s) = foldl (\(c,s) x -> (c+1, s+x)) (0,0) xs in s / c
=  { banana split, recognizing components }  sum xs / length xs   -- the mean
```

### Effect Commutation

Two effects commute when swapping them preserves all observable behavior.

| Effect pair                           | Commutes?                                 | Why                        |
| ------------------------------------- | ----------------------------------------- | -------------------------- |
| read x; read y                        | yes                                       | no state change            |
| write x; write y (x ≠ y, no aliasing) | yes                                       | independent targets        |
| write x; read x                       | no                                        | read observes write        |
| log a; log b                          | only if log order is not part of the spec |                            |
| throw/trap; anything after            | no                                        | abort — nothing after runs |
| await independent reads               | yes, if you accept concurrency semantics  | state argument above       |
| pure; anything                        | yes                                       | pure has no effects        |

Use commutation to cluster pure fragments together, then apply laws inside the
clusters only.

### When NOT to Reason Equationally

- **The effect is the point**: logging order, audit trails, UI sequencing.
- **Effects interact**: write-then-read, lock order, cleanup order.
- **Shared-state concurrency**: intermediate states are observable; almost
  nothing commutes. Confine reasoning to data owned by one thread/actor/task.

In these cases, leave the effectful skeleton fixed and simplify only the pure
subexpressions within each step.

## Procedure

1. **State the equation.** Name the input and output. Transcribe the relevant
   fragment into equational notation using the recognition catalogue — this is
   working notation, not the target language.
2. **Unfold definitions** to expose structure that matches known laws.
3. **Apply laws**, simplest applicable first, _naming each one_ and checking its
   side conditions against the table above. Prefer fusion laws.
4. **Fold back**: recognize the result as a known function or simpler scheme
   (universal property of fold is the main tool).
5. **Translate back** to idiomatic code in the source language, using the
   per-language reference. Re-introduce mutation/loops where idiomatic. Confirm
   the performance claim (e.g., "single pass, O(1) extra space") holds in the
   _target_ language — watch for accidental O(n²) accumulator copies.

## Worked Example: Full Round Trip (TypeScript)

```typescript
// Original — three passes, two intermediate arrays:
const names = users.map((u) => u.name);
const upper = names.map((s) => s.toUpperCase());
const long = upper.filter((s) => s.length > 3);
```

```
  filter (\s -> length s > 3) . map toUpper . map name
= { map fusion }
  filter (\s -> length s > 3) . map (toUpper . name)
= { universal property: filter p . map f = foldr (\u acc ->
    let s = f u in if p s then s : acc else acc) [] }
  foldr (\u acc -> let s = toUpper (name u)
                   in if length s > 3 then s : acc else acc) []
```

Translate back — single pass:

```typescript
const long = users.flatMap((u) => {
  const s = u.name.toUpperCase();
  return s.length > 3 ? [s] : [];
});
```

(A `reduce` with `[...acc, s]` would also be "single pass" equationally but
O(n²) operationally — the spread copies the accumulator each step. If using
`reduce`, mutate the accumulator: `acc.push(s); return acc`. The per-language
references flag these target-language costs.)

## Common Pitfalls

- **Skipping steps.** If a step is a big jump, split it. Unjustified steps are
  where wrong "simplifications" come from.
- **Applying laws across effect boundaries.** Identify the pure core, check
  commutation, and state any semantic change (sequential→concurrent, fewer/more
  effect executions) explicitly.
- **Ignoring strictness.** Check the side-conditions table for every fusion step
  in a strict language: exception ordering, overflow, floats.
- **Faithful math, unfaithful machine.** A derivation can be correct over ideal
  integers and wrong over `Int32`/`Double`. Say which algebra you're using.
- **Forgetting the round trip.** The answer is idiomatic source-language code,
  not the Haskell-ish intermediate.

## Presentation

When presenting a simplification:

1. The original code.
2. The recognized scheme ("this loop is a foldl with a pair accumulator").
3. The chain of equational steps, each labeled with its law and any side
   condition discharged.
4. The final code in the source language.
5. Any semantic changes made deliberately (effect reordering, early-exit count,
   numeric reassociation) — called out, with the justification.
