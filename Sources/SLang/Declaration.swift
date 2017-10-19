enum Declaration {
    case type(named: String, kind: TypeKind)
    case global(named: String, type: LanguageType)
    case function(named: String, signature: Signature)
}

enum TypeKind {
    case `struct`
}
