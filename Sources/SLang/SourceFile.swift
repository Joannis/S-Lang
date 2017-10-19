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
    
    subscript(type expected: String) -> LanguageType? {
        for (name, type, _) in variables where name == expected {
            return type
        }
        
        return self.super?[type: expected]
    }
    
    subscript(expected: String) -> IRValue? {
        for (name, _, value) in variables where name == expected {
            return value
        }
        
        return self.super?[expected]
    }

    init() {}
}

enum BuilderState {
    case global
    case codeBlock
}

final class LanguageType {
    static func getType(named name: String, from project: Project) throws -> LanguageType {
        if let type = project.types[name] {
            return type
        }
        
        return try LanguageType(named: name)
    }
    
    static let primitives = ["Void", "Int8", "Int16", "Int32", "Int64", "struct"]
    
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
        case "struct":
            self.irType = nil
        default:
            throw CompilerError.unknownType(name)
        }
    }
    
    init(named name: String, definition: StructureDefinition) {
        self.name = name
        self.definition = definition
        self.irType = definition.type
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
    let irType: IRType!
    var definition: StructureDefinition?
    var integerLiteral = false
    var void = false
}

struct StructureDefinition {
    var arguments = [(String, LanguageType)]()
    var type: StructType
}

final class GlobalFunction {
    let function: Function
    let signature: Signature
    
    init(function: Function, signature: Signature) {
        self.function = function
        self.signature = signature
    }
}

final class InstanceFunction {
    let instanceType: LanguageType
    let function: Function
    let signature: Signature
    
    init(type: LanguageType , function: Function, signature: Signature) {
        self.instanceType = type
        self.function = function
        self.signature = signature
    }
}

typealias Arguments = [(String, LanguageType)]

struct Signature {
    var arguments: Arguments
    var returnType: LanguageType
    
    init(arguments: Arguments, returnType: LanguageType) {
        self.arguments = arguments
        self.returnType = returnType
    }
}

public final class SourceFile {
    let data: Data
    var position = 0
    var state = State.none
    let project: Project
    var builder: IRBuilder {
        return project.builder
    }
    var builderState = BuilderState.global
    
    public init(atPath path: String, project: Project) throws {
        guard let file = FileManager.default.contents(atPath: path) else {
            throw CompilerError.fileNotFound(atPath: path)
        }
        
        self.data = file
        self.project = project
    }
}

