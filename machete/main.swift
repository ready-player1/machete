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

typealias Token = (str: String, len: Int)

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
  private lazy var vars = [Int](repeating: 0, count: maxTokenCodes) // 変数
  private lazy var tokens = [Token?](repeating: nil, count: maxTokenCodes)
  private var lastAllocatedCode = -1

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

  func getTokenCode(_ str: String, len: Int? = nil) -> Int {
    if let foundCode = tokens.indices.filter({ tokens[$0]?.str == str }).first {
      return foundCode
    }
    precondition(lastAllocatedCode < maxTokenCodes, "Too many tokens")
    lastAllocatedCode += 1
    vars[lastAllocatedCode] = Int(str) ?? 0
    tokens[lastAllocatedCode] = Token(str: str, len: len ?? str.count)
    return lastAllocatedCode
  }

  func run() throws {
    let args = CommandLine.arguments
    loadText(args)

    var tc = try lexer.lex(text, getTokenCode)

    let plus      = getTokenCode("+")
    let minus     = getTokenCode("-")
    let assign    = getTokenCode("=")
    let semicolon = getTokenCode(";")
    let _print    = getTokenCode("print")

    let endIndex = tc.endIndex
    tc += [Int](repeating: -1, count: 5) // エラー表示用
    var pc = 0
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
      else {
        throw Machete.Error.syntaxError(tokens[tc[pc]]!.str)
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
