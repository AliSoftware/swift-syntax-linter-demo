import Foundation
import SwiftParser
import SwiftSyntax

public struct NSLocalizedStringLinter {
  public enum DiagnosticType: String {
    case valid = "Valid call"
    case missingBundle = "Missing parameter `bundle:`"
    case incorrectBundle = "Incorrect value for parameter `bundle:`"
  }

  public struct DetectedCall: CustomStringConvertible {
    let type: DiagnosticType
    let location: SourceLocation
    let sourceLine: String

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

  public func detectCalls(source: String, fileName: String = "<stdin>") -> [DetectedCall] {
    let tree = Parser.parse(source: source)
    let visitor = NSLocalizedStringVisitor()
    visitor.walk(tree)

    let locationConverter = SourceLocationConverter(fileName: fileName, tree: tree)
    let lines = source.components(separatedBy: .newlines)
    return visitor.foundCalls.map { call in
      let sourceLocation = locationConverter.location(for: call.position)
      return DetectedCall(
        type: call.type,
        location: sourceLocation,
        sourceLine: (lines.indices ~= sourceLocation.line-1) ? lines[sourceLocation.line-1] : ""
      )
    }
  }

  public func lint(source: String, fileName: String = "<stdin>") -> [DetectedCall] {
    return detectCalls(source: source, fileName: fileName).filter { $0.type != .valid }
  }

  public func detectCalls(path: String) throws -> [DetectedCall] {
    let source = try String(contentsOfFile: path)
    return detectCalls(source: source, fileName: path)
  }

  public func lint(path: String) throws -> [DetectedCall] {
    let source = try String(contentsOfFile: path)
    return lint(source: source, fileName: path)
  }
}

private class NSLocalizedStringVisitor: SyntaxVisitor {
  struct DetectedCall {
    let type: NSLocalizedStringLinter.DiagnosticType
    let position: AbsolutePosition
  }
  private(set) var foundCalls: [DetectedCall] = []

  init() {
    super.init(viewMode: .fixedUp)
  }

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    // Exit early if not a function call to `NSLocalizedString`
    guard
      let decl = node.calledExpression.as(DeclReferenceExprSyntax.self),
      decl.baseName.text == "NSLocalizedString"
      else { return super.visit(node) }

    // Find the `bundle:` argument in the function call
    guard let bundleArg: LabeledExprSyntax = node.arguments.first(where: { arg in arg.label?.text == "bundle" }) else {
      // `bundle:` parameter was missing
      foundCalls.append(.init(type: .missingBundle, position: node.positionAfterSkippingLeadingTrivia))
      return super.visit(node)
    }

    // Get the value of that argument (without surrounding trivia if any)
    let bundleArgValue = bundleArg.expression.trimmedDescription
    guard bundleArgValue == ".module" || bundleArgValue == "Bundle.module" else {
      // `bundle:` parameter present but not using `.module`
      foundCalls.append(.init(type: .incorrectBundle, position: bundleArg.positionAfterSkippingLeadingTrivia))
      return super.visit(node)
    }

    // valid call
    foundCalls.append(.init(type: .valid, position: node.positionAfterSkippingLeadingTrivia))
    return super.visit(node)
  }
}
