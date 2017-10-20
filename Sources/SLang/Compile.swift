import Foundation
import LLVM

extension SourceFile {
    func scanTopLevel() throws -> ([InstanceFunction], [GlobalFunction]) {
        var instanceFunctions = [InstanceFunction]()
        var globalFunctions = [GlobalFunction]()
        
        while position < data.count {
            skipWhitespace(includingNewline: true)
            
            guard position < data.count else {
                return (instanceFunctions, globalFunctions)
            }
            
            switch try scanDeclaration() {
            case .type(let name, let kind):
                try assertCharactersAfterWhitespace()
                
                try consume(SourceCharacters.equal)
                
                try assertCharactersAfterWhitespace()
                let structString = try scanNonEmptyString()
                
                guard structString == kind.rawValue else {
                    throw CompilerError.invalidTypeDefinition
                }
                
                let structure = builder.createStruct(name: name)
                
                let arguments = try scanTypeArguments()
                
                structure.setBody(
                    arguments.map { argument in
                        return argument.1.irType
                    }
                )
                
                let type = LanguageType(
                    named: name,
                    definition: StructureDefinition(
                        arguments: arguments,
                        type: structure,
                        kind: kind
                    )
                )
                
                try project.types.append(type, named: name)
            case .global(let name, let type):
                let value = try scanAssignment(for: type, scope: Scope())
                
                try project.globals.append(builder.addGlobal(name, initializer: value), named: name)
            case .function(let name, let signature):
                let arguments = signature.arguments.map { type in
                    return type.1.irType!
                }
                
                let type = FunctionType(
                    argTypes: arguments,
                    returnType: signature.returnType.irType
                )
                
                let function = builder.addFunction(name, type: type)
                
                let sourcePosition = SourcePosition(file: self, position: self.position)
                let functionDefinition = GlobalFunction(function: function, signature: signature, position: sourcePosition)
                
                try project.functions.append(functionDefinition, named: name)
                
                globalFunctions.append(functionDefinition)
                
                try skipCodeBlock()
            case .instanceFunction(let name, let instance, let instanceTypeName, let originalSignature):
                let sourcePosition = SourcePosition(file: self, position: self.position)
                
                let functionName = "\(instanceTypeName).\(name)"
                
                let functionDefinition = InstanceFunction(
                    functionName: functionName,
                    instanceTypeName: instanceTypeName,
                    instanceName: instance,
                    signature: originalSignature,
                    position: sourcePosition
                )
                
                instanceFunctions.append(functionDefinition)
                try project.instanceFunctions.append(functionDefinition, named: functionName)
                
                try skipCodeBlock()
            }
        }
        
        return (instanceFunctions, globalFunctions)
    }
    
    public func compile() throws {
        skipWhitespace(includingNewline: true)
        
        guard position < data.count else {
            return
        }
        
        let (instanceFunctions, globalFunctions) = try scanTopLevel()
        
        for definition in instanceFunctions {
            var signature = definition.signature
            
            let instanceType = try LanguageType.getType(named: definition.instanceTypeName, from: project)
            
            var arguments = signature.arguments.map { type in
                return type.1.irType!
            }
            
            if instanceType.definition?.kind == .model {
                let pointer = PointerType(pointee: instanceType.irType)
                arguments.insert(pointer, at: 0)
            } else {
                arguments.insert(instanceType.irType, at: 0)
            }
            
            signature.arguments.insert((definition.instanceName, instanceType), at: 0)
            
            let type = FunctionType(
                argTypes: arguments,
                returnType: signature.returnType.irType
            )
            
            let function = builder.addFunction(definition.functionName, type: type)
            definition.function = function
            
            let entry = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entry)
            
            let scope = Scope()
            
            let alloc: IRValue
            
            if let kind = instanceType.definition?.kind, kind == .struct {
                alloc = builder.buildAlloca(type: instanceType.irType, name: definition.instanceName)
                builder.buildStore(function.parameters[0], to: alloc)
            } else {
                alloc = function.parameters[0]
            }
            
            scope.variables.append((definition.instanceName, instanceType, alloc))
            
            var index = 1
            
            for (name, type) in definition.signature.arguments {
                if let typeDefinition = type.definition {
                    if typeDefinition.kind == .struct {
                        let alloc = builder.buildAlloca(type: typeDefinition.type)
                        builder.buildStore(function.parameters[index], to: alloc)
                        
                        scope.variables.append((name, type, alloc))
                    } else {
                        scope.variables.append((name, type, function.parameters[index]))
                    }
                } else {
                    scope.variables.append((name, type, function.parameters[index]))
                }
                
                index = index &+ 1
            }
            
            position = definition.codeBlockPosition.position
            
            try scanCodeBlock(inFunction: definition.signature, scope: scope)
        }
        
        for definition in globalFunctions {
            let entry = definition.function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entry)
            
            let scope = Scope()
            
            var index = 0
            
            for (name, type) in definition.signature.arguments {
                if let typeDefinition = type.definition {
                    let alloc = builder.buildAlloca(type: typeDefinition.type)
                    builder.buildStore(definition.function.parameters[index], to: alloc)
                    
                    scope.variables.append((name, type, alloc))
                } else {
                    scope.variables.append((name, type, definition.function.parameters[index]))
                }
                
                index = index &+ 1
            }
            
            position = definition.codeBlockPosition.position
            
            try scanCodeBlock(inFunction: definition.signature, scope: scope)
        }
    }
}
