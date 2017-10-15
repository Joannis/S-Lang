import Foundation

enum State {
    case none
    case declaration
    case type
    case function
}

public final class SourceFile {
    let data: Data
    var position = 0
    var state: State
    
    public init(atPath path: String) throws {
        guard let file = FileManager.default.contents(atPath: path) else {
            throw CompilerError.fileNotFound(atPath: path)
        }
        
        self.data = file
    }
}

