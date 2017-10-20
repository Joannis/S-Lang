import LLVM

extension SourceFile {
    func scanAssignment(for type: LanguageType, scope: Scope) throws -> IRValue {
        try assertCharactersAfterWhitespace()
        
        try consume(SourceCharacters.equal)
        
        try assertCharactersAfterWhitespace()
        
        guard let literal = try scanLiteral(expecting: type, scope: scope) else {
            // TODO: Custom types
            throw CompilerError.unknownType(type.name)
        }
        
        state = .none
        
        return literal
    }
    
    func skipArguments() throws {
        while position < data.count {
            if data[position] == SourceCharacters.rightParenthesis.rawValue {
                try consume(.rightParenthesis)
                return
            }
            
            position = position &+ 1
        }
    }
    
    func skipValue() throws {
        _ = try scanNonEmptyString()
        
        if isFunctionCall() {
            try consume(.leftParenthesis)
            
            try skipArguments()
        }
    }
    
    func skipValueExpression() throws {
        try skipValue()
        
        while charactersBeforeNewline() {
            position = position &+ 1
            
            try assertCharactersAfterWhitespace()
            
            try skipValue()
        }
    }
    
    func skipStatement() throws {
        try assertCharactersAfterWhitespace()
        
        let name = try scanNonEmptyStringWithMember()
        try assertCharactersAfterWhitespace()
        
        if let reserved = ReservedFunction(rawValue: name) {
            try reserved.skip(in: self)
        } else if isFunctionCall() {
            try consume(.leftParenthesis)
            try skipArguments()
        } else if data[position] == SourceCharacters.dot.rawValue {
            try consume(.dot)
            _ = try scanNonEmptyString()
            
            if isFunctionCall() {
                try consume(.leftParenthesis)
                
                try skipArguments()
            }
        } else {
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            _ = try scanNonEmptyString()
            try assertCharactersAfterWhitespace()
            try consume(.equal)
            try assertCharactersAfterWhitespace()
            try skipValue()
        }
    }
    
    func enterCodeBlock() throws {
        try assertCharactersAfterWhitespace()
        
        try consume(.equal)
        
        try assertCharactersAfterWhitespace()
        
        try consume(.codeBlockOpen)
    }
    
    func skipCodeBlock() throws {
        try enterCodeBlock()
        
        while position < data.count {
            try assertCharactersAfterWhitespace()
            
            if data[position] == SourceCharacters.codeBlockClose.rawValue {
                position = position &+ 1
                state = .none
                return
            }
            
            try skipStatement()
        }
        
        throw CompilerError.unexpectedEOF
    }
}
