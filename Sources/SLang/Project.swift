import LLVM

final class Globals {
    init() {}
    
    var names = [String]()
    var globals = [Global]()
    
    func append(_ global: Global) throws {
        if self.names.contains(global.name) {
            throw CompilerError.redundantDefinitionOfGlobal(global.name)
        }
        
        globals.append(global)
        names.append(global.name)
    }
    
    subscript(name: String) -> Global? {
        var index = 0
        
        while index < names.count {
            if names[index] == name {
                return globals[index]
            }
            
            index = index &+ 1
        }
        
        return nil
    }
}

final class Functions {
    init() {}
    
    var names = [String]()
    var functions = [Function]()
    
    func append(_ function: Function) throws {
        if self.names.contains(function.name) {
            throw CompilerError.redundantDefinitionOfGlobal(function.name)
        }
        
        functions.append(function)
        names.append(function.name)
    }
    
    subscript(name: String) -> Function? {
        var index = 0
        
        while index < names.count {
            if names[index] == name {
                return functions[index]
            }
            
            index = index &+ 1
        }
        
        return nil
    }
}

public final class Project {
    var sources = [SourceFile]()
    
    let globals = Globals()
    let functions = Functions()
    let name: String
    let module: Module
    
    public init(named name: String) {
        self.name = name
        self.module = Module(name: name)
    }
    
    public func append(file: SourceFile) {
        self.sources.append(file)
    }
}

extension Project {
    public func compile() throws -> String {
        let builder = IRBuilder(module: self.module)
        
        for source in sources {
            try source.compile(into: builder)
        }
        
        try module.verify()
        
        let object = "/Users/joannis/Desktop/\(name).o"
        
        try TargetMachine().emitToFile(module: module, type: .object, path: object)
        
        return object
    }
}
