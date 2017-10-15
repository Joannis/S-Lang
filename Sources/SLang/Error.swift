enum CompilerError: Error {
    case fileNotFound(atPath: String)
    case missingTypeForDeclaration(String)
    case unknownType(String)
    case unknownStatement(String)
    case unexpectedEOF
    case missingCommaAfterArguments(Arguments)
    case missingReturnType
}
