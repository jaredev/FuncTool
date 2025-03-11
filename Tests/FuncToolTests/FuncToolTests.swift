import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FuncToolMacros)
import FuncToolMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
]
#endif

final class FuncToolTests: XCTestCase {
    func testMacro() throws {
        #if canImport(FuncToolMacros)
        assertMacroExpansion(
            """
            func add(a: Int, b: Int) -> Int { return a + b }
            #tool(add(a:b:)
            """,
            expandedSource: """
            FuncToolBase(name:"add", parameters: [] description: "FIXME", exec: (_ toolCallArgs: [Any]) -> String 
                {
                    // @TODO: Check number of argument sinput matches!
                    let result = add(a:toolCallArgs[0], b:toolCallArgs[1])
                    return "Observation: the tool add returned: \\(result)"
                }
            )
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringLiteral() throws {
        #if canImport(FuncToolMacros)
        assertMacroExpansion(
            #"""
            #stringify("Hello, \(name)")
            """#,
            expandedSource: #"""
            ("Hello, \(name)", #""Hello, \(name)""#)
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
