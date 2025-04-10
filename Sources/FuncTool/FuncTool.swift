// MIT License. Copyright Charles Jared Jetsel 2025
import Foundation

/// Creates a string literal of given expression
@freestanding(expression)
public macro stringify<T>(_ value: T) -> String = #externalMacro(module: "FuncToolMacros", type: "StringifyMacro")

/// Creates a closure which calls the given function with indexed args[i] parameters
///
/// For example
/// `#callFuncWithIndexedParams(foo(a:b:))`
/// expands to
/// ```swift
/// {
///     args in
///     foo(a:.init(args[0]?? .init(), args[1]?? .init())
/// }
/// ```
/// - Note: For this to work, the parameter types have to be constructable from a String
@freestanding(expression)
public macro callFuncWithIndexedParams<T>(_ value: T) -> ([String]) -> Any = #externalMacro(module: "FuncToolMacros", type: "CallFuncWithIndexedParamsMacro")

public typealias ToolSpec = [String: any Sendable]

/// Describes an individual function parameter for a FuncTool
public struct FuncToolParam
{
    let name: String
    let typeDesc: String
    let isRequired: Bool
    var usage: String
    
    /// Constructs a FuncToolParam
    ///
    /// - Parameters:
    ///     - name: Name of the function parameter
    ///     - typeDesc: String description of the type of the parameter
    ///     - usage: Documentation and instruction on the usage of the parameter. Like what would appear in documentation comments.
    ///     - isRequired: Indicates that the parameter is required (no default argument). Defaults to true
    init(name: String, typeDesc: String, usage: String = "", isRequired: Bool = true)
    {
        self.name = name
        self.typeDesc = typeDesc
        self.usage = usage
        self.isRequired = isRequired
    }
}

/// Stores details about a function so that its name and parameters can be easily handed to an MLX LLM
///
/// Note: This can be generated by the #tool() macro to make things easy
public struct FuncTool: Copyable, CustomStringConvertible
{
    /// Name of the function this tool calls
    public let name: String
    
    /// A description of what the function does and how to use it
    public let usage: String
    
    /// An array of parameter descriptions
    public let parameters: [FuncToolParam]
    
    public var description: String
    {
        var desc: String = "\tName:  \(name)\n"
        desc += "\tUsage: \(usage)\n"
        desc += "\tFunc:  \(name)("
        
        for param in parameters
        {
            desc += "\(param.name): \(param.typeDesc), "
        }
        
        if !parameters.isEmpty
        {
            desc.removeLast(2)
        }
        
        desc += ")\n"
        return desc
    }
    
    /// A closure that executes the underlying function the tool wraps.
    /// - Parameters:
    ///     - args: An array of Any parameters. These are handed in order to parameters to the function. These _must_ be convertible to the parameter types!
    ///
    /// - Returns: The closure must return a string to send along the LLM, this means the underlying function's return type must be convertible to String!
    public let exec: (_ args: [String]) -> String
        
    public init(name: String, usage: String, parameters: [FuncToolParam], exec: @escaping (_ args: [String]) -> String)
    {
        self.name = name
        self.usage = usage
        self.parameters = parameters
        self.exec = exec
    }
    
    /// The specification of the tool to inform an LLM with
    ///
    /// - See: `swift-transformers Tokenizer.swift ToolSpec`
    public func toolSpec() -> ToolSpec
    {
        var properties: [String: [String: any Sendable]] = [:]
        var required: [String] = []

        if parameters.count > 0
        {
            
            for p in parameters
            {
                properties[p.name] =
                [
                    "type": p.typeDesc,
                    "description": p.usage,
                ] as [String: String]
                
                if p.isRequired
                {
                    required.append(p.name)
                }
            }
        }
        
        let spec: ToolSpec =
        [
            "type": "function",
            "function":
            [
                "name": "\(name)",
                "description": "\(usage)",
                "parameters":
                [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ] as [String: any Sendable],
            ] as [String: any Sendable],
        ] as [String: any Sendable]

        return spec
    }
}

/// Tuple of a function's parameter type names and return type as Strings
typealias FuncParamsAndReturnTypes = (paramTypes: [String], returnType: String)

/// Extracts type info from a function stub to extract its parameter types and return types
@available(macOS 13.0, *)
func funcTypesToStrings<T>(_ function: T) -> FuncParamsAndReturnTypes
{
    let typeInfoStr = String(describing: type(of:function)) // Example (Type,Type) -> ReturnType (or not, doesn't work...)
    var paramTypes: [Substring]
    var finalParamTypes: [String] = []

    // Extract type info from string such as (Type, Type) -> ReturnType
    guard let returnRange = typeInfoStr.firstRange(of:"->") else
    {
        fatalError("FuncTool: A return type is required for all tool functions!")
    }
    let returnTypeStr = String(typeInfoStr.suffix(typeInfoStr.distance(from: returnRange.upperBound, to: typeInfoStr.endIndex)));

    if returnTypeStr.isEmpty || returnTypeStr == "Void"
    {
        fatalError("FuncTool: A return type is required for all tool functions! Input: \(function) with typeInfo: \(typeInfoStr)")
    }
    
    // Extract parameter types
    let startParenTypeRange = typeInfoStr.firstRange(of:"(")
    let endParenTypeRange = typeInfoStr.firstRange(of:")")
    
    if startParenTypeRange == nil || endParenTypeRange == nil
    {
        fatalError("funcTypesToStrings(): Could not find function parameters. Missing parentheses? Input: \(function) with typeInfo: \(typeInfoStr)")
    }
    else
    {
        let allParamTypesRange = startParenTypeRange!.upperBound..<endParenTypeRange!.lowerBound // between ( and )
        paramTypes = typeInfoStr[allParamTypesRange].split(separator: ",")
    }
    
    for paramType in paramTypes
    {
        finalParamTypes.append(String(paramType).trimmingCharacters(in: CharacterSet.whitespaces))
    }
    
    return (finalParamTypes, returnTypeStr)
}

/// Tuple holding a function's name and its parameter names as Strings
typealias FuncDetails = (funcName: String, paramNames: [String])

/// Extracts details of the function name, parameter names, and the function call string from a function
@available(macOS 13.0, *)
func detailsOfStringifiedFunction(_ stringifiedFunc: String, paramTypes: [String]) -> FuncDetails
{
    let funcInput = stringifiedFunc;
    var paramNames: [Substring]
    
    // Extract names from input to macro such as funcName(param:param:)
    let startParenRange = funcInput.firstRange(of:"(")
    let endParenRange = funcInput.firstRange(of:")")
            
    if startParenRange == nil || endParenRange == nil
    {
        fatalError("@FuncTool: Could not find function parameters. Missing parentheses?")
    }
    
    var name = String(funcInput[...startParenRange!.lowerBound])
    name.removeLast() // trailing ')'

    var finalParamNames : [String] = []
    let allParamNamesRange = startParenRange!.upperBound..<endParenRange!.lowerBound // between ( and )
    paramNames = funcInput[allParamNamesRange].split(separator: ":")
    
    for paramName in paramNames
    {
        finalParamNames.append(String(paramName).trimmingCharacters(in: CharacterSet.whitespaces))
    }
    
    return (String(name), finalParamNames)
}

/// Creates a FuncTool for the provided function
///
/// - Parameters:
///     - function: A function stub. Note that this isn't a function call. Parameter names _MUST_ be included for this to work right! Use `foo(a:b:)` instead of `foo()` or `foo(a:1,b:2)`
///     - stringifiedFunc: Stringified version of the function argument using #stringify() macro
///     - internalExec: A closure that calls function with parameters by index of incoming [String] arguments
///     - usage: (Optional) Documentation and explanation of how to use the tool such as documention. This is provided to the AI
///
/// - Returns: A FuncTool struct containing all the details of the function which were extracted
///
/// Example:
/// ```swift
/// makeTool(foo(a:b:),
///     stringifiedFunc: #stringify(foo(a:b:)),
///     internalExec: {
///         args in
///         foo(a:.init(args[0]? .init(), args[1]? .init())
///     },
///     usage: "A function called foo()")
///
/// // But this is _way_ easier with the #tool() macro
/// #tool(foo(a:b:), usage: "A function called foo()")
/// ```
///
/// - See: `#tool()` macro
@available(macOS 13.0, *)
public func makeTool<T>(_ function: T, stringifiedFunc: String, internalExec: @escaping ([String]) -> Any, usage: String = "") -> FuncTool
{
    let (paramTypes, _) = funcTypesToStrings(function)
    let (name, paramNames) = detailsOfStringifiedFunction(stringifiedFunc, paramTypes: paramTypes)
    
    if paramNames.count != paramTypes.count
    {
        fatalError("FuncTool: Parameter type and name mismatch!")
    }
    
    var params : [FuncToolParam] = []
    
    for (idx, paramName) in paramNames.enumerated()
    {
        params.append(FuncToolParam.init(name: paramName, typeDesc: paramTypes[idx]))
    }
        
    return FuncTool(name:name, usage: usage, parameters: params, exec:
    {
        args in
        
        do
        {
            if params.count != args.count
            {
                return "Observation: Error using tool named '\(name)'. The tool '\(name)' expects \(params.count) arguments, but \(args.count) were given."
            }
            
            let result = internalExec(args)
            return "Observation: the tool '\(name)' returned: \(result)"
        }
        catch
        {
            print(error)
        }
    })
}

/// Generates a FuncTool which can easily get a ToolSpec for the given function
///
/// - Parameters:
///     - function: A function stub. Note that this isn't a function call. Parameter names _MUST_ be included for this to work right! Use `foo(a:b:)` instead of `foo()` or `foo(a:1,b:2)`
///     - usage: (Optional) Documentation and explanation of how to use the tool such as documention. This is provided to the AI
///
/// - Returns: A FuncTool struct which has the name, parameter info, and usage of the function to easily hand its ToolSpec to an LLM
@freestanding(expression)
public macro tool<T>(_ function: T, usage: String = "") -> FuncTool = #externalMacro(module: "FuncToolMacros", type: "MakeToolMacro")

/// A registry of tools available to an LLM with an easy call syntax for integration
public struct ToolRegistry: CustomStringConvertible
{
    public typealias ToolResponse = String
    var tools: [String: FuncTool] = [:]
    
    /// Constructs a ToolRegistry with the provided tools
    ///
    /// Example
    /// ```
    /// let registry = ToolRegistry(
    ///     #tool(add(l:r:), usage: "Add to numbers together. l + r"),
    ///     #tool(sub(l:r:), usage: "Subtracts the second number from the first. l - r"),
    ///     #tool(div(l:r:), usage: "Divides the first number by the second. l / r")
    /// )
    ///
    /// // Then somewhere in the LLM code for handling tool calls
    /// let observation = registry.call(toolName, toolParameters)
    ///
    /// // Or used directly
    /// let result = registry.call("div", ["10", "5"])
    /// assert(result == "2")
    /// ```
    public init(withTools: FuncTool...)
    {
        for tool in withTools
        {
            tools[tool.name] = tool
        }
    }

    /// Adds the provided FuncTools to the registry
    ///
    /// - Note: These are keyed by the FuncTool.name to one must avoid duplicates such as overloads!
    public mutating func register(_ tools: FuncTool...)
    {
        for tool in tools
        {
            self.tools[tool.name] = tool
        }
    }
    
    public func count() -> Int
    {
        return tools.count
    }
    
    public func allToolSpecs() -> [ToolSpec]
    {
        var specs : [ToolSpec] = []
        
        for tool in tools
        {
            specs.append(tool.value.toolSpec())
        }
        return specs
    }
    
    /// Call one of the FuncTools that was registered
    ///
    /// - Parameters:
    ///     - toolNamed: The name of the FuncTool
    ///     - withParams: String array of function parameters
    /// - Returns: String representation of the function's response or an error message if something went wrong
    public func call(_ toolNamed: String, withParams: [String]) -> ToolResponse
    {
        if let tool = tools[toolNamed]
        {
            return tool.exec(withParams)
        }
        else
        {
            return "Observation: Error. No tool named '\(toolNamed)' found in the tools registry.\n"
        }
    }
    
    public func call(withJSON: String) -> ToolResponse
    {
        // Decode JSON and extract tool name and parameters
        return "FINISH ME"
    }
        
    public func get(_ toolNamed: String) -> FuncTool?
    {
        return tools[toolNamed]
    }

    public var description: String
    {
        var desc = "\n"
        
        for tool in tools
        {
            desc += "\(tool.value)\n"
        }
        return desc
    }

}
