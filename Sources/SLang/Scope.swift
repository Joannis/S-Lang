import LLVM

final class Scope {
    var `super`: Scope?
    
    var variables = [(String, LanguageType, IRValue)]()
    
    subscript(type expected: String) -> LanguageType? {
        for (name, type, _) in variables where name == expected {
            return type
        }
        
        return self.super?[type: expected]
    }
    
    subscript(expected: String) -> IRValue? {
        for (name, _, value) in variables where name == expected {
            return value
        }
        
        return self.super?[expected]
    }
    
    init() {}
}
