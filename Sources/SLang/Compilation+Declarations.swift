extension SourceFile {
    /// Scans (not compiles) a top-level declaration such as
    /// an instance method, function, global variable or type declaration
    func scanDeclaration() throws -> Declaration {
        try assertCharactersAfterWhitespace()
        
        // The name of the entity
        let typeName = try scanNonEmptyString()
        
        // If immediately followed by a dot, this is an instance method
        if data[position] == SourceCharacters.dot.rawValue {
            position = position &+ 1
            
            // The member name
            let memberName = try scanNonEmptyString()
            
            // Scan the type definition
            try assertCharactersAfterWhitespace()
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            // The type is a function signature starting with the current scope
            try consume(.leftParenthesis)
            
            // The current scope variable name
            let instanceName = try scanNonEmptyString()
            
            try assertCharactersAfterWhitespace()
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            // Expect the current type to be the scope, this is required
            guard try scanNonEmptyString() == typeName else {
                throw CompilerError.invalidMember(memberName)
            }
            
            // End the scope definition
            try assertCharactersAfterWhitespace()
            try consume(.rightParenthesis)
            try assertCharactersAfterWhitespace()
            
            // Next comes the remaining function signature
            try consume(.minus)
            try consume(.greater)
            
            try assertCharactersAfterWhitespace()
            
            position = position &+ 1
            
            // Scan the normal function signature
            let signature = try scanSignature()
            
            return .instanceFunction(named: memberName, instance: instanceName, typeName: typeName, signature: signature)
        }
        
        // Not an instance function means the next character is a type definition
        try assertCharactersAfterWhitespace()
        try consume(.colon)
        try assertCharactersAfterWhitespace()
        
        // If the definition starts with leftParenthesis this can be either a type or global
        guard data[position] == SourceCharacters.leftParenthesis.rawValue else {
            let type = try scanType()
            
            // Scan the type if the type matches a typekind such as `struct` or `model`
            if let kind = TypeKind(rawValue: type.name) {
                return .type(named: typeName, kind: kind)
            }
            
            // Otherwise, define a global
            return .global(named: typeName, type: type)
        }
        
        // Last possibility is a function signature
        position = position &+ 1
        
        let signature = try scanSignature()
        
        return .function(named: typeName, signature: signature)
    }
}
