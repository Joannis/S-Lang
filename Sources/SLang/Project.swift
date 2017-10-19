import LLVM

final class Manager<Type> {
    init() {}
    
    var names = [String]()
    var data = [Type]()
    
    func append(_ data: Type, named name: String) throws {
        if self.names.contains(name) {
            throw CompilerError.redundantDefinitionOfGlobal(name)
        }
        
        self.data.append(data)
        names.append(name)
    }
    
    subscript(name: String) -> Type? {
        var index = 0
        
        while index < names.count {
            if names[index] == name {
                return data[index]
            }
            
            index = index &+ 1
        }
        
        return nil
    }
}

public final class Project {
    var sources = [SourceFile]()
    
    let globals = Manager<Global>()
    let functions = Manager<GlobalFunction>()
    let types = Manager<LanguageType>()
    let name: String
    let module: Module
    let builder: IRBuilder
    
    public init(named name: String) {
        self.name = name
        self.module = Module(name: name)
        self.builder = IRBuilder(module: self.module)
    }
    
    public func append(file: SourceFile) {
        self.sources.append(file)
    }
}

extension Project {
    public func compile(dumping: Bool = false) throws -> String {
        for source in sources {
            try source.compile()
        }
        
        try module.verify()
        
        if dumping {
            module.dump()
        }
        
        let object = "/Users/joannisorlandos/Desktop/\(name).o"
        
        try TargetMachine().emitToFile(module: module, type: .object, path: object)
        
        return object
    }
}
