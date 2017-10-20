import LLVM

extension SourceFile {
    @discardableResult
    func callFunction(named name: String, withArguments arguments: [IRValue], scope: Scope) throws -> Call {
        if let function = project.functions[name] {
            return builder.buildCall(function.function, args: arguments)
        }
        
        if let function = project.instanceFunctions[name]?.function {
            return builder.buildCall(function, args: arguments)
        }
        
        throw CompilerError.unknownFunction(name)
    }
    
    func callFunctionAndReturn(named name: String, withArguments arguments: [IRValue], scope: Scope) throws -> IRValue {
        let call = try callFunction(named: name, withArguments: arguments, scope: scope)
        
        let result = builder.buildAlloca(type: call.type)
        builder.buildStore(call, to: result)
        return builder.buildLoad(result)
    }
    
    func construct(structure: LanguageType, scope: Scope) throws -> IRValue {
        guard let definition = structure.definition else {
            throw CompilerError.unknownType(structure.name)
        }
        
        let arguments = try scanArguments(
            types: definition.arguments.map { _, type in
                return type
            },
            scope: scope
        )
        
        let value = definition.type.constant(values: arguments.map { _, value in
            return value
        })
        
        return value
    }
}
