enum ReservedFunction: String {
    case `if`
    case `return`
    
    func compile(in source: SourceFile, inFunction signature: Signature, scope: Scope) throws {
        switch self {
        case .if:
            try source.assertCharactersAfterWhitespace()
            
            
            
            try source.consume(.codeBlockOpen)
            try source.assertCharactersAfterWhitespace()
            
        case .return:
            if !source.charactersBeforeNewline() {
                source.builder.buildRetVoid()
                return
            }
            
            try source.assertCharactersAfterWhitespace()
            
            let value = try source.readValueExpression(ofType: signature.returnType, scope: scope)
            
            source.builder.buildRet(value)
        }
    }
}
