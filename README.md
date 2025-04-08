# FuncTool
---

FuncTool is a tool for Large Language Model tool calling to native functions in [Swift](https://github.com/SwiftLang). It was designed as a proof of concept of a `#tool()` macro similar to the `@tool()` macros for other LLM and agentic libraries in Python which automatically extract details about a function for the tool spec for an AI Agent.

This proof of concept shows that it is possible to get at least some of this functionality going in native Swift and generate the `ToolSpec` which is used by [Apple's MLX library](https://github.com/ml-explore/mlx) for on device inference.

## Basic Usage

```swift
// Basic Usage. A function to use as a tool by an AI agent
func getWeather(at: String) { ... }

// Use the #tool() macro with the function name, including its parameter names
let weatherTool = #tool(getWeather(at:), "Get the current weather at a specific location")

// For multiple parameters, each need to be named
func perform(a: Int, b: Int, c: Int) { ... }

// Note each parameter name is included so that the ToolSpec has the names and types of parameters
let performTool = #tool(perform(a:b:c:), "A tool that takes 3 parameters")

// This macro creates a FuncTool object for the function which can generate a ToolSpec including
// the parameter names and their types and the return type for the function.
// These ToolSpecs can be handed to MLX to inform an agent about what tools it has to use
let weatherSpec: ToolSpec = weatherTool.toolSpec()
```

That's it for the basic usage. A single line per function will use Swift's macros to extract the name of the function, the parameter names and types, and the return type of the function. These details are then all used to generate a ToolSpec which is similar to other agentic frameworks in a JSON like format describing the tool. These can then be handed to MLX to simplify adding tools to an MLX based agent for native Swift function calling.

## Tool calling

A FuncTool object can be invoked with the `call` method. The `#tool()` macro wraps a closure which performs the underlying function call and converts parameters from string to the function's parameter types. Be aware that this prototype assumes that the parameters are **convertible from String**.

The underlying macro does something similar to

```swift
    // For n parameters
    let result = wrappedFunction(param: .init(stringParam[0]) ?? .init())
```

So be aware that this has its limitation if the parameter is not convertible or constructible from `String` then it will be default initialized for that parameter! Potentially, a more robust and type safe solution could be done to expand upon this concept later. For example, converting JSON strings into objects that are encodable/decodable and so forth. However this is beyond the scope of this proof of concept.

To call a `FuncTool` object's underlying function use `exec`. `exec()` expects an array of Strings and that the number of parameters match. 

```swift   
let result = weatherTool.exec(["Seattle, WA"]) // calls getWeather(at:"Seattle, WA")
```

## Tool registry

To simplify the process of calling a variable assortment of tools from an AI Agent in MLX, the `ToolRegistry` struct holds a collection of `FuncTool` instances which can be called by name if the agent requests a tool call from the LLM. Multiple tools can be inline added to the registry but also appended later. Be aware that these are keyed in a dictionary by name so avoid using the name for multiple functions (including overloads).

```swift
    func add(a: Int = 1, b: Int = -1) -> Int
    {
        return a + b
    }

    var registry: ToolRegistry = .init()
    await registry.register(
        #tool(getWeather(at:), usage: "Get the current weather at a specific location"),
        #tool(perform(a:b:c:), "A tool that takes 3 parameters"),
        #tool(add(a:b:))
    )
    print("Tool Registery: \(registry)")
    print(await registry.call("getWeather", withParams: ["Mountain View, CA"]))
    print(await registry.call("perform", withParams: ["1", "2", "3"])
    print(await registry.call("add", withParams: ["32", "32"]))
``` 

The usage here then would be to check for tool calls from an LLM and then use that tool call json to get the name and parameters and use those to invoke the function in the registry and return the response observation as a String.

## Takeaways and Observations

Initially this prototype's goal was to mimick the type of `@tool` macros used in other agentic AI libraries in Python. Where these would extract documentation comments and details about a function for easy integration into a tool calling LLM agent. 

The approach was to utilize Swift's macro capabilities to do this. Earlier approaches attempted to have the `#tool()` macro immediately before a function declaration however it appeared that doing code generation like generating a struct which invokes the attached function after the macro was not permitted by Swift's macro system. That attached macros can modify a function's declaration but it can't add a struct before it to call that function (yet). 

So instead the macro just takes the symbol of the function including its parameters. This is then used to do a combination of macro stringification which breaks the function into chunks to insert the necessary syntax for function calling of the tool with variable parameters and utilization of `String(describing: type(of:function))` to get the type information. This managed to get *most* of the relevant details for easy tool calling in native swift with the major exception being the lack of documentation reading. The solution for now was to just write the documentation as a parameter in the macro itself such as `#tool(f(x:), "f()'s documentation")`. 

If this were to be more competitive with recent Python tooling then having a means of also getting documentation comments would be useful to reduce boilerplate.



