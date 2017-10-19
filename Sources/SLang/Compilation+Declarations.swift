extension SourceFile {
    func scanDeclaration() throws -> Declaration {
        try assertCharactersAfterWhitespace()
        
        let name = try scanNonEmptyString()
        try assertCharactersAfterWhitespace()
        
        if data[position] == SourceCharacters.dot.rawValue {
            position = position &+ 1
            
            let type = try LanguageType.getType(named: name, from: project)
            
            let memberName = try scanNonEmptyString()
            
            try assertCharactersAfterWhitespace()
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            try consume(.leftParenthesis)
            
            let instanceName = try scanNonEmptyString()
            
            try assertCharactersAfterWhitespace()
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            guard try scanNonEmptyString() == name else {
                throw CompilerError.invalidMember(memberName)
            }
            
            try assertCharactersAfterWhitespace()
            try consume(.rightParenthesis)
            try assertCharactersAfterWhitespace()
            
            try consume(.minus)
            try consume(.greater)
            
            try assertCharactersAfterWhitespace()
            
            position = position &+ 1
            let signature = try scanSignature()
            
            return .instanceFunction(named: memberName, instance: instanceName, type: type, signature: signature)
        }
        
        try consume(.colon)
        try assertCharactersAfterWhitespace()
        
        guard data[position] == SourceCharacters.leftParenthesis.rawValue else {
            let type = try scanType()
            
            if type.name == "struct" {
                return .type(named: name, kind: .struct)
            }
            
            return .global(named: name, type: type)
        }
        
        position = position &+ 1
        
        let signature = try scanSignature()
        
        return .function(named: name, signature: signature)
    }
}
