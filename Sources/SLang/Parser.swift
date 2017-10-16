import Foundation
import LLVM

fileprivate let whitespace = Data("\r\n ".utf8)

fileprivate enum SourceCharacters: UInt8 {
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

fileprivate let specialCharacters = whitespace + SourceCharacters.all

extension SourceFile {
    fileprivate func skipWhitespace() {
        while position < data.count {
            guard whitespace.contains(data[position]) else {
                return
            }
            
            position = position &+ 1
        }
    }
    
    fileprivate func scanString() -> String {
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
    
    fileprivate func scanNonEmptyString() throws -> String {
        let string = scanString()
        
        guard string.characters.count > 0 else {
            // TODO: Infer types on `=`
            throw CompilerError.unexpectedEOF
        }
        
        return string
    }
    
    fileprivate func assertMoreCharacters() throws {
        guard position < data.count else {
            throw CompilerError.unexpectedEOF
        }
    }
    
    fileprivate func assertCharactersAfterWhitespace() throws {
        skipWhitespace()
        try assertMoreCharacters()
    }
    
    fileprivate func scanAnything() throws {
        let word = scanString()
        
        guard word.characters.count > 0 else {
            return
        }
        
        switch word {
//        case "if":
        default:
            self.state = .declaration(word)
        }
    }
    
    fileprivate func scanSignature() throws -> Signature {
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
    
    fileprivate func scanType(forDeclaration declaration: String) throws {
        try assertCharactersAfterWhitespace()
        
        try consume(.colon)
        
        try assertCharactersAfterWhitespace()
        
        guard data[position] == SourceCharacters.leftParenthesis.rawValue else {
            let word = try scanNonEmptyString()
            
            self.state = .type(declaration, try LanguageType(named: word))
            return
        }
        
        position = position &+ 1
        
        let signature = try scanSignature()
        self.state = .function(declaration, signature)
    }
    
    fileprivate func readLiteral(from literal: String, expecting type: LanguageType) -> IRValue? {
        guard literal.characters.count > 0 else {
            return nil
        }
        
        if type.integerLiteral, literal.utf8.first?.isNumeric == true {
            return type.makeValue(from: literal)
        }
        
        return nil
    }
    
    fileprivate func scanLiteral(expecting type: LanguageType) throws -> IRValue? {
        try assertCharactersAfterWhitespace()
        
        let literal = scanString()
        
        return readLiteral(from: literal, expecting: type)
    }
    
    fileprivate func consume(_ char: SourceCharacters) throws {
        guard data[position] == char.rawValue else {
            throw CompilerError.missingAssignment
        }
        
        position = position &+ 1
    }
    
    fileprivate func scanAssignment(for type: LanguageType) throws -> IRValue {
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
    
    fileprivate func isFunctionCall() throws -> Bool {
        return position < data.count && data[position] == SourceCharacters.leftParenthesis.rawValue
    }
    
    fileprivate func callFunction(named name: String, builder: IRBuilder) -> IRValue {
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
    
    fileprivate func compileStatement(inFunction signature: Signature, buildingInto builder: IRBuilder, scope: Scope) throws {
        try assertCharactersAfterWhitespace()
        
        let word = scanString()
        
        switch word {
        case "return":
            try assertCharactersAfterWhitespace()
            let string = scanString()
            
            if isFunctionCall() {
                let result = try callFunction(named: string, builder: builder)
                
                builder.buildRet(result)
                return
            }
            
            if string.characters.count == 0 {
                builder.buildRetVoid()
            } else if let literal = readLiteral(from: string, expecting: signature.returnType) {
                builder.buildRet(literal)
            } else if let variable = scope[string] {
                let variable = builder.buildLoad(variable)
                builder.buildRet(variable)
            } else if let global = project.globals[string] {
                let global = builder.buildLoad(global)
                builder.buildRet(global)
            } else {
                throw CompilerError.unknownVariable(string)
            }
        default:
            try scanType(forDeclaration: word)
            
            switch state {
            case .type(_, let type):
                let value = builder.buildAlloca(type: type.irType, name: word)
                
                scope.variables.append((word, type, value))
                
                let assigned = try scanAssignment(for: type)
                
                builder.buildStore(assigned, to: value)
            case .function(_, _):
                fatalError("Unsupported")
            default:
                fatalError("Impossible")
            }
        }
    }
    
    fileprivate func scanCodeBlock(inFunction signature: Signature, buildingInto builder: IRBuilder) throws {
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
            
            try compileStatement(inFunction: signature, buildingInto: builder, scope: scope)
        }
        
        throw CompilerError.unexpectedEOF
    }
    
    public func compile(into builder: IRBuilder) throws {
        while position < data.count {
            skipWhitespace()
            
            guard position < data.count else {
                return
            }
            
            guard builderState == .global else {
                fatalError()
            }
            
            switch state {
            case .none:
                try scanAnything()
            case .declaration(let name):
                try scanType(forDeclaration: name)
            case .type(let name, let type):
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
                
                try scanCodeBlock(inFunction: signature, buildingInto: builder)
                
                try project.functions.append(function)
            }
        }
    }
}

fileprivate extension UInt8 {
    var isNumeric: Bool {
        return self >= 0x30 && self <= 0x39
    }
}
