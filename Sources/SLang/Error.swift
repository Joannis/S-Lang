enum CompilerError: Error {
    case fileNotFound(atPath: String)
    case missingTypeForDeclaration(String)
    case unknownType(String)
    case unknownStatement(String)
    case unknownVariable(String)
    case unknownFunction(String)
    case unknownOperation
    case unexpectedEOF
    case missingCommaAfterArguments(Arguments)
    case missingReturnType
    case missingAssignment
    case redundantDefinitionOfGlobal(String)
}
