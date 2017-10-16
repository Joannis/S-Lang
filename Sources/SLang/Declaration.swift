enum Declaration {
    case global(named: String, type: LanguageType)
    case function(named: String, signature: Signature)
}
