import LLVM

extension Manager where Type == LanguageType {
    static func `default`() throws -> Manager<LanguageType> {
        let manager = Manager<LanguageType>()
        
        try manager.append(.any)
        try manager.append(.void)
        try manager.append(.bool)
        try manager.append(.int8)
        try manager.append(.int16)
        try manager.append(.int32)
        try manager.append(.int64)
        
        return manager
    }
    
    func append(_ type: LanguageType) throws {
        try self.append(type, named: type.name)
    }
}

final class LanguageType {
    static func getType(named name: String, from project: Project) throws -> LanguageType {
        if let type = project.types[name] {
            return type
        }
        
        return try LanguageType(named: name)
    }
    
    static let primitives = ["Void", "Int8", "Int16", "Int32", "Int64", "struct", "model"]
    
    static let any = try! LanguageType(named: "Any")
    static let void = try! LanguageType(named: "Void")
    static let bool = try! LanguageType(named: "Bool")
    static let int8 = try! LanguageType(named: "Int8")
    static let int16 = try! LanguageType(named: "Int16")
    static let int32 = try! LanguageType(named: "Int32")
    static let int64 = try! LanguageType(named: "Int64")
    
    init(named name: String) throws {
        self.name = name
        
        switch name {
        case "Any":
            self.irType = nil
        case "Void":
            self.irType = VoidType()
            self.void = true
        case "Bool":
            self.irType = IntType(width: 1)
            self.booleanLiteral = true
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
        case "struct", "model":
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
    var booleanLiteral = false
    var integerLiteral = false
    var void = false
}

struct StructureDefinition {
    var arguments = [(String, LanguageType)]()
    var type: StructType
    var kind: TypeKind
}

final class GlobalFunction {
    let function: Function
    let signature: Signature
    var codeBlockPosition: SourcePosition
    
    init(function: Function, signature: Signature, position: SourcePosition) {
        self.function = function
        self.signature = signature
        self.codeBlockPosition = position
    }
}

final class InstanceFunction {
    let functionName: String
    let instanceTypeName: String
    let instanceName: String
    let signature: Signature
    var codeBlockPosition: SourcePosition
    var function: Function?
    
    init(functionName: String, instanceTypeName: String, instanceName: String, signature: Signature, position: SourcePosition) {
        self.functionName = functionName
        self.instanceTypeName = instanceTypeName
        self.instanceName = instanceName
        self.signature = signature
        self.codeBlockPosition = position
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
