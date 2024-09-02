import XCTest
import NSLocalizedStringLinter

// Note: I'd love to use SwiftTesting instead of XCTest but I wrote this toy project while Swift 6 was barely out
// So SwiftTesting was not available in latest stable Xcode and too new to adopt for me yet. Maybe later.

class NSLocalizedStringLinterTests: XCTestCase {
  let linter = NSLocalizedStringLinter()

  func testValidImplicitType() {
    let source = """
      let string = NSLocalizedString("key1", bundle: .module, value: "value1", comment: "comment1")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertTrue(result.isEmpty)
  }

  func testValidExplicitType() {
    let source = """
      let str = NSLocalizedString("key2", bundle: Bundle.module, value: "value2", comment: "comment2")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertTrue(result.isEmpty)
  }

  func testValidImplicitMultilineWithTrivia() {
    let source = """
      let str = NSLocalizedString(
        "key3",
        bundle: /* be sure to get the string from the Package */ .module  , // it's easy to forget this argument, but be sure not to
        value: "value3",
        comment: "comment3"
      )
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertTrue(result.isEmpty)
  }

  func testMissingBundle() {
    let source =
      """
      let str = NSLocalizedString("key", value: "value", comment: "comment1")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.description, """
      test.swift:1:11: error: Missing parameter `bundle:`
      let str = NSLocalizedString("key", value: "value", comment: "comment1")
                ^
      """)
  }

  func testDontDetectCommentedLines() {
    let source =
      """
      // let str = NSLocalizedString("key", value: "value", comment: "comment1")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertTrue(result.isEmpty)
  }

  func testInvalidMainBundle() {
    let source = """
      let str = NSLocalizedString("key", bundle: .main, value: "value", comment: "comment")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.description, """
      test.swift:1:36: error: Incorrect value for parameter `bundle:`
      let str = NSLocalizedString("key", bundle: .main, value: "value", comment: "comment")
                                         ^
      """)
  }

  func testUnsupportedComplexExpression() {
    let source = """
      let str = NSLocalizedString("key", bundle: GetKlass("Bundle").module, value: "value", comment: "comment")
      """
    let result = linter.lint(source: source, fileName: "test.swift")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.description, """
      test.swift:1:36: error: Incorrect value for parameter `bundle:`
      let str = NSLocalizedString("key", bundle: GetKlass("Bundle").module, value: "value", comment: "comment")
                                         ^
      """)
  }

  func testComplexCodeWithFailures() throws {
    let fixturePath = Bundle.module.path(forResource: "NSLocalizedStringFixture.swift", ofType: "fixture", inDirectory: "Fixtures")!
    let source = try! String(contentsOfFile: fixturePath)
    let result = linter.detectCalls(source: source, fileName: "NSLocalizedStringFixture.swift")

    XCTAssertEqual(result.count, 4)
    XCTAssertEqual(result[0].description,
      """
      NSLocalizedStringFixture.swift:9:12: note: Valid call
        let s1 = NSLocalizedString("key1", bundle: .module, value: "value1", comment: "comment1")
                 ^
      """)
    XCTAssertEqual(result[1].description,
      """
      NSLocalizedStringFixture.swift:11:12: error: Missing parameter `bundle:`
        let s2 = NSLocalizedString("key2", value: "value2", comment: "comment2")
                 ^
      """)
    XCTAssertEqual(result[2].description,
      """
      NSLocalizedStringFixture.swift:13:38: error: Incorrect value for parameter `bundle:`
        let s3 = NSLocalizedString("key3", bundle: .main, value: "value3", comment: "comment3")
                                           ^
      """)
    XCTAssertEqual(result[3].description,
      """
      NSLocalizedStringFixture.swift:15:16: note: Valid call
        let format = NSLocalizedString(
                     ^
      """)
  }
}
