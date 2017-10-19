extension SourceFile {
    func scanString() -> String {
        var string = String()
        string.reserveCapacity(64)
        
        while position < data.count {
            if specialCharacters.contains(data[position]) {
                return string
            }
            
            string.append(Character(.init(data[position])))
            position = position &+ 1
        }
        
        return string
    }
    
    func scanNonEmptyString() throws -> String {
        let string = scanString()
        
        guard string.characters.count > 0 else {
            // TODO: Infer types on `=`
            throw CompilerError.unexpectedEOF
        }
        
        return string
    }
}
