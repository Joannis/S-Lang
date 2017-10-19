extension UInt8 {
    var isNumeric: Bool {
        return self >= 0x30 && self <= 0x39
    }
}

extension SourceFile {
    func consume(_ char: SourceCharacters) throws {
        guard data[position] == char.rawValue else {
            throw CompilerError.missingAssignment
        }
        
        position = position &+ 1
    }
    
    func isFunctionCall() -> Bool {
        return position < data.count && data[position] == SourceCharacters.leftParenthesis.rawValue
    }
}
