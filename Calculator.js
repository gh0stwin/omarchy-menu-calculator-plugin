.pragma library

// Arithmetic for the menu search field.
//
// Hand-rolled rather than handed to eval(): the string comes straight from a
// text field, and a parser that only knows numbers and math cannot be talked
// into running anything else. Anything it does not recognize is not an
// expression, and evaluate() answers null so the menu behaves as it always
// has.

var CONSTANTS = {
  "pi": Math.PI,
  "π": Math.PI,
  "tau": Math.PI * 2,
  "e": Math.E
}

// Arity -1 means variadic (at least one argument).
var FUNCTIONS = {
  "abs":   { arity: 1,  fn: function(x) { return Math.abs(x) } },
  "acos":  { arity: 1,  fn: function(x) { return Math.acos(x) } },
  "asin":  { arity: 1,  fn: function(x) { return Math.asin(x) } },
  "atan":  { arity: 1,  fn: function(x) { return Math.atan(x) } },
  "atan2": { arity: 2,  fn: function(y, x) { return Math.atan2(y, x) } },
  "cbrt":  { arity: 1,  fn: function(x) { return Math.cbrt(x) } },
  "ceil":  { arity: 1,  fn: function(x) { return Math.ceil(x) } },
  "cos":   { arity: 1,  fn: function(x) { return Math.cos(x) } },
  "exp":   { arity: 1,  fn: function(x) { return Math.exp(x) } },
  "floor": { arity: 1,  fn: function(x) { return Math.floor(x) } },
  "hypot": { arity: -1, fn: function() { return Math.hypot.apply(Math, arguments) } },
  "ln":    { arity: 1,  fn: function(x) { return Math.log(x) } },
  "log":   { arity: 1,  fn: function(x) { return Math.log10(x) } },
  "log2":  { arity: 1,  fn: function(x) { return Math.log2(x) } },
  "log10": { arity: 1,  fn: function(x) { return Math.log10(x) } },
  "max":   { arity: -1, fn: function() { return Math.max.apply(Math, arguments) } },
  "min":   { arity: -1, fn: function() { return Math.min.apply(Math, arguments) } },
  "mod":   { arity: 2,  fn: function(a, b) { return a % b } },
  "pow":   { arity: 2,  fn: function(a, b) { return Math.pow(a, b) } },
  "round": { arity: 1,  fn: function(x) { return Math.round(x) } },
  "sign":  { arity: 1,  fn: function(x) { return Math.sign(x) } },
  "sin":   { arity: 1,  fn: function(x) { return Math.sin(x) } },
  "sqrt":  { arity: 1,  fn: function(x) { return Math.sqrt(x) } },
  "tan":   { arity: 1,  fn: function(x) { return Math.tan(x) } },
  "trunc": { arity: 1,  fn: function(x) { return Math.trunc(x) } }
}

// The symbols a calculator app prints on its keys, mapped onto the ASCII the
// parser speaks: typing × or ÷ should work as well as * or /.
var OPERATOR_ALIASES = {
  "+": "+", "-": "-", "*": "*", "/": "/", "%": "%", "^": "^",
  "(": "(", ")": ")", ",": ",",
  "×": "*",  // ×
  "÷": "/",  // ÷
  "−": "-",  // −
  "⁄": "/",  // ⁄
  "·": "*"   // ·
}

var MAX_INPUT = 160

function isDigit(c) {
  return c >= "0" && c <= "9"
}

function isIdentifierChar(c) {
  return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_" || c === "π"
}

// ---------------------------------------------------------------- tokenizer

function readNumber(text, start) {
  var i = start
  var radixPrefix = text.substr(i, 2).toLowerCase()
  if (text.charAt(i) === "0" && (radixPrefix === "0x" || radixPrefix === "0b" || radixPrefix === "0o")) {
    var digits = radixPrefix === "0x" ? /[0-9a-fA-F]/ : (radixPrefix === "0b" ? /[01]/ : /[0-7]/)
    var j = i + 2
    while (j < text.length && digits.test(text.charAt(j))) j++
    if (j === i + 2) return null
    return { value: parseInt(text.slice(i + 2, j), radixPrefix === "0x" ? 16 : (radixPrefix === "0b" ? 2 : 8)), next: j }
  }

  while (i < text.length && isDigit(text.charAt(i))) i++
  if (text.charAt(i) === ".") {
    i++
    while (i < text.length && isDigit(text.charAt(i))) i++
  }
  // An exponent only counts when a signed number actually follows it, so the
  // e in "2e" stays an identifier and the whole thing fails to parse.
  if (text.charAt(i) === "e" || text.charAt(i) === "E") {
    var k = i + 1
    if (text.charAt(k) === "+" || text.charAt(k) === "-") k++
    if (k < text.length && isDigit(text.charAt(k))) {
      while (k < text.length && isDigit(text.charAt(k))) k++
      i = k
    }
  }

  var literal = text.slice(start, i)
  if (!literal || literal === ".") return null
  var value = parseFloat(literal)
  if (isNaN(value)) return null
  return { value: value, next: i }
}

function tokenize(input) {
  var text = String(input)
  var tokens = []
  var i = 0

  while (i < text.length) {
    var c = text.charAt(i)

    if (c === " " || c === "\t") { i++; continue }

    if (isDigit(c) || (c === "." && isDigit(text.charAt(i + 1)))) {
      var number = readNumber(text, i)
      if (!number) return null
      tokens.push({ type: "number", value: number.value })
      i = number.next
      continue
    }

    if (isIdentifierChar(c)) {
      var j = i
      while (j < text.length && (isIdentifierChar(text.charAt(j)) || isDigit(text.charAt(j)))) j++
      tokens.push({ type: "name", value: text.slice(i, j).toLowerCase() })
      i = j
      continue
    }

    if (c === "*" && text.charAt(i + 1) === "*") {
      tokens.push({ type: "op", value: "^" })
      i += 2
      continue
    }

    var op = OPERATOR_ALIASES[c]
    if (op) {
      tokens.push({ type: "op", value: op })
      i++
      continue
    }

    return null
  }

  return tokens
}

// ------------------------------------------------------------------- parser
//
// Ordinary precedence climbing: + - < * / % < unary - < ^ (right
// associative) < postfix % < primary. `state.operations` counts the moments
// that make the input a calculation rather than a number someone typed, and
// evaluate() insists on at least one of them.

function peek(state) {
  return state.pos < state.tokens.length ? state.tokens[state.pos] : null
}

function isOperator(token, value) {
  return !!token && token.type === "op" && token.value === value
}

function fail() {
  throw new Error("parse")
}

function startsOperand(token) {
  if (!token) return false
  if (token.type === "number" || token.type === "name") return true
  return token.type === "op" && (token.value === "(" || token.value === "-" || token.value === "+")
}

function parseExpression(state) {
  var value = parseTerm(state)

  while (true) {
    var token = peek(state)
    if (isOperator(token, "+") || isOperator(token, "-")) {
      state.pos++
      state.operations++
      var right = parseTerm(state)
      value = token.value === "+" ? value + right : value - right
      continue
    }
    return value
  }
}

function parseTerm(state) {
  var value = parseUnary(state)

  while (true) {
    var token = peek(state)
    if (isOperator(token, "*") || isOperator(token, "/")) {
      state.pos++
      state.operations++
      var right = parseUnary(state)
      value = token.value === "*" ? value * right : value / right
      continue
    }
    // A % with an operand after it is a remainder ("10 % 3"); one without is
    // a percentage, and parsePostfix has already folded it into the value.
    if (isOperator(token, "%") && startsOperand(state.tokens[state.pos + 1])) {
      state.pos++
      state.operations++
      value = value % parseUnary(state)
      continue
    }
    return value
  }
}

function parseUnary(state) {
  var token = peek(state)
  if (isOperator(token, "-")) {
    state.pos++
    return -parseUnary(state)
  }
  if (isOperator(token, "+")) {
    state.pos++
    return parseUnary(state)
  }
  return parsePower(state)
}

function parsePower(state) {
  var base = parsePostfix(state)
  if (isOperator(peek(state), "^")) {
    state.pos++
    state.operations++
    return Math.pow(base, parseUnary(state))
  }
  return base
}

function parsePostfix(state) {
  var value = parsePrimary(state)
  while (isOperator(peek(state), "%") && !startsOperand(state.tokens[state.pos + 1])) {
    state.pos++
    state.operations++
    value = value / 100
  }
  return value
}

function parsePrimary(state) {
  var token = peek(state)
  if (!token) fail()

  if (token.type === "number") {
    state.pos++
    return token.value
  }

  if (isOperator(token, "(")) {
    state.pos++
    state.operations++
    var inner = parseExpression(state)
    if (!isOperator(peek(state), ")")) fail()
    state.pos++
    return inner
  }

  if (token.type === "name") {
    state.pos++
    if (CONSTANTS.hasOwnProperty(token.value) && !isOperator(peek(state), "(")) return CONSTANTS[token.value]

    var spec = FUNCTIONS[token.value]
    if (!spec || !isOperator(peek(state), "(")) fail()
    state.pos++
    state.operations++

    var args = []
    if (!isOperator(peek(state), ")")) {
      args.push(parseExpression(state))
      while (isOperator(peek(state), ",")) {
        state.pos++
        args.push(parseExpression(state))
      }
    }
    if (!isOperator(peek(state), ")")) fail()
    state.pos++

    if (spec.arity === -1 ? args.length < 1 : args.length !== spec.arity) fail()
    return spec.fn.apply(null, args)
  }

  fail()
}

// ---------------------------------------------------------------- formatting

function trimExponent(text) {
  return String(text).replace(/\.?0+e/, "e").replace(/e\+?(-?)0*(\d)/, "e$1$2")
}

// Twelve significant digits is where binary floats stop agreeing with the
// arithmetic people expect (0.1 + 0.2 reads as 0.3), and still far more
// precision than a menu row is ever asked for. Rounding stays a display rule
// and never changes the answer: whole numbers climb until the printed digits
// are the computed value itself — seventeen significant digits round-trip any
// IEEE double — while fractions keep the twelve-digit look.
function formatValue(value) {
  if (typeof value !== "number" || !isFinite(value)) return null

  var p = 12
  if (Number.isInteger(value)) {
    while (p < 17 && Number(value.toPrecision(p)) !== value) p++
  }
  var rounded = Number(value.toPrecision(p))
  if (rounded === 0) return "0"

  var magnitude = Math.abs(rounded)
  if (magnitude >= 1e15 || magnitude < 1e-9) return trimExponent(rounded.toExponential(Math.max(p - 1, 6)))

  var text = String(rounded)
  return text.indexOf("e") >= 0 ? trimExponent(rounded.toExponential(Math.max(p - 1, 6))) : text
}

// ------------------------------------------------------------------- public

// Returns { display, expression, value } for something worth answering, and
// null for everything else — including a bare number, which is a search for
// "42", not a sum.
function evaluate(input) {
  var text = String(input || "").trim()
  if (!text || text.length > MAX_INPUT) return null

  var tokens = tokenize(text)
  if (!tokens || tokens.length === 0) return null

  var state = { tokens: tokens, pos: 0, operations: 0 }
  var value
  try {
    value = parseExpression(state)
  } catch (e) {
    return null
  }

  if (state.pos !== tokens.length) return null
  if (state.operations < 1) return null

  var display = formatValue(value)
  if (display === null) return null

  return { display: display, expression: text, value: value }
}
