import Foundation
import LLVM

let whitespace = Data("\r\n ".utf8)

enum SourceCharacters: UInt8 {
    case stringQuote = 0x22
    case and = 0x26
    case leftParenthesis = 0x28
    case rightParenthesis = 0x29
    case multiply = 0x2a
    case plus = 0x2b
    case comma = 0x2c
    case minus = 0x2d
    case dot = 0x2e
    case divide = 0x2f
    case colon = 0x3a
    case less = 0x3c
    case equal = 0x3d
    case greater = 0x3e
    case codeBlockOpen = 0x7b
    case pipe = 0x7c
    case codeBlockClose = 0x7d
    
    static let all = Data([
        SourceCharacters.stringQuote.rawValue,
        SourceCharacters.and.rawValue,
        SourceCharacters.leftParenthesis.rawValue,
        SourceCharacters.rightParenthesis.rawValue,
        SourceCharacters.multiply.rawValue,
        SourceCharacters.plus.rawValue,
        SourceCharacters.comma.rawValue,
        SourceCharacters.minus.rawValue,
        SourceCharacters.dot.rawValue,
        SourceCharacters.divide.rawValue,
        SourceCharacters.colon.rawValue,
        SourceCharacters.less.rawValue,
        SourceCharacters.equal.rawValue,
        SourceCharacters.greater.rawValue,
        SourceCharacters.codeBlockOpen.rawValue,
        SourceCharacters.codeBlockClose.rawValue,
    ])
}

let specialCharacters = whitespace + SourceCharacters.all

extension SourceFile {
    func skipWhitespace(includingNewline: Bool) {
        while position < data.count {
            guard whitespace.contains(data[position]) else {
                return
            }
            
            if !includingNewline && data[position] == 0x0a {
                return
            }
            
            position = position &+ 1
        }
    }
    
    func scanString() -> String {
        var string = String()
        string.reserveCapacity(64)
        
        while position < data.count {
            if specialCharacters.contains(data[position]) {
                return string
            }
            
            string.append(Character(.init(data[position])))
            position = position &+ 1
        }
        
        return string
    }
    
    func scanNonEmptyString() throws -> String {
        let string = scanString()
        
        guard string.characters.count > 0 else {
            // TODO: Infer types on `=`
            throw CompilerError.unexpectedEOF
        }
        
        return string
    }
    
    func assertMoreCharacters() throws {
        guard position < data.count else {
            throw CompilerError.unexpectedEOF
        }
    }
    
    func assertCharactersAfterWhitespace() throws {
        skipWhitespace(includingNewline: true)
        try assertMoreCharacters()
    }
    
    func charactersBeforeNewline() -> Bool {
        skipWhitespace(includingNewline: false)
    
        guard position < data.count else {
            return false
        }
        
        return data[position] != 0x0a
    }
    
    func scanSignature() throws -> Signature {
        var arguments = Arguments()
        
        while position < data.count, data[position] != SourceCharacters.rightParenthesis.rawValue {
            if arguments.count > 0 {
                try assertCharactersAfterWhitespace()
                
                guard data[position] == SourceCharacters.comma.rawValue else {
                    throw CompilerError.missingCommaAfterArguments(arguments)
                }
            }
            
            try assertCharactersAfterWhitespace()
            
            let name = try scanNonEmptyString()
            
            try assertCharactersAfterWhitespace()
            
            guard data[position] == SourceCharacters.colon.rawValue else {
                throw CompilerError.missingTypeForDeclaration(name)
            }
            
            try assertCharactersAfterWhitespace()
            
            let typeName = try scanNonEmptyString()
            let type = try LanguageType(named: typeName)
            
            arguments.append((name, type))
        }
        
        position = position &+ 1
        
        try assertCharactersAfterWhitespace()
        
        guard position + 3 < data.count else {
            throw CompilerError.unexpectedEOF
        }
        
        guard
            data[position] == SourceCharacters.minus.rawValue,
            data[position &+ 1] == SourceCharacters.greater.rawValue
        else {
            throw CompilerError.missingReturnType
        }
        
        position = position &+ 2
        
        try assertCharactersAfterWhitespace()
        
        let typeName = try scanNonEmptyString()
        let type = try LanguageType(named: typeName)
        
        return Signature(arguments: arguments, returnType: type)
    }
    
    func scanType() throws -> LanguageType {
        let name = try scanNonEmptyString()
        return try LanguageType(named: name)
    }
    
    func scanDeclaration() throws -> Declaration {
        try assertCharactersAfterWhitespace()
        
        let name = try scanNonEmptyString()
        try assertCharactersAfterWhitespace()
        
        try consume(.colon)
        try assertCharactersAfterWhitespace()
        
        guard data[position] == SourceCharacters.leftParenthesis.rawValue else {
            let type = try scanType()
            
            return .global(named: name, type: type)
        }
        
        position = position &+ 1
        
        let signature = try scanSignature()
        
        return .function(named: name, signature: signature)
    }
    
    func readLiteral(from literal: String, expecting type: LanguageType) -> IRValue? {
        guard literal.characters.count > 0 else {
            return nil
        }
        
        if type.integerLiteral, literal.utf8.first?.isNumeric == true {
            return type.makeValue(from: literal)
        }
        
        return nil
    }
    
    func scanLiteral(expecting type: LanguageType) throws -> IRValue? {
        try assertCharactersAfterWhitespace()
        
        let literal = scanString()
        
        return readLiteral(from: literal, expecting: type)
    }
    
    func consume(_ char: SourceCharacters) throws {
        guard data[position] == char.rawValue else {
            throw CompilerError.missingAssignment
        }
        
        position = position &+ 1
    }
    
    func scanAssignment(for type: LanguageType) throws -> IRValue {
        try assertCharactersAfterWhitespace()
        
        try consume(SourceCharacters.equal)
        
        try assertCharactersAfterWhitespace()
        
        guard let literal = try scanLiteral(expecting: type) else {
            // TODO: Custom types
            throw CompilerError.unknownType(type.name)
        }
        
        state = .none
        
        return literal
    }
    
    func isFunctionCall() -> Bool {
        return position < data.count && data[position] == SourceCharacters.leftParenthesis.rawValue
    }
    
    func callFunction(named name: String) throws -> IRValue {
        // Enter function call
        position = position &+ 1
        
        guard let function = project.functions[name] else {
            throw CompilerError.unknownFunction(name)
        }
        
        let arguments = [IRValue]()
        
        try consume(.rightParenthesis)
        
        let call = builder.buildCall(function, args: arguments)
        let result = builder.buildAlloca(type: call.type)
        builder.buildStore(call, to: result)
        return builder.buildLoad(result)
    }
    
    func readValue(ofType type: LanguageType, scope: Scope) throws -> IRValue {
        let string = try scanNonEmptyString()
        
        if isFunctionCall() {
            return try callFunction(named: string)
        }
        
        if let literal = readLiteral(from: string, expecting: type) {
            return literal
        } else if let variable = scope[string] {
            return builder.buildLoad(variable)
        } else if let global = project.globals[string] {
            return builder.buildLoad(global)
        }
        
        throw CompilerError.unknownVariable(string)
    }
    
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
        } else if project.functions.names.contains(name) {
            
        } else {
            try consume(.colon)
            try assertCharactersAfterWhitespace()
            
            let type = try scanType()
            let value = builder.buildAlloca(type: type.irType, name: name)
            
            scope.variables.append((name, type, value))
            
            let assigned = try scanAssignment(for: type)
            
            builder.buildStore(assigned, to: value)
        }
    }
    
    func scanCodeBlock(inFunction signature: Signature) throws {
        try assertCharactersAfterWhitespace()
        
        try consume(.equal)
        
        try assertCharactersAfterWhitespace()
        
        try consume(.codeBlockOpen)
        
        let scope = Scope()
        
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
    
    public func compile() throws {
        while position < data.count {
            skipWhitespace(includingNewline: true)
            
            guard position < data.count else {
                return
            }
            
            guard builderState == .global else {
                fatalError()
            }
            
            switch try scanDeclaration() {
            case .global(let name, let type):
                let value = try scanAssignment(for: type)
                
                try project.globals.append(builder.addGlobal(name, initializer: value))
            case .function(let name, let signature):
                let type = FunctionType(
                    argTypes: signature.arguments.map { type in
                        return type.1.irType
                    },
                    returnType: signature.returnType.irType
                )
                
                let function = builder.addFunction(name, type: type)
                let entry = function.appendBasicBlock(named: "entry")
                builder.positionAtEnd(of: entry)
                
                try scanCodeBlock(inFunction: signature)
                
                try project.functions.append(function)
            }
        }
    }
}

extension UInt8 {
    var isNumeric: Bool {
        return self >= 0x30 && self <= 0x39
    }
}
