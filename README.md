# NSLocalizedStringLinter

## What is it?

This is a toy project I used to experiment with `SwiftSyntax` and how to write a custom Swift linter that would parse your Swift code to detect particular call sites.

This idea came up because we brainstormed a way to detect calls to `NSLocalizedString` in our codebase that would be missing the `bundle: .module` call to ensure they would pick the translations from the `Localizable.strings` files of our SwiftPM module we were working on (a framework) and not the ones from the hosting app bundle (aka `Bundle.main`)

<details><summary>Why not just use <tt>swiftlint</tt> for that?</summary>

This type of linting is not really possible easily with tools like `swiftlint` (at least not just using a custom RegEx rule in your `.swiftlint.yml` config file), because you want to:
 - Detect the absence of a parameter (`bundle:`), not its presence. Detecting an occurrence of `NSLocalizedString` (with arbitrary parameters like `value:`, `comment:`, …) but **without** a `bundle:` in its call can lead to quite a tricky RegEx to write in the first place
 - You'd also want to support call sites that are multiline (so that `bundle:` parameter you're looking for can be on a different line than the `NSLocalizedString`)
 - You'd also want to support call sites that might contain multiline strings (those with `"""`)… and maybe those strings themselves contains parentheses and commas in their copy (`"Delete (this is permanent, are you sure?)"`), which might make the RegEx even more difficult to write when trying to split the call site into parameters to detect that `bundle:` parameter or not

</details>

## How does it work?

### The symplicity of `SyntaxVisitor` and the visitor pattern

I was pleasantly surprised to see how easy it was to implement such a linter thanks to `SwiftParser` (to transform a Swift source code into a syntax tree), `SwiftSyntax`, and a custom subclass of `SyntaxVisitor`.

`SyntaxVisitor` is particularly suited for this, since as the name suggests it implements the visitor pattern, and has overloads for each of the type of nodes in your syntax tree you could be interested to visit.

For my case I was only interested in nodes corresponding to function calls, so all I had to do was override `func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind` in my custom subclass of `SyntaxVisitor`, then check if that `node.calledExpression` corresponded to a call to the `NSLocalizedString` function, and from there get the `node.arguments` to find if there was one labeled `bundle:` and if that argument's `expressions` was the expected `.module` or `Bundle.module` string.

Once I got that `NSLocalizedStringVisitor` subclass with its custom overload for `FunctionCallExprSyntax`, all I had to do to use it was:

```swift
let source: String = // swift source code; probably read from String(contentsOfFile: <#path to swift source file #>)
Parser.parse(source: source)
let visitor = NSLocalizedStringVisitor()
visitor.walk(tree)
```

### Converting `AbsolutePosition` of found nodes to `SourceLocation`

When you visit a Syntax tree, you can get the `AbsolutePosition` of a node. An `AbsolutePosition` is basically just an offset in the Unicode stream of characters that is the source code.

More precisely, you can get the `AbsolutePosition` of various points in the node, from its start `position`, to its `endPosition` to the position after the leading trivia (the "trivia" is things like whitespaces and comments around a node) or before the trailing trivia.

But to report an error to the user, it's usually more useful to report a `SourceLocation`, which corresponds to a file name, line and column.

You can use `SourceLocationConverter` to convert from/to an `AbsolutePosition` and its corresponding `SourceLocation` in source.

Using this allowed me to make my parser report the linter violations it found in the format of `\(file):\(line):\(column): error: \(message)`, which is recognized by Xcode when it appears in logs of Build Phases, making it report those are errors in the Xcode UI.
That means you can then use this small executable in a Script Build Phase of an Xcode project for example and have it report the violations it found as errors in Xcode's UI.

