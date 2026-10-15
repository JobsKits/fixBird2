//
//  UIImagePickerController+DSL.swift
//  JobsByUIKit
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - DSL
extension UIImagePickerController {
    // delegate
    @discardableResult
    public func byDelegate(_ delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?) -> Self {
        self.delegate = delegate
        return self
    }
    // sourceType
    @discardableResult
    public func bySourceType(_ sourceType: UIImagePickerController.SourceType) -> Self {
        self.sourceType = sourceType
        return self
    }
    // mediaTypes
    @discardableResult
    public func byMediaTypes(_ mediaTypes: [String]) -> Self {
        self.mediaTypes = mediaTypes
        return self
    }
    // allowsEditing
    @discardableResult
    public func byAllowsEditing(_ allowsEditing: Bool) -> Self {
        self.allowsEditing = allowsEditing
        return self
    }
    // imageExportPreset (iOS 11+, deprecated in SDK snippet)
    @available(iOS 11.0, *)
    @discardableResult
    public func byImageExportPreset(_ preset: UIImagePickerController.ImageURLExportPreset) -> Self {
        self.imageExportPreset = preset
        return self
    }
    // videoMaximumDuration
    @available(iOS 3.1, *)
    @discardableResult
    public func byVideoMaximumDuration(_ duration: TimeInterval) -> Self {
        self.videoMaximumDuration = duration
        return self
    }
    // videoQuality
    @available(iOS 3.1, *)
    @discardableResult
    public func byVideoQuality(_ quality: UIImagePickerController.QualityType) -> Self {
        self.videoQuality = quality
        return self
    }
    // videoExportPreset (iOS 11+, deprecated in SDK snippet)
    @available(iOS 11.0, *)
    @discardableResult
    public func byVideoExportPreset(_ preset: String) -> Self {
        self.videoExportPreset = preset
        return self
    }
    // showsCameraControls
    @available(iOS 3.1, *)
    @discardableResult
    public func byShowsCameraControls(_ shows: Bool) -> Self {
        self.showsCameraControls = shows
        return self
    }
    // cameraOverlayView
    @available(iOS 3.1, *)
    @discardableResult
    public func byCameraOverlayView(_ overlayView: UIView?) -> Self {
        self.cameraOverlayView = overlayView
        return self
    }
    // cameraViewTransform
    @available(iOS 3.1, *)
    @discardableResult
    public func byCameraViewTransform(_ transform: CGAffineTransform) -> Self {
        self.cameraViewTransform = transform
        return self
    }
    // cameraCaptureMode
    @available(iOS 4.0, *)
    @discardableResult
    public func byCameraCaptureMode(_ mode: UIImagePickerController.CameraCaptureMode) -> Self {
        self.cameraCaptureMode = mode
        return self
    }
    // cameraDevice
    @available(iOS 4.0, *)
    @discardableResult
    public func byCameraDevice(_ device: UIImagePickerController.CameraDevice) -> Self {
        self.cameraDevice = device
        return self
    }
    // cameraFlashMode
    @available(iOS 4.0, *)
    @discardableResult
    public func byCameraFlashMode(_ mode: UIImagePickerController.CameraFlashMode) -> Self {
        self.cameraFlashMode = mode
        return self
    }
    // 兜底：复杂配置用它（不算属性，但很实用，不会破坏“只覆盖属性”的目标）
    @discardableResult
    public func byConfig(_ block: (UIImagePickerController) -> Void) -> Self {
        block(self)
        return self
    }
}
