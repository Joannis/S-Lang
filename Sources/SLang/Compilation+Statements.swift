import LLVM

extension SourceFile {
    /// Reads a value expression of a specific type, such as an Int64
    func readValueExpression(ofType type: LanguageType, scope: Scope) throws -> IRValue {
        var value = try readValue(ofType: type, scope: scope)
        
        // If this statement is longer, try to parse it
        while charactersBeforeNewline() {
            // Try to parse an operator
            let character = data[position]
            position = position &+ 1
            
            try assertCharactersAfterWhitespace()
            
            // Read the next value
            let other = try readValue(ofType: type, scope: scope)
            
            // Change behaviour depending on the operator
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
    
    // Compile a statement within a function
    func compileStatement(inFunction signature: Signature, scope: Scope) throws {
        try assertCharactersAfterWhitespace()
        
        // Scan the first statement name
        let name = try scanNonEmptyString()
        try assertCharactersAfterWhitespace()
        
        // If this is a reserved name such as `if` or `return
        if let reserved = ReservedFunction(rawValue: name) {
            try reserved.compile(in: self, inFunction: signature, scope: scope)
            
        // If this is a global function
        } else if let index = project.functions.names.index(of: name) {
            try consume(.leftParenthesis)
            
            let expectations = project.functions.data[index].signature.arguments.map { _, type in
                return type
            }
            
            // Scan for arguments
            let arguments = try scanArguments(
                types: expectations,
                scope: scope
                ).map { _, value in
                    return value
            }
            
            // Call the function without fetching the return values
            try callFunction(named: name, withArguments: arguments, scope: scope)
        // If accessing an instance
        } else if let type = scope[type: name], let variable = scope[name] {
            // If accessedby `dot` notation, accessing a property
            if type.definition != nil, data[position] == SourceCharacters.dot.rawValue {
                try consume(.dot)
                let member = try scanNonEmptyString()
                try assertCharactersAfterWhitespace()
                
                let functionName = "\(type.name).\(member)"
                
                // If this is a function call
                if isFunctionCall(), let instanceFunction = project.instanceFunctions[functionName] {
                    try consume(.leftParenthesis)
                    
                    // Scan for arguments
                    let arguments = try scanArguments(
                        types: instanceFunction.signature.arguments.map { $0.1 },
                        scope: scope
                        ).map { _, value in
                            return value
                    }
                    
                    // Call the function, ditch the result
                    try callFunction(
                        named: functionName,
                        withArguments: [variable] + arguments,
                        scope: scope
                    )
                    
                    return
                }
                
                // Otherwise, expect an assignment
                try assertCharactersAfterWhitespace()
                try consume(.equal)
                try assertCharactersAfterWhitespace()
                
                // Find the member type
                guard let index = type.definition?.arguments.index(where: { name, _ in
                    return name == member
                }) else {
                    throw CompilerError.invalidMember(member)
                }
                
                // Read the new value of this type
                let newValue = try readValue(ofType: type, scope: scope)
                
                // Store the new value into the member
                let element = builder.buildStructGEP(variable, index: index)
                builder.buildStore(newValue, to: element)
            } else {
                fatalError("Instance left unused, no idea what to do!")
            }
        // If this is a variable definition
        } else if data[position] == SourceCharacters.colon.rawValue {
            // Expect an explicit type definition
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            // Scan for the type
            let type = try scanType()
            
            // Allocate this type
            let value = builder.buildAlloca(type: type.irType, name: name)
            
            // Add the variable to this scope
            scope.variables.append((name, type, value))
            
            // Scan for assignment
            let assigned = try scanAssignment(for: type, scope: scope)
            
            // Store the new value into this allocated space
            builder.buildStore(assigned, to: value)
        } else if let type = scope[type: name], let variable = scope[name] {
            try consume(.equal)
            try assertCharactersAfterWhitespace()
            
            let newValue = try readValue(ofType: type, scope: scope)
            
            builder.buildStore(newValue, to: variable)
        }
    }
    
    // Scans and compiles all statements in a code block from the current position
    func compileCodeBlock(inFunction signature: Signature, scope: Scope) throws {
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
