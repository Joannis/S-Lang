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
}
