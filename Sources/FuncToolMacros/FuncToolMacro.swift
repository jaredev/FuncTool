// MIT License. Copyright Charles Jared Jetsel 2025
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

/// Generates the `makeTool()` function call to reduce boilerplate of handing the function stub around to the other required macros
public struct MakeToolMacro: ExpressionMacro
{
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) -> ExprSyntax
    {
        guard let argument = node.arguments.first?.expression else
        {
            fatalError("#Tool: the macro does not have any arguments")
        }
        
        if (node.arguments.count > 2)
        {
            fatalError("#makeTool: Too many arguments. Expected 2 got \(node.arguments.count)")
        }
        
        var usage = ExprSyntax("\"\"")
        
        if (node.arguments.count == 2 && node.arguments.last != nil)
        {
            usage = node.arguments.last!.expression
        }
        
        return """
        makeTool(\(raw:argument.description), 
                 stringifiedFunc: #stringify(\(raw:argument.description)), 
                 internalExec: #callFuncWithIndexedParams(\(raw:argument.description)), 
                 usage: \(raw: usage.description))
        """
    }
}

/// Generates an immediately executed closure which takes an arguments array in and calls the function by index
///
/// Note: This uses `.init(args[i]) ?? .init()` for each param to convert from string to the parameter type which could result in default initialization!
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
        CallFuncWithIndexedParamsMacro.self,
        MakeToolMacro.self,
    ]
}
