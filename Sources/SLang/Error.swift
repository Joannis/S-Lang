enum CompilerError: Error {
    case fileNotFound(atPath: String)
    case missingTypeForDeclaration(String)
    case unknownType(String)
    case unknownStatement(String)
    case unknownVariable(String)
    case unknownFunction(String)
    case unknownOperation
    case invalidTypeDefinition
    case invalidMember(String)
    case unexpectedEOF
    case missingCommaAfterArguments
    case missingReturnType
    case missingAssignment
    case tooManyArguments
    case redundantDefinitionOfGlobal(String)
}
