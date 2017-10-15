import LLVM

public final class Project {
    var sources = [SourceFile]()
    
    let module: Module
    
    public init(named name: String) {
        self.module = Module(name: name)
    }
    
    public func append(file: SourceFile) {
        self.sources.append(file)
    }
}

