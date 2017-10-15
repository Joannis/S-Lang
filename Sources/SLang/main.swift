import LLVM
import Foundation

// executable "test"
let testModule = Module(name: "test")

// Generate executable IR
let testModuleBuilder = IRBuilder(module: testModule)

// Add the main function
let mainFunction = testModuleBuilder.addFunction(
    "main",
    type: FunctionType(
        argTypes: [],
       returnType: IntType(width: 64)
    )
)

let entry = mainFunction.appendBasicBlock(named: "entry")
testModuleBuilder.positionAtEnd(of: entry)

let constant = IntType.int64.constant(21)
let sum = testModuleBuilder.buildAdd(constant, constant)
testModuleBuilder.buildRet(sum)

try testModule.verify()
try TargetMachine().emitToFile(module: testModule, type: .object, path: "/Users/joannisorlandos/Desktop/testexec.o")

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

shell(path: getClangPath(), args: ["-o", "/Users/joannisorlandos/Desktop/testexec", "/Users/joannisorlandos/Desktop/testexec.o"])
