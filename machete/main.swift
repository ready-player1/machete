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

class Machete {
  enum Error: Swift.Error {
    case syntaxError(Character)
  }

  var text = """
     a=1;
     b=2;
     c=a+b;
     print c;
     """
  var vars = [Int](repeating: 0, count: 256) // 変数

  func run() throws {
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
catch Machete.Error.syntaxError(let token) {
  print("Syntax error: \(token)")
}
catch {
  print("An error occurred: \(error)")
}
