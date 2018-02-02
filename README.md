# Dependencies

 * OCaml (at least 4.03.0)
 * OCamlbuild
 * Findlib
 * Earley (https://github.com/rlepigre/ocaml-earley)
 * GNU Make

# Installation procedure

```bash
git clone https://github.com/rlepigre/ocaml-earley-ocaml.git
cd ocaml-earley-ocaml
make && make
sudo make install
```

**Note:** the first `make` command will compile `pa_ocaml` from an ascii OCaml
files in directory `boostrap/...` (generated by pa_ocaml before distribution).
The second `make` command will use the newly generated pa_ocaml binary as a
preprocessor directly. It is safe to run make only once, but it is not a bad
idea to try and compile the files with the generated ocaml binary, if only to
be sure that everything is not broken...

# Getting started writing parser with Earley

The Earley library (https://github.com/rlepigre/ocaml-earley), which provides
a set of parser combinators, is not intended to be used directly (although it
can be). Indeed, calls to these combinators can be automatically generated
from a BNF-like syntax, accessed through a very natural syntax extension for
the OCaml language (documented bellow).

## Compilation example (single file)

Assuming a project with a single file `my_project.ml`, and no other dependency
than Earley, a binary could be produced with the following command.
```bash
ocamlfind ocamlopt -pp pa_ocaml -package earley -linkpkg -o my_project my_project.ml
```

# Syntax extension

## Parser expression

A parser expression, corresponding to a value of type `'a Earley.grammar`
(where `'a` is the type of object the parser produces), can be constructed
using:
```ocaml
parser
| RULE1
| ...
| RULEN
```

**Note:** the syntax is similar to `match ... with ...`. The first `|` can be
omitted, and parentheses are often required around parser expressions. In
particular, `parser` is a keyword.

## Parser declaration at the top level

Declaration of a simple parser:
```ocaml
let parser p1 = (* Here, "parser" is a keyword, like "rec" in "let rec". *)
  | RULE11
  | RULE12
  | ...
  | RULE1N
```

**Note:** this syntax is equivalent to:
```ocaml
let p1 =
  parser
  | RULE11
  | RULE12
  | ...
  | RULE1N
```

Parsers can be defined mutually recursive with other parsers (and functions):
```ocaml
let parser p1 =
  | RULE11
  | RULE12
  | ...
  | RULE1N

and f x1 ... xk =
  ...

and parser p2 =
  | RULE21
  | ...
  | RULE2M

and f x y z ... =
  ...

...

and parser pK arg =
  | RULEK1
  | ...
  | RULEKM
```

**Note:** parsers can take arguments (see `pK`).

## Parsing rule

A parsing rule is formed of a sequence of atoms, followed by an action.
```OCaml
x1:ATOM1 x2:ATOM2 ... xN:ATOMN -> ACTION
```
Here, the parsed input corresponding to `ATOM1` is put in variable `x1`,
which is bound in `ACTION`, and similarly for other atoms. If no labels
is given in front of an atom, then the parsed input is not recorded.

If no action is given, the value of the atoms are gathered in a tuple. As
a consequence, the following three rules are equivalent.
```OCaml
x1:ATOM1 x2:ATOM2 ... xN:ATOMN -> (x1, ..., xN)
x1:ATOM1 x2:ATOM2 ... xN:ATOMN
ATOM1 ATOM2 ... ATOMN
```

**Note:** in fact, in the last rule, only the atoms which value is really
meaningful are added to the couple (e.g., atoms corresponding to regexps,
but not atoms that only accept a single input string). It is possible to
prevent a meaningful atom from being added to the couple using the syntax
`_:ATOM`.

## Positions

Flexible support for positions is provided. It is enabled using a line of
the following form, involving a `locate` function. It should be in scope
and have type `Earley.input -> int -> Earley.input -> int -> t`, where `t`
is a type of your choice for representing a position.
```
#define LOCATE locate
```

Once positions have been enabled, position variables of the form `_loc_x`
are automatically created for each atom label `x`. They are available in
the corresponding action. Note that a `_loc` variable is also provided. It
corresponds to the full rule.

## Parsing atoms

We provide atoms of the following form:
```ocaml
ANY         (* Accepts any character, and returns it. *)
EOF         (* Accepts only the end of file. *)
EMPTY       (* Does not accept anything. *)
'a'         (* Accepts only the character `'a'`. *)
CHR('a')    (* Same as above. *)
"ab"        (* Accepts only the string `"ab"`. *)
STR("ab")   (* Same as above. *)
''[ab]+''   (* Accepts the input matching the given regexp, and returns it. *)
RE("[ab]+") (* Same as above, but needs escaping as with usual Str regexp. *)
```

More complex atoms can be built from OCaml expressions or other atoms:
```ocaml
expr        (* Any OCaml expression corresponding to a parser. *)
ATOM?       (* Optionally accept an ATOM, returns option type. *)
ATOM?[v]    (* Optionally accept an ATOM, returns v as default value. *)
ATOM*       (* Accepts a list of ATOM, returns a list. *)
ATOM+       (* Accepts a non-empty list of ATOM, returns a list. *)
```

Finally, a parser can be used as an atom with the following syntax:
```ocaml
{ RULE1 | RULE2 | ... | RULEN }
```

## Scanner-less parsing

Earley parsers do not require a lexer. Non-significant parts of the input
(blank characters, comments, ...) are ignored using a `blank` function,
which is called between every atom. The top level `blank` function is
provided when calling a parsing function (see `Earley.parse_file` for
example).

**Note:** the current `blank` function can be changed at any time (see the
`Earley.change_layout` function).

**Note:** blanks can be temporarily disabled between two atoms with the
syntax `ATOM1 - ATOM2`.