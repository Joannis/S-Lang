import LLVM

extension SourceFile {
    func readValueExpression(ofType type: LanguageType, scope: Scope) throws -> IRValue {
        var value = try readValue(ofType: type, scope: scope)
        
        while charactersBeforeNewline() {
            let character = data[position]
            position = position &+ 1
            
            try assertCharactersAfterWhitespace()
            
            let other = try readValue(ofType: type, scope: scope)
            
            switch character {
            case SourceCharacters.plus.rawValue:
                value = builder.buildAdd(value, other)
            case SourceCharacters.minus.rawValue:
                value = builder.buildSub(value, other)
            default:
                throw CompilerError.unknownOperation
            }
        }
        
        return value
    }
    
    func compileStatement(inFunction signature: Signature, scope: Scope) throws {
        try assertCharactersAfterWhitespace()
        
        let name = try scanNonEmptyString()
        try assertCharactersAfterWhitespace()
        
        if let reserved = ReservedFunction(rawValue: name) {
            try reserved.compile(in: self, inFunction: signature, scope: scope)
        } else if let index = project.functions.names.index(of: name) {
            try consume(.leftParenthesis)
            
            let expectations = project.functions.data[index].signature.arguments.map { _, type in
                return type
            }
            
            let arguments = try scanArguments(
                types: expectations,
                scope: scope
                ).map { _, value in
                    return value
            }
            
            try callFunction(named: name, withArguments: arguments, scope: scope)
        } else if let type = scope[type: name], let variable = scope[name] {
            if type.definition != nil, data[position] == SourceCharacters.dot.rawValue {
                try consume(.dot)
                let member = try scanNonEmptyString()
                try assertCharactersAfterWhitespace()
                
                let functionName = "\(type.name).\(member)"
                
                guard
                    isFunctionCall(),
                    let instanceFunction = project.instanceFunctions[functionName]
                else {
                    try assertCharactersAfterWhitespace()
                    try consume(.equal)
                    try assertCharactersAfterWhitespace()
                    
                    guard let index = type.definition?.arguments.index(where: { name, _ in
                        return name == member
                    }) else {
                        throw CompilerError.invalidMember(member)
                    }
                    
                    let newValue = try readValue(ofType: type, scope: scope)
                    let element = builder.buildStructGEP(variable, index: index)
                    
                    builder.buildStore(newValue, to: element)
                    return
                }
                
                try consume(.leftParenthesis)
                
                let arguments = try scanArguments(
                    types: instanceFunction.signature.arguments.map { $0.1 },
                    scope: scope
                ).map { _, value in
                    return value
                }
                
                try callFunction(
                    named: functionName,
                    withArguments: [variable] + arguments,
                    scope: scope
                )
            }
        } else if data[position] == SourceCharacters.colon.rawValue {
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            let type = try scanType()
            let value = builder.buildAlloca(type: type.irType, name: name)
            
            scope.variables.append((name, type, value))
            
            let assigned = try scanAssignment(for: type, scope: scope)
            
            builder.buildStore(assigned, to: value)
        } else if let type = scope[type: name], let variable = scope[name] {
            try consume(.equal)
            try assertCharactersAfterWhitespace()
            
            let newValue = try readValue(ofType: type, scope: scope)
            
            builder.buildStore(newValue, to: variable)
        }
    }
    
    func scanCodeBlock(inFunction signature: Signature, scope: Scope) throws {
        try enterCodeBlock()
        
        while position < data.count {
            try assertCharactersAfterWhitespace()
            
            if data[position] == SourceCharacters.codeBlockClose.rawValue {
                position = position &+ 1
                state = .none
                return
            }
            
            try compileStatement(inFunction: signature, scope: scope)
        }
        
        throw CompilerError.unexpectedEOF
    }
}
