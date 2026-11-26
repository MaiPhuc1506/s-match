import Flutter
import UIKit
import SwiftUI

public class BotAvatarObservableModel: ObservableObject {
    @Published public var avatarType: BotAvatarType = .clover
    @Published public var avatarState: BotAvatarState = .default
    @Published public var avatarExpression: BotAvatarExpression = .auto
    @Published public var avatarColor: BotColor? = BotColor("#35B96C")
    @Published public var avatarSize: Double = 64
    @Published public var interactive: Bool = true

    public init() {}
}

public struct BotAvatarHostingView: View {
    @ObservedObject var model: BotAvatarObservableModel

    public var body: some View {
        ZStack {
            Color.clear
            BotAvatar(
                type: model.avatarType,
                state: model.avatarState,
                size: model.avatarSize,
                color: model.avatarColor,
                shading: .smooth,
                shadow: 0.55,
                highlight: 1.55,
                depth: 0.70,
                spread: 1.85,
                interactive: model.interactive,
                jump: BotAvatarJumpConfig(spin: 0, lean: 3, every: 0),
                expression: model.avatarExpression
            )
        }
        .background(Color.clear)
    }
}

public class BotAvatarPlatformView: NSObject, FlutterPlatformView {
    private let _view: UIView
    private var hostingController: UIHostingController<BotAvatarHostingView>?
    private let model = BotAvatarObservableModel()
    private var methodChannel: FlutterMethodChannel?

    /// Flutter uses five assistant states; the rig has three motions. Thinking
    /// is a calm rig with concentrated eyes, and success reuses the happy
    /// working motion with Flutter-side sparkles.
    private static func mappedAnimation(for raw: String) -> (BotAvatarState, BotAvatarExpression) {
        switch raw.lowercased() {
        case "thinking": return (.default, .thinking)
        case "typing", "working": return (.working, .auto)
        case "success": return (.working, .auto)
        case "sleep", "sleeping": return (.sleeping, .auto)
        default: return (.default, .auto)
        }
    }

    public init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        let container = UIView(frame: frame)
        container.backgroundColor = .clear
        container.isOpaque = false
        container.clipsToBounds = false
        self._view = container
        super.init()

        // Parse initial parameters
        if let params = args as? [String: Any] {
            if let stateStr = params["state"] as? String {
                let mapped = Self.mappedAnimation(for: stateStr)
                self.model.avatarState = mapped.0
                self.model.avatarExpression = mapped.1
            }
            if let typeStr = params["type"] as? String {
                self.model.avatarType = BotAvatarType(rawValue: typeStr) ?? .clover
            }
            if let colorHex = params["color"] as? String {
                self.model.avatarColor = BotColor(colorHex) ?? BotColor("#35B96C")
            }
            if let sizeVal = params["size"] as? Double {
                self.model.avatarSize = sizeVal
            } else if let sizeVal = params["size"] as? Int {
                self.model.avatarSize = Double(sizeVal)
            }
            if let interactiveVal = params["interactive"] as? Bool {
                self.model.interactive = interactiveVal
            }
        }

        // Decorative avatars must not intercept the enclosing Flutter button.
        container.isUserInteractionEnabled = self.model.interactive

        let hosting = UIHostingController(rootView: BotAvatarHostingView(model: self.model))
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        hosting.view.clipsToBounds = false
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        self.hostingController = hosting

        // MethodChannel for Flutter -> Swift dynamic updates
        let channelName = "smashscot/bot_avatar_\(viewId)"
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
        self.methodChannel = channel
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setState":
            if let args = call.arguments as? [String: Any],
               let stateStr = args["state"] as? String {
                DispatchQueue.main.async {
                    let mapped = Self.mappedAnimation(for: stateStr)
                    self.model.avatarState = mapped.0
                    self.model.avatarExpression = mapped.1
                    result(true)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing state argument", details: nil))
            }

        case "setType":
            if let args = call.arguments as? [String: Any],
               let typeStr = args["type"] as? String {
                DispatchQueue.main.async {
                    if let newType = BotAvatarType(rawValue: typeStr) {
                        self.model.avatarType = newType
                        result(true)
                    } else {
                        result(FlutterError(code: "INVALID_TYPE", message: "Unknown type \(typeStr)", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing type argument", details: nil))
            }

        case "setColor":
            if let args = call.arguments as? [String: Any],
               let hexStr = args["color"] as? String {
                DispatchQueue.main.async {
                    self.model.avatarColor = BotColor(hexStr)
                    result(true)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing color argument", details: nil))
            }

        case "setSize":
            if let args = call.arguments as? [String: Any] {
                let sizeVal = (args["size"] as? Double) ?? (args["size"] as? Int).map(Double.init)
                if let sz = sizeVal {
                    DispatchQueue.main.async {
                        self.model.avatarSize = sz
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing size argument", details: nil))
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing size argument", details: nil))
            }

        case "getState":
            result([
                "state": self.model.avatarState.rawValue,
                "expression": self.model.avatarExpression.rawValue,
                "type": self.model.avatarType.rawValue,
                "size": self.model.avatarSize
            ])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func view() -> UIView {
        return _view
    }
}

public class BotAvatarPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return BotAvatarPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
