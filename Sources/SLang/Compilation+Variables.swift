import LLVM

extension SourceFile {
    func readValue(ofType type: LanguageType, scope: Scope) throws -> IRValue {
        let string = try scanNonEmptyString()
        
        if isFunctionCall() {
            if project.types.names.contains(string) {
                return try construct(
                    structure: type,
                    scope: scope
                )
            } else {
                guard let index = project.functions.names.index(of: string) else {
                    throw CompilerError.unknownFunction(string)
                }
                
                let expectations = project.functions.data[index].signature.arguments.map { $0.1 }
                
                try consume(.leftParenthesis)
                
                let arguments = try scanArguments(
                    types: expectations,
                    scope: scope
                ).map { _, value in
                    return value
                }
                
                return try callFunctionAndReturn(
                    named: string,
                    withArguments: arguments,
                    scope: scope
                )
            }
        }
        
        if let literal = readLiteral(from: string, expecting: type) {
            return literal
        } else if let type = scope[type: string], let instance = scope[string] {
            if let definition = type.definition, data[position] == SourceCharacters.dot.rawValue {
                try consume(.dot)
                let member = try scanNonEmptyString()
                
                if isFunctionCall(), let instanceFunction = project.instanceFunctions["\(type.name).\(member)"]
                {
                    try consume(.leftParenthesis)
                    
                    let arguments = try scanArguments(
                        types: instanceFunction.signature.arguments.map { $0.1 },
                        scope: scope
                        ).map { _, value in
                            return value
                    }
                    
                    let instance = builder.buildLoad(instance)
                    
                    return try callFunctionAndReturn(
                        named: "\(type.name).\(member)",
                        withArguments: [instance] + arguments,
                        scope: scope
                    )
                }
                
                if let index = definition.arguments.index(where: { name, _ in
                    return name == member
                }) {
                    let member = builder.buildStructGEP(instance, index: index)
                    return builder.buildLoad(member)
                }
                
                throw CompilerError.invalidMember(member)
            } else {
                return builder.buildLoad(instance)
            }
        } else if let global = project.globals[string] {
            return builder.buildLoad(global)
        }
        
        throw CompilerError.unknownVariable(string)
    }
}
