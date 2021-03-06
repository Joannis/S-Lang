enum ReservedFunction: String {
    case `if`
    case `return`
    
    func compile(in source: SourceFile, inFunction signature: Signature, scope: Scope) throws {
        switch self {
        case .if:
//            let value = try source.readValueExpression(ofType: LanguageType.bool, scope: scope)
            try source.assertCharactersAfterWhitespace()
            
            try source.consume(.codeBlockOpen)
            try source.assertCharactersAfterWhitespace()
            
        case .return:
            if !source.charactersBeforeNewline() || signature.returnType.name == "Void" {
                source.builder.buildRetVoid()
                return
            }
            
            try source.assertCharactersAfterWhitespace()
            
            let value = try source.readValueExpression(ofType: signature.returnType, scope: scope)
            
            source.builder.buildRet(value)
        }
    }
    
    func skip(in source: SourceFile) throws {
        switch self {
        case .if:
            try source.assertCharactersAfterWhitespace()
            
            try source.consume(.codeBlockOpen)
            try source.assertCharactersAfterWhitespace()
            
        case .return:
            try source.assertCharactersAfterWhitespace()
            
            if !source.charactersBeforeNewline() {
                return
            }
            
            if source.data[source.position] == SourceCharacters.codeBlockClose.rawValue {
                return
            }
            
            try source.skipValueExpression()
        }
    }
}
