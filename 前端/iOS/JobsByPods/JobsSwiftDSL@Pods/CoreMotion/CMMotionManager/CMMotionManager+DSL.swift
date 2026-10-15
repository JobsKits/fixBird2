//
//  CMMotionManager+DSL.swift
//  JobsSwiftDSL
//
//  Created by Jobs on 2026年7月13日，星期一.
//

import CoreMotion

public extension CMMotionManager {

    static func make() -> CMMotionManager {
        CMMotionManager()
    }

    @discardableResult
    func byAccelerometerUpdateInterval(_ interval: TimeInterval) -> Self {
        accelerometerUpdateInterval = interval
        return self
    }

    @discardableResult
    func byGyroUpdateInterval(_ interval: TimeInterval) -> Self {
        gyroUpdateInterval = interval
        return self
    }

    @discardableResult
    func byMagnetometerUpdateInterval(_ interval: TimeInterval) -> Self {
        magnetometerUpdateInterval = interval
        return self
    }

    @discardableResult
    func byDeviceMotionUpdateInterval(_ interval: TimeInterval) -> Self {
        deviceMotionUpdateInterval = interval
        return self
    }

    @discardableResult
    func byShowsDeviceMovementDisplay(_ shows: Bool) -> Self {
        showsDeviceMovementDisplay = shows
        return self
    }

    @discardableResult
    func byStartAccelerometerUpdates() -> Self {
        startAccelerometerUpdates()
        return self
    }

    @discardableResult
    func byStartAccelerometerUpdates(to queue: OperationQueue,
                                     withHandler handler: @escaping CMAccelerometerHandler) -> Self {
        startAccelerometerUpdates(to: queue, withHandler: handler)
        return self
    }

    @discardableResult
    func byStopAccelerometerUpdates() -> Self {
        stopAccelerometerUpdates()
        return self
    }

    @discardableResult
    func byStartGyroUpdates() -> Self {
        startGyroUpdates()
        return self
    }

    @discardableResult
    func byStartGyroUpdates(to queue: OperationQueue,
                            withHandler handler: @escaping CMGyroHandler) -> Self {
        startGyroUpdates(to: queue, withHandler: handler)
        return self
    }

    @discardableResult
    func byStopGyroUpdates() -> Self {
        stopGyroUpdates()
        return self
    }

    @discardableResult
    func byStartMagnetometerUpdates() -> Self {
        startMagnetometerUpdates()
        return self
    }

    @discardableResult
    func byStartMagnetometerUpdates(to queue: OperationQueue,
                                    withHandler handler: @escaping CMMagnetometerHandler) -> Self {
        startMagnetometerUpdates(to: queue, withHandler: handler)
        return self
    }

    @discardableResult
    func byStopMagnetometerUpdates() -> Self {
        stopMagnetometerUpdates()
        return self
    }

    @discardableResult
    func byStartDeviceMotionUpdates() -> Self {
        startDeviceMotionUpdates()
        return self
    }

    @discardableResult
    func byStartDeviceMotionUpdates(to queue: OperationQueue,
                                    withHandler handler: @escaping CMDeviceMotionHandler) -> Self {
        startDeviceMotionUpdates(to: queue, withHandler: handler)
        return self
    }

    @discardableResult
    func byStartDeviceMotionUpdates(using referenceFrame: CMAttitudeReferenceFrame) -> Self {
        startDeviceMotionUpdates(using: referenceFrame)
        return self
    }

    @discardableResult
    func byStartDeviceMotionUpdates(using referenceFrame: CMAttitudeReferenceFrame,
                                    to queue: OperationQueue,
                                    withHandler handler: @escaping CMDeviceMotionHandler) -> Self {
        startDeviceMotionUpdates(using: referenceFrame, to: queue, withHandler: handler)
        return self
    }

    @discardableResult
    func byStopDeviceMotionUpdates() -> Self {
        stopDeviceMotionUpdates()
        return self
    }

    @discardableResult
    func byStopAllUpdates() -> Self {
        stopAccelerometerUpdates()
        stopGyroUpdates()
        stopMagnetometerUpdates()
        stopDeviceMotionUpdates()
        return self
    }
}
