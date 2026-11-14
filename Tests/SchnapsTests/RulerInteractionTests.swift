import AppKit
import MeasurementCore
import Testing

@testable import Schnaps

@Test func rulerProjectionPreservesGlobalEndpointsAcrossDisplayArrangements() {
  let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
  let displays = [
    CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    CGRect(x: -1920, y: -180, width: 1920, height: 1080),
    CGRect(x: 0, y: 900, width: 1440, height: 900),
    CGRect(x: 0, y: -1080, width: 1920, height: 1080),
  ]
  var marker = DesignMarker(tool: .ruler, display: 1)
  marker.x = 1300
  marker.y = 200
  marker.width = 800
  for angle in [0.0, 45, 90, 180, 270] {
    marker.angle = angle
    for target in displays {
      let projected = marker.projected(from: primary, to: target)
      #expect(abs(primary.minX + marker.end.x - target.minX - projected.end.x) < 0.000001)
      #expect(abs(primary.maxY - marker.end.y - target.maxY + projected.end.y) < 0.000001)
      let restored = projected.projected(from: target, to: primary)
      #expect(restored == marker)
    }
  }
}

@Test func rulerHitRegionFollowsRotatedSegmentAndEndpoints() {
  var marker = DesignMarker(tool: .ruler, display: 1)
  marker.x = 100
  marker.y = 100
  marker.width = 200
  marker.angle = 90
  #expect(marker.containsEditingPoint(CGPoint(x: 100, y: 200)))
  #expect(marker.containsEditingPoint(CGPoint(x: 100, y: 315)))
  #expect(!marker.containsEditingPoint(CGPoint(x: 130, y: 200)))
  #expect(!marker.containsEditingPoint(CGPoint(x: 300, y: 100)))
}

@Test @MainActor func canvasOnlyInterceptsEditableVisibleMarkerRegions() throws {
  let screen = try #require(NSScreen.main)
  let name = "Schnaps.RulerInput.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  let marker = DesignMarker(tool: .ruler, display: DesignTools.displayID(screen))
  tools.markers = [marker]
  tools.visible = true
  tools.editing = true
  let canvas = DesignCanvas(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: tools)
  let onRuler = CGPoint(x: 200, y: 100)
  #expect(canvas.editableMarker(at: onRuler)?.id == marker.id)
  #expect(canvas.editableMarker(at: CGPoint(x: 600, y: 400)) == nil)
  tools.markers[0].locked = true
  #expect(canvas.editableMarker(at: onRuler) == nil)
  tools.markers[0].locked = false
  tools.markers[0].isVisible = false
  #expect(canvas.editableMarker(at: onRuler) == nil)
  tools.markers[0].isVisible = true
  tools.editing = false
  #expect(canvas.editableMarker(at: onRuler) == nil)
  tools.editing = true
  tools.visible = false
  #expect(canvas.editableMarker(at: onRuler) == nil)
}

@Test @MainActor func rulerDragPersistsOnlyCompletedGeometry() throws {
  let name = "Schnaps.RulerPersistence.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  let marker = DesignMarker(tool: .ruler, display: 0)
  tools.markers = [marker]
  tools.selectedID = marker.id
  let initial = defaults.data(forKey: "designMarkers.v1")
  tools.beginDragging()
  for offset in 1...100 { tools.update { $0.x = Double(offset) + 100 } }
  #expect(tools.selected?.x == 200)
  #expect(defaults.data(forKey: "designMarkers.v1") == initial)
  tools.endDragging()
  let persisted = try JSONDecoder().decode([DesignMarker].self, from: #require(defaults.data(forKey: "designMarkers.v1")))
  #expect(persisted == tools.markers)
  tools.update { $0.y = 250 }
  #expect(defaults.data(forKey: "designMarkers.v1") != initial)
}

@Test(arguments: [false, true]) @MainActor func rulerDragContinuesBeyondOwningDisplay(resizingEnd: Bool) throws {
  let screen = try #require(NSScreen.main)
  let name = "Schnaps.RulerDrag.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  let marker = DesignMarker(tool: .ruler, display: DesignTools.displayID(screen))
  tools.markers = [marker]
  tools.visible = true
  tools.editing = true
  let canvas = DesignCanvas(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: tools)
  let panel = DesignPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
  panel.isReleasedWhenClosed = false
  panel.contentView = canvas
  defer { panel.close() }
  func send(_ type: NSEvent.EventType, at point: CGPoint) throws {
    let event = try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil),
      modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 1))
    switch type {
    case .leftMouseDown: canvas.mouseDown(with: event)
    case .leftMouseDragged: canvas.mouseDragged(with: event)
    default: canvas.mouseUp(with: event)
    }
  }
  let start = resizingEnd ? marker.end : CGPoint(x: 200, y: 100)
  let outside = CGPoint(x: screen.frame.width + 200, y: 100)
  try send(.leftMouseDown, at: start)
  #expect(canvas.isDragging)
  try send(.leftMouseDragged, at: outside)
  #expect(canvas.wantsMouseInput)
  let dragged = try #require(tools.selected)
  if resizingEnd {
    #expect(abs(dragged.end.x - outside.x) < 0.000001)
  } else {
    #expect(abs(dragged.x - (marker.x + outside.x - start.x)) < 0.000001)
  }
  try send(.leftMouseUp, at: outside)
  #expect(!canvas.isDragging)
  let persisted = try JSONDecoder().decode([DesignMarker].self, from: #require(defaults.data(forKey: "designMarkers.v1")))
  #expect(persisted == tools.markers)
}

@Test(arguments: [DesignTool.ruler, .guides]) @MainActor
func markerLabelsDragAndCloseWithoutAffectingOtherMarkers(tool: DesignTool) throws {
  let screen = try #require(NSScreen.main)
  let name = "Schnaps.MarkerControls.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  let marker = DesignMarker(tool: tool, display: DesignTools.displayID(screen))
  let other = DesignMarker(tool: .frames, display: marker.display)
  tools.markers = [other, marker]
  tools.selectedID = other.id
  tools.visible = true
  tools.editing = true
  let canvas = DesignCanvas(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: tools)
  let panel = DesignPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
  panel.isReleasedWhenClosed = false
  panel.contentView = canvas
  defer { panel.close() }
  func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
    try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil),
      modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 1))
  }
  let label = try #require(canvas.markerLabelRect(for: marker))
  let start = CGPoint(x: label.midX, y: label.midY)
  #expect(canvas.editableMarker(at: start)?.id == marker.id)
  let target = CGPoint(x: start.x + 60, y: start.y + 40)
  canvas.mouseDown(with: try event(.leftMouseDown, at: start))
  #expect(canvas.cursor(at: start) === NSCursor.closedHand)
  canvas.mouseDragged(with: try event(.leftMouseDragged, at: target))
  canvas.mouseUp(with: try event(.leftMouseUp, at: target))
  let moved = try #require(tools.selected)
  #expect(abs(moved.x - marker.x - 60) < 0.000001)
  #expect(abs(moved.y - marker.y - 40) < 0.000001)
  #expect(moved.width == marker.width && moved.angle == marker.angle)
  let close = try #require(canvas.removeButtonRect(for: moved))
  let closePoint = CGPoint(x: close.midX, y: close.midY)
  #expect(canvas.cursor(at: closePoint) === NSCursor.pointingHand)
  canvas.mouseDown(with: try event(.leftMouseDown, at: closePoint))
  #expect(!canvas.isDragging)
  #expect(tools.markers == [other])
  let restored = DesignTools(defaults: defaults)
  #expect(restored.markers == [other])
}

@Test @MainActor func guideHitTargetsAndCursorsRespectEditingAndVisibility() throws {
  let screen = try #require(NSScreen.main)
  let name = "Schnaps.GuideHit.Tests." + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let tools = DesignTools(defaults: defaults)
  var marker = DesignMarker(tool: .guides, display: DesignTools.displayID(screen))
  tools.visible = true
  tools.editing = true
  let canvas = DesignCanvas(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, state: tools)
  for vertical in [false, true] {
    marker.vertical = vertical
    tools.markers = [marker]
    let point = vertical ? CGPoint(x: marker.x + 13, y: 300) : CGPoint(x: 600, y: marker.y + 13)
    #expect(canvas.editableMarker(at: point)?.id == marker.id)
    #expect(canvas.cursor(at: point) === (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown))
    tools.markers[0].locked = true
    #expect(canvas.cursor(at: point) == nil)
    #expect(canvas.removeButtonRect(for: tools.markers[0]) == nil)
    tools.markers[0].locked = false
    tools.editing = false
    #expect(canvas.cursor(at: point) == nil)
    #expect(canvas.removeButtonRect(for: marker) == nil)
    tools.editing = true
    tools.visible = false
    #expect(canvas.cursor(at: point) == nil)
    tools.visible = true
  }
}
