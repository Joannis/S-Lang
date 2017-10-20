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
            case .type(let name, _):
                try assertCharactersAfterWhitespace()
                
                try consume(SourceCharacters.equal)
                
                try assertCharactersAfterWhitespace()
                let structString = try scanNonEmptyString()
                
                guard structString == "struct" else {
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
                    definition: StructureDefinition(arguments: arguments, type: structure)
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
                
                let position = SourcePosition(file: self, position: self.position)
                let functionDefinition = GlobalFunction(function: function, signature: signature, position: position)
                
                try project.functions.append(functionDefinition, named: name)
                
                globalFunctions.append(functionDefinition)
                
                try skipCodeBlock()
            case .instanceFunction(let name, let instance, let instanceType, let originalSignature):
                var signature = originalSignature
                
                signature.arguments.insert((instance, instanceType), at: 0)
                
                let arguments = signature.arguments.map { type in
                    return type.1.irType!
                }
                
                let type = FunctionType(
                    argTypes: arguments,
                    returnType: signature.returnType.irType
                )
                
                let function = builder.addFunction("\(instanceType.name).\(name)", type: type)
                let position = SourcePosition(file: self, position: self.position)
                
                let functionDefinition = InstanceFunction(
                    type: instanceType,
                    name: instance,
                    function: function,
                    signature: originalSignature,
                    position: position
                )
                
                try project.instanceFunctions.append(functionDefinition, named: "\(instanceType.name).\(name)")
                
                instanceFunctions.append(functionDefinition)
                
                try skipCodeBlock()
            }
        }
        
        return (instanceFunctions, globalFunctions)
    }
    
    public func compile() throws {
        while position < data.count {
            skipWhitespace(includingNewline: true)
            
            guard position < data.count else {
                return
            }
            
            let (instanceFunctions, globalFunctions) = try scanTopLevel()
            
            for definition in instanceFunctions {
                let entry = definition.function.appendBasicBlock(named: "entry")
                builder.positionAtEnd(of: entry)
                
                let scope = Scope()
                
                let alloc = builder.buildAlloca(type: definition.instanceType.irType)
                builder.buildStore(definition.function.parameters[0], to: alloc)
                
                scope.variables.append((definition.instanceName, definition.instanceType, alloc))
                
                var index = 1
                
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
}
