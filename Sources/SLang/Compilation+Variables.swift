import LLVM

extension SourceFile {
    /// Reads a value by scanning the statement at the current position in the source file
    ///
    /// If necessary, accesses the expected type and scope
    ///
    /// TODO: Check types for functions and variables, throw proper errors
    func readValue(ofType type: LanguageType, scope: Scope) throws -> IRValue {
        let string = try scanNonEmptyString()
        
        // If this is a global function call
        if isFunctionCall() {
            // If this is a typename, attempt instantiating it instead
            if project.types.names.contains(string) {
                return try construct(
                    structure: type,
                    scope: scope
                )
            } else {
                // Find the function
                guard let index = project.functions.names.index(of: string) else {
                    throw CompilerError.unknownFunction(string)
                }
                
                // Scan the arguments
                let expectations = project.functions.data[index].signature.arguments.map { $0.1 }
                
                try consume(.leftParenthesis)
                
                let arguments = try scanArguments(
                    types: expectations,
                    scope: scope
                ).map { _, value in
                    return value
                }
                
                // Call the function and return the value
                return try callFunctionAndReturn(
                    named: string,
                    withArguments: arguments,
                    scope: scope
                )
            }
        }
        
        // If the string is a literal, return the associated value
        if let literal = readLiteral(from: string, expecting: type) {
            return literal
        } else if let type = scope[type: string], let instance = scope[string] {
            // If accessing a struct
            if let definition = type.definition, data[position] == SourceCharacters.dot.rawValue {
                try consume(.dot)
                
                // Check for the member
                let member = try scanNonEmptyString()
                
                // If this is a function cal
                if isFunctionCall() {
                    // Function call must be found
                    guard let instanceFunction = project.instanceFunctions["\(type.name).\(member)"] else {
                        throw CompilerError.invalidMember(member)
                    }
                    
                    // Scan the function call arguments
                    try consume(.leftParenthesis)
                    
                    let arguments = try scanArguments(
                        types: instanceFunction.signature.arguments.map { $0.1 },
                        scope: scope
                        ).map { _, value in
                            return value
                    }
                    
                    var instance = instance
                    
                    // Structs must be loaded before accessed (models are pointers)
                    if type.definition?.kind == .struct {
                        instance = builder.buildLoad(instance)
                    }
                    
                    // Call the function and return it's value
                    return try callFunctionAndReturn(
                        named: "\(type.name).\(member)",
                        withArguments: [instance] + arguments,
                        scope: scope
                    )
                }
                
                // Accessing a struct's member (variable)
                if let index = definition.arguments.index(where: { name, _ in
                    return name == member
                }) {
                    let member = builder.buildStructGEP(instance, index: index)
                    return builder.buildLoad(member)
                }
                
                throw CompilerError.invalidMember(member)
            } else {
                // Read alloca's in assignment
                if instance.type is PointerType {
                    return builder.buildLoad(instance)
                // Read constants
                } else {
                    return instance
                }
            }
        // Last resort is a global variable
        } else if let global = project.globals[string] {
            return builder.buildLoad(global)
        }
        
        throw CompilerError.unknownVariable(string)
    }
}
