import LLVM
import Foundation

let project = Project(named: "test")

project.append(file: try SourceFile(atPath: "/Users/joannisorlandos/Desktop/testexec.slang", project: project))

let object = try project.compile(dumping: true)

@discardableResult
func shell(path launchPath: String, args arguments: [String]) -> String {
    let process = Process()
    process.launchPath = launchPath
    process.arguments = arguments
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let result = String(data: data, encoding: .utf8)!
    
    if result.characters.count > 0 {
        let lastIndex = result.index(before: result.endIndex)
        return String(result[result.startIndex ..< lastIndex])
    }
    
    return result
}

func getClangPath() -> String {
    return shell(path: "/usr/bin/which", args: ["clang"])
}

shell(path: getClangPath(), args: ["-o", "/Users/joannisorlandos/Desktop/testexec", object])
