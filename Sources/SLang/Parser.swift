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
        guard data[position] == SourceCharacters.colon.rawValue else {
            throw CompilerError.missingTypeForDeclaration(declaration)
        }
        
        position = position &+ 1
        
        try assertCharactersAfterWhitespace()
        
        guard data[position] == SourceCharacters.leftParenthesis.rawValue else {
            let word = try scanNonEmptyString()
            
            self.state = .type(try LanguageType(named: word))
            return
        }
        
        position = position &+ 1
        
        let signature = try scanSignature()
        self.state = .function(declaration, signature)
    }
    
    fileprivate func scanAssignment(for type: LanguageType) throws {
        
    }
    
    fileprivate func scanLiteral(expecting type: LanguageType) throws -> IRValue? {
        try assertCharactersAfterWhitespace()
        
        let literal = scanString()
        
        guard literal.characters.count > 0 else {
            return nil
        }
        
        if type.integerLiteral, literal.utf8.first?.isNumeric == true {
            return type.makeValue(from: literal)
        }
        
        return nil
    }
    
    fileprivate func compileStatement(inFunction signature: Signature, buildingInto builder: IRBuilder) throws {
        try assertCharactersAfterWhitespace()
        
        let word = scanString()
        
        switch word {
        case "return":
            if let literal = try scanLiteral(expecting: signature.returnType) {
                builder.buildRet(literal)
            } else {
                throw CompilerError.unknownStatement(word)
            }
        default:
            throw CompilerError.unknownStatement(word)
        }
    }
    
    fileprivate func scanCodeBlock(inFunction signature: Signature, buildingInto builder: IRBuilder) throws {
        try assertCharactersAfterWhitespace()
        
        guard data[position] == SourceCharacters.codeBlockOpen.rawValue else {
            return
        }
        
        position = position &+ 1
        
        while position < data.count {
            try assertCharactersAfterWhitespace()
            
            if data[position] == SourceCharacters.codeBlockClose.rawValue {
                position = position &+ 1
                return
            }
            
            try compileStatement(inFunction: signature, buildingInto: builder)
        }
    }
    
    public func compile(into builder: IRBuilder) throws {
        while position < data.count {
            skipWhitespace()
            
            guard position < data.count else {
                return
            }
            
            switch state {
            case .none:
                try scanAnything()
            case .declaration(let name):
                try scanType(forDeclaration: name)
            case .type(let type):
                try scanAssignment(for: type)
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
            }
        }
    }
}

fileprivate extension UInt8 {
    var isNumeric: Bool {
        return self >= 0x30 && self <= 0x39
    }
}
