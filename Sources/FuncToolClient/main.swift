// MIT License. Copyright Charles Jared Jetsel 2025
import FuncTool

func foo(a: Int, b: Int) -> Int
{
    return a + b
}

let testStr: String = #stringify(foo(a:b:))

// Structures convertible to string are still okay to return to an LLM
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

func printPerson(p: Person) -> Void
{
    print("\(p)")
}

func invalid()
{
    print("I don't return!")
}

Task
{
    if #available(macOS 13.0, *)
    {
        func add(a: Int = 1, b: Int = -1) -> Int
        {
            return a + b
        }
        
        var registry: ToolRegistry = .init()
        await registry.register(
            #tool(foo(a:b:), usage: "Adds together two numbers a + b"),
            #tool(makePerson(name:age:)),
            #tool(add(a:b:))
            //        #tool(printPerson(p:)) // Error: Cannot convert value of type 'String?' to expected argument type 'Person'. OK for compiler checking error!
            //        #tool(invalid()) // Errors
        )
        print("Tool Registery: \(registry)")
        print(await registry.call("foo", withParams: [String(Int.random(in: 1..<10)), "4"]))
        print(await registry.call("makePerson", withParams: ["Alice", String(Int.random(in:0..<100))]))
        print(await registry.call("add", withParams: []))
    }
}
