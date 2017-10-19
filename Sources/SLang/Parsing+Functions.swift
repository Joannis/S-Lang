import LLVM

extension SourceFile {
    func forEachArgument<T>(_ read: (() throws -> (T))) throws -> [(String, T)] {
        var arguments = [(String, T)]()
        
        while position < data.count, data[position] != SourceCharacters.rightParenthesis.rawValue {
            if arguments.count > 0 {
                try assertCharactersAfterWhitespace()
                
                try consume(.comma)
            }
            
            try assertCharactersAfterWhitespace()
            
            let preNamePosition = position
            let name = try scanNonEmptyString()
            
            let t: T
            
            if data[position] == SourceCharacters.colon.rawValue {
                try consume(.colon)
                
                t = try read()
            } else {
                position = preNamePosition
                
                t = try read()
            }
            
            arguments.append((name, t))
            
            try assertCharactersAfterWhitespace()
        }
        
        // skip past right parenthesis
        position = position &+ 1
        
        return arguments
    }
    
    func scanTypeArguments() throws -> [(String, LanguageType)] {
        try assertCharactersAfterWhitespace()
        try consume(.leftParenthesis)
        
        return try forEachArgument {
            try assertCharactersAfterWhitespace()
            return try scanType()
        }
    }
    
    func scanArguments(types: [LanguageType], scope: Scope) throws -> [(String, IRValue)] {
        var parsed = 0
        
        return try forEachArgument {
            guard parsed < types.count else {
                throw CompilerError.tooManyArguments
            }
            
            defer { parsed += 1 }
            
            try assertCharactersAfterWhitespace()
            
            return try readValue(ofType: types[parsed], scope: scope)
        }
    }
    
    func scanSignature() throws -> Signature {
        let arguments = try forEachArgument { () throws -> LanguageType in
            try assertCharactersAfterWhitespace()
            
            let typeName = try scanNonEmptyString()
            return try LanguageType(named: typeName)
        }
        
        position = position &+ 1
        
        try assertCharactersAfterWhitespace()
        
        guard position + 3 < data.count else {
            throw CompilerError.unexpectedEOF
        }
        
        guard
            data[position] == SourceCharacters.minus.rawValue,
            data[position &+ 1] == SourceCharacters.greater.rawValue
            else {
                throw CompilerError.missingReturnType
        }
        
        position = position &+ 2
        
        try assertCharactersAfterWhitespace()
        
        let typeName = try scanNonEmptyString()
        let type = try LanguageType(named: typeName)
        
        return Signature(arguments: arguments, returnType: type)
    }
}
