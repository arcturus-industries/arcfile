//
//  CVPixelBuffer+Extension.swift
//  VideoToolboxCompression
//
//  Modified from code created by tomisacat on 14/08/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import Foundation
import VideoToolbox
import CoreVideo

extension CVPixelBuffer {
    public enum LockFlag {
        case readwrite
        case readonly
        
        func flag() -> CVPixelBufferLockFlags {
            switch self {
            case .readonly:
                return .readOnly
            default:
                return CVPixelBufferLockFlags.init(rawValue: 0)
            }
        }
    }

    public func lock(_ flag: LockFlag) -> Bool {
        return (CVPixelBufferLockBaseAddress(self, flag.flag()) == kCVReturnSuccess)
    }
    
    public func unlock(_ flag: LockFlag) -> Bool {
        return (CVPixelBufferUnlockBaseAddress(self, flag.flag()) == kCVReturnSuccess)
    }

    public func wrapLockAndUnlock(_ flag: LockFlag, closure: (() -> Void)?) -> Bool {

        if CVPixelBufferLockBaseAddress(self, flag.flag()) == kCVReturnSuccess {
            if let c = closure {
                c()
            }
        } else { return false }
        
        if CVPixelBufferUnlockBaseAddress(self, flag.flag()) == kCVReturnSuccess {
            
        } else { return false }
        
        return true
    }
    
    public static func copyCVPixelBuffer(srcBuffer:CVPixelBuffer, destBuffer:CVPixelBuffer)
    {
        if(!srcBuffer.wrapLockAndUnlock(.readonly) {
            if(!destBuffer.wrapLockAndUnlock(.readwrite) {
                
                let isPlanar = CVPixelBufferIsPlanar(srcBuffer)
                
                if(isPlanar) {
                    let numPlanes = CVPixelBufferGetPlaneCount(srcBuffer)
                    
                    for idx in 0..<numPlanes {
                        
                        let srcPlaneWidth  = CVPixelBufferGetWidthOfPlane(srcBuffer, idx)
                        let srcPlaneHeight = CVPixelBufferGetHeightOfPlane(srcBuffer, idx)
                        
                        let destPlaneWidth  = CVPixelBufferGetWidthOfPlane(destBuffer, idx)
                        let destPlaneHeight = CVPixelBufferGetHeightOfPlane(destBuffer, idx)
                        
                        arc_assert(
                            srcPlaneWidth == destPlaneWidth &&
                                srcPlaneHeight == destPlaneHeight,
                            "Dimensions need to be equal")
                        
                        let srcPlaneBuffer = CVPixelBufferGetBaseAddressOfPlane(srcBuffer, idx)
                        let destPlaneBuffer = CVPixelBufferGetBaseAddressOfPlane(destBuffer, idx)
                        
                        let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(srcBuffer, idx)
                        let destBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(destBuffer, idx)
                        
                        arc_assert(srcBytesPerRow == destBytesPerRow, "If not equal, we can't do a simple memcopy, would need to iterate through each row and copy the number of bytes from the least bytes per row one which has less padding")
                        
                        memcpy(destPlaneBuffer, srcPlaneBuffer, srcBytesPerRow * srcPlaneHeight)                        
                    }
                    
                } else {

                    let srcBufferAddress = CVPixelBufferGetBaseAddress(srcBuffer)
                    let destBufferAddress = CVPixelBufferGetBaseAddress(destBuffer)
                    
                    let srcBufferWidth = CVPixelBufferGetWidth(srcBuffer)
                    let srcBufferHeight = CVPixelBufferGetHeight(srcBuffer)
                    
                    let destBufferWidth = CVPixelBufferGetWidth(destBuffer)
                    let destBufferHeight = CVPixelBufferGetHeight(destBuffer)
                    
                    arc_assert(
                        srcBufferWidth == destBufferWidth &&
                        srcBufferHeight == destBufferHeight,
                        "Dimensions need to be equal")
                    
                    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcBuffer)
                    let destBytesPerRow = CVPixelBufferGetBytesPerRow(destBuffer)
                    arc_assert(srcBytesPerRow == destBytesPerRow, "If not equal, we can't do a simple memcopy, would need to iterate through each row and copy the number of bytes from the least bytes per row one which has less padding")
                    
                    memcpy(destBufferAddress, srcBufferAddress, srcBufferHeight * srcBytesPerRow);
                }
                
            }) { arc_assertion_failure("Failed to lock buffer")}
        }) { arc_assertion_failure("Failed to lock buffer")}

    }
    
    // Inspired by this: https://gist.github.com/valkjsaaa/f9edfc25b4fd592caf82834fafc07759
    public func deepCopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional:CVPixelBuffer?
        
        let pixelBufferAttributes = [
            kCVPixelBufferWidthKey: width as CFTypeRef,
            kCVPixelBufferHeightKey: height as CFTypeRef,
            kCVPixelBufferPixelFormatTypeKey: format.unicodeStringValue as CFString,
            kCVPixelBufferMetalCompatibilityKey: true as CFTypeRef,
//            kCVPixelBufferOpenGLESCompatibilityKey: true as CFTypeRef,
//            kCVPixelBufferOpenGLESTextureCacheCompatibilityKey: true as CFTypeRef,
            kCVPixelBufferIOSurfacePropertiesKey: Dictionary<CFString,CFString>() as CFDictionary
        ]
        
        
        CVPixelBufferCreate(nil, width, height, format, pixelBufferAttributes as CFDictionary, &pixelBufferCopyOptional)
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBuffer.copyCVPixelBuffer(srcBuffer: self, destBuffer: pixelBufferCopy)
        }
        return pixelBufferCopyOptional
    }
}
