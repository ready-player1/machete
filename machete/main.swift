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
      let tokenCode = 0
      #warning("TODO: Receive a token code from a closure")
      tokenCodes.append(tokenCode)
    }
    return tokenCodes
  }
}

class Machete {
  enum Error: Swift.Error {
    case syntaxError(Character)
  }

  var text = ""
  private let maxTokenCodes = 1000
  private lazy var vars = [Int](repeating: 0, count: maxTokenCodes) // 変数
  private lazy var tokens = [Token?](repeating: nil, count: maxTokenCodes)

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

  #warning("TODO: Implement the getTokenCode method")

  func run() throws {
    let args = CommandLine.arguments
    loadText(args)

    for c in [UInt8]("0123456789".utf8) {
      vars[Int(c)] = Int(c) - 48
    }

    text += "\u{0000}"
    var pc = 0
    while text[pc] != "\u{0000}" {
      if text[pc] == "\n" || text[pc] == "\r" || text[pc] == " " || text[pc] == "\t" || text[pc] == ";" {
        pc += 1
        continue
      }

      if text[pc + 1] == "=" && text[pc + 3] == ";" { // 単純代入
        vars[text[pc].ascii] = vars[text[pc + 2].ascii]
      }
      else if text[pc + 1] == "=" && text[pc + 3] == "+" && text[pc + 5] == ";" { // 加算
        vars[text[pc].ascii] = vars[text[pc + 2].ascii] + vars[text[pc + 4].ascii]
      }
      else if text[pc + 1] == "=" && text[pc + 3] == "-" && text[pc + 5] == ";" { // 減算
        vars[text[pc].ascii] = vars[text[pc + 2].ascii] - vars[text[pc + 4].ascii]
      }
      else if text[pc] == "p" && text[pc + 1] == "r" && text[pc + 5] == " " && text[pc + 7] == ";" { // 最初の2文字しか調べていない（手抜き）
        print("\(vars[text[pc + 6].ascii])")
      }
      else {
        throw Machete.Error.syntaxError(text[pc])
      }

      while text[pc] != ";" {
        pc += 1
      }
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
