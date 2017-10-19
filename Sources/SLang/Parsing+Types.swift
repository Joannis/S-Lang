import LLVM

extension SourceFile {
    func scanType() throws -> LanguageType {
        let name = try scanNonEmptyString()
        return try LanguageType.getType(named: name, from: project)
    }
    
    func readLiteral(from literal: String, expecting type: LanguageType) -> IRValue? {
        guard literal.characters.count > 0 else {
            return nil
        }
        
        if type.integerLiteral, literal.utf8.first?.isNumeric == true {
            return type.makeValue(from: literal)
        }
        
        return nil
    }
    
    func scanLiteral(expecting type: LanguageType, scope: Scope) throws -> IRValue? {
        try assertCharactersAfterWhitespace()
        
        let literal = scanString()
        
        if type.definition != nil {
            try assertCharactersAfterWhitespace()
            try consume(.leftParenthesis)
            
            let value = try construct(structure: type, scope: scope)
            
            return value
        }
        
        return readLiteral(from: literal, expecting: type)
    }
}
