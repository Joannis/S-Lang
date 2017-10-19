import Foundation
import LLVM

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

