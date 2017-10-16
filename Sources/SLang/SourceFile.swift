import Foundation
import LLVM

enum State {
    case none
    case declaration(String)
    case type(String, LanguageType)
    case function(String, Signature)
}

final class Scope {
    var `super`: Scope?
    
    var variables = [(String, LanguageType, IRValue)]()
    
    subscript(expected: String) -> IRValue? {
        for (name, _, value) in variables where name == expected {
            return value
        }
        
        return nil
    }

    init() {}
}

enum BuilderState {
    case global
    case codeBlock
}

struct LanguageType {
    init(named name: String) throws {
        self.name = name
        
        switch name {
        case "Void":
            self.irType = VoidType()
            self.void = true
        case "Int8":
            self.irType = IntType(width: 8)
            self.integerLiteral = true
        case "Int16":
            self.irType = IntType(width: 16)
            self.integerLiteral = true
        case "Int32":
            self.irType = IntType(width: 32)
            self.integerLiteral = true
        case "Int64":
            self.irType = IntType(width: 64)
            self.integerLiteral = true
        default:
            throw CompilerError.unknownType(name)
        }
    }
    
    func makeValue(from literal: String) -> IRValue? {
        switch self.name {
        case "Int8":
            return Int8(literal)
        case "Int16":
            return Int16(literal)
        case "Int32":
            return Int32(literal)
        case "Int64":
            return Int64(literal)
        default:
            return nil
        }
    }
    
    let name: String
    let irType: IRType
    var integerLiteral = false
    var void = false
}

typealias Arguments = [(String, LanguageType)]

struct Signature {
    let arguments: Arguments
    let returnType: LanguageType
    
    init(arguments: Arguments, returnType: LanguageType) {
        self.arguments = arguments
        self.returnType = returnType
    }
}

public final class SourceFile {
    let data: Data
    var position = 0
    var state = State.none
    var builderState = BuilderState.global
    
    public init(atPath path: String) throws {
        guard let file = FileManager.default.contents(atPath: path) else {
            throw CompilerError.fileNotFound(atPath: path)
        }
        
        self.data = file
    }
}

