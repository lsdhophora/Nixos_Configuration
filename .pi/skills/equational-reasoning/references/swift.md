# Equational Reasoning — Swift

Load this when the source or target language is Swift.

Swift is the friendliest of the four targets for this skill: value semantics
give you genuine referential transparency for struct data, `lazy` gives you
fusion as a library feature, and typed errors make the Either lifting literal.

## Idiom Recognition

| Swift idiom                                              | Scheme                                        |
| -------------------------------------------------------- | --------------------------------------------- |
| `xs.map(f)` / `xs.filter(p)` / `xs.flatMap(f)`           | `map` / `filter` / `concatMap`                |
| `xs.compactMap(f)`                                       | `mapMaybe f` — map + drop nils, fused         |
| `xs.reduce(z, f)`                                        | `foldl f z xs`                                |
| `xs.reduce(into: z) { acc, x in ... }`                   | `foldl` with in-place accumulator             |
| `for x in xs { out.append(f(x)) }`                       | `map f`                                       |
| `for x in xs { guard p(x) else { continue }; ... }`      | fold over `filter p`                          |
| `for x in xs { if p(x) { break } ... }`                  | fold over `takeWhile (!p)`                    |
| `xs.first(where: p)` / `contains(where:)` / `allSatisfy` | `find` / `any` / `all`                        |
| `sequence(state:next:)` / `while let s = next(s)`        | `unfoldr`                                     |
| `xs.enumerated()`                                        | `zip [0..] xs`                                |
| `zip(xs, ys).map(f)`                                     | `zipWith f xs ys`                             |
| `a?.b?.c` / `x ?? y`                                     | Maybe bind / alternative                      |
| `if let` / `guard let` chains                            | Maybe bind, statement form                    |
| `do { try ... } catch { ... }`                           | Either bind + handler                         |
| `try?` / `try!`                                          | `toMaybe` / `fromRight!`                      |
| `Result.map/.flatMap/.mapError`                          | Either functor/bind/first-functor             |
| `defer { ... }`                                          | `finally` (LIFO order across multiple defers) |

## Law Translations

Eager fusion (eliminates intermediate arrays):

```swift
xs.map(f).map(g)        ==  xs.map { g(f($0)) }
xs.filter(p).filter(q)  ==  xs.filter { p($0) && q($0) }    // p first
xs.map(f).filter(p)     ==  xs.compactMap { let y = f($0); return p(y) ? y : nil }
xs.map(g).reduce(z, f)  ==  xs.reduce(z) { f($0, g($1)) }
```

`compactMap` is the natural target for fused map∘filter — it is the
`flatMap`-into-Optional special case and avoids array-of-arrays allocation.

**`lazy` is fusion as a library.** `xs.lazy.map(f).filter(p)` builds no
intermediates; the chain is one pass by construction. Two caveats that matter
equationally: (1) lazy sequences re-run their closures on _every_ traversal —
traverse twice, effect twice; reify with `Array(...)` at the boundary if the
result is consumed more than once. (2) A lazy chain over a one-shot `Sequence`
is itself one-shot. So: derive with the laws, then choose `lazy` (when consumed
once) or hand-fused eager code (when not) as the translation.

Accumulation cost: the equational "single pass" claim must survive translation.
`reduce(z) { $0 + [x] }` copies per step (the TypeScript spread trap, Swift
edition); use `reduce(into:)` with `append`, or `map`/`compactMap` which manage
storage internally.

Optionals obey the Maybe laws:

```swift
(a?.b)?.c          ==  a?.b?.c
(x ?? y) ?? z      ==  x ?? (y ?? z)     // ?? is right-assoc & lazy in rhs
x.map(f)?.flatMap(g) etc. — Optional.map/.flatMap satisfy functor/monad laws
```

`if let a = x, let b = a.f { ... }` is the statement spelling of
`x.flatMap { $0.f }.map { ... }` — convert to expression form to calculate,
convert back to whichever reads better.

### throws / do-catch

Swift's `throws` is `Result` in the control plane; with typed throws
(`throws(E)`) the Either is literal. All SKILL.md exception laws apply:

```swift
do { throw e } catch { h(error) }      ==  h(e)
do { try f() } catch { throw error }   ==  try f()       // catch-rethrow
do { e } catch { ... }  — handler dead when e is non-throwing (compiler
                          enforces this: warning on catch of non-throwing body)
```

Multi-clause `catch` with patterns = sum-typed handler; flattening nested
do-catch merges clause lists, first-match by pattern (same shape as the Common
Lisp handler-case note). `rethrows` functions are Kleisli-polymorphic: pure when
given pure arguments — fusion through `map`/`filter` with non-throwing closures
needs no exception side conditions, and the compiler is checking that for you.

`defer` is `finally`; multiple `defer`s run LIFO. Cleanup order is an effect:
never commute `defer` bodies, and remember a `defer` declared _after_ a throwing
call doesn't guard it.

## Language-Specific Side Conditions

- **Overflow traps.** `+`, `*` on fixed-width integers trap on overflow —
  defined behavior (unlike C's UB), but reassociation can still change _whether_
  a trap occurs. `&+`/`&*` wrap mod 2ⁿ and are genuinely associative, with
  modular meaning. Floats: non-associative as everywhere.
- **Value semantics are your friend.** `let` structs/arrays/dictionaries are
  immutable values; substitution is fully valid for them — no aliasing analysis
  needed. CoW makes the copies cheap. Reference types (`class`, closures
  capturing `var`s) reintroduce aliasing; check before fusing loops that touch
  them.
- **Closures capturing `var`s** are stateful — a "pure-looking" `map` closure
  incrementing a captured counter is a fold in disguise. Recognize it as such
  rather than fusing it as a map.
- **Concurrency.** `async let` / `withTaskGroup` parallelization of a sequential
  `for await` loop is the sequential→concurrent change from SKILL.md: requires
  effect commutation plus acceptance of cancellation semantics (first error
  cancels siblings in a throwing task group). Actor isolation actually _helps_:
  state confined to one actor can't be observed mid-transformation by others, so
  reasoning within an actor is single-threaded reasoning. Don't reason
  equationally across `await` suspension points where shared mutable state
  (globals, unisolated classes) could change.

## Worked Example: loop with guard/continue → compactMap

```swift
// Original:
var results: [String] = []
for u in users {
    guard let email = u.email else { continue }
    let normalized = email.lowercased()
    if normalized.hasSuffix("@example.com") { continue }
    results.append(normalized)
}
```

Recognize: append-loop with two skip-guards =
`filter q . map norm . mapMaybe email`, in source order: extract optional →
normalize → drop matching suffix.

```
  filter (not . suffix) . map lower . mapMaybe email
= { map into mapMaybe: mapMaybe g . — fuse pure post-map into the Maybe step:
    mapMaybe (fmap lower . email) }
  filter (not . suffix) . mapMaybe (fmap lower . email)
= { filter into mapMaybe: mapMaybe h . then guard — fuse predicate into Maybe }
  mapMaybe (\u -> case email u of
                    Nothing -> Nothing
                    Just e  -> let n = lower e
                               in if suffix n then Nothing else Just n)
```

Translate back — `mapMaybe` is `compactMap`:

```swift
let results = users.compactMap { u -> String? in
    guard let email = u.email else { return nil }
    let n = email.lowercased()
    return n.hasSuffix("@example.com") ? nil : n
}
```

Single pass, no intermediate arrays, guards preserved in original order. All
closures non-throwing and pure (String is a value type), so no side conditions
to discharge.

## Worked Example: do-catch flattening with Result

```swift
// Original:
func loadConfig() -> Config {
    do {
        do { return try parse(at: path) }
        catch let e as ParseError { return Config.default(reporting: e) }
    } catch {
        fatalError("unreadable: \(error)")
    }
}
```

`Config.default(reporting:)` is non-throwing (compiler-checkable). Apply
nested-handler flattening + dead-inner-guard elimination; merge into one clause
list, most specific first — identical algebra to the CL example:

```swift
func loadConfig() -> Config {
    do { return try parse(at: path) }
    catch let e as ParseError { return Config.default(reporting: e) }
    catch { fatalError("unreadable: \(error)") }
}
```

Or, lifting fully into Either space when a value is preferable to control flow:

```swift
let config = Result { try parse(at: path) }
    .flatMapError { e in
        (e as? ParseError).map { .success(Config.default(reporting: $0)) }
            ?? .failure(e)
    }
```

The do-catch form is the better _translation back_ here — the Result form is the
scratch notation showing why the flattening is sound.
