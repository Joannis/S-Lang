import Foundation
import LLVM

extension SourceFile {
    public func compile() throws {
        while position < data.count {
            skipWhitespace(includingNewline: true)
            
            guard position < data.count else {
                return
            }
            
            guard builderState == .global else {
                fatalError("Invalid compiler state")
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
                let entry = function.appendBasicBlock(named: "entry")
                builder.positionAtEnd(of: entry)
                
                let scope = Scope()
                
                var index = 0
                
                for (name, type) in signature.arguments {
                    if let definition = type.definition {
                        let alloc = builder.buildAlloca(type: definition.type)
                        builder.buildStore(function.parameters[index], to: alloc)
                        
                        scope.variables.append((name, type, alloc))
                    } else {
                        scope.variables.append((name, type, function.parameters[index]))
                    }
                    
                    index = index &+ 1
                }
                
                try scanCodeBlock(inFunction: signature, scope: scope)
                
                let functionDefinition = GlobalFunction(function: function, signature: signature)
                
                try project.functions.append(functionDefinition, named: name)
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
                let entry = function.appendBasicBlock(named: "entry")
                builder.positionAtEnd(of: entry)
                
                let scope = Scope()
                
                var index = 0
                
                for (name, type) in signature.arguments {
                    if let definition = type.definition {
                        let alloc = builder.buildAlloca(type: definition.type)
                        builder.buildStore(function.parameters[index], to: alloc)
                        
                        scope.variables.append((name, type, alloc))
                    } else {
                        scope.variables.append((name, type, function.parameters[index]))
                    }
                    
                    index = index &+ 1
                }
                
                try scanCodeBlock(inFunction: signature, scope: scope)
                
                let functionDefinition = InstanceFunction(
                    type: instanceType,
                    function: function,
                    signature: originalSignature
                )
                
                try project.instanceFunctions.append(functionDefinition, named: "\(instanceType.name).\(name)")
            }
        }
    }
}
