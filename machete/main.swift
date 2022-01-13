//
//  main.swift
//  
//  
//  Created by Masahiro Oono on 2021/12/13
//  
//

import Foundation

extension String {
  subscript(offset: Int) -> Character {
    self[index(startIndex, offsetBy: offset)]
  }
}

extension Character {
  var ascii: Int { Int(asciiValue!) }
}

extension Character {
  var isAlphabet: Bool {
    "a"..."z" ~= self || "A"..."Z" ~= self || "_" == self
  }

  var isNumber: Bool {
    "0"..."9" ~= self
  }
}

struct Token {
  let str: String
  let len: Int

  init(str: String, len: Int) {
    self.str = str
    self.len = len
  }

  init(_ str: String) {
    self.init(str: str, len: str.count)
  }
}

extension Token: Equatable {
  static func ==(lhs: Token, rhs: Token) -> Bool {
    lhs.len == rhs.len && lhs.str == rhs.str
  }
}

extension Token: CustomStringConvertible {
  var description: String { str }
}

class Lexer {
  enum Error: Swift.Error {
    case invalidCharacter(Character)
  }

  private var input = "" {
    didSet {
      pos = input.startIndex
    }
  }
  private lazy var pos = input.startIndex

  private func peek() -> Character? {
    guard pos < input.endIndex else {
      return nil
    }
    return input[pos]
  }

  private func addvance() {
    assert(pos < input.endIndex, "Cannot advance past endIndex")
    pos = input.index(after: pos)
  }

  func lex(_ input: String, _ allocTokenCode: (Int, String, Int) throws -> ()) throws -> Int {
    self.input = input

    var nTokens = 0
    while let ch = peek() {
      if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
        addvance()
        continue
      }

      var (start, len) = (pos, 0)

      if "(){}[];,".contains(ch) {
        addvance()
        len = 1
      }
      else if ch.isAlphabet || ch.isNumber {
        while let ch = peek(), ch.isAlphabet || ch.isNumber {
          addvance()
          len += 1
        }
      }
      else if "=+-*/!%&~|<>?:.#".contains(ch) {
        while let ch = peek(), "=+-*/!%&~|<>?:.#".contains(ch) {
          addvance()
          len += 1
        }
      }
      else {
        throw Lexer.Error.invalidCharacter(ch)
      }

      let beforeEnd = input.index(start, offsetBy: len - 1)
      try allocTokenCode(nTokens, "\(input[start...beforeEnd])", len)
      nTokens += 1
    }
    return nTokens
  }
}

enum Key: Int, CaseIterable {
  case WildCard

  case Equal
  case NotEq
  case Les
  case GtrEq
  case LesEq
  case Gtr
  case Plus
  case Minus
  case Period
  case Semicolon

  case Assign

  case Lparen
  case Rparen
  case Colon

  case Zero
  case One
  case Two
  case Three
  case Four
  case Five
  case Six
  case Seven
  case Eight
  case Nine

  case Print
  case If
  case Goto
  case Time

  func getToken() -> Token {
    switch self {
    case .WildCard: return Token("!!*")

    case .Equal: return Token("==")
    case .NotEq: return Token("!=")
    case .Les: return Token("<")
    case .GtrEq: return Token(">=")
    case .LesEq: return Token("<=")
    case .Gtr: return Token(">")
    case .Plus: return Token("+")
    case .Minus: return Token("-")
    case .Period: return Token(".")
    case .Semicolon: return Token(";")

    case .Assign: return Token("=")

    case .Lparen: return Token("(")
    case .Rparen: return Token(")")
    case .Colon: return Token(":")

    case .Zero: return Token("0")
    case .One: return Token("1")
    case .Two: return Token("2")
    case .Three: return Token("3")
    case .Four: return Token("4")
    case .Five: return Token("5")
    case .Six: return Token("6")
    case .Seven: return Token("7")
    case .Eight: return Token("8")
    case .Nine: return Token("9")

    case .Print: return Token("print")
    case .If: return Token("if")
    case .Goto: return Token("goto")
    case .Time: return Token("time")
    }
  }
}

extension String {
  func compare(_ phrCmp: (Int, String, Int) -> Bool , id: Int, beginning offset: Int) -> Bool {
    phrCmp(id, self, offset)
  }
}

enum Opcode: Int {
  case OpCpy
  case OpAdd
  case OpSub
  case OpGoto
  case OpJeq
  case OpJne
  case OpJlt
  case OpJge
  case OpJle
  case OpJgt
  case OpPrint
  case OpTime
  case OpEnd
}

typealias IntPtr = UnsafeMutablePointer<Int>?

class InternalCodePointer {
  var ptr: UnsafeMutablePointer<IntPtr>

  init(_ ptr: UnsafeMutablePointer<IntPtr>) {
    self.ptr = ptr
  }

  subscript(offset: Int) -> IntPtr {
    get {
      ptr[offset]
    }
    set {
      ptr[offset] = newValue
    }
  }

  static func +=(icp: InternalCodePointer, offset: Int) {
    icp.ptr += offset
  }

  static func -=(icp: InternalCodePointer, offset: Int) {
    icp.ptr -= offset
  }
}

public class Machete {
  enum Error: Swift.Error {
    case syntaxError(String)
  }

  public var text = ""
  let maxTokenCodes = 1000
  let maxPhraseLen = 31
  let wpcLen = 9
  let maxInternalCodes = 10000
  let lexer = Lexer()
  var vars, tc, phraseTc, wpc: UnsafeMutablePointer<Int>
  var nextPc = 0
  var internalCodes: UnsafeMutablePointer<IntPtr>
  lazy var icp = InternalCodePointer(internalCodes)
  lazy var tokens = [Token?](repeating: nil, count: maxTokenCodes)
  private var lastAllocatedCode = -1

  public init() {
    vars = UnsafeMutablePointer<Int>.allocate(capacity: maxTokenCodes)
    vars.initialize(repeating: 0, count: maxTokenCodes)

    tc = UnsafeMutablePointer<Int>.allocate(capacity: maxTokenCodes)
    tc.initialize(repeating: -1, count: maxTokenCodes)

    phraseTc = UnsafeMutablePointer<Int>.allocate(capacity: (maxPhraseLen + 1) * 100)
    phraseTc.initialize(repeating: -1, count: (maxPhraseLen + 1) * 100)

    wpc = UnsafeMutablePointer<Int>.allocate(capacity: wpcLen)
    wpc.initialize(repeating: 0, count: wpcLen)

    internalCodes = UnsafeMutablePointer<IntPtr>.allocate(capacity: maxInternalCodes)
    internalCodes.initialize(repeating: nil, count: maxInternalCodes)

    for token in Key.allCases.map({ $0.getToken() }) {
      _ = getTokenCode(token)
    }
  }

  deinit {
    vars.deinitialize(count: maxTokenCodes)
    vars.deallocate()

    tc.deinitialize(count: maxTokenCodes)
    tc.deallocate()

    phraseTc.deinitialize(count: (maxPhraseLen + 1) * 100)
    phraseTc.deallocate()

    wpc.deinitialize(count: wpcLen)
    wpc.deallocate()

    internalCodes.deinitialize(count: maxInternalCodes)
    internalCodes.deallocate()
  }

  public func loadText(path: String) {
    let start = path.first == "\"" ? path.index(after: path.startIndex) : path.startIndex
    let end = path[start..<path.endIndex].firstIndex(of: "\"") ?? path.endIndex
    do {
      text = try String(contentsOf: URL(fileURLWithPath: "\(path[start..<end])"))
    }
    catch {
      print("Failed to open \(path[start..<end])")
      exit(1)
    }
  }

  func getTokenCode(_ token: Token) -> Int {
    if let foundCode = tokens.indices.filter({ tokens[$0] == token }).first {
      return foundCode
    }
    precondition(lastAllocatedCode < maxTokenCodes, "Too many tokens")
    lastAllocatedCode += 1
    vars[lastAllocatedCode] = Int(token.str) ?? 0
    tokens[lastAllocatedCode] = token
    return lastAllocatedCode
  }

  func getTokenCode(_ str: String, len: Int? = nil) -> Int {
    let token = Token(str: str, len: len ?? str.count)
    return getTokenCode(token)
  }

  func phrCmp(id: Int, phrase: String, offset: Int) -> Bool {
    let (tc, phraseTc, wpc) = (tc, phraseTc, wpc)

    let head = id * (maxPhraseLen + 1)
    var phraseLen: Int
    if phraseTc[head + maxPhraseLen] == -1 {
      phraseLen = try! lexer.lex(phrase) { i, str, len in
        phraseTc[head + i] = getTokenCode(str, len: len)
      }
      assert(phraseLen <= maxPhraseLen, "Phrase too long")
      phraseTc[head + maxPhraseLen] = phraseLen
    }

    phraseLen = phraseTc[head + maxPhraseLen]
    var pc = offset
    var i = 0
    while i < phraseLen {
      if phraseTc[head + i] == Key.WildCard.rawValue {
        i += 1
        wpc[ phraseTc[head + i] - Key.Zero.rawValue ] = pc
        i += 1
        pc += 1
        continue
      }
      if phraseTc[head + i] != tc[pc] {
        return false
      }
      i += 1
      pc += 1
    }
    nextPc = pc
    return true
  }

  func putIc(_ op: Opcode, _ p1: IntPtr, _ p2: IntPtr, _ p3: IntPtr, _ p4: IntPtr) {
    icp[0] = UnsafeMutablePointer<Int>.init(bitPattern: op.rawValue)!
    icp[1] = p1
    icp[2] = p2
    icp[3] = p3
    icp[4] = p4
    icp += 5
  }

  func exec() throws {
    let begin = clock()

    let tc = tc
    var nTokens = try lexer.lex(text) { i, str, len in
      tc[i] = getTokenCode(str, len: len)
    }
    tc[nTokens] = Key.Semicolon.rawValue // 末尾に「;」を付け忘れることが多いので、付けてあげる
    nTokens += 1

    let f = phrCmp
    icp = InternalCodePointer(internalCodes)

    var pc = 0
    while pc < nTokens {
      if "!!*0 = !!*1;".compare(f, id: 1, beginning: pc) { // 単純代入
        putIc(.OpCpy, vars + tc[wpc[0]], vars + tc[wpc[1]], nil, nil)
      }
      else if "!!*0 = !!*1 + !!*2;".compare(f, id: 2, beginning: pc) { // 加算
        putIc(.OpAdd, vars + tc[wpc[0]], vars + tc[wpc[1]], vars + tc[wpc[2]], nil)
      }
      else if "!!*0 = !!*1 - !!*2;".compare(f, id: 3, beginning: pc) { // 減算
        putIc(.OpSub, vars + tc[wpc[0]], vars + tc[wpc[1]], vars + tc[wpc[2]], nil)
      }
      else if "print !!*0;".compare(f, id: 4, beginning: pc) { // print
        putIc(.OpPrint, vars + tc[wpc[0]], nil, nil, nil)
      }
      else if "!!*0:".compare(f, id: 0, beginning: pc) { // ラベル定義命令
        #warning("Set the relative position of the label")
      }
      else if "goto !!*0;".compare(f, id: 5, beginning: pc) { // goto
        putIc(.OpGoto, vars + tc[wpc[0]], nil, nil, nil)
      }
      else if "if (!!*0 !!*1 !!*2) goto !!*3;".compare(f, id: 6, beginning: pc) && Key.Equal.rawValue <= tc[wpc[1]] && tc[wpc[1]] <= Key.Gtr.rawValue { // if...goto
        let op = Opcode(rawValue: Opcode.OpJeq.rawValue + tc[wpc[1]] - Key.Equal.rawValue)!
        putIc(op, vars + tc[wpc[3]], vars + tc[wpc[0]], vars + tc[wpc[2]], nil)
      }
      else if "time;".compare(f, id: 7, beginning: pc) {
        putIc(.OpTime, nil, nil, nil, nil)
      }
      else if ";".compare(f, id: 8, beginning: pc) {
        // 何もしない
      }
      else {
        throw Machete.Error.syntaxError("\(tokens[tc[pc]]!)")
      }
      pc = nextPc
    }
    putIc(.OpEnd, nil, nil, nil, nil)

    #warning("Specify the jump destination")
  }

  public func run() {
    do {
      try exec()
    }
    catch Lexer.Error.invalidCharacter(let ch) {
      print("Input contained an invalid character: \(ch)")
    }
    catch Machete.Error.syntaxError(let token) {
      print("Syntax error: \(token)")
    }
    catch {
      print("An error occurred: \(error)")
    }
  }

  public func runRepl(prompt: String, handleCommand: (String) -> Bool) {
    var nLines = 1
    while true {
      print(String(format: prompt, nLines), terminator: "")
      fflush(stdout)
      if let line = readLine(), !handleCommand(line) {
        break
      }
      run()
      nLines += 1
    }
  }
}

let machete = Machete()
let args = CommandLine.arguments
if args.count >= 2 {
  machete.loadText(path: args[1])
  machete.run()
}
else {
  machete.runRepl(prompt: "(%d)> ") { input in
    if input == "exit" {
      return false
    }

    if input.hasPrefix("run ") {
      let start = input.index(input.startIndex, offsetBy: 4)
      machete.loadText(path: "\(input[start..<input.endIndex])")
    }
    else {
      machete.text = input
    }
    return true
  }
}
