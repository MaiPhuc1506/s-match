import Flutter
import UIKit
#if targetEnvironment(simulator)
import MapLibre
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  #if targetEnvironment(simulator)
  private var simulatorMapPinch: SimulatorMapPinchBridge?
  #endif
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if targetEnvironment(simulator)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SMatchSimulatorMapPinch") {
      simulatorMapPinch = SimulatorMapPinchBridge(registrar: registrar)
    }
    #endif
  }
}

#if targetEnvironment(simulator)
/// Device Hub trackpad transforms are not synthetic two-finger UITouch events.
/// Install a transform-only recognizer on native map views, never on other UI.
private final class SimulatorMapPinchBridge {
  private let registrar: FlutterPluginRegistrar
  private let channel: FlutterMethodChannel
  private var adapters: [ObjectIdentifier: SimulatorMapPinchAdapter] = [:]

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    channel = FlutterMethodChannel(name: "smatch/simulator_map_pinch", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "install" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result(0); return }
      // Flutter's platform views may be siblings of FlutterView, rather than
      // descendants. Search the scene windows after platform-view composition.
      let windows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        .filter { !$0.isHidden }
      for key in self.adapters.filter({ $0.value.mapView == nil }).keys {
        self.adapters.removeValue(forKey: key)?.detach()
      }
      let count = windows.reduce(0) { $0 + self.install(in: $1, host: $1) }
      NSLog("[SMatch Map] Pinch install: %ld native map views", count)
      result(count)
    }
  }

  private func install(in view: UIView, host: UIView) -> Int {
    var count = 0
    if let map = view as? MLNMapView {
      let key = ObjectIdentifier(map)
      if adapters[key] == nil {
        adapters[key] = SimulatorMapPinchAdapter(mapView: map, host: host)
        NSLog("[SMatch Map] Simulator trackpad pinch installed")
      }
      count += 1
    }
    for child in view.subviews { count += install(in: child, host: host) }
    return count
  }
}

private final class SimulatorMapPinchAdapter: NSObject, UIGestureRecognizerDelegate {
  weak var mapView: MLNMapView?
  private var initialZoom = 0.0
  private weak var recognizer: UIPinchGestureRecognizer?

  init(mapView: MLNMapView, host: UIView) {
    self.mapView = mapView
    super.init()
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    pinch.delegate = self
    pinch.cancelsTouchesInView = false
    // Device Hub can target the Flutter root rather than the embedded map.
    // Listen at that root, then restrict transforms to this visible map's bounds.
    host.addGestureRecognizer(pinch)
    recognizer = pinch
  }

  // This adapter handles Mac trackpad transforms only. Touchscreen pinch and
  // single-finger panning continue through MapLibre's existing recognizers.
  func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
    if event.type == .transform { NSLog("[SMatch Map] Trackpad transform reached root") }
    guard event.type == .transform, let map = mapView,
          map.window != nil, map.bounds.contains(recognizer.location(in: map)) else { return false }
    var ancestor: UIView? = map
    while let view = ancestor {
      if view.isHidden || view.alpha < 0.01 { return false }
      ancestor = view.superview
    }
    return true
  }

  func detach() {
    if let recognizer = recognizer { recognizer.view?.removeGestureRecognizer(recognizer) }
  }

  func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { false }

  func gestureRecognizer(_ recognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

  @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
    guard let map = mapView, map.allowsZooming else { return }
    switch pinch.state {
    case .began:
      initialZoom = map.zoomLevel
      NSLog("[SMatch Map] Simulator trackpad pinch began")
    case .changed:
      guard pinch.scale.isFinite && pinch.scale > 0 else { return }
      let zoom = min(map.maximumZoomLevel, max(map.minimumZoomLevel, initialZoom + log2(Double(pinch.scale))))
      map.setZoomLevel(zoom, animated: false)
    default: break
    }
  }
}
#endif
