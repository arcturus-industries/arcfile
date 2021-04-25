// Thanks to Vikas Reddy who generously allowed us to use this code
// Taken from code created by Vikas Reddy with permission
//
//  Created by Vikas Reddy on 5/17/20.
//

//NOTE: This work was inspired by https://github.com/greenpig/VideoToolboxH265Encoder which served as a great initial reference.
//Also thanks to Jeff Powers (https://twitter.com/jrpowers) who helped answer various questions about this!

import Foundation

import AVFoundation
import VideoToolbox
import VideoToolbox.VTDecompressionProperties
import os.log

private let EXPECTED_NALUNITHEADER_LENGTH:Int32 = 4 //seems like what it is for HEVC checking it on a few images, what is it for H264?

//TODO: Verify this is always the case
private let EXPECTED_PARAMETER_SETS_HEVC:Int = 4
private let EXPECTED_PARAMETER_SETS_H264:Int = 2

public typealias LTVideoEncoderFinishedHandler = (_:Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)>, _:UnsafeMutablePointer<Int8>, _:Int, _:CMSampleBuffer?, _:CMVideoFormatDescription) -> Void

public class ARC_VideoEncoder : NSObject {
    
    private let compressionQueue = DispatchQueue(label: "LTVideoEncoder", qos: DispatchQoS.utility)
    
    private var compressionSession: VTCompressionSession?
    private var codecType: CMVideoCodecType
    private var profileLevelToUse: CFString
    
    private let encodingLog:OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "LTVideoEncoder")
    
    init(codecType: CMVideoCodecType) {
        assert(codecType == kCMVideoCodecType_HEVC || codecType == kCMVideoCodecType_H264, "Unsupported codec type, only kCMVideoCodecType_HEVC and kCMVideoCodecType_H264 are supported currently")
        
        self.codecType = codecType
        self.profileLevelToUse = (codecType == kCMVideoCodecType_HEVC)  ? kVTProfileLevel_HEVC_Main_AutoLevel : kVTProfileLevel_H264_Main_AutoLevel
    }
    
    public func encode(
        imageBuffer: CVImageBuffer,
        presentationTimeStamp: CMTime,
        duration: CMTime,
        fpsHint: Float = 30.0, //assume 30 by default
        handleEncoding: @escaping LTVideoEncoderFinishedHandler
    ) -> Void {
        
        compressionQueue.async {
            //Create compression session if this is the first frame
            if self.compressionSession == nil {
                let width = Int32(CVPixelBufferGetWidth(imageBuffer))
                let height = Int32(CVPixelBufferGetHeight(imageBuffer))
                
                //lt_log("width: %d, height: %d", log: self.encodingLog, width, height)
                
                //TODO: How long does this call take, should we somehow do this outside the encode loop?
                
                RunAndCheckOSStatus({ () -> OSStatus in
                    VTCompressionSessionCreate(
                    allocator:kCFAllocatorDefault,
                    width:width,
                    height:height,
                    codecType: self.codecType,
                    encoderSpecification: nil, //pass nil or an actually created dict, empty dict might cause issues
                    imageBufferAttributes: nil, //pass nil or an actually created dict, empty dict might cause issues
                    compressedDataAllocator: nil,
                    outputCallback: nil, //compressionOutputCallback,
                    refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                    compressionSessionOut: &(self.compressionSession))
                }, errorCode: { (status:OSStatus) -> Void in
                    assertionFailure("Error creating VTCompressionSession: \(status)")
                })
                
                guard let c = self.compressionSession else {
                    assertionFailure("Error creating compression session")
                    return
                }
                
                //TODO: Potentially adjust compression targets for H265 vs H264?
                //TODO: Does it make sense to try to set some Data Rate Limit (see properties dictionary below)
                
                let SWAGCompressionFactor:Float = self.codecType == kCMVideoCodecType_HEVC ? 0.15 : 0.15 //No idea if this is good at all it just seems to be OK for HEVC.
                let bitsPerPixelTarget:Float = Float(width) * Float(height) * SWAGCompressionFactor
                let bitsPerSecondTarget:Int32 = Int32(bitsPerPixelTarget * fpsHint)
                
                let properties = [
                    kVTCompressionPropertyKey_ProfileLevel: self.profileLevelToUse,
                    kVTCompressionPropertyKey_RealTime: true as CFTypeRef,
                    kVTCompressionPropertyKey_AllowFrameReordering: false as CFTypeRef,
                    kVTCompressionPropertyKey_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4,
                    kVTCompressionPropertyKey_MaxKeyFrameInterval: 5 as CFTypeRef,
                    kVTCompressionPropertyKey_AverageBitRate: bitsPerSecondTarget as CFTypeRef,
                    //kVTCompressionPropertyKey_DataRateLimits: [width * height * 2 * 4, 1] as CFArray //IMPORTANT WARNING: THIS CAN POTENTIALLY CAUSE DELIVERED FRAMES TO BE NULL IF DATA RATE IS EXCEEDED!!!!
                ]
                RunAndCheckOSStatus({ () -> OSStatus in
                VTSessionSetProperties(c, propertyDictionary: properties as CFDictionary)
                })
                
                RunAndCheckOSStatus({ () -> OSStatus in
                VTCompressionSessionPrepareToEncodeFrames(c)
                })
            }
            
            guard let c = self.compressionSession else {
                assertionFailure("Error creating compression session")
                return
            }
            
            var flagsOut = VTEncodeInfoFlags()

            if !(imageBuffer.wrapLockAndUnlock(CVBuffer.LockFlag.readonly) {

                RunAndCheckOSStatus({ () -> OSStatus in
                
                VTCompressionSessionEncodeFrame(
                    c,
                    imageBuffer: imageBuffer,
                    presentationTimeStamp: presentationTimeStamp,
                    duration: duration,
                    frameProperties: nil,
                    infoFlagsOut: &flagsOut,
                    outputHandler:
                    { (status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) -> Void in
                        
                        self.handleCompressionOutputCallback(status: status, infoFlags: infoFlags, sampleBuffer: sampleBuffer, encodingFinishedHandler: handleEncoding)
                    })
                })
                
                assert(!flagsOut.contains(VTEncodeInfoFlags.frameDropped), "Frame dropped!")

                if(flagsOut.contains(VTEncodeInfoFlags.asynchronous)) {
                    VTCompressionSessionCompleteFrames(c, untilPresentationTimeStamp:CMTime.positiveInfinity);
                }
                
            }) { assertionFailure("Could not lock or unlock!") }
        }
    }
    
    private func isKeyFrame(sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) else {
            arc_log("could not get attachments from sampleBuffer", log: self.encodingLog)
            assertionFailure("Compression failed")
            return false
        }

        arc_log(String(format:"attachments: %@", "\(attachments)"), log: self.encodingLog)
        
        let rawDict: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
        let dict: CFDictionary = Unmanaged.fromOpaque(rawDict).takeUnretainedValue()
        let isKeyFrame:Bool = !CFDictionaryContainsKey(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        return isKeyFrame
    }
    
    private func handleCompressionOutputCallback(status: OSStatus,
                                                    infoFlags: VTEncodeInfoFlags,
                                                    sampleBuffer: CMSampleBuffer?,
                                                    encodingFinishedHandler: @escaping LTVideoEncoderFinishedHandler) -> Void
    {
        compressionQueue.async {

        guard status == noErr else {
            arc_log(String(format:"error when encoding: %@", status), log: self.encodingLog)

            assertionFailure("Compression failed")
            return
        }

        if infoFlags == .frameDropped {
            arc_log("frame dropped when encoding", log: self.encodingLog)
            assertionFailure("Compression failed")
            return
        }

        guard let sampleBuffer = sampleBuffer else {
            arc_log("sampleBuffer is nil", log: self.encodingLog)
            assertionFailure("Compression failed")
            return
        }

        if CMSampleBufferDataIsReady(sampleBuffer) != true {
            arc_log("sampleBuffer data is not ready", log: self.encodingLog)
            assertionFailure("Compression failed")
            return
        }

        //TODO: Is it necessary to persist whether a frame was a keyframe or not? Doesn't seem required on the decoding side of things
        //var isKeyFrame = isKeyFrame(sampleBuffer: sampleBuffer)
            
        guard let videoFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            arc_assertion_failure("videoFormatDescription is nil")
            return
        }
            
        guard let parameterSets: Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)> = self.getParameterSetsForSampleBuffer(sampleBuffer: sampleBuffer, codec: self.codecType, videoFormatDescription: videoFormatDescription) else {
            arc_log("problem with parameter sets", log: self.encodingLog)
            assertionFailure("Failing")
            return
        }

        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            arc_log("Could not get data buffer from sampleBuffer", log: self.encodingLog)
            assertionFailure("Failing")
            return
        }

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr else {
            arc_log("Could not get data pointer from dataBuffer", log: self.encodingLog)
            assertionFailure("Failing")
            return
        }

        assert(totalLength == lengthAtOffset, "Unhandled case if we don't get the whole buffer at once")

        guard let dataPointerNotNil:UnsafeMutablePointer<Int8> = dataPointer else {
            arc_log("Could not get data pointer from dataBuffer", log: self.encodingLog)
            assertionFailure("Failing")
            return
        }

        encodingFinishedHandler(parameterSets, dataPointerNotNil, totalLength, sampleBuffer, videoFormatDescription)
        
        }//end async call
    }
    
    
    private func getParameterSetsForSampleBuffer(sampleBuffer: CMSampleBuffer, codec: CMVideoCodecType, videoFormatDescription:CMVideoFormatDescription) -> Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)>? {
        
        
        var topLevelParameterSetCount:Int = 0

        
        var nalHeaderLength:Int32 = -99
        
        let usingHEVC = codec == kCMVideoCodecType_HEVC
        let expectedParameterSets = usingHEVC ? EXPECTED_PARAMETER_SETS_HEVC : EXPECTED_PARAMETER_SETS_H264
        let formatDescriptionFunctionToCall = usingHEVC ? CMVideoFormatDescriptionGetHEVCParameterSetAtIndex : CMVideoFormatDescriptionGetH264ParameterSetAtIndex
        
        RunAndCheckOSStatus({ () -> OSStatus in
        formatDescriptionFunctionToCall(
            videoFormatDescription,
            0,
            nil,
            nil,
            &topLevelParameterSetCount,
            &nalHeaderLength
        )
        })
        
        assert(nalHeaderLength == EXPECTED_NALUNITHEADER_LENGTH, String(format:"Unexpected NAL Unit Header Length: %d", nalHeaderLength))
        assert(topLevelParameterSetCount >= 0, "Count is weird")
        
        var parameterSets = Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)>(repeating: (parameterSetCount: -1, parameterData: nil, parameterDataSizeInBytes: -1), count: topLevelParameterSetCount)
        
        for index in 0..<topLevelParameterSetCount
        {
            var parameterSetCount:Int = 0
            var parameterData: UnsafePointer<UInt8>?
            var parameterDataSizeInBytes: Int = 0
            nalHeaderLength = -99
            
            
            RunAndCheckOSStatus({ () -> OSStatus in
            formatDescriptionFunctionToCall(
                videoFormatDescription,
                index,
                &parameterData,
                &parameterDataSizeInBytes,
                &parameterSetCount,
                &nalHeaderLength
            )
            })
            
//            lt_log("PARAM DATA ORIG index: %d, MD5: %@",
//                   log: self.encodingLog, index,
//                   Get_MD5_Hash_String(
//                        messageDataPointer:parameterData,
//                        messageDataLength: parameterDataSizeInBytes
//                    )
//            )
            
            assert(nalHeaderLength == EXPECTED_NALUNITHEADER_LENGTH, String(format:"Unexpected NAL Unit Header Length: %d", nalHeaderLength))
            assert(parameterSetCount == expectedParameterSets, "Num parameter sets doesn't match expecation");
            
            parameterSets[index].parameterSetCount = parameterSetCount
            parameterSets[index].parameterData = parameterData
            parameterSets[index].parameterDataSizeInBytes = parameterDataSizeInBytes
        }
        
        //lt_log("\(parameterSets)", log: self.encodingLog)
        
        //lt_log("parameterSets: %@", log: self.encodingLog, "\(parameterSets)")
        return parameterSets
    }
}




public typealias ARCVideoDecoderFinishedHandler = (CVImageBuffer?, CMVideoFormatDescription) -> Void

public class ARCVideoDecoder : NSObject {

    private let decompressionQueue = DispatchQueue(label: "LTVideoDecoder")

    private var decompressionSession: VTDecompressionSession? = nil
    private var formatDescription: CMFormatDescription? = nil
    
    
    #if os(iOS)
        private let decodingLog:OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ARCVideoDecoder")
    #elseif os(macOS)
        private let decodingLog:OSLog = OSLog(subsystem: "ARCVideoDecoder", category: "ARCVideoDecoder")
    #endif
    
    
    
    private var codecType: CMVideoCodecType
    
    var dummyPtr = UInt8(0)
    
    init(codecType: CMVideoCodecType) {
        
        assert(codecType == kCMVideoCodecType_HEVC || codecType == kCMVideoCodecType_H264, "Unsupported codec type, only kCMVideoCodecType_HEVC and kCMVideoCodecType_H264 are supported currently")
        
        self.codecType = codecType
    }
    
    public func decode(imageHeader:[Data], imageData:Data, presentationTimeStamp:CMTime, duration: CMTime, handleFinishedDecoding:@escaping ARCVideoDecoderFinishedHandler) -> Void {
        
        //self.decompressionQueue.async {
        if(self.formatDescription == nil) {
            
            let parameterSetCount = imageHeader.count
            
            let usingHEVC:Bool = self.codecType == kCMVideoCodecType_HEVC
            
            let expectedParameterSets = usingHEVC ? EXPECTED_PARAMETER_SETS_HEVC : EXPECTED_PARAMETER_SETS_H264
            
            assert(parameterSetCount == expectedParameterSets)
            
            var parameterSetPointers = Array<UnsafePointer<UInt8>>(repeating: &self.dummyPtr, count: parameterSetCount)
            var parameterSetSizes = Array<Int>(repeating:-1, count:parameterSetCount)
            
            for index in 0..<parameterSetCount
            {
                //lt_log("DECODING Header index: %d, SHA256: %@", log: self.decodingLog, index, Get_SHA256_Hash_String(messageData:imageFrame.imageHeader[index]))
                
                //Using toll free bridging over to NSData because for some reason trying to access the data withUnsafeBytes or similar causes weird issues when the data is 7 bytes long (I think everything < 8 bytes probably causes issue?) and we need a UInt8 pointer
                let headerDataAsNSData = (imageHeader[index] as NSData)
                
                parameterSetPointers[index] = headerDataAsNSData.bytes.bindMemory(to:
                    UInt8.self,
                    capacity: imageHeader[index].count)
                
                parameterSetSizes[index] = imageHeader[index].count
            }
            
            RunAndCheckOSStatus({ () -> OSStatus in
                
                if(usingHEVC) {
                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                    allocator: nil,
                    parameterSetCount: parameterSetCount,
                    parameterSetPointers: &parameterSetPointers,
                    parameterSetSizes: &parameterSetSizes,
                    nalUnitHeaderLength: EXPECTED_NALUNITHEADER_LENGTH,
                    extensions: nil,
                    formatDescriptionOut: &self.formatDescription)
                } else {
                    return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil,
                    parameterSetCount: parameterSetCount,
                    parameterSetPointers: &parameterSetPointers,
                    parameterSetSizes: &parameterSetSizes,
                    nalUnitHeaderLength: EXPECTED_NALUNITHEADER_LENGTH,
                    formatDescriptionOut: &self.formatDescription)
                }
            })
        }
        
        
        let dimensions:CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(self.formatDescription!);
        
        
        if self.decompressionSession == nil {
            
            //things seem to work even if none of these properties are specified?
            let imageBufferProperties = [
                //kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange.unicodeStringValue as CFString, //TODO: This doesn't seem to be needed at all
                //kCVPixelBufferMemoryAllocatorKey: TODO LOOK INTO,
                kCVPixelBufferWidthKey: dimensions.width as CFTypeRef, //TODO LOOK INTO,
                kCVPixelBufferHeightKey: dimensions.height as CFTypeRef, //TODO LOOK INTO,
                //kCVPixelBufferExtendedPixelsLeftKey: TODO LOOK INTO,
                //kCVPixelBufferExtendedPixelsTopKey: TODO LOOK INTO,
                //kCVPixelBufferExtendedPixelsRightKey: TODO LOOK INTO,
                //kCVPixelBufferExtendedPixelsBottomKey: TODO LOOK INTO,
                //kCVPixelBufferBytesPerRowAlignmentKey: TODO LOOK INTO,
                //kCVPixelBufferCGBitmapContextCompatibilityKey: TODO LOOK INTO,
                //kCVPixelBufferCGImageCompatibilityKey: TODO LOOK INTO,
                kCVPixelBufferOpenGLCompatibilityKey: true as CFTypeRef, //TODO: DO we need this?
                //kCVPixelBufferPlaneAlignmentKey: TODO LOOK INTO,
                //kCVPixelBufferIOSurfacePropertiesKey: Dictionary<CFString,CFString>() as CFDictionary, //TODO: Do we need this?
                //kCVPixelBufferOpenGLESCompatibilityKey: true as CFTypeRef, //TODO LOOK INTO,
                kCVPixelBufferMetalCompatibilityKey: true as CFTypeRef, //TODO LOOK INTO,
                //kCVPixelBufferOpenGLESTextureCacheCompatibilityKey: true as CFTypeRef, //TODO LOOK INTO,
            ]
            
            let decodingProperties = [
                kVTDecompressionPropertyKey_RealTime: true as CFTypeRef,
                
                //the following only seem to work on OSX? Any way to force hardware acceleration?
                //kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder
                //kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder
            ]

            RunAndCheckOSStatus({ () -> OSStatus in
                VTDecompressionSessionCreate(
                    allocator: nil,
                    formatDescription: self.formatDescription!,
                    decoderSpecification: decodingProperties as CFDictionary,
                    imageBufferAttributes: imageBufferProperties as CFDictionary,
                    outputCallback: nil, //&outputCallback,
                    decompressionSessionOut: &self.decompressionSession
                )
            })
        }
        
        var decodedImageBlockBuffer:CMBlockBuffer?
        
        let imageDataSizeInBytes = imageData.count
        
        let imageDataPtr =
        imageData.withUnsafeBytes({ (bufferPtr:UnsafeRawBufferPointer) -> UnsafeMutableRawPointer? in
            UnsafeMutableRawPointer(mutating: bufferPtr.baseAddress!)
        })
        
        RunAndCheckOSStatus({ () -> OSStatus in
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: imageDataPtr,
                blockLength: imageDataSizeInBytes,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: imageDataSizeInBytes,
                flags: 0,
                blockBufferOut: &decodedImageBlockBuffer
            )
        })
        
        
        var sampleBuffer:CMSampleBuffer?;
        
        var sampleTimings = [CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid
            )]

        var sampleSizes = [imageDataSizeInBytes]
        
        RunAndCheckOSStatus({ () -> OSStatus in
            CMSampleBufferCreate(
                allocator: kCFAllocatorDefault,
                dataBuffer: decodedImageBlockBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: self.formatDescription,
                sampleCount: 1,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &sampleTimings,
                sampleSizeEntryCount: 1,
                sampleSizeArray: &sampleSizes,
                sampleBufferOut: &sampleBuffer
            )
        })
        
        var infoFlags:VTDecodeInfoFlags = VTDecodeInfoFlags()
        
        RunAndCheckOSStatus(
        { () -> OSStatus in

            VTDecompressionSessionDecodeFrame(
                self.decompressionSession!,
                sampleBuffer: sampleBuffer!,
                flags: VTDecodeFrameFlags(rawValue:0),
                infoFlagsOut: &infoFlags,
                outputHandler: { (status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, duration: CMTime) -> Void in
                    
                    
                    handleFinishedDecoding(imageBuffer, self.formatDescription!)
                    
            })
        })
    }
}
