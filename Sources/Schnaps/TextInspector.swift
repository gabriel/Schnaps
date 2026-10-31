import AppKit
import CoreText
import MeasurementCore
import SwiftUI

private struct UnicodeMatch: Identifiable, Sendable {
  let value: UInt32
  let name: String
  var fontName: String? = nil
  var id: UInt32 { value }
  var character: String { Unicode.Scalar(value).map(String.init) ?? "" }
  var code: String { String(format: "U+%04X", value) }
}

@MainActor
private final class TextInspectorSession: ObservableObject {
  static let shared = TextInspectorSession()
  @Published var input = ""
  @Published var output = ""
  @Published var format = TextEncodingFormat.html
  @Published var query = ""
  @Published var fontName = "Helvetica Neue"
  @Published var fontSize = 32.0
}

struct TextInspectorView: View {
  @ObservedObject private var session = TextInspectorSession.shared
  @State private var error: String?
  @State private var matches: [UnicodeMatch] = []
  @State private var searching = false
  @State private var favorites: [String] =
    UserDefaults.standard.stringArray(forKey: "characterPalette") ?? []
  @State private var favoriteFonts: [String: String] =
    UserDefaults.standard.dictionary(forKey: "characterPaletteFonts") as? [String: String] ?? [:]
  @State private var foreground = Color.primary
  @State private var background = Color(nsColor: .textBackgroundColor)
  private var font: NSFont {
    NSFontManager.shared.font(
      withFamily: session.fontName, traits: [], weight: 5, size: max(6, min(300, session.fontSize)))
      ?? .systemFont(ofSize: max(6, min(300, session.fontSize)))
  }
  var body: some View {
    Section("Convert text") {
      TextEditor(text: $session.input).font(.system(.body, design: .monospaced)).frame(
        minHeight: 90
      )
      .accessibilityLabel("Input text")
      Picker("Format", selection: $session.format) {
        ForEach(TextEncodingFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      HStack {
        Button("Encode") {
          session.output = TextCodec.encode(session.input, as: session.format)
          error = nil
        }
        Button("Decode") {
          do {
            session.output = try TextCodec.decode(session.input, from: session.format)
            error = nil
          } catch { self.error = error.localizedDescription }
        }
        Button("Repair UTF-8") {
          if let repaired = TextCodec.repairMojibake(session.input) {
            session.output = repaired
            error = nil
          } else {
            error = "No Windows-1252 / UTF-8 mismatch found."
          }
        }
      }
      TextEditor(text: $session.output).font(.system(.body, design: .monospaced)).frame(
        minHeight: 90
      )
      .accessibilityLabel("Converted text")
      HStack {
        Button("Copy Result") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(session.output, forType: .string)
        }
        Button("Use Result") { session.input = session.output }
        Button("Open Text File…") {
          let panel = NSOpenPanel()
          panel.allowsMultipleSelection = false
          guard panel.runModal() == .OK, let url = panel.url else { return }
          do {
            let data = try Data(contentsOf: url)
            guard data.count <= 1_000_000, let text = String(data: data, encoding: .utf8) else {
              throw TextCodecError.invalid("Choose a UTF-8 text file up to 1 MB.")
            }
            session.input = text
          } catch { self.error = error.localizedDescription }
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }
    Section("Unicode") {
      TextField("Search name, character, or U+code", text: $session.query)
      if searching { ProgressView().controlSize(.small) }
      ForEach(matches.prefix(60)) { match in
        LabeledContent {
          Button(match.name) {
            session.input += match.character
            if let name = match.fontName { session.fontName = name }
          }.lineLimit(2)
        } label: {
          HStack {
            Text(match.character).font(.custom(match.fontName ?? session.fontName, size: 18))
            Text(match.code).monospaced()
          }
        }
      }
    }
    .task(id: session.query + "|" + session.fontName) { await search() }
    Section("Characters in text") {
      ForEach(Array(session.input.unicodeScalars.prefix(100).enumerated()), id: \.offset) {
        _, scalar in
        VStack(alignment: .leading, spacing: 3) {
          Text(
            "\(String(scalar))   \(String(format:"U+%04X",scalar.value))   \(scalar.properties.name ?? "Unnamed")"
          ).textSelection(.enabled)
          Text(
            "\(String(describing:scalar.properties.generalCategory)) · UTF-8 \(TextCodec.encode(String(scalar),as:.bytes)) · UTF-16 \(String(scalar).utf16.map{String(format:"%04X",$0)}.joined(separator:" "))"
          ).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
        }
      }
      HStack {
        Button("Compose NFC") {
          session.input = session.input.precomposedStringWithCanonicalMapping
        }
        Button("Decompose NFD") {
          session.input = session.input.decomposedStringWithCanonicalMapping
        }
        Button("Compatibility NFKC") {
          session.input = session.input.precomposedStringWithCompatibilityMapping
        }
      }
    }
    Section("Glyph metrics") {
      Picker("Font", selection: $session.fontName) {
        ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) {
          Text($0).tag($0)
        }
      }
      TextField("Size (pt)", value: $session.fontSize, format: .number)
      ColorPicker("Foreground", selection: $foreground)
      ColorPicker("Background", selection: $background)
      Text(session.input.isEmpty ? "Ag" : session.input).font(Font(font)).foregroundStyle(
        foreground
      ).padding(8)
        .frame(maxWidth: .infinity, alignment: .leading).background(background)
      Text(metrics).monospacedDigit().textSelection(.enabled)
    }
    Section("Character palette") {
      Button("Save Input to Palette") {
        for character in session.input {
          let value = String(character)
          if !favorites.contains(value) { favorites.append(value) }
          favoriteFonts[value] = session.fontName
        }
        UserDefaults.standard.set(favoriteFonts, forKey: "characterPaletteFonts")
        favorites = Array(favorites.prefix(200))
        UserDefaults.standard.set(favorites, forKey: "characterPalette")
      }
      ForEach(favorites, id: \.self) { value in
        HStack {
          Button {
            session.input += value
            if let family = favoriteFonts[value] { session.fontName = family }
          } label: {
            Text(value).font(favoriteFonts[value].map { Font.custom($0, size: 18) } ?? .body)
          }
          Spacer()
          Button("Remove") {
            favorites.removeAll { $0 == value }
            favoriteFonts.removeValue(forKey: value)
            UserDefaults.standard.set(favorites, forKey: "characterPalette")
            UserDefaults.standard.set(favoriteFonts, forKey: "characterPaletteFonts")
          }
        }
      }
    }
  }
  private var metrics: String {
    let text =
      session.input.isEmpty
      ? "Ag"
      : String(session.input.split(separator: "\n", omittingEmptySubsequences: false).first ?? "")
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: [.font: font]))
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    return String(
      format:
        "Advance %.2f pt · ascent %.2f · descent %.2f · leading %.2f\nCap height %.2f · x-height %.2f · CSS line-height %.2f px (first line)",
      width, ascent, descent, leading, font.capHeight, font.xHeight,
      ceil(ascent + descent + leading))
  }
  private func search() async {
    let value = session.query.trimmingCharacters(in: .whitespacesAndNewlines)
    matches = []
    searching = false
    guard !value.isEmpty else { return }
    searching = true
    let awesome = session.fontName == "FontAwesome" || value.lowercased().hasPrefix("fa-")
    let task = Task.detached(priority: .userInitiated) { () -> [UnicodeMatch] in
      let range = value.uppercased().replacingOccurrences(of: "U+", with: "").components(
        separatedBy: "..")
      if range.count == 2, let first = UInt32(range[0], radix: 16),
        let last = UInt32(range[1], radix: 16), first <= last, last <= 0x10ffff
      {
        return Array(
          (first...last).lazy.compactMap { code in
            Unicode.Scalar(code).map {
              UnicodeMatch(value: code, name: $0.properties.name ?? "Unnamed")
            }
          }.prefix(200))
      }
      if awesome, !value.uppercased().hasPrefix("U+") {
        let text =
          value.lowercased().hasPrefix("fa-") ? String(value.dropFirst(3)) : value.lowercased()
        let terms = text.split(whereSeparator: { $0 == " " || $0 == "-" })
        var seen = Set<UInt32>()
        return FontAwesomeNames.values.sorted { $0.key < $1.key }.filter { pair in
          terms.allSatisfy { pair.key.contains($0) }
        }.compactMap { pair in
          guard seen.insert(pair.value).inserted else { return nil }
          return UnicodeMatch(value: pair.value, name: "fa-" + pair.key, fontName: "FontAwesome")
        }
      }
      if value.uppercased().hasPrefix("U+"), let code = UInt32(value.dropFirst(2), radix: 16),
        let scalar = Unicode.Scalar(code)
      {
        return [UnicodeMatch(value: code, name: scalar.properties.name ?? "Unnamed")]
      }
      if value.count == 1 {
        return value.unicodeScalars.map {
          UnicodeMatch(value: $0.value, name: $0.properties.name ?? "Unnamed")
        }
      }
      guard value.count >= 2 else { return [] }
      let words = value.uppercased().split(separator: " ")
      var result: [UnicodeMatch] = []
      for code in UInt32(0)...0x10ffff {
        if Task.isCancelled { break }
        guard let scalar = Unicode.Scalar(code), let name = scalar.properties.name,
          words.allSatisfy({ name.contains($0) })
        else { continue }
        result.append(UnicodeMatch(value: code, name: name))
        if result.count >= 200 { break }
      }
      return result
    }
    let result = await withTaskCancellationHandler(
      operation: { await task.value }, onCancel: { task.cancel() })
    guard !Task.isCancelled else { return }
    matches = result
    searching = false
  }
}
