import Foundation

fileprivate let whitespace = Data("\r\n ".utf8)

fileprivate enum SourceCharacters: UInt8 {
    case stringQuote = 0x22
    case and = 0x26
    case leftParenthesis = 0x28
    case rightParenthesis = 0x29
    case multiply = 0x2a
    case plus = 0x2b
    case comma = 0x2c
    case minus = 0x2d
    case dot = 0x2e
    case divide = 0x2f
    case less = 0x3c
    case equal = 0x3d
    case greater = 0x3e
    case codeBlockOpen = 0x7b
    case pipe = 0x7c
    case codeBlockClose = 0x7d
    
    static let all = Data([
        SourceCharacters.stringQuote.rawValue,
        SourceCharacters.and.rawValue,
        SourceCharacters.leftParenthesis.rawValue,
        SourceCharacters.rightParenthesis.rawValue,
        SourceCharacters.multiply.rawValue,
        SourceCharacters.plus.rawValue,
        SourceCharacters.comma.rawValue,
        SourceCharacters.minus.rawValue,
        SourceCharacters.dot.rawValue,
        SourceCharacters.divide.rawValue,
        SourceCharacters.less.rawValue,
        SourceCharacters.equal.rawValue,
        SourceCharacters.greater.rawValue,
        SourceCharacters.codeBlockOpen.rawValue,
        SourceCharacters.codeBlockClose.rawValue,
    ])
}

fileprivate let specialCharacters = whitespace + SourceCharacters.all

extension SourceFile {
    func skipWhitespace() {
        while position < data.count {
            guard whitespace.contains(data[position]) else {
                return
            }
            
            position = position &+ 1
        }
    }
    
    func scanWord() {
        
    }
    
    public func parse() {
        while position < data.count {
            skipWhitespace()
            
            guard position < data.count else {
                return
            }
            
            switch data[position] {
            default:
                scanWord()
            }
        }
    }
}
