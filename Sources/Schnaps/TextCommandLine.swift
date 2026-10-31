import Foundation
import MeasurementCore

@MainActor
enum TextCommandLine {
  static func runIfRequested() -> Bool {
    guard CommandLine.arguments.dropFirst().first == "--convert" else { return false }
    do {
      let args = Array(CommandLine.arguments.dropFirst(2))
      let formats: [String: TextEncodingFormat] = [
        "plain": .plain, "html": .html, "url": .url, "c": .cString, "bytes": .bytes,
        "nsdata": .nsData, "names": .named,
      ]
      guard let name = args.first, let format = formats[name] else {
        FileHandle.standardError.write(
          Data(
            "Usage: Schnaps --convert plain|html|url|c|bytes|nsdata|names [--decode] [text]; omitted text reads stdin.\n"
              .utf8))
        exit(2)
      }
      let decode = args.dropFirst().first == "--decode"
      let values = Array(args.dropFirst(decode ? 2 : 1))
      let text =
        values.isEmpty
        ? String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        : values.joined(separator: " ")
      do {
        print(
          try decode ? TextCodec.decode(text, from: format) : TextCodec.encode(text, as: format))
        return true
      } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        exit(1)
      }
    }
  }
}
