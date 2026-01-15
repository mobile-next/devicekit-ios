import Foundation
import XCTest

// MARK: - Global State

/// Global storage for overwrite parameters.
/// Instance variables are not accessible after method swizzling.
private var _overwriteDefaultParameters = [String: Int]()

// MARK: - AX Client Swizzler

/// Swizzles XCTest's accessibility client to customize snapshot parameters.
///
/// This utility uses Objective-C runtime method swizzling to override the
/// default parameters used by `XCAXClient_iOS` when taking accessibility snapshots.
/// Primary use case is increasing the `maxDepth` parameter to handle deep view hierarchies.
///
/// ## Usage
/// ```swift
/// // Increase max snapshot depth to 60
/// AXClientSwizzler.overwriteDefaultParameters["maxDepth"] = 60
///
/// // Take snapshot with increased depth limit
/// let snapshot = try element.snapshot()
/// ```
///
/// ## Why This Is Needed
/// Deep view hierarchies (common in complex apps like ReactNative) can trigger
/// `kAXErrorIllegalArgument` errors. This swizzler allows overriding the default
/// depth limit to capture complete hierarchies.
///
/// ## Implementation Details
/// - Swizzles `XCAXClient_iOS.defaultParameters` method
/// - Merges custom parameters with original defaults
/// - Setup is performed lazily on first access
struct AXClientSwizzler {

    /// Standin class instance for method swizzling.
    fileprivate static let proxy = AXClientiOS_Standin()

    private init() {}

    /// Parameters to override in accessibility client defaults.
    ///
    /// Common parameters:
    /// - `maxDepth`: Maximum depth for view hierarchy traversal (default varies by iOS version)
    ///
    /// Setting any value triggers lazy initialization of the swizzler.
    static var overwriteDefaultParameters: [String: Int] {
        get { _overwriteDefaultParameters }
        set {
            setup
            _overwriteDefaultParameters = newValue
        }
    }

    /// Lazy initializer that performs the method swizzle.
    static let setup: Void = {
        let axClientiOSClass: AnyClass =
            objc_getClass("XCAXClient_iOS") as! AnyClass
        let defaultParametersSelector = #selector(
            XCAXClient_iOS.defaultParameters
        )
        let original = class_getInstanceMethod(
            axClientiOSClass,
            defaultParametersSelector
        )!

        let replaced = class_getInstanceMethod(
            AXClientiOS_Standin.self,
            #selector(AXClientiOS_Standin.swizzledDefaultParameters)
        )!

        method_exchangeImplementations(original, replaced)
    }()
}

// MARK: - Standin Class

/// Standin class providing the swizzled method implementation.
///
/// This class provides the replacement `defaultParameters` method that
/// merges custom overrides with the original default parameters.
@objc private class AXClientiOS_Standin: NSObject {

    /// Calls the original (swizzled) implementation of `defaultParameters`.
    ///
    /// After swizzling, the original implementation is accessible through
    /// our swizzled selector.
    func originalDefaultParameters() -> NSDictionary {
        let selector = #selector(XCAXClient_iOS.defaultParameters)
        let swizzeledSelector = #selector(swizzledDefaultParameters)
        let imp = class_getMethodImplementation(
            AXClientiOS_Standin.self,
            swizzeledSelector
        )
        typealias Method = @convention(c) (NSObject, Selector) -> NSDictionary
        let method = unsafeBitCast(imp, to: Method.self)
        return method(self, selector)
    }

    /// Replacement implementation for `defaultParameters`.
    ///
    /// Returns the original defaults merged with any custom overrides from
    /// `AXClientSwizzler.overwriteDefaultParameters`.
    @objc func swizzledDefaultParameters() -> NSDictionary {
        let defaultParameters =
            originalDefaultParameters().mutableCopy() as! NSMutableDictionary

        for (key, value) in _overwriteDefaultParameters {
            defaultParameters[key] = value
        }

        return defaultParameters
    }
}
