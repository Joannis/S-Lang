enum State {
    case none
    case declaration(String)
    case type(String, LanguageType)
    case function(String, Signature)
}

enum BuilderState {
    case global
    case codeBlock
}
