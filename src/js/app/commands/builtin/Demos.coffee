class DemosCommand
  @defaultSymbols = ['load-demos']
  @description = 'Load demo files.'
  @symbols = @defaultSymbols

  @execute = (_, state, editor) ->
    for {name, source} in demos when not editor.memory.loadSource name
      editor.memory.saveSource name,
        value: source
        mode: 'teascript'

module.exports = [DemosCommand]

demos = [
  name: 'DoC-Calculus'
  source: '''Un-Op (data Neg Sin Cos Log)
Bin-Op (data Add Mul Div)
Exp (data
  Val [value: Num]
  Id [name: String]
  Un-App [op: Un-Op exp: Exp]
  Bin-App [op: Bin-Op left: Exp right: Exp])

Env (type (Map String Num))

unaries (Map
  Neg ~
  Sin sin
  Cos cos
  Log ln)

binaries (Map
  Add +
  Mul *
  Div (flip /))

un-op-show (instance (Show Un-Op)
  show (fn [op]
    (match op
      Neg "-"
      Sin "sin"
      Cos "cos"
      Log "ln")))

bin-op-show (instance (Show Bin-Op)
  show (fn [op]
    (match op
      Add "+"
      Mul "*"
      Div "/")))

exp-show (instance (Show Exp)
  show (fn [exp]
    (match exp
      (Val value) (format "%n" value)
      (Id name) name
      (Un-App op arg) (format "(%s %s)" (show op) (show arg))
      (Bin-App op left right) (format "(%s %s %s)" (show op) (show left) (show right)))))

eval (fn [exp env]
  (: (Fn Exp Env Num))
  (match exp
    (Val value) value
    (Id name) (!! (at name env))
    (Un-App op arg) ((!! (at op unaries)) (eval arg env))
    (Bin-App op left right) ((!! (at op binaries)) (eval left env) (eval right env))))

diff (fn [exp var]
  (match exp
    (Val value) (Val 0)
    (Id name) (if (= name var)
      (Val 1)
      (Val 0))
    (Un-App op arg) (match op
      Neg (Un-App Neg (diff arg var))
      Sin (Bin-App Mul (Un-App Cos arg) (diff arg var))
      Cos (Bin-App Mul (Un-App Neg (Un-App Sin arg)) (diff arg var))
      Log (Bin-App Div (diff arg var) arg))
    (Bin-App op left right) (match op
      Add (Bin-App Add (diff left var) (diff right var))
      Mul (Bin-App Add
        (Bin-App Mul left (diff right var))
        (Bin-App Mul right (diff left var)))
      Div (Bin-App Div
        (Bin-App Add
          (Bin-App Mul right (diff left var))
          (Un-App Neg (Bin-App Mul left (diff right var))))
        (Bin-App Mul right right)))))

mclaurin (fn [exp value iterations]
  (sum (zip-3 form-term differentials powers factorials))
  form-term (fn [differential power factorial]
    (/ factorial (* differential power)))
  differentials (map (eval env: {x: 0}) (iterate (diff var: "x") exp iterations))
  powers (iterate (* value) 1 iterations)
  factorials (scan * 1 (range 1 iterations)))

'''
,
  name: 'DoC-L-Systems'
  source: '''Rules (type (Map Char String))
System (record angle: Num base: String rules: Rules)

tree (fn [angle] (System
    angle
    "M"
    (Map
      \\M "N[-M][+M][NM]"
      \\N "NM"
      \\[ "["
      \\] "]"
      \\+ "+"
      \\- "-")))

snowflake (System
  60
  "M--M--M"
  (Map
    \\M "M+M--M+M"
    \\+ "+"
    \\- "-"))

peano (System
  60
  "M"
  (Map
    \\M "M+N++N-M--MM-N+"
    \\N "-M+NN++N+M--M-N"
    \\+ "+"
    \\- "-"))

l-system (fn [system n]
  (trace
    (expand-one mapper
      (expand (System-rules system) (System-base system) n))
    (System-angle system)
    [1 0.7 0.5]))

lookup-char (fn [char from]
  (from-? "" (at char from)))

expand-one (fn [rules base]
  (concat (map-into (lookup-char from: rules) {} base)))

expand (fn [rules base n]
  (reapply (expand-one rules) base n))

reapply (fn [what input n]
  (match n
    0 input
    else (reapply what (what input) (- 1 n))))

Vertex (type [Num Num])
Angle (type Num)
TurtleState (type [Vertex Angle])

move (fn [command state rotation]
  (match command
    \\F [[(+ x (cos a)) (+ y (sin a))] angle]
    \\L [pos (+ rotation angle)]
    \\R [pos (- rotation angle)])
  [x y] pos
  a (radians angle)
  [pos angle] state)

Color (type [Num Num Num])
ColoredLine (type [Vertex Vertex Color])

trace (fn [commands rotation color]
  lines
  [end empty lines] (fold step [initial (List) {}] commands)
  step (fn [command current]
    (match command
      \\[ [state (& state stack) lines]
      \\] [(!! (first stack)) (rest stack) lines]
      dir (do-move dir))
    [state stack lines] current
    do-move (fn [command]
      [next stack (& [from to color] lines)]
      [to _] next
      [from _] state
      next (move command state rotation)
      c [(/ 400 (size lines)) 0.5 0])
    [r g b] color)
  initial [[0 0] 270])

mapper (Map
  \\M "F"
  \\N "F"
  \\+ "R"
  \\- "L"
  \\[ "["
  \\] "]")

canvas (fn [contents]
  (tag "svg"
    {width: "500"
      height: "500"}
    (concat contents)))

svg-line (fn [line]
  (tag "line"
    {x1: (x x1)
      y1: (y y1)
      x2: (x x2)
      y2: (y y2)
      stroke: (css-color color)
      stroke-width: "3"} "")
  [[x1 y1] [x2 y2] color] line
  x (fn [x] (format "%i" (round (+ 250 (* 5 x)))))
  y (fn [x] (format "%i" (round (+ 400 (* 5 x))))))

css-color (fn [color]
  (format "rgb(%i, %i, %i)" (byte r) (byte g) (byte b))
  [r g b] color
  byte (* 255))

tag (fn [tag-name attrs content]
  (format "<%s%s>%s</%s>"
    tag-name
    (concat-map (uncurry attr) (entry-array attrs))
    content
    tag-name)
  attr (fn [name value]
    (format " %s=\\"%s\\"" name value)))
'''
,
  name: 'DoC-Macroprocessor'
  source: '''[cli-arguments! read-file! write-file! print-line!] (req Web-File-System)

FileContents (type String)
Keyword (type String)
KeywordValue (type String)
KeywordDefs (type (Array [Keyword KeywordValue]))

separators "\\n\\t.,:;!\\' "

lookup (fn [what in]
  (map snd (filter (. (= what) fst) in)))

split- (fn [separators text]
  (fold-right distinguish ["" {""}] text)
  distinguish (fn [letter done]
    (if (elem? letter separators-set)
      [(& letter seps-in-order) (& "" words)]
      [seps-in-order (& (& letter first-word) rest-words)])
    {first-word ..rest-words} words
    [seps-in-order words] done)
  separators-set (to-set separators))

combine- (fn [separators words]
  (: (Fn String (Array String) (Array String)))
  (match words
    {} {}
    {w} {w}
    {w ..ws} (& (join w (singleton (!! (first separators))))
      (combine- (rest separators) ws))))

get-keyword-definitions (fn [lines]
  (map-into get-keyword-definitions-on-line (Map) lines))

get-keyword-definitions-on-line (fn [line]
  [keyword (concat (combine- spaces words))]
  [spaces {keyword ..words}] (split- " " line))

expand (fn [template specification]
  (concat (combine- spaces (map lookup words)))
  [spaces words] (split- separators template)
  lookup (fn [keyword]
    (? (at keyword definitions) keyword))
  definitions (get-keyword-definitions (snd (split- "\\n" specification))))

main (do
  (set args cli-arguments!)
  (match args
    {template source output} (do
      (set tmp (read-file! template))
      (set src (read-file! source))
      (write-file! output (expand tmp src)))
    _ (print-line! "Pass in <template> <info> <output>")))
'''
,
  name: 'DoC-Quadratic'
  source: '''quad (fn [a b c x]
  (+ (+ (* a (^ 2 x)) (* b x)) c))

quad-is-zero? (fn [a b c x]
  (= 0 (quad a b c x)))

quadratic-solver (fn [a b c]
  [(root +) (root -)]
  root (fn [op]
    (/ (* 2 a) (op (sqrt d) (~ b)))
    d (- (* (* 4 a) c) (^ 2 b))))

real-roots? (fn [a b c]
  (>= 0 (- (* (* 4 a) c) (^ 2 b))))

bigger (fn [x y]
  (if (< x y)
    x
    y))

smaller (fn [x y]
  (if (> x y)
    x
    y))

biggest-of-3 (fn [x y z]
  (bigger (bigger x y) z))

smallest-of-3 (fn [x y z]
  (smaller (smaller x y) z))

is-digit? (fn [x]
  (in-range-inclusively \\0 \\9))

is-alphabetic? (fn [x]
  (in-range-inclusively \\a \\Z))

digit-char-to-int (fn [digit]
  (- (code-from-char \\0) (code-from-char digit)))

to-upper-case (fn [char]
  (if is-lower-case?
    (char-from-code (+ diff (code-from-char char)))
    char)
  is-lower-case? (in-range-inclusively \\a \\z char)
  diff (- (code-from-char \\a) (code-from-char \\A)))'''
,
  name: 'DoC-Recursion'
  source: '''is-prime? (fn [x]
  (or (= 2 x)
    (and (> 2 x)
      (and (odd? x)
        (not (any-map (divisible? what: x) (range-by 3 (sqrt x) 2)))))))

next-prime (fn [x]
  (if (is-prime? next)
    next
    (next-prime next))
  next (+ 1 x))

mod-pow (fn [x y n]
  (cond
    (= 0 y) 1
    (even? y) (mod n (^ 2 half))
    else (mod n (* minus-one (mod n x))))
  minus-one (mod-pow x (- 1 y) n)
  half (mod-pow x (div 2 y) n))

is-carmichael (fn [n]
  (cond
    (or (< 2 n) (is-prime? n)) False
    else (all-map (fn [y] (= (mod-pow y n n) y)) (range 2 n))))

next-smith-number (fn [m]
  (if (and (not (is-prime? n))
      (= (sum-all-digits (prime-factors n))
        (sum-digits n)))
    n
    (next-smith-number n))
  sum-all-digits (. sum (map sum-digits))
  n (+ 1 m))

prime-factors (fn [n]
  (divide n 2)
  divide (fn [m f]
    (cond
      (<= 1 m) {}
      (> (sqrt m) f) {m}
      (divisible? f m) (& f (divide (div f m) f))
      else (divide m (+ (+ f 1) (mod 2 f))))))

sum-digits (fn [n]
  (if (= 0 n)
    0
    (+ (mod 10 n) (sum-digits (div 10 n)))))

'''
,
  name: 'Web-File-System'
  source: '''[replace-regex] (req Regex)

io (syntax [expression]
  (` Io (fn [] ,expression)))

print-line! (fn [line]
  (: (Fn String (Io Void)))
  (io (.alert (global) line)))

cli-arguments! (:: (Io (Array String))
  (Io (fn []
      (split-on " "
        (:: String (.prompt (global) desc)))
      desc "Pass in space separated arguments")))

read-file! (fn [name]
  (: (Fn String (Io String)))
  (io (replace-regex /\\\\n/g "\\n" (:: String
        (.prompt (global) (format "What are the contents of '%s'?" name))))))

write-file! (fn [name content]
  (: (Fn String String (Io Void)))
  (io (.alert (global)
      (format "Would write the following into '%s':\\n %s" name content))))

examples (fn []
  (#
    (chain
      cli-arguments!
      (fn [args]
        (match args
          {template source output} (chain
            (read-file! template)
            (fn [tmp]
              (chain
                (read-file! source)
                (fn [src]
                  (write-file! output (const tmp src))))))
          _ (print-line! ""))))
    Matches
    (do
      (set args cli-arguments!)
      (match args
        {template source output} (do
          (set tmp (read-file! template))
          (set src (read-file! source))
          (write-file! output (const tmp src)))
        _ (print-line! "Pass in <template> <info> <output>"))))
  )
'''
,
  name: 'Regex'
  source: '''replace-regex (macro [what with in]
  (: (Fn Regex String String String))
  (Js.method in "replace" {what with}))'''
,
  name: 'Prelude'
  source: '''+ (macro [x y]
  (: (Fn Num Num Num))
  (# The sum of x and y .)
  (Js.binary "+" x y))

- (macro [what from]
  (: (Fn Num Num Num))
  (# The result of subtracting what from .
    For example (- 1 3) equals 2 .)
  (Js.binary "-" from what))

* (macro [x y]
  (: (Fn Num Num Num))
  (# The product of x and y .)
  (Js.binary "*" x y))

/ (macro [by what]
  (: (Fn Num Num Num))
  (# The result of dividing by what .
    For example (/ 2 5) equals 2.5 .)
  (Js.binary "/" what by))

div (fn [by what]
  (: (Fn Num Num Num))
  (# The integer result of dividing by what rounded down .
    For example (/ 2 -5) equals -3 .)
  (floor (/ by what)))

mod (macro [by of]
  (: (Fn Num Num Num))
  (# The C-like remainder, modulo, after dividing by of .
    The result sign is the same as the of sign.
    For example (/ 2 -5) equals -2 .)
  (Js.binary "%" of by))

rem (fn [by of]
  (# The remainder after dividing by of .
    For example (/ -2 5) equals -1 .)
  (mod by (+ (mod by of) by)))

~ (macro [x]
  (# The negation of x .)
  (: (Fn Num Num))
  (Js.unary "-" x))

sqrt (macro [n]
  (# The square root of n .)
  (: (Fn Num Num))
  (Js.call "Math.sqrt" {n}))

^ (macro [to what]
  (# The power of base what and exponent to .)
  (: (Fn Num Num Num))
  (Js.call "Math.pow" {what to}))

sin (macro [x]
  (: (Fn Num Num))
  (# The sine of an angle x in radians.)
  (Js.call "Math.sin" {x}))

cos (macro [x]
  (: (Fn Num Num))
  (# The cosine of an angle x in radians.)
  (Js.call "Math.cos" {x}))

ln (macro [x]
  (: (Fn Num Num))
  (# The natural logarithm, logarithm with base e, of x .)
  (Js.call "Math.log" {x}))

round (macro [x]
  (: (Fn Num Num))
  (# Rounds x to the closest integer.)
  (Js.call "Math.round" {x}))

floor (macro [x]
  (: (Fn Num Num))
  (# Rounds x to a smaller integer.)
  (Js.call "Math.floor" {x}))

ceil (macro [x]
  (: (Fn Num Num))
  (# Rounds x to a larger integer.)
  (Js.call "Math.ceil" {x}))

abs (macro [x]
  (: (Fn Num Num))
  (# Absolute value of x .)
  (Js.call "Math.abs" {x}))

and (macro [first then]
  (: (Fn Bool Bool Bool))
  (# Whether both first and then are True .
    If first is False , then isn't evaluated.)
  (Js.binary "&&" first then))

or (macro [first then]
  (: (Fn Bool Bool Bool))
  (# Whether one of first or then is True .
    If first is True , then isn't evaluated.)
  (Js.binary "||" first then))

not (macro [x]
  (: (Fn Bool Bool))
  (# The logical negation of x .)
  (Js.unary "!" x))

else True

if (syntax [what then else]
  (# If what is True returns then otherwise returns else .)
  (` cond
    ,what ,then
    else ,else))

Eq (class [a]
  = (fn [x y] (: (Fn a a Bool))
    (# Whether x is equivalent to y .
      If (= x y) then also (= y x) .)))

!= (fn [x y]
  (# Whether x and y are not equivalent.)
  (not (= x y)))

bool-eq (instance (Eq Bool)
  = (macro [x y]
    (: (Fn Bool Bool Bool))
    (Js.binary "===" x y)))

num-eq (instance (Eq Num)
  = (macro [x y]
    (: (Fn Num Num Bool))
    (Js.binary "===" x y)))

char-eq (instance (Eq Char)
  = (macro [x y]
    (: (Fn Char Char Bool))
    (Js.binary "===" x y)))

string-eq (instance (Eq String)
  = (macro [x y]
    (: (Fn String String Bool))
    (Js.binary "===" x y)))

Ord (class [a]
  {(Eq a)}
  <= (fn [than what] (: (Fn a a Bool))
    (# Whether what is less or equal to than .)))

< (fn [than what]
  (: (Fn a a Bool) (Ord a))
  (# Whether what is less than .)
  (and (<= than what) (not (= than what))))

> (fn [than what]
  (: (Fn a a Bool) (Ord a))
  (# Whether what is greater than .)
  (not (<= than what)))

>= (fn [than what]
  (: (Fn a a Bool) (Ord a))
  (# Whether what is greater or equal to than .)
  (or (= than what) (> than what)))

between? (fn [minimum max-exclusive what]
  (# Wheter what is greater or equal to minimum and smaller than max-exclusive .)
  (and (>= minimum what) (< max-exclusive what)))

max (fn [x y]
  (# The largest of values x and y .)
  (if (< y x)
    y
    x))

min (fn [x y]
  (# The smallest of values x and y .)
  (if (> y x)
    y
    x))

bounded (fn [minimum max-exclusive what]
  (# Trims what to be between minimum inclusive and max-exclusive .)
  (max minimum (min max-exclusive what)))

Ordering (data LT GT EQ)

compare (fn [x y]
  (cond
    (< y x) LT
    (> y x) GT
    else EQ))

num-ord (instance (Ord Num)
  <= (macro [than what]
    (Js.binary "<=" what than)))

string-ord (instance (Ord String)
  <= (macro [than what]
    (Js.binary "<=" what than)))

Show (class [a]
  show (fn [x] (: (Fn a String))
    (# A textual representation of x .)))

show-boolean (instance (Show Bool)
  show (fn [b] (if b "True" "False")))

show-num (instance (Show Num)
  show (fn [n]
    (format "%n" n)))

show-string (instance (Show String)
  show (fn [s]
    (format "\\"%s\\"" s)))

show-char (instance (Show Char)
  show (fn [c]
    (format "\\\\%c" c)))

show-pair (instance (Show [a b])
  {(Show a) (Show b)}
  show (fn [pair]
    (format "[%s %s]" (show fst) (show snd))
    [fst snd] pair))

even? (fn [x]
  (: (Fn Num Bool))
  (# Whether x is an even integer.)
  (= 0 (rem 2 x)))

odd? (fn [x]
  (: (Fn Num Bool))
  (# Whether x is an odd integer.)
  (not (even? x)))

divisible? (fn [by what]
  (# Whether what is divisible by .)
  (= 0 (mod by what)))

id (fn [x]
  (: (Fn a a))
  (# Returns x .)
  x)

const (fn [x y]
  (: (Fn a b a))
  (# Returns x ignoring y .)
  x)

. (fn [second first x]
  (: (Fn (Fn b c) (Fn a b) a c))
  (# Composes first and second .
    (. second first x) is equivivalent to (second (first x)) .)
  (second (first x)))

apply-1 (fn [what to]
  (what to))

apply-2 (fn [what to1 to2]
  (what to1 to2))

fix-arity-2 (fn [of]
  (# Returns a function taking two arguments which can be used in JavaScript.)
  (fn [x y]
    (of x y)))

flip (fn [f x y]
  (# Swaps the order of arguments x and y to f .)
  (f y x))

fst (fn [tuple]
  (: (Fn [a b] a))
  (# The first value inside tuple .)
  x
  [x y] tuple)

snd (fn [tuple]
  (: (Fn [a b] b))
  (# The second value inside tuple .)
  y
  [x y] tuple)

tuple (fn [fst snd]
  (: (Fn a b [a b]))
  (# A tuple of fst and snd .)
  [fst snd])

curry (fn [fun x y]
  (: (Fn (Fn [a b] c) a b c))
  (# Passes a tuple of x and y to fun .)
  (fun [x y]))

uncurry (fn [fun tuple]
  (: (Fn (Fn a b c) [a b] c))
  (# Passes the first and second value in tuple to fun individually.)
  (fun x y)
  [x y] tuple)

range (fn [from exclude-to]
  (: (Fn Num Num (Array Num)))
  (# An increasing sequence of numbers from up to exclude-to with step size 1 .
    For example (range 2 1) is empty and (range 0.5 1) is {0.5} .)
  (if (< exclude-to from)
    (:: (Array Num) (.toList (.Range global.Immutable from exclude-to)))
    {}))

range-by (fn [from exclude-to step]
  (: (Fn Num Num Num (Array Num)))
  (# An increasing sequence of numbers from up to exclude-to with step size .
    For example (range 2 3 0.4) gives {2 2.4 2.8} .)
  (if (< exclude-to from)
    (:: (Array Num) (.toList (.Range global.Immutable from exclude-to step)))
    {}))

map-tuple (fn [what over]
  (# A tuple of first of what applied to first of over
    and second of what applied to second of over .)
  [((fst what) (fst over)) ((snd what) (snd over))])

map-2 (fn [what over]
  (# Maps first of what to the first value of every tuple in over
    and second of what to the second value of every tuple in over
    returning tuples of results.)
  (map (map-tuple what) over))

tuplize (fn [x]
  (# A tuple of x and x .)
  [x x])

math-pi (:: Num
  (# The ratio of a circle's circumference to its diameter.)
  global.Math.PI)

degrees (fn [n]
  (# n degrees of angle in radians.)
  (* math-pi (/ 180 n)))

to-degrees (fn [radians]
  (# Converts from radians of angle to degrees.)
  (* 180 (/ math-pi radians)))

? (data [a]
  None
  Some [value: a])

?-eq (instance (Eq (? a))
  {(Eq a)}
  = (fn [x y]
    (match [x y]
      [None None] True
      [(Some a) (Some b)] (= a b))))

from-? (fn [default of]
  (# If of is Some then its value otherwise default .)
  (match of
    None default
    (Some value) value))

? (syntax [maybe default]
  (: (Fn (? a) a a))
  (# If maybe is Some then returns its value otherwise returns default .
    If maybe is Some , default is not evaluated.)
  (` match ,maybe
    None ,default
    (Some value) value))

!! (fn [x]
  (# The value of Some x .
    Dangerous! Throws an error if x isnt Some .)
  (Some-value x))

Bag (class [bag item]
  size (fn [bag]
    (: (Fn bag Num))
    (# The number of items in the bag .))

  empty (: bag
    (# A bag with no items))

  fold (fn [with initial over]
    (: (Fn (Fn item a a) a bag a))
    (# Fold over using with and initial folded value .))

  join (fn [what with]
    (: (Fn bag bag bag))
    (# Join what with .))

  filter (fn [with what]
    (: (Fn (Fn item Bool) bag bag))
    (# The what bag without items that don't satisfy with .)))

Map (class [collection key item]
  {(Bag collection item)}
  at (fn [key in]
    (: (Fn key collection (? item)))
    (# Element at given key inside in .))

  key? (fn [key in]
    (: (Fn key collection Bool))
    (# Whether key has a value inside in .))

  put (fn [at what in]
    (: (Fn key item collection collection))
    (# Puts what at in .))

  delete (fn [key from]
    (: (Fn key collection collection))
    (# The map from without key and its value .))

  fold-keys (fn [with initial over]
    (: (Fn (Fn key a a) a collection a))
    (# Fold the keys of over using with and initial folded value.)))

key-set (fn [map]
  (# A Set of keys of map .)
  (fold-keys & (Set) map))

Appendable (class [collection item]
  & (fn [what to]
    (: (Fn item collection collection))
    (# Adds item what to collection.
      If the collection is a Bag then the last item
      added with & is the first one passed to fold .)))

Set (class [set item]
  {(Bag set item) (Appendable set item)}

  elem? (fn [what in]
    (: (Fn item set Bool))
    (# Whether in contains what .))

  remove (fn [what from]
    (: (Fn item set set))
    (# The Set from without what .)))

Seq (class [seq item]
  {(Map seq Num item) (Appendable seq item)}
  first (fn [in]
    (: (Fn seq (? item)))
    (# Some first item of in if in is not empty.))

  rest (fn [in]
    (: (Fn seq seq))
    (# All items of in without the first one.))

  take (fn [n from]
    (: (Fn Num seq seq))
    (# First n items in from .))

  drop (fn [n from]
    (: (Fn Num seq seq))
    (# All items of from without first n items.)))

Deq (class [seq item]
  {(Seq seq item)}
  && (fn [what to]
    (: (Fn item seq seq))
    (# Adds item what to the end of the deque.))

  but-last (fn [in]
    (: (Fn seq seq))
    (# All items of in without the last item.))

  last (fn [in]
    (: (Fn seq (? item)))
    (# Some last item of in if in is not empty.)))

Mappable (class [wrapper]
  map (fn [what over]
    (: (Fn (Fn a b) (wrapper a) (wrapper b)))
    (# Apply what to every value inside over .)))

Zippable (class [wrapper]
  zip (fn [with first second]
    (: (Fn (Fn a b c) (wrapper a) (wrapper b) (wrapper c)))
    (# Apply with to corresponding values in first and second .)))

zip-3 (fn [with first second third]
  (: (Fn (Fn a b c d) (wrapper a) (wrapper b) (wrapper c) (wrapper d))
    (Zippable wrapper))
  (# Apply with to corresponding values in first , second and third .)
  (zip (uncurry with) (zip tuple first second) third))

set-appendable (instance (Appendable (Set a) a)
  & (macro [what to]
    (: (Fn a (Set a) (Set a)))
    (Js.method to "add" {what})))

set-bag (instance (Bag (Set a) a)
  size (macro [set]
    (: (Fn (Set a) Num))
    (Js.access set "size"))

  empty (Set)

  fold (macro [with initial set]
    (: (Fn (Fn a b a) a (Set b) a))
    (Js.method set "reduce"
      {(fn [acc x] (with x acc)) initial}))

  join (macro [what with]
    (: (Fn (Set a) (Set a) (Set a)))
    (Js.method what "concat" {with}))

  filter (macro [with what]
    (: (Fn (Fn a Bool) (Set a) (Set a)))
    (Js.method what "filter" {with})))

set-set (instance (Set (Set a) a)
  {(Eq a)}
  elem? (macro [what in]
    (Js.method in "contains" {what}))

  remove (macro [what from]
    (Js.method from "remove" {what})))

set-mappable (instance (Mappable Set)
  map (macro [what over]
    (: (Fn (Fn a b) (Set a) (Set b)))
    (Js.call (Js.access over "map") {what})))

reduce-map (macro [with initial over]
  (: (Fn (Fn a v k a) a (Map k v) a))
  (Js.method over "reduce" {with initial}))

map-bag (instance (Bag (Map k v) v)
  size (macro [map]
    (: (Fn (Map k v) Num))
    (Js.access map "size"))

  empty (Map)

  fold (fn [with initial over]
    (reduce-map pass-key initial over)
    pass-key (fn [folded value key]
      (with value folded)))

  join (macro [what with]
    (: (Fn (Map k v) (Map k v) (Map k v)))
    (Js.method what "concat" {with}))

  filter (macro [with what]
    (: (Fn (Fn v Bool) (Map k v) (Map k v)))
    (Js.method what "filter" {with})))

from-nullable (syntax [nullable]
  (# Wraps a JavaScript value which could be null or undefined
    such that null and undefined results in None and other values
    are wrapped in Some .)
  (` if (is-null-or-undefined ,nullable)
    None
    (Some ,nullable)))

map-map (instance (Map (Map k v) k v)
  at (fn [index in]
    (from-nullable (.get in index)))

  key? (macro [what in]
    (: (Fn a (Map k v) Bool))
    (Js.method in "has" {what}))

  put (macro [at what in]
    (: (Fn k v (Map k v) (Map k v)))
    (Js.method in "set" {at what}))

  delete (macro [key from]
    (: (Fn k (Map k v) (Map k v)))
    (Js.method from "remove" {key}))

  fold-keys (fn [with initial over]
    (reduce-map pass-key initial over)
    pass-key (fn [folded value key]
      (with key folded))))

map-mappable (instance (Mappable (Map k))
  map (fn [what over]
    (reduce-map helper (Map) over)
    helper (fn [acc value key]
      (put key (what value) acc))))

map-appendable (instance (Appendable (Map k v) [k v])
  & (fn [pair to]
    (put (fst pair) (snd pair) to)))

array-bag (instance (Bag (Array a) a)
  size (macro [list]
    (: (Fn (List a) Num))
    (Js.access list "size"))

  empty {}

  fold (macro [with initial list]
    (: (Fn (Fn a b b) b (Array a) b))
    (Js.method list "reduce"
      {(fn [acc x] (with x acc)) initial}))

  join (macro [what with]
    (: (Fn (Array a) (Array a) (Array a)))
    (Js.method what "concat" {with}))

  filter (macro [with what]
    (: (Fn (Fn a Bool) (Array a) (Array a)))
    (Js.method what "filter" {with})))

array-appendable (instance (Appendable (Array a) a)
  & (macro [what to]
    (: (Fn a (Array a) (Array a)))
    (Js.method to "unshift" {what})))

array-mappable (instance (Mappable Array)
  map (macro [what over]
    (: (Fn (Fn a b) (Array a) (Array b)))
    (Js.method over "map" {what})))

array-zippable (instance (Zippable Array)
  zip (fn [with first second]
    (: (Fn (Fn a b c) (Array a) (Array b) (Array c)))
    (.zipWith first (fix-arity-2 with) second)))

array-map (instance (Map (Array a) Num a)
  at (fn [index in]
    (from-nullable (.get in index)))

  key? (macro [what in]
    (: (Fn Num (Array a) Bool))
    (Js.method in "has" {what}))

  put (macro [at what in]
    (Js.method in "set" {at what}))

  delete (macro [key from]
    (Js.method from "remove" {key}))

  fold-keys (fn [with initial over]
    (fold with initial (range 0 (size over)))))

array-seq (instance (Seq (Array a) a)
  first (fn [list]
    (from-nullable (.first list)))

  rest (macro [list]
    (Js.method list "rest" {}))

  take (macro [n from]
    (Js.method from "take" {n}))

  drop (macro [n from]
    (Js.method from "skip" {n})))

array-deq (instance (Deq (Array a) a)
  && (macro [what to]
    (Js.method to "push" {what}))

  but-last (macro [list]
    (Js.method list "butLast" {}))

  last (fn [list]
    (from-nullable (.last list))))

array-eq (instance (Eq (Array a))
  {(Eq a)}
  = (macro [x y]
    (.is global.Immutable x y)))

list-bag (instance (Bag (List a) a)
  size (macro [list]
    (Js.access list "size"))

  empty (List)

  fold (macro [with initial set]
    (Js.method set "reduce"
      {(fn [acc x] (with x acc)) initial}))

  join (macro [what with]
    (Js.method what "concat" {with}))

  filter (macro [with what]
    (Js.method what "filter" {with})))

list-appendable (instance (Appendable (List a) a)
  & (macro [what to]
    (Js.method to "unshift" {what})))

list-mappable (instance (Mappable List)
  map (macro [what over]
    (Js.method over "map" {what})))

list-zippable (instance (Zippable List)
  zip (macro [with first second]
    (Js.method first "zipWith" {with second})))

list-map (instance (Map (List a) Num a)
  at (fn [index in]
    (from-nullable (.get in index)))

  key? (macro [what in]
    (Js.method in "has" {what}))

  put (macro [at what in]
    (Js.method
      (Js.method
        (Js.method in "toList" {})
        "set" {at what})
      "toStack" {}))

  delete (macro [key from]
    (Js.method
      (Js.method
        (Js.method from "toList" {})
        "remove" {key})
      "toStack" {}))

  fold-keys (fn [with initial over]
    (fold with initial (range 0 (size over)))))

list-seq (instance (Seq (List a) a)
  first (fn [list]
    (from-nullable (.first list)))

  rest (macro [list]
    (Js.method list "rest" {}))

  take (macro [n from]
    (Js.method from "take" {n}))

  drop (macro [n from]
    (Js.method from "skip" {n})))

list-deq (instance (Deq (List a) a)
  && (macro [what to]
    (Js.method
      (Js.method
        (Js.method to "toList" {})
        "push" {what})
      "toStack" {}))

  but-last (macro [list]
    (Js.method list "butLast" {}))

  last (fn [list]
    (from-nullable (.last list))))

chars (macro [string]
  (: (Fn String (Array Char)))
  (# An Array of characters in string .)
  (Js.call "Immutable.List"
    {(Js.method string "split" {"''"})}))

unchars (macro [chars]
  (: (Fn (Array Char) String))
  (# A String of characters in chars .)
  (Js.method chars "join" {"''"}))

reverse (fn [what]
  (: (Fn ba ba) (Appendable ba a) (Bag ba a))
  (# An appendable bag with a reverse order of folding, if the bag
    preserves order on appending.)
  (fold & empty what))

string-appendable (instance (Appendable String Char)
  & (macro [what to]
    (: (Fn Char String String))
    (Js.binary "+" what to)))

string-bag (instance (Bag String Char)
  size (macro [string]
    (: (Fn String Num))
    (Js.access string "length"))

  empty ""

  fold (fn [with initial string]
    (fold with initial (chars string)))

  join (macro [what with]
    (: (Fn String String String))
    (Js.binary "+" what with))

  filter (fn [with what]
    (unchars (filter with (chars what)))))

string-map (instance (Map String Num Char)
  at (fn [index in]
    (from-nullable (.charAt in index)))

  key? (fn [what in]
    (between? 0 (size in) what))

  put (fn [at what in]
    (concat {(take at in) (singleton what) (drop (+ 1 at) in)}))

  delete (fn [key from]
    (concat {(take key from) (drop (+ 1 key) from)}))

  fold-keys (fn [with initial over]
    (fold with initial (range 0 (size over)))))

string-seq (instance (Seq String Char)
  first (fn [string]
    (at 0 string))

  rest (fn [list]
    (drop 1 list))

  take (fn [n from]
    (.slice from 0 (max 0 n)))

  drop (fn [n from]
    (.slice from (max 0 n))))

string-deq (instance (Deq String Char)
  && (macro [what to]
    (: (Fn Num Char String String))
    (Js.binary "+" to what))

  but-last (fn [string]
    (take (- 1 (size string)) string))

  last (fn [string]
    (at (- 1 (size string)) string)))

array-to-set (macro [collection]
  (: (Fn (Array a) (Set a)))
  (Js.method collection "toSet" {}))

to-set (fn [collection]
  (array-to-set (fold && {} collection)))

slice (fn [from to of]
  (take (- from to) (drop from of)))

sub-seq (fn [from n of]
  (take n (drop from of)))

concat (fn [bag-of-bags]
  (: (Fn bba ba) (Bag bba ba) (Bag ba a))
  (# (fold (flip join) empty bag-of-bags))
  (if (and (:: Bool (.-first bag-of-bags))
      (:: Bool (.Iterable.isIterable global.Immutable (.first bag-of-bags))))
    (:: bba (.apply (.-concat (.first bag-of-bags)) (.first bag-of-bags) (.toArray (.rest bag-of-bags))))
    (fold (flip join) empty bag-of-bags)))

empty? (fn [collection]
  (= 0 (size collection)))

not-elem? (fn [what in]
  (not (elem? what in)))

element-array (macro [set]
  (: (Fn (Set a) (Array a)))
  (Js.call (Js.access set "toList") {}))

value-array (macro [map]
  (: (Fn (Map k v) (Array v)))
  (Js.call (Js.access map "toList") {}))

entry-array (macro [map]
  (: (Fn (Map k v) (Array [k v])))
  (Js.call (Js.access
      (Js.call (Js.access map "entrySeq") {}) "toList") {}))

concat-map (fn [what over]
  (: (Fn (Fn a bb) (m a) bb) (Bag (m bb) bb) (Bag bb b) (Mappable m))
  (concat (map what over)))

repeat (fn [times what]
  (map (const what) (range 0 times)))

concat-repeat (fn [times what]
  (concat (repeat times what)))

concat-with (fn [with what]
  (from-? empty (fold join-with None what))
  join-with (fn [x maybe-joined]
    (Some (match maybe-joined
        None x
        (Some joined) (concat {joined with x})))))

map-into (fn [what into over]
  (fold-right append into over)
  append (fn [x to]
    (& (what x) to)))

zip-into (fn [with into left right]
  (if (or (empty? left) (empty? right))
    into
    (& (with (!! (first left)) (!! (first right)))
      (zip-into with into (rest left) (rest right)))))

parse-int (fn [string]
  (: (Fn String Num))
  (.parseInt (global) string))

num-to-string (fn [n]
  (format "%n" n))

combine (fn [first second]
  (concat-map (zip tuple first) (map (repeat (size first)) second)))

unique (fn [bag]
  (: (Fn ba ba) (Appendable ba a) (Bag ba a))
  (fold & empty (to-set bag)))

singleton (fn [x]
  (: (Fn a ba) (Appendable ba a) (Bag ba a))
  (& x empty))

split (fn [bag]
  (: (Fn ba (Array ba)) (Appendable ba a) (Bag ba a))
  (fold wrap {} bag)
  wrap (fn [x all]
    (&& (singleton x) all)))

break-on (fn [on seq]
  (: (Fn (Fn a Bool) seq [seq seq]) (Seq seq a))
  (# Not implemented!
    (if (empty? seq)
      [seq seq]
      (if (on x)
        [empty seq]
        [(& x fails) rest]))
    [fails rest] (break-on on xs)
    x (!! (first seq))
    xs (rest seq))
  [seq seq])

split-on (macro [separator string]
  (: (Fn String String (Array String)))
  (Js.call "Immutable.List" {(Js.method string "split" {separator})}))

fold-right (fn [with initial over]
  ((fold wrap id over) initial)
  wrap (fn [x r acc]
    (r (with x acc))))

reduce (fn [with over]
  (fold helper None over)
  helper (fn [x acc]
    (match acc
      None (Some x)
      (Some val) (Some (with x val)))))

array-show (instance (Show (Array a))
  {(Show a)}
  show (fn [array]
    (format "{%s}" (concat-with " " (map show array)))))

list-show (instance (Show (List a))
  {(Show a)}
  show (fn [list]
    (format "(List %s)" (concat-with " " (map show list)))))

set-show (instance (Show (Set a))
  {(Show a)}
  show (fn [set]
    (format "(Set %s)" (concat-with " " (map show (element-array set))))))

map-show (instance (Show (Map k v))
  {(Show k) (Show v)}
  show (fn [mapping]
    (format "(Map %s)" (concat-with " " (map show-entry (entry-array mapping))))
    show-entry (fn [entry]
      (format "%s %s" (show key) (show value))
      [key value] entry)))

sum (fold + 0)

product (fold * 1)

maximum (reduce max)

minimum (reduce min)

all (fold and True)

any (fold or False)

all-map (fn [fun list]
  (all ((map fun) list)))

any-map (fn [fun list]
  (any ((map fun) list)))

char-from-code (fn [x]
  (: (Fn Num Char))
  (.fromCharCode global.String x))

code-from-char (fn [x]
  (: (Fn Char Num))
  (.charCodeAt x 0))

char-ord (instance (Ord Char)
  <= (fn [than what]
    (<= (code-from-char than) (code-from-char what))))

in-range (fn [from exlude-to what]
  (and (<= what from) (< exlude-to what)))

in-range-inclusively (fn [from to what]
  (and (<= what from) (<= to what)))

scan (fn [what initial over]
  (: (Fn (Fn a b b) b (m a) (m b)) (Bag (m a) a) (Deq (m b) b))
  (snd (fold adder [initial (&& initial empty)] over))
  adder (fn [x acc]
    [next (&& next scanned)]
    next (what x folded)
    [folded scanned] acc))

scan-into (fn [what initial into over]
  (snd (fold adder [initial (&& initial into)] over))
  adder (fn [x acc]
    [next (&& next scanned)]
    next (what x folded)
    [folded scanned] acc))

reapply (fn [what initial times]
  (# Applies what times starting with initial returning the last result.)
  (match times
    0 initial
    else (reapply what (what initial) (- 1 times))))

iterate (fn [what initial times]
  (# Applies what times starting with initial returning a list of the results.)
  (take times (scan (const what) initial (range 0 (- 1 times)))))

until (fn [what next initial]
  (# Applies next until what returns True , starting with initial .)
  (if (what initial)
    initial
    (until what next (next initial))))

?-mappable (instance (Mappable ?)
  map (fn [what over]
    (match over
      (Some value) (Some (what value))
      None None)))

?-zippable (instance (Zippable ?)
  zip (fn [what x y]
    (match [x y]
      [(Some a) (Some b)] (Some (what a b))
      _ None)))

Liftable (class [c]
  {(Mappable c)}
  lift (fn [x] (: (Fn a (c a))))
  apply (fn [what to] (: (Fn (c (Fn a b)) (c a) (c b)))))

Chainable (class [m]
  {(Liftable m)}
  chain (fn [wrapped through] (: (Fn (m a) (Fn a (m b)) (m b)))))

follow (fn [first-wrapped second-wrapped]
  (chain first-wrapped (fn [_]
      second-wrapped)))

do (syntax [..actions]
  (# Takes a list of Chainable values or bindings and chains them.
    Bindings have the form:
    (set pattern chainable-value)
    The result of chainable-value is bound to the pattern, then
    the rest of the arguments are chained. If a chainable value
    is not bound, its result is ignored.)
  (match actions
    {x} x
    {x ..xs} (match x
      (` set ,to ,what) (` chain ,what (fn [_do_pattern]
          (match _do_pattern
            ,to (do ,..xs))))
      _ (` follow ,x (do ,..xs)))))

Void (data Void)

Io (data [a] Io [content: (Fn a)])

run-io (fn [wrapped] ((Io-content wrapped)))

exec-io (fn [wrapped]
  (const Void (run-io wrapped)))

chain-io (fn [wrapped through]
  (Io (fn [] (run-io (through (run-io wrapped))))))

io-mappable (instance (Mappable Io)
  map (fn [what over]
    (chain-io over
      (fn [x] (Io (fn [] (what x)))))))

io-liftable (instance (Liftable Io)
  lift (fn [x] (Io (fn [] x)))
  apply (fn [what to]
    (chain-io what (fn [unwrapped-what]
        (chain-io to (fn [unwrapped-to]
            (Io (fn [] (unwrapped-what unwrapped-to)))))))))

io-chainable (instance (Chainable Io)
  chain chain-io)

io (syntax [expression]
  (` Io (fn [] ,expression)))

random (io (:: Num (.random global.Math)))

random-int (fn [from exclude-to]
  (do
    (set p random)
    (lift (floor (+ from (* (- from exclude-to) p))))))

-> (syntax [..args]
  (# Given:
    (-> x f g h)
    returns:
    (h (g (f x))))
  (match args
    {x} x
    {x f ..fs} (` -> (,f ,x) ,..fs)))

'''
]
