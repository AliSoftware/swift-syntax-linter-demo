import Foundation
import SwiftParser
import SwiftSyntax

// This is the higher level class encapsulating the Linter

// Its role is simply to expose the high-level `detectCalls` and `linter` methods, which are then responsible for
//  - Parsing the source code into a syntax tree, using `Parser.parse(source:)`
//  - Calling the `NSLocalizedStringVisitor` subclass of `SyntaxVisitor`
//  - Transforming the result (list of detected calls and their absolute position in source) into something more useful to end users
//    (especially transforming the `AbsolutePosition` reported by the visitor into `SourceLocation` representing file:line:column)
public struct NSLocalizedStringLinter {
  // An enum representing a diagnostic if a particular call to NSLocalizedString was using the right parameter for `bundle:` or not
  public enum DiagnosticType: String {
    case valid = "Valid call"
    case missingBundle = "Missing parameter `bundle:`"
    case incorrectBundle = "Incorrect value for parameter `bundle:`"
  }

  // A struct representing a particular call of `NSLocalizedString` detected and reported by the linter
  public struct DetectedCall: CustomStringConvertible {
    let type: DiagnosticType
    let location: SourceLocation
    let sourceLine: String

    // A description of a detected call suitable for Xcode logs
    // Looks like `file:line:column: error: message`
    //   followed by the line of source code where the error appeared
    //   and a `^` below the character where that error appeared to help locate it within the line
    public var description: String {
      let severity = if case type = .valid { "note" } else { "error" }
      return """
      \(location.file):\(location.line):\(location.column): \(severity): \(type.rawValue)
      \(sourceLine)
      \(String(repeating: " ", count: max(0, location.column-1)))^
      """
    }
  }

  public init() {}

  // The main entry point of this class.
  //
  // Walks the tree of the provided source code to detect all the calls to `NSLocalizedString` and report them with a diagnostic.
  // Note that this method returns all the calls, including the ones with `type: .valid`
  //
  public func detectCalls(source: String, fileName: String = "<stdin>") -> [DetectedCall] {
    let tree = Parser.parse(source: source)
    let visitor = NSLocalizedStringVisitor()
    visitor.walk(tree)

    let locationConverter = SourceLocationConverter(fileName: fileName, tree: tree)
    let lines = source.components(separatedBy: .newlines)
    // convert the `AbsolutePosition` (unicode offsets) of the calls detected by the Visitor
    // into `SourceLocation` and code lines in the original source code
    return visitor.foundCalls.map { call in
      let sourceLocation = locationConverter.location(for: call.position)
      return DetectedCall(
        type: call.type,
        location: sourceLocation,
        sourceLine: (lines.indices ~= sourceLocation.line-1) ? lines[sourceLocation.line-1] : ""
      )
    }
  }

  // Does the same as `detectCalls`, but filters out the call sites that were detected as `.valid`,
  // to instead only report the detected errors.
  public func lint(source: String, fileName: String = "<stdin>") -> [DetectedCall] {
    return detectCalls(source: source, fileName: fileName).filter { $0.type != .valid }
  }

  // Convenience method to call `detectCalls` on a file path
  public func detectCalls(path: String) throws -> [DetectedCall] {
    let source = try String(contentsOfFile: path)
    return detectCalls(source: source, fileName: path)
  }

  // Convenience method to call `lint` on a file path
  public func lint(path: String) throws -> [DetectedCall] {
    let source = try String(contentsOfFile: path)
    return lint(source: source, fileName: path)
  }
}

