import CoreText
import Foundation

@MainActor
enum AppFonts {
  static func install() {
    guard let url = Bundle.main.url(forResource: "FontAwesome", withExtension: "otf") else {
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}
