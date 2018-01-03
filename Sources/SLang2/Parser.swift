import Foundation
import Bits

final class Parser {
    let file: Data
    var offset = 0
    var size: Int
    var ast = AST()
    
    init(_ path: String) {
        self.file = FileManager.default.contents(atPath: path)!
        self.size = file.count
    }
    
    var state: State = .none
    
    func parse() -> AST {
        
        while offset < size {
            guard let keyword = parseKeyword() else {
                return ast
            }
            
            switch keyword {
            case .func:
                let function = parseFunction()
                ast.functions[function.name] = function
            case .let:
                fatalError()
            case .var:
                fatalError()
            case .model:
                fatalError()
            case .data:
                fatalError()
            case .return:
                fatalError() // NO can do
            }
        }
        
        return ast
    }
    
    func parseFunction() -> AST.Function {
        let name = parseString(until: [.leftParenthesis, .space]).assert()
        
        // Parameters
        token(.leftParenthesis)
        let parameters = parseFunctionParameters()
        token(.rightParenthesis)
        
        // Return
        token(.hyphen)
        token(.greaterThan)
        
        let returnType = parseString().assert()
        
        // Code
        token(.leftCurlyBracket)
        let body = parseBody()
        token(.rightCurlyBracket)
        
        return AST.Function(name: name, parameters: parameters, returnType: returnType, body: body)
    }
    
    func parseFunctionParameters() -> [AST.Parameter] {
        var parameters = [AST.Parameter]()
        
        while moreBytes {
            guard file[offset] != .rightParenthesis else {
                return parameters
            }
            
            let name = parseString().assert()
            token(.colon)
            let value = parseString().assert()
            
            parameters.append(.init(name: name, value: value))
        }
        
        // EOF
        fatalError()
    }
    
    func parseBody() -> [AST.Statement] {
        var statements = [AST.Statement]()
        
        while moreBytes {
            guard file[offset] != .rightCurlyBracket else {
                return statements
            }
            
            let keyword = parseString().assert()
            
            if let keyword = Keyword(rawValue: keyword) {
                switch keyword {
                case .func, .data, .model:
                    fatalError()
                case .var, .let:
                    let name = parseString().assert()
                    
                    token(.colon)
                    let type = parseString().assert()
                    
                    token(.equals)
                    let firstStatementToken = parseString().assert()
                    let value = parseStatement(name: firstStatementToken)
                    
                    statements.append(
                        .createVariable(name: name, value: value, type: type, constant: keyword == .let)
                    )
                case .return:
                    if hasToken(.rightCurlyBracket) {
                        return statements
                    }
                    
                    let lastStatement = parseString().assert()
                    
                    statements.append(.return(parseStatement(name: lastStatement)))
                }
            } else {
                _ = parseFunctionCall(to: keyword)
            }
        }
        
        return statements
    }
    
    func parseStatement(name token: String) -> AST.Value {
        if hasToken(.leftParenthesis) {
            return .returnValue(parseFunctionCall(to: token))
        } else {
            return .tokens([token] + tokensUntilEOL())
        }
    }
    
    func parseFunctionCall(to function: String) -> AST.FunctionCall {
        fatalError()
    }
    
    func tokensUntilEOL() -> [String] {
        var base: Int?
        var tokens = [String]()
        
        func appendBase() {
            if let base = base {
                guard let string = String(data: file[base..<offset], encoding: .utf8) else {
                    fatalError()
                }
                
                tokens.append(string)
            }
        }
        
        while moreBytes, file[offset] != .newLine {
            defer { offset = offset &+ 1 }
            
            guard file[offset] != .space && file[offset] != .carriageReturn else {
                appendBase()
                
                base = nil
                continue
            }
            
            if base == nil {
                base = offset
            }
        }
        
        appendBase()
        
        return tokens
    }
    
    var moreBytes: Bool {
        return offset < size
    }
    
    func hasToken(_ byte: Byte) -> Bool {
        let base = offset
        defer { offset = base }
        skipWhitespace()
        
        guard moreBytes, file[offset] == byte else {
            return false
        }
        
        return true
    }
    
    func token(_ byte: Byte) {
        skipWhitespace()
        
        guard moreBytes, file[offset] == byte else {
            fatalError()
        }
        
        offset = offset &+ 1
    }
    
    func skipWhitespace() {
        while moreBytes {
            if whitespace.contains(file[offset]) {
                offset = offset &+ 1
            } else {
                return
            }
        }
    }
    
    func parseKeyword() -> Keyword? {
        guard let string = parseString() else {
            return nil
        }
        
        return Keyword(rawValue: string)
    }
    
    func parseString(until tokens: [Byte] = endOfToken) -> String? {
        guard let token = parseToken(until: tokens) else {
            return nil
        }
        
        return String(data: file[token.from ... token.to], encoding: .utf8)
    }
    
    func parseToken(until tokens: [Byte] = whitespace) -> Token? {
        skipWhitespace()
        
        let base = offset
        
        while moreBytes {
            offset = offset &+ 1
            
            if tokens.contains(file[offset]) {
                return Token(from: base, to: offset &- 1)
            }
        }
        
        return nil
    }
}

let whitespace: [Byte] = [.space, .newLine, .carriageReturn]
let specialCharacters: [Byte] = [.leftParenthesis, .rightParenthesis, .leftCurlyBracket, .rightCurlyBracket, .colon, .equals]
let endOfToken = whitespace + specialCharacters

struct Token {
    var from: Int
    var to: Int
}

enum Keyword: String {
    case model, data, `var`, `let`, `func`, `return`
}

enum State {
    case none
    case keyword(Keyword)
}

extension Optional {
    func assert() -> Wrapped {
        return self!
    }
}

struct AST {
    var functions = [String: Function]()
    
    struct ASTType {
        var name: String
    }
    
    struct Parameter {
        var name: String
        var value: String
    }
    
    enum Statement {
        case createVariable(name: String, value: Value, type: String, constant: Bool)
        case `return`(Value)
    }
    
    enum Value {
        case returnValue(FunctionCall)
        case tokens([String])
    }
    
    struct Function {
        var name: String
        var parameters: [Parameter]
        var returnType: String
        var body = [Statement]()
    }
    
    struct Return {
        var value: Value
    }
    
    struct FunctionCall {
        var name: String
        var parameters: [Parameter]
    }
}
