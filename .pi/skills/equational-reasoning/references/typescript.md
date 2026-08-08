# Equational Reasoning — TypeScript / JavaScript

Load this when the source or target language is TypeScript or JavaScript.

## Idiom Recognition

| TS idiom                                                | Scheme                                    |
| ------------------------------------------------------- | ----------------------------------------- |
| `xs.map(f)` / `xs.filter(p)` / `xs.flatMap(f)`          | `map` / `filter` / `concatMap`            |
| `xs.reduce(f, z)`                                       | `foldl f z xs`                            |
| `xs.reduceRight(f, z)`                                  | `foldr` (note arg order: `(acc, x)`)      |
| `for (const x of xs) out.push(f(x))`                    | `map f`                                   |
| `xs.find(p)` / `xs.some(p)` / `xs.every(p)`             | `find` / `any` / `all` — short-circuiting |
| `for (...) { if (p(x)) break; ... }`                    | fold over `takeWhile`                     |
| `while (s) { yield emit(s); s = next(s); }` (generator) | `unfoldr`                                 |
| `xs.flatMap(x => p(x) ? [f(x)] : [])`                   | `map f . filter p`, fused                 |
| `a?.b?.c`                                               | Maybe bind chain                          |
| `x ?? y`                                                | Maybe alternative (`<                     |
| `p.then(f).catch(g)`                                    | Either bind + handler over async          |
| `try {} catch {} finally {}`                            | Either + finally law (SKILL.md)           |
| `async function` with sequential `await`s in a loop     | Kleisli chain, _sequenced_ effects        |

## Law Translations and Corrections

Array fusion:

```ts
xs.map(f).map(g)        ===  xs.map(x => g(f(x)))
xs.filter(p).filter(q)  ===  xs.filter(x => p(x) && q(x))   // p first!
xs.map(f).filter(p)     ===  xs.flatMap(x => { const y = f(x); return p(y) ? [y] : []; })
xs.reduce(f, z) after xs.map(g)
                        ===  xs.reduce((acc, x) => f(acc, g(x)), z)
```

Optional chaining obeys Maybe laws:

```ts
(a?.b)?.c === a?.b?.c // bind associativity
    (x ?? y) ?? z === x ?? (y ?? z); // alternative associativity
x ?? x === x; // ONLY if x is a pure expression —
// f() ?? f() calls f twice
```

### Promise laws (with the honest side conditions)

```ts
Promise.reject(e).catch(f)   ≈  Promise.resolve().then(() => f(e))
  // f's result is lifted; if f THROWS, both sides reject with f's error —
  // but the naive statement "= Promise.resolve(f(e))" is wrong when f throws
  // (that form would throw synchronously). State it via .then-lifting.

p.catch(e => { throw e; })   ===  p            // catch-rethrow elimination
p.catch(f).catch(g)          ===  p.catch(f)   // ONLY when f never throws/rejects
p.catch(f).catch(g)          ===  p.catch(e => Promise.resolve().then(() => f(e)).catch(g))
                                                // general associativity
```

**`.then`/`.catch` do not commute.** `p.then(f).catch(g)` guards both `p` and
`f`; `p.catch(g).then(f)` recovers `p` first and then runs `f` on the recovery,
unguarded. Reordering a chain across a `.catch` is a semantic change — treat
`.catch` as a boundary that pure-stage clustering may not cross.

`finally` law: `p.finally(b)` threads the settled state through `b`; `b` runs in
both branches and its rejection _replaces_ the outcome. Never commute `.finally`
with surrounding handlers.

Kleisli reassociation for `.then` chains:

```ts
p.then(f).then(g).then(h) === p.then((x) => f(x).then(g).then(h)) ===
  p.then(f).then((x) => g(x).then(h));
```

Use this to cluster adjacent _pure_ `.then(pure1).then(pure2)` stages and fuse
them into `.then(x => pure2(pure1(x)))` — valid because pure functions lift into
Kleisli arrows and composition agrees. Do not move a pure stage across a
`.catch`.

### Sequential vs concurrent await

```ts
for (const x of xs) await f(x); // sequenced effects: f(x0); f(x1); ...
await Promise.all(xs.map(f)); // concurrent, fail-fast
```

These are equal only when (a) the effects of the `f(x)` commute pairwise, and
(b) you accept `Promise.all` semantics: all started immediately, first rejection
wins, others continue in flight unobserved. State this justification explicitly
when parallelizing (see the Pure Core example in SKILL.md). `Promise.allSettled`
changes (b); `for await` over an async iterable is sequential by construction.

## Language-Specific Side Conditions

- **Accumulator copying is the O(n²) trap.** `reduce((acc, x) => [...acc, x])`
  and `{...acc, [k]: v}` copy per step. A derivation that proves "single pass"
  must also pick a constant-time accumulation in the translation:
  `acc.push(x);
  return acc`, or prefer `flatMap`/`map` which handle allocation
  internally.
- **Iterators and generators are single-shot.** `xs.map` on an array traverses a
  reusable structure; a generator can be consumed once. Two folds over a
  generator require banana split (one pass, pair accumulator) — it's mandatory,
  not stylistic. Spreading a generator (`[...gen]`) reifies it; that is the
  explicit "build the intermediate list" step fusion tries to avoid.
- **Exceptions in async functions become rejections**; `throw` inside `.then`
  becomes a rejection of the resulting promise. The Either lifting is uniform,
  which is why the laws above work — but synchronous code _before_ the first
  `await` in an async function runs eagerly at call time.
- **Floating point** is the only number type — accumulator reassociation changes
  results. Integer-like reasoning is safe within ±2⁵³ (or use `bigint`, which is
  genuinely associative).
- **`NaN !== NaN`**, and `sort` is in-place and (pre-ES2019 engines) unstable —
  treat `sort`, `reverse`, `splice` as destructive ops: reason with the
  non-mutating forms (`toSorted`, `toReversed`) and reintroduce mutation only
  where the array is provably unshared.
- **Getters and Proxies** make property access effectful. `u.name` is only
  "pure" if `name` is a data property; with a getter, even map fusion changes
  how many times the effect runs (it doesn't here — same count — but filter-map
  interchange does).

## Worked Example: Flattening a then/catch chain

```ts
// Original:
fetchUser(id)
  .then((u) => u.profile)
  .then((p) => p.displayName)
  .catch((e) => {
    throw new AppError(e);
  })
  .catch(log)
  .then((n) => n.trim());
```

```
  ((fetch >=> pure profile >=> pure displayName) `catch` rethrowWrap) `catch` log
    >=> pure trim
= { pure-stage fusion: then(f).then(g) = then(g ∘ f), no catch crossed }
  (fetch >=> pure (displayName ∘ profile)) `catch` rethrowWrap `catch` log
    >=> pure trim
= { catch associativity; rethrowWrap always throws, so the second catch
    receives AppError(e) — fuse handlers: }
  (fetch >=> pure (displayName ∘ profile)) `catch` (e => log(new AppError(e)))
    >=> pure trim
```

```ts
fetchUser(id)
  .then((u) => u.profile.displayName)
  .catch((e) => log(new AppError(e)))
  .then((n) => n.trim());
```

Declared semantic notes: handler fusion is valid because the first handler
unconditionally rethrows (its only effect is constructing AppError). One
residual hazard surfaced by the derivation: after `.catch`, `n` is `log`'s
return value (likely `undefined`), so `n.trim()` will throw — the _original_ had
the same bug; the derivation makes it visible. Flag it to the user rather than
silently "fixing" it.

## Worked Example: generator pipeline, banana split

```ts
// Original — WRONG for a generator: consumes it twice.
function stats(src: Iterable<number>) {
  const xs = [...src]; // forced reification
  const sum = xs.reduce((a, x) => a + x, 0);
  const count = xs.length;
  return sum / count;
}
```

Banana split: two folds over one structure = one fold with a pair accumulator.

```ts
function stats(src: Iterable<number>) {
  let sum = 0, count = 0;
  for (const x of src) {
    sum += x;
    count += 1;
  }
  return sum / count;
}
```

Single pass, no reification — works on one-shot iterables, O(1) space. (FP
caveat: same accumulation order as the original, so no reassociation.)
