/// Any Top-Level declaration
enum Declaration {
    /// Type definition
    case type(named: String, kind: TypeKind)
    
    /// A global variable
    case global(named: String, type: LanguageType)
    
    /// A 'normal' function definition
    case function(named: String, signature: Signature)
    
    /// An instance-bound function definition
    case instanceFunction(named: String, instance: String, typeName: String, signature: Signature)
}

/// The kind of type definition
enum TypeKind: String {
    case `struct`, model
}
