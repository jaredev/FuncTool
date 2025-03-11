import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a string containing that expression
///
///     #stringify(x + y)
///
///  will expand to
///
///     "x + y"
public struct StringifyMacro: ExpressionMacro
{
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> ExprSyntax
    {
        guard let argument = node.arguments.first?.expression else
        {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "\(literal: argument.description)"
    }
}

public struct CallToolMacro: ExpressionMacro
{
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> ExprSyntax
    {
        guard let argument = node.arguments.first?.expression else
        {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "\(literal: argument.description)"
    }
}
// @TODO: Remove. Nope, can't introduce struct before/after an attached function in swift macros.
public struct FuncToolMacroAlt: PeerMacro
{
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax]
    {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else
        {
            fatalError("Error: The macro @FuncName can only be used with functions")
        }
        
        typealias Param = (String, String, Bool) // name, type, isRequired
        let name = funcDecl.name.text
        var params: [Param] = []
        
        for param in funcDecl.signature.parameterClause.parameters
        {
            var paramName: String = ""

            // A parameter's firstName is not optional but second one is
            if param.secondName?.text != "_"
            {
                paramName = param.secondName?.text ?? ""
            }
            else
            {
                paramName = param.firstName.text
            }
            
            let typeDesc = String(describing: type(of: param))
            let required = param.defaultValue == nil
            params.append((paramName, typeDesc, required))
        }
        
        if funcDecl.body == nil
        {
            fatalError("@FuncTool could not find the body of the function \(name)")
        }
        
        return[DeclSyntax(stringLiteral:
            """
            struct \(name) 
            { 
                let name = "\(name)" 
                
                func call\(funcDecl.signature)
                \(funcDecl.body!.description)
            }
            """)]
        
        ////                \(funcDecl.description)

//        return [DeclSyntax.init("let test = \"\(funcDecl.description)\"")]
    }
}

public struct MakeToolMacro: ExpressionMacro
{
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> ExprSyntax
    {
        guard let argument = node.arguments.first?.expression else
        {
            fatalError("#Tool: the macro does not have any arguments")
        }
        
        // @TODO: Description
        
        return """
        makeTool(\(raw:argument.description), 
                 stringifiedFunc: #stringify(\(raw:argument.description)), 
                 internalExec: #callFuncWithIndexedParams(\(raw:argument.description)), 
                 usage: "FINISH ME!")
        """
    }
}

public struct CallFuncWithIndexedParamsMacro: ExpressionMacro
{
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> ExprSyntax
    {
        guard let argument = node.arguments.first?.expression else
        {
            fatalError("#Tool: the macro does not have any arguments")
        }
        let funcInput = "\(argument.description)" // Example foo(x:y:)

        let funcParts = funcInput.split(separator: ":") // Example: foo(x:y:) -> ["foo(x", "y", ")"]
        var callWithIndexedParams: String = ""
        var idx: Int = 0

        // Insert parameter values by index yields something like "foo(x:args[0], y:args[1])"
        for part in funcParts
        {
            if (part != ")")
            {
                callWithIndexedParams += part + ":.init(args[\(idx)]) ?? .init(), "
                idx += 1
            }
            else
            {
                callWithIndexedParams.removeLast(2) // Trailing ', '
                callWithIndexedParams += part; // Closing ')'
            }
        }

        // Still errors, compiler thinks its type '()' for some reason even hard coded... Meh.

        return """
        { 
            args in
            \(raw:callWithIndexedParams)
        }
        """
    }
}

@main
struct FuncToolPlugin: CompilerPlugin
{
    let providingMacros: [Macro.Type] =
    [
        StringifyMacro.self,
        CallToolMacro.self,
        CallFuncWithIndexedParamsMacro.self,
        MakeToolMacro.self,
        FuncToolMacro.self,
    ]
}
