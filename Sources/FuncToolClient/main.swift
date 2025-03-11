import FuncTool

let a = 17
let b = 25

//let (result, code) = #stringify(a + b)
//
//print("The value \(result) was produced by the code \"\(code)\"")


func foo(a: Int, b: Int) -> Int
{
    return a + b
}

let testStr: String = #stringify(foo(a:b:))

var closure: (_ args: [Any]) -> String

closure = {
    args in
    return "Test"
};

// Testing any conversion with init?
var anyInt: Any = 5
//foo(a: .init(anyInt), b: 5) // Nope: Error: Initializer init(_:) requires that 'T' conform to 'BinaryInteger'

var intConstruct: Int = Int() // Okay
//foo(a: try .init("5"), b: 4) // Nope. Error: Int? must be unwrapped to value of type 'Int'

//func implicit<V>(_ x: Any) -> V
//{
//    return x as? V ?? V() // Error: Type 'V' has no member init (but Int does...)
//}

//foo(a: .init(implicit(anyInt)), b: 5) // Error: Ambiguous use of init(), raw Int.init() and Int.init<S>() it looks like


//func unwrapOrThrow<T>(_ value: Any) throws  -> T
//{
//    guard let converted = value as T else // Error: Any/String is not converrible to 'T'
//    {
//        throw "Could not convert string parameter to parameter type!"
//    }
//}

struct Person: CustomStringConvertible
{
    var description: String
    {
        get
        {
            return "\(name) is \(age) years old"
        }
    }
    
    let name: String
    let age: Int
 
}

func makePerson(name: String, age: Int) -> Person
{
    return Person(name: name, age: age)
}

if #available(macOS 13.0, *)
{
    
    
    //    let realToolTest = makeTool(foo(a:b:), stringifiedFunc: #stringify(foo(a:b:)), internalExec: #callFuncWithIndexedParams(foo(a:b:)), description: "A function called foo()")
    
    // Shortened!
    let aTool = #tool(foo(a:b:))
    
    print("FuncTool for \(aTool)\n")
    let results = aTool.exec(["40","2"])
    print("Results: '\(results)'\n")
    
    //let invalidParamTest = #Tool(4)
    
    // Nope...
    //let aTool: FuncToolBase = tool(foo(a:b:))  // ERROR: Cannot convert value of type '()' to specified type FuncToolBase. Why? Dunno
    
    //let funcTypeStr = #funcTypeString(foo(a:b:))
    //let anotherTool: FuncToolBase = #makeTool(foo(a:b:), functionTypeString: funcTypeStr)
    
//    let toolEntry =
    
    func invalid()
    {
        print("I don't return!")
    }
    
    func add(a: Int = 1, b: Int = -1) -> Int
    {
        return a + b
    }
    
    var toolRegistry: ToolRegistry = .init()
    toolRegistry.register(
        #tool(foo(a:b:)),
        #tool(makePerson(name:age:)),
        #tool(add(a:b:))
//        #tool(invalid()) // Errors
        //    #Tool(foo)
    )
    print("Tool Registery: \(toolRegistry)")
    print(toolRegistry.call("foo", withParams: ["3", "4"]))
    print(toolRegistry.call("makePerson", withParams: ["Alice", "30"]))
    print(toolRegistry.call("add", withParams: []))
}

