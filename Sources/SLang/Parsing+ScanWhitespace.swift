extension SourceFile {
    func skipWhitespace(includingNewline: Bool) {
        while position < data.count {
            guard whitespace.contains(data[position]) else {
                return
            }
            
            if !includingNewline && data[position] == 0x0a {
                return
            }
            
            position = position &+ 1
        }
    }
    
    func assertMoreCharacters() throws {
        guard position < data.count else {
            throw CompilerError.unexpectedEOF
        }
    }
    
    func assertCharactersAfterWhitespace() throws {
        skipWhitespace(includingNewline: true)
        try assertMoreCharacters()
    }
    
    func charactersBeforeNewline() -> Bool {
        skipWhitespace(includingNewline: false)
        
        guard position < data.count else {
            return false
        }
        
        return data[position] != 0x0a
    }
}
