import SwiftSyntax

// This is a subclass of SyntaxVisitor implementing the visitor pattern only for the function calls
// so that we can detect call sites to `NSLocalizedString` and report them as a list
//
internal class NSLocalizedStringVisitor: SyntaxVisitor {
  // Structure to report the result of found calls in the visited syntax tree
  struct DetectedCall {
    let type: NSLocalizedStringLinter.DiagnosticType
    let position: AbsolutePosition
  }
  private(set) var foundCalls: [DetectedCall] = []

  // Convenience init
  init() {
    super.init(viewMode: .fixedUp)
  }

  // We only need to visit function calls found in the syntax tree
  override internal func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
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
