#!/usr/bin/env node
'use strict'

// Regression tests for Calculator.js — plain node, no QML host needed:
//
//   node test/calculator.test.js
//
// Calculator.js is a QML .pragma library module; the harness strips that line
// and evaluates the rest in a vm sandbox, which is how a QML engine loads it.
// Assertions are made against the display string the menu row would show, and
// — for the exponent-notation branches — against the number that string
// denotes, which must be the value the parser actually computed.

const fs = require('fs')
const path = require('path')
const vm = require('vm')

let source = fs.readFileSync(path.join(__dirname, '..', 'Calculator.js'), 'utf8')
source = source.replace(/^\.pragma library\s*/, '')

const sandbox = {}
vm.createContext(sandbox)
vm.runInContext(source, sandbox, { filename: 'Calculator.js' })

let checks = 0
let failures = 0

function check(what, actual, expected) {
  checks++
  if (actual === expected) return
  failures++
  console.error(`FAIL: ${what}\n  expected: ${JSON.stringify(expected)}\n  actual:   ${JSON.stringify(actual)}`)
}

function display(expr) {
  const result = sandbox.evaluate(expr)
  return result === null ? null : result.display
}

// ---- W1: whole-number answers must never be rounded into a different number

check('1000000000000+1 displays the computed answer', display('1000000000000+1'), '1000000000001')
check('123456789012345+1 displays the computed answer', display('123456789012345+1'), '123456789012346')

// 9007199254740993 is not representable in a double: it parses as 2^53, so the
// true computed answer is 2^53 - 1 = 9007199254740991, shown in the >= 1e15
// exponential branch — but showing it, not a 7-digit lookalike.
check('the literal 9007199254740993 parses as 2^53',
  sandbox.tokenize('9007199254740993')[0].value, 9007199254740992)
const big = sandbox.evaluate('9007199254740993-1')
check('9007199254740993-1 computes 2^53-1', big.value, 9007199254740991)
check('9007199254740993-1 displays the true value', big.display, '9.007199254740991e15')
check('9007199254740993-1 display equals the computed value', Number(big.display), big.value)

check('1e15+23456789012 displays the true value', display('1e15+23456789012'), '1.000023456789012e15')
check('1e15+23456789012 display equals the computed value',
  Number(display('1e15+23456789012')), sandbox.evaluate('1e15+23456789012').value)

// The whole-number invariant: whenever the computed value is an integer, what
// is displayed must denote exactly that value — nothing silently rounded.
for (const expr of [
  '2^53', '2^53-1', '2^62', '1e15+0', '1e15+1', '1e15+23456789012',
  '123456789012345+1', '9007199254740992-1', '0xffffffff+1',
  '0xffffffffffffffff+1', '1e21*2', '1234567890123456+1'
]) {
  const r = sandbox.evaluate(expr)
  check(`${expr} produces a row`, r !== null, true)
  check(`${expr} computes a whole number`, Number.isInteger(r.value), true)
  check(`${expr} display equals the computed value`, Number(r.display), r.value)
}

// ---- W2: the >= 1e15 / < 1e-9 branches honor the twelve-digit promise ------

check('0.000000000123456789*1 keeps its digits in the small branch',
  display('0.000000000123456789*1'), '1.23456789e-10')

// ---- accepted behavior: 0.1+0.2 still reads 0.3 ----------------------------

check('0.1+0.2 reads 0.3', display('0.1+0.2'), '0.3')

// ---- fractions keep the twelve-digit display policy ------------------------

check('10/3 keeps twelve digits', display('10/3'), '3.33333333333')
check('pi*2 keeps twelve digits', display('pi*2'), '6.28318530718')

// ---- every README usage-table example, verbatim ----------------------------

const readmeTable = [
  ['4+4', '8'], ['10-3', '7'], ['6*7', '42'], ['10/4', '2.5'],
  ['1250*1.21', '1512.5'],
  ['2^10', '1024'], ['2**8', '256'],
  ['(2+3)*4', '20'],
  ['10%3', '1'],
  ['20%', '0.2'], ['50%*2', '1'],
  ['sqrt(144)+2^5', '44'],
  ['round(2.5)', '3'], ['min(3,9,2)', '2'],
  ['pi*2', '6.28318530718'], ['ln(e)', '1'],
  ['0x1f+1', '32'], ['0b1010*2', '20'], ['1e3+1', '1001'],
  ['2×3', '6'], ['10÷4', '2.5']
]
for (const [expr, expected] of readmeTable) {
  check(`README: ${expr} -> ${expected}`, display(expr), expected)
}

// ---- non-finite results produce no row at all ------------------------------

for (const expr of ['1/0', '1e309*2', '9e999+0', '0/0', 'sqrt(-1)', 'mod(1,0)', '1/(-0)']) {
  check(`${expr} produces no row`, display(expr), null)
}

// ---- trimExponent output shapes are unchanged ------------------------------

check('trimExponent trims "1.000000e+15"', sandbox.trimExponent('1.000000e+15'), '1e15')
check('trimExponent trims "1.050000e+5"', sandbox.trimExponent('1.050000e+5'), '1.05e5')
check('trimExponent trims "3.000000e-7"', sandbox.trimExponent('3.000000e-7'), '3e-7')
check('trimExponent keeps "1.234567e-70"', sandbox.trimExponent('1.234567e-70'), '1.234567e-70')

// ---- a bare number is still a search, not a calculation --------------------

for (const expr of ['42', '3.14', '-5', '0xff', '1e3', 'pi', '', '   ']) {
  check(`"${expr}" produces no row`, display(expr), null)
}

// ---- summary ---------------------------------------------------------------

if (failures > 0) {
  console.error(`\n${failures} of ${checks} checks failed`)
  process.exit(1)
}
console.log(`ok — ${checks} checks passed`)
