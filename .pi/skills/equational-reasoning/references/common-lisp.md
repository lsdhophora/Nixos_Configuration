# Equational Reasoning — Common Lisp

Load this when the source or target language is Common Lisp (or, loosely,
another Lisp — Scheme/Clojure differ in the places noted).

## Idiom Recognition

| CL idiom                                                           | Scheme                                                            |
| ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| `(mapcar #'f xs)`                                                  | `map f xs`                                                        |
| `(remove-if-not #'p xs)` / `(remove-if #'p xs)`                    | `filter p` / `filter (not . p)`                                   |
| `(reduce #'f xs :initial-value z)`                                 | **foldl** `f z xs` (left fold by default)                         |
| `(reduce #'f xs :initial-value z :from-end t)`                     | `foldr f z xs`                                                    |
| `(loop for x in xs collect (f x))`                                 | `map f xs`                                                        |
| `(loop for x in xs when (p x) collect (f x))`                      | `map f . filter p` (already fused)                                |
| `(loop for x in xs sum (f x))` / `count` / `maximize`              | fold with named monoid                                            |
| `(loop for x in xs thereis (p x))` / `always` / `never`            | `any` / `all` — short-circuiting                                  |
| `(loop for x in xs until (p x) collect x)`                         | `takeWhile (not . p)`                                             |
| `(loop for i from 0 for x in xs ...)`                              | fold over `zip [0..] xs`                                          |
| `(dolist (x xs) (when (p x) (push (f x) acc)))` + `(nreverse acc)` | `map f . filter p` — push/nreverse _is_ the standard map encoding |
| `(do ((s seed (next s))) ((done s) acc) (push (emit s) acc))`      | `unfoldr`                                                         |
| `(mapcan #'f xs)`                                                  | `concatMap f xs` — **but see destructive note below**             |
| `(loop for x in xs append (f x))`                                  | `concatMap`, non-destructive                                      |
| `(some #'p xs)` / `(every #'p xs)` / `(find-if #'p xs)`            | `any` / `all` / `find`                                            |
| `(handler-case e (err (c) (h c)))`                                 | `try { e } catch (c) { h(c) }`                                    |
| `(unwind-protect a b)`                                             | `try { a } finally { b }`                                         |
| recursion via `labels` on list structure                           | fold — apply the universal property                               |

## Key Law Translations

reduce-mapcar fusion (fold-map fusion, left-fold form):

```lisp
(reduce #'f (mapcar #'g xs) :initial-value z)
= (reduce (lambda (acc x) (f acc (g x))) xs :initial-value z)
```

remove-if-not fusion:

```lisp
(remove-if-not #'p (remove-if-not #'q xs))
= (remove-if-not (lambda (x) (and (q x) (p x))) xs)   ; q tested first
```

push/nreverse is foldl-then-reverse; recognize it as map/filter rather than
calculating with it directly:

```lisp
(let (acc) (dolist (x xs (nreverse acc)) (push (f x) acc)))
= (nreverse (reduce (lambda (a x) (cons (f x) a)) xs :initial-value nil))
= (mapcar #'f xs)        ; foldl-cons-reverse = map
```

LOOP clause fusion — consecutive LOOPs where the second consumes the first's
`collect` fuse into one LOOP by composing inside the clause:

```lisp
(loop for s in (loop for u in users collect (name u))
      when (> (length s) 3) collect (string-upcase s))
= { map fusion + filter-map fold }
(loop for u in users
      for s = (string-upcase (name u))
      when (> (length s) 3) collect s)
```

Note `for s = ...` evaluates per iteration — this is the `let` inside the fold
body. Watch LOOP clause order: `for`/`with` bindings, `when` guards, and
side-effecting `do` clauses execute in written order each iteration; fusion must
preserve that order.

## Language-Specific Side Conditions

- **Integer `+`/`*` ARE associative** — CL integers are arbitrary precision.
  Reassociating integer accumulators is safe. Floats are still non-associative.
- **reduce is foldl by default.** The generic foldl↔foldr interchange needs the
  associativity+identity side condition from SKILL.md; with bignum arithmetic it
  is usually discharged, with floats it is not. Also: `reduce` without
  `:initial-value` on an empty list calls `f` with zero arguments — preserve
  that edge case or pin `:initial-value`.
- **Destructive functions break substitution.** `nconc`, `mapcan`, `sort`,
  `delete`, `nreverse` mutate their arguments. `(mapcan #'f xs)` is only
  `concatMap` when each `(f x)` returns a _fresh_ list — if `f` returns shared
  structure (a literal, a cached list), mapcan splices it destructively. When in
  doubt, calculate with the non-destructive form (`append`-based) and
  reintroduce the destructive op at the end only where freshness is provable.
- **Multiple values** vanish silently in most contexts. A "pure" function
  returning multiple values is not freely substitutable into single-value
  contexts; wrap reasoning in `multiple-value-bind` explicitly.
- **TCO is not guaranteed** by the standard. When translating a derived fold
  back, prefer LOOP/DO over self-recursion for unbounded input unless the
  implementation is known to eliminate tail calls.
- **Special variables are ambient state.** A function reading `*print-base*`,
  `*default-pathname-defaults*`, etc. is effectful for commutation purposes.

## Conditions and Restarts — the Big Caveat

The Either-isomorphism laws in SKILL.md apply to **`handler-case`** and
`ignore-errors`: those unwind to the handler, exactly like try-catch.

They do **not** apply to **`handler-bind` + restarts**. A `handler-bind` handler
runs _before_ the stack unwinds and may invoke a restart that resumes execution
at or near the signal point (`use-value`, `store-value`, `continue`,
`muffle-warning`). That control flow is not `Either E A` — "throw" doesn't mean
"abort the rest". Concretely, these familiar laws all fail under resumable
handling:

- throw-catch elimination (the signal might be resumed, not handled-and-done),
- "e cannot throw ⇒ handler is dead code" (a handler can be there to _decline_),
- nested-handler flattening (inner restarts change what the outer sees).

Rule: lift to Either only code whose condition handling is `handler-case`
shaped. Treat `handler-bind`/restart regions as opaque effectful shells.

`unwind-protect` obeys the `finally` law: it threads through both the normal and
non-local-exit paths (including `throw`, `return-from`, and restarts that
unwind). Cleanup order is an effect — never commute.

## Worked Example: dolist/push → single mapcar-style pass

```lisp
;; Original — two passes, manual accumulation:
(defun shout-long-names (users)
  (let (names)
    (dolist (u users) (push (user-name u) names))
    (setf names (nreverse names))
    (let (result)
      (dolist (s names)
        (when (> (length s) 3)
          (push (string-upcase s) result)))
      (nreverse result))))
```

```
  pass 1 = push/nreverse over users          = map name
  pass 2 = push/nreverse with guard          = map upcase . filter (len>3)
  whole  = map upcase . filter (len>3) . map name
= { filter-map interchange: filter p . map f = map f . filter (p . f),
    length and name are total }
  map upcase . map name . filter ((len>3) . name)
= { map fusion }
  map (upcase . name) . filter ((len>3) . name)
```

Hmm — that computes `name` twice per kept element. Better path: fuse into one
fold with a local binding (universal property), as in SKILL.md:

```
  map upcase . filter (len>3) . map name
= foldr (\u acc -> let s = (name u)
                   in if length s > 3 then upcase s : acc else acc) []
```

Translate back:

```lisp
(defun shout-long-names (users)
  (loop for u in users
        for s = (user-name u)
        when (> (length s) 3)
          collect (string-upcase s)))
```

Single pass, no intermediate lists, `user-name` called once per element.

## Worked Example: handler-case flattening

```lisp
;; Original:
(handler-case
    (handler-case (parse-config path)
      (parse-error (c) (default-config c)))
  (error (c) (log-and-die c)))
```

`default-config` constructs a value and cannot signal. Apply nested-handler
flattening, then dead-handler elimination on the inner result:

```
  try { try { parse } catch parse-error { default } } catch error { die }
= { flattening }
  try { parse } catch parse-error { try { default } catch error { die } }
                ... but the outer handler also guards parse's OTHER errors —
                flattening in CL must respect handler TYPE specificity:
```

Careful: the two handlers catch _different condition types_. The outer `error`
handler also catches non-`parse-error` conditions from `parse-config` itself.
The correct flattened form keeps both clauses on one handler-case, ordered
most-specific-first:

```lisp
(handler-case (parse-config path)
  (parse-error (c) (default-config c))   ; default-config cannot signal
  (error (c) (log-and-die c)))
```

Justified by: flattening + (default-config cannot throw ⇒ inner region needs no
guard) + handler-case clause matching is first-match by type. Typed,
multi-clause handlers mean CL flattening merges clause _lists_ rather than
nesting catches — same Either algebra, sum-typed error.
