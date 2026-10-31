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

struct TextInspectorView: View {
  @State private var input = ""
  @State private var output = ""
  @State private var format = TextEncodingFormat.html
  @State private var error: String?
  @State private var query = ""
  @State private var matches: [UnicodeMatch] = []
  @State private var searching = false
  @State private var fontName = "Helvetica Neue"
  @State private var fontSize = 32.0
  @State private var favorites: [String] =
    UserDefaults.standard.stringArray(forKey: "characterPalette") ?? []
  @State private var foreground = Color.primary
  @State private var background = Color(nsColor: .textBackgroundColor)
  private var font: NSFont {
    NSFontManager.shared.font(
      withFamily: fontName, traits: [], weight: 5, size: max(6, min(300, fontSize)))
      ?? .systemFont(ofSize: max(6, min(300, fontSize)))
  }
  var body: some View {
    Section("Convert text") {
      TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(minHeight: 90)
        .accessibilityLabel("Input text")
      Picker("Format", selection: $format) {
        ForEach(TextEncodingFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      HStack {
        Button("Encode") {
          output = TextCodec.encode(input, as: format)
          error = nil
        }
        Button("Decode") {
          do {
            output = try TextCodec.decode(input, from: format)
            error = nil
          } catch { self.error = error.localizedDescription }
        }
        Button("Repair UTF-8") {
          if let repaired = TextCodec.repairMojibake(input) {
            output = repaired
            error = nil
          } else {
            error = "No Windows-1252 / UTF-8 mismatch found."
          }
        }
      }
      TextEditor(text: $output).font(.system(.body, design: .monospaced)).frame(minHeight: 90)
        .accessibilityLabel("Converted text")
      HStack {
        Button("Copy Result") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(output, forType: .string)
        }
        Button("Use Result") { input = output }
        Button("Open Text File…") {
          let panel = NSOpenPanel()
          panel.allowsMultipleSelection = false
          guard panel.runModal() == .OK, let url = panel.url else { return }
          do {
            let data = try Data(contentsOf: url)
            guard data.count <= 1_000_000, let text = String(data: data, encoding: .utf8) else {
              throw TextCodecError.invalid("Choose a UTF-8 text file up to 1 MB.")
            }
            input = text
          } catch { self.error = error.localizedDescription }
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }
    Section("Unicode") {
      TextField("Search name, character, or U+code", text: $query)
      if searching { ProgressView().controlSize(.small) }
      ForEach(matches.prefix(60)) { match in
        LabeledContent {
          Button(match.name) {
            input += match.character
            if let name = match.fontName { fontName = name }
          }.lineLimit(2)
        } label: {
          HStack {
            Text(match.character).font(.custom(match.fontName ?? fontName, size: 18))
            Text(match.code).monospaced()
          }
        }
      }
    }
    .task(id: query + "|" + fontName) { await search() }
    Section("Characters in text") {
      ForEach(Array(input.unicodeScalars.prefix(100).enumerated()), id: \.offset) { _, scalar in
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
        Button("Compose NFC") { input = input.precomposedStringWithCanonicalMapping }
        Button("Decompose NFD") { input = input.decomposedStringWithCanonicalMapping }
        Button("Compatibility NFKC") { input = input.precomposedStringWithCompatibilityMapping }
      }
    }
    Section("Glyph metrics") {
      Picker("Font", selection: $fontName) {
        ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) {
          Text($0).tag($0)
        }
      }
      TextField("Size (pt)", value: $fontSize, format: .number)
      ColorPicker("Foreground", selection: $foreground)
      ColorPicker("Background", selection: $background)
      Text(input.isEmpty ? "Ag" : input).font(Font(font)).foregroundStyle(foreground).padding(8)
        .frame(maxWidth: .infinity, alignment: .leading).background(background)
      Text(metrics).monospacedDigit().textSelection(.enabled)
    }
    Section("Character palette") {
      Button("Save Input to Palette") {
        for character in input where !favorites.contains(String(character)) {
          favorites.append(String(character))
        }
        favorites = Array(favorites.prefix(200))
        UserDefaults.standard.set(favorites, forKey: "characterPalette")
      }
      ForEach(favorites, id: \.self) { value in
        HStack {
          Button(value) { input += value }
          Spacer()
          Button("Remove") {
            favorites.removeAll { $0 == value }
            UserDefaults.standard.set(favorites, forKey: "characterPalette")
          }
        }
      }
    }
  }
  private var metrics: String {
    let text =
      input.isEmpty
      ? "Ag" : String(input.split(separator: "\n", omittingEmptySubsequences: false).first ?? "")
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
    let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
    matches = []
    searching = false
    guard !value.isEmpty else { return }
    searching = true
    let awesome = fontName == "FontAwesome" || value.lowercased().hasPrefix("fa-")
    let task = Task.detached(priority: .userInitiated) { () -> [UnicodeMatch] in
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
