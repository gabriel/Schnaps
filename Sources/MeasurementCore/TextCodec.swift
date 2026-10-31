import Foundation

public enum TextEncodingFormat: String, CaseIterable, Sendable {
  case plain = "Plain text"
  case html = "HTML entities"
  case url = "URL encoding"
  case cString = "C string"
  case bytes = "UTF-8 bytes"
  case nsData = "NSData"
  case named = "Unicode names"
}
public enum TextCodecError: Error, LocalizedError {
  case invalid(String)
  public var errorDescription: String? {
    if case .invalid(let text) = self { return text }
    return nil
  }
}
public enum TextCodec {
  public static func encode(_ text: String, as format: TextEncodingFormat) -> String {
    switch format {
    case .plain: return text
    case .url:
      return text.addingPercentEncoding(
        withAllowedCharacters: CharacterSet(
          charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))
        ?? text
    case .html:
      return text.unicodeScalars.map { scalar in
        switch scalar.value {
        case 38: "&amp;"
        case 60: "&lt;"
        case 62: "&gt;"
        case 34: "&quot;"
        case 39: "&#39;"
        case 32...126: String(scalar)
        default: "&#x\(String(scalar.value,radix:16).uppercased());"
        }
      }.joined()
    case .cString:
      return "\""
        + text.unicodeScalars.map { s in
          switch s.value {
          case 10: "\\n"
          case 13: "\\r"
          case 9: "\\t"
          case 0: "\\000"
          case 34: "\\\""
          case 92: "\\\\"
          case 32...126: String(s)
          case 0...0xffff: String(format: "\\u%04X", s.value)
          default: String(format: "\\U%08X", s.value)
          }
        }.joined() + "\""
    case .bytes: return text.utf8.map { String(format: "%02X", $0) }.joined(separator: " ")
    case .nsData: return "<" + text.utf8.map { String(format: "%02x", $0) }.joined() + ">"
    case .named:
      return text.unicodeScalars.map {
        String(format: "U+%04X", $0.value) + " " + ($0.properties.name ?? "UNNAMED")
      }.joined(separator: "\n")
    }
  }
  public static func decode(_ text: String, from format: TextEncodingFormat) throws -> String {
    switch format {
    case .plain: return text
    case .url:
      guard let result = text.removingPercentEncoding else {
        throw TextCodecError.invalid("Invalid percent encoding.")
      }
      return result
    case .bytes, .nsData:
      let value = text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(
        in: CharacterSet(charactersIn: "<>"))
      let hex = value.filter { !$0.isWhitespace }
      guard hex.count % 2 == 0, hex.allSatisfy({ $0.isHexDigit }) else {
        throw TextCodecError.invalid("Enter pairs of hexadecimal UTF-8 bytes.")
      }
      var data = Data()
      var index = hex.startIndex
      while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        data.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
      }
      guard let decoded = String(data: data, encoding: .utf8) else {
        throw TextCodecError.invalid("These bytes are not valid UTF-8.")
      }
      return decoded
    case .html:
      let regex = try NSRegularExpression(
        pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]+);")
      let source = text as NSString
      var result = text
      for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        .reversed()
      {
        let entity = source.substring(with: match.range(at: 1))
        var decoded: String?
        if entity.hasPrefix("#") {
          let hex = entity.lowercased().hasPrefix("#x")
          let number = String(entity.dropFirst(hex ? 2 : 1))
          if let code = UInt32(number, radix: hex ? 16 : 10), let scalar = Unicode.Scalar(code) {
            decoded = String(scalar)
          } else {
            throw TextCodecError.invalid("Invalid HTML Unicode character reference.")
          }
        } else {
          decoded = HTMLEntities.values[entity]
        }
        if let decoded, let range = Range(match.range, in: result) {
          result.replaceSubrange(range, with: decoded)
        }
      }
      return result
    case .cString:
      var input = Array(text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
      if input.first == "\"" && input.last == "\"" && input.count >= 2 {
        input.removeFirst()
        input.removeLast()
      }
      var output = Data()
      var index = 0
      func append(_ scalar: Unicode.Scalar) { output.append(contentsOf: String(scalar).utf8) }
      while index < input.count {
        let scalar = input[index]
        index += 1
        if scalar != "\\" {
          append(scalar)
          continue
        }
        guard index < input.count else { throw TextCodecError.invalid("Incomplete C escape.") }
        let escape = input[index]
        index += 1
        if (48...55).contains(escape.value) {
          var octal = String(escape)
          while index < input.count, octal.count < 3, (48...55).contains(input[index].value) {
            octal += String(input[index])
            index += 1
          }
          guard let byte = UInt8(octal, radix: 8) else {
            throw TextCodecError.invalid("Octal escape is outside the byte range.")
          }
          output.append(byte)
          continue
        }
        let simple: [Unicode.Scalar: Unicode.Scalar] = [
          "n": "\n", "r": "\r", "t": "\t", "\\": "\\", "\"": "\"", "'": "'", "b": "\u{8}",
          "f": "\u{c}", "v": "\u{b}", "a": "\u{7}", "?": "?",
        ]
        if let value = simple[escape] {
          append(value)
          continue
        }
        if escape == "x" {
          var hex = ""
          while index < input.count, String(input[index]).allSatisfy(\.isHexDigit) {
            hex += String(input[index])
            index += 1
          }
          guard !hex.isEmpty, let byte = UInt8(hex, radix: 16) else {
            throw TextCodecError.invalid("Hex escape is outside the byte range.")
          }
          output.append(byte)
          continue
        }
        let count = escape == "u" ? 4 : escape == "U" ? 8 : 0
        guard count > 0, index + count <= input.count,
          let code = UInt32(
            String(String.UnicodeScalarView(input[index..<index + count])), radix: 16),
          let value = Unicode.Scalar(code)
        else { throw TextCodecError.invalid("Invalid C escape or Unicode scalar.") }
        append(value)
        index += count
      }
      guard let result = String(data: output, encoding: .utf8) else {
        throw TextCodecError.invalid("Escaped bytes are not valid UTF-8.")
      }
      return result
    case .named:
      var output = String.UnicodeScalarView()
      for line in text.split(whereSeparator: \.isNewline) {
        guard let token = line.split(separator: " ").first, token.hasPrefix("U+"),
          let code = UInt32(token.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(code)
        else {
          throw TextCodecError.invalid(
            "Each line must begin with a Unicode code point, for example U+0041.")
        }
        output.append(scalar)
      }
      return String(output)
    }
  }
  public static func repairMojibake(_ text: String) -> String? {
    guard let bytes = text.data(using: .windowsCP1252),
      let decoded = String(data: bytes, encoding: .utf8), decoded != text
    else { return nil }
    return decoded
  }
}
