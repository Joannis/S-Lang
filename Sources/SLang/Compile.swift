import Foundation
import LLVM

extension SourceFile {
    /// Scans the top level of this source file for all declarations
    func scanTopLevel() throws -> ([InstanceFunction], [GlobalFunction]) {
        var instanceFunctions = [InstanceFunction]()
        var globalFunctions = [GlobalFunction]()
        
        while position < data.count {
            skipWhitespace(includingNewline: true)
            
            // If this is the end of the file, return the results
            guard position < data.count else {
                return (instanceFunctions, globalFunctions)
            }
            
            // Find the next declaration
            switch try scanDeclaration() {
            case .type(let name, let kind):
                // This is a type declaration
                try assertCharactersAfterWhitespace()
                
                // They must be assigned to a model or struct
                try consume(SourceCharacters.equal)
                
                try assertCharactersAfterWhitespace()
                let structString = try scanNonEmptyString()
                
                // Check if the declaration matches the declaration kind
                guard structString == kind.rawValue else {
                    throw CompilerError.invalidTypeDefinition
                }
                
                // Create a new struct
                let structure = builder.createStruct(name: name)
                
                let arguments = try scanTypeArguments()
                
                // Assign the struct the expected values
                structure.setBody(
                    arguments.map { argument in
                        return argument.1.irType
                    }
                )
                
                // Construct a new language type for the compiler
                let type = LanguageType(
                    named: name,
                    definition: StructureDefinition(
                        arguments: arguments,
                        type: structure,
                        kind: kind
                    )
                )
                
                // Append to the project types
                try project.types.append(type, named: name)
            case .global(let name, let type):
                // Scan for an assignment of this type
                let value = try scanAssignment(for: type, scope: Scope())
                
                // Append the global to the project's globals
                try project.globals.append(builder.addGlobal(name, initializer: value), named: name)
            case .function(let name, let signature):
                // Set up all the expected types
                let arguments = signature.arguments.map { type in
                    return type.1.irType!
                }
                
                // Create a new compiler function type
                let type = FunctionType(
                    argTypes: arguments,
                    returnType: signature.returnType.irType
                )
                
                // Create the function IR
                let function = builder.addFunction(name, type: type)
                
                // Create and set the source position for scanning the code block
                let sourcePosition = SourcePosition(file: self, position: self.position)
                let functionDefinition = GlobalFunction(function: function, signature: signature, position: sourcePosition)
                
                // Append the definition to the project
                try project.functions.append(functionDefinition, named: name)
                globalFunctions.append(functionDefinition)
                
                // Skip past the code block
                try skipCodeBlock()
            case .instanceFunction(let name, let instance, let instanceTypeName, let originalSignature):
                // Create and set the source position for scanning the code block
                let sourcePosition = SourcePosition(file: self, position: self.position)
                
                // Create a new compiler function type
                let functionName = "\(instanceTypeName).\(name)"
                
                let functionDefinition = InstanceFunction(
                    functionName: functionName,
                    instanceTypeName: instanceTypeName,
                    instanceName: instance,
                    signature: originalSignature,
                    position: sourcePosition
                )
                
                // Append the definition to the project
                instanceFunctions.append(functionDefinition)
                try project.instanceFunctions.append(functionDefinition, named: functionName)
                
                // Skip past the code block
                try skipCodeBlock()
            }
        }
        
        return (instanceFunctions, globalFunctions)
    }
    
    /// Compiles this source file
    public func compile() throws {
        skipWhitespace(includingNewline: true)
        
        guard position < data.count else {
            return
        }
        
        let (instanceFunctions, globalFunctions) = try scanTopLevel()
        
        for definition in instanceFunctions {
            var signature = definition.signature
            
            // Get the instance's type
            let instanceType = try LanguageType.getType(named: definition.instanceTypeName, from: project)
            
            // Map all arguments to their IR type
            var arguments = signature.arguments.map { type in
                return type.1.irType!
            }
            
            // If the subject is a model
            if instanceType.definition?.kind == .model {
                // Point to the instance
                let pointer = PointerType(pointee: instanceType.irType)
                arguments.insert(pointer, at: 0)
            } else {
                // Otherwise, don't point but copy
                arguments.insert(instanceType.irType, at: 0)
            }
            
            // Insert the model as the first argument
            signature.arguments.insert((definition.instanceName, instanceType), at: 0)
            
            // Create the IR function definition
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
            
            // Insert the current subject into the start
            if let kind = instanceType.definition?.kind, kind == .struct {
                alloc = builder.buildAlloca(type: instanceType.irType, name: definition.instanceName)
                builder.buildStore(function.parameters[0], to: alloc)
            } else {
                alloc = function.parameters[0]
            }
            
            // Append this variable to the scope
            scope.variables.append((definition.instanceName, instanceType, alloc))
            
            var index = 1
            
            // Fetch all argument's parameters
            for (name, type) in definition.signature.arguments {
                if let typeDefinition = type.definition {
                    // Structs are copied, models are referenced
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
            
            // Reset the position to the start of the code block
            position = definition.codeBlockPosition.position
            
            // Start compiling the block
            try compileCodeBlock(inFunction: definition.signature, scope: scope)
        }
        
        for definition in globalFunctions {
            let entry = definition.function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entry)
            
            let scope = Scope()
            
            var index = 0
            
            // Fetch all argument's parameters
            for (name, type) in definition.signature.arguments {
                if let typeDefinition = type.definition {
                    // Structs are copied, models are referenced
                    if typeDefinition.kind == .struct {
                        let alloc = builder.buildAlloca(type: typeDefinition.type)
                        builder.buildStore(definition.function.parameters[index], to: alloc)
                        
                        scope.variables.append((name, type, alloc))
                    } else {
                        scope.variables.append((name, type, definition.function.parameters[index]))
                    }
                } else {
                    scope.variables.append((name, type, definition.function.parameters[index]))
                }
                
                index = index &+ 1
            }
            
            // Reset the position to the start of the code block
            position = definition.codeBlockPosition.position
            
            // Start compiling the block
            try compileCodeBlock(inFunction: definition.signature, scope: scope)
        }
    }
}
