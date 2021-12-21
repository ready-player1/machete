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

  func lex(_ input: String, _ getTokenCode: (String, Int?) -> Int) throws -> [Int] {
    self.input = input
    var tokenCodes = [Int]()

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
      let tokenCode = getTokenCode("\(input[start...beforeEnd])", len)
      tokenCodes.append(tokenCode)
    }
    return tokenCodes
  }
}

class Machete {
  enum Error: Swift.Error {
    case syntaxError(String)
  }

  var text = ""
  private let maxTokenCodes = 1000
  private let lexer = Lexer()
  private var vars: UnsafeMutablePointer<Int> // 変数
  private lazy var tokens = [Token?](repeating: nil, count: maxTokenCodes)
  private var lastAllocatedCode = -1

  init() {
    vars = UnsafeMutablePointer<Int>.allocate(capacity: maxTokenCodes)
    vars.initialize(repeating: 0, count: maxTokenCodes)
  }

  deinit {
    vars.deinitialize(count: maxTokenCodes)
    vars.deallocate()
  }

  func loadText(_ args: [String]) {
    if args.count < 2 {
      print("Usage: \((args[0] as NSString).lastPathComponent) program-file")
      exit(1)
    }

    do {
      text = try String(contentsOf: URL(fileURLWithPath: args[1]))
    }
    catch {
      print("Failed to open \(args[1])")
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

  func run() throws {
    let args = CommandLine.arguments
    loadText(args)

    var tc = try lexer.lex(text, getTokenCode)

    let equal     = getTokenCode("==")
    let notEq     = getTokenCode("!=")
    let les       = getTokenCode("<")
    let gtrEq     = getTokenCode(">=")
    let lesEq     = getTokenCode("<=")
    let gtr       = getTokenCode(">")
    let colon     = getTokenCode(":")
    let lparen    = getTokenCode("(")
    let rparen    = getTokenCode(")")
    let plus      = getTokenCode("+")
    let minus     = getTokenCode("-")
    let assign    = getTokenCode("=")
    let semicolon = getTokenCode(";")
    let _print    = getTokenCode("print")
    let _if       = getTokenCode("if")
    let goto      = getTokenCode("goto")
    let time      = getTokenCode("time")

    let endIndex = tc.endIndex
    tc += [Int](repeating: -1, count: 8) // エラー表示用
    var pc = 0
    while pc < endIndex - 1 { // ラベル定義命令を探して位置を登録
      if tc[pc + 1] == colon {
        vars[tc[pc]] = pc + 2; // ラベル定義命令の次のpc値を変数に記録しておく
      }
      pc += 1
    }
    pc = 0
    while pc < endIndex {
      if tc[pc + 1] == assign && tc[pc + 3] == semicolon { // 単純代入
        vars[tc[pc]] = vars[tc[pc + 2]]
      }
      else if tc[pc + 1] == assign && tc[pc + 3] == plus && tc[pc + 5] == semicolon { // 加算
        vars[tc[pc]] = vars[tc[pc + 2]] + vars[tc[pc + 4]]
      }
      else if tc[pc + 1] == assign && tc[pc + 3] == minus && tc[pc + 5] == semicolon { // 減算
        vars[tc[pc]] = vars[tc[pc + 2]] - vars[tc[pc + 4]]
      }
      else if tc[pc] == _print && tc[pc + 2] == semicolon { // print
        print("\(vars[tc[pc + 1]])")
      }
      else if tc[pc + 1] == colon { // ラベル定義命令
        pc += 2 // 読み飛ばす
        continue
      }
      else if tc[pc] == goto && tc[pc + 2] == semicolon { // goto
        pc = vars[tc[pc + 1]];
        continue
      }
      else if (tc[pc] == _if && tc[pc + 1] == lparen && tc[pc + 5] == rparen &&
               tc[pc + 6] == goto && tc[pc + 8] == semicolon) { // if...goto
        let (lhs, op, rhs) = (vars[tc[pc + 2]], tc[pc + 3], vars[tc[pc + 4]])
        let dest = vars[tc[pc + 7]]

        if op == equal && lhs == rhs { pc = dest; continue }
        if op == notEq && lhs != rhs { pc = dest; continue }
        if op == les   && lhs <  rhs { pc = dest; continue }
        if op == gtrEq && lhs >= rhs { pc = dest; continue }
        if op == lesEq && lhs <= rhs { pc = dest; continue }
        if op == gtr   && lhs >  rhs { pc = dest; continue }
      }
      else if tc[pc] == time && tc[pc + 1] == semicolon {
        print(String(format: "time: %.3f[sec]", Double(clock()) / Double(CLOCKS_PER_SEC)))
      }
      else {
        throw Machete.Error.syntaxError("\(tokens[tc[pc]]!)")
      }

      while tc[pc] != semicolon {
        pc += 1
      }
      pc += 1
    }
  }
}

do {
  try Machete().run()
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
