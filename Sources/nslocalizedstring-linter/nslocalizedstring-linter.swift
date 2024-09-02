import Foundation
import NSLocalizedStringLinter

@main struct CLI {
  // This is the executable entry point
  //
  // It parses the command line arguments and calls the `NSLocalizedStringLinter` appropriately
  //
  // Note: Maybe one day we should migrate this code to use SwiftArgumentsParser.
  // For the time being the need was simple enough to make do with directly using `CommandLine.arguments` though.
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      print("error: Not enough arguments!")
      return
    }
    let path = CommandLine.arguments[1]

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
      print("error: File doesn't exist at path: \(path)")
      return
    }

    var violations: [NSLocalizedStringLinter.DetectedCall]
    let linter = NSLocalizedStringLinter()

    if !isDir.boolValue && FileManager.default.isReadableFile(atPath: path) {
      // Single file
      violations = try linter.lint(path: path)
    } else if isDir.boolValue, let dirEnum = FileManager.default.enumerator(
        at: URL(filePath: path),
        includingPropertiesForKeys: [.isRegularFileKey, .isReadableKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) {
      // Directory found, enumerate all the *.swift files in it recursively
      violations = []
      for case let fileURL as URL in dirEnum where fileURL.pathExtension == "swift" {
        let flags = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
        if flags.isRegularFile! && flags.isReadable! {
          print("Parsing: \(fileURL.path(percentEncoded: false))...")
          violations += try linter.lint(path: fileURL.path(percentEncoded: false))
        }
      }
    } else {
      fatalError("Unable to read input path")
    }

    print("\(violations.count) violations found.")
    print(violations.map(\.description).joined(separator: "\n\n"))
  }
}
