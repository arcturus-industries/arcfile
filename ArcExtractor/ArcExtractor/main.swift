//
//  main.swift
//  ArcExtractor
//
//  Created by Aaron Bryden on 3/27/21.
//

import Foundation
import SwiftProtobuf
import FlatBuffers
import CoreImage
import Darwin

import AVFoundation
import VideoToolbox

if CommandLine.arguments.count < 2 {
    print("No file specified")
    exit(1)
}

//TODO: Optionally specify output options and set of frames to output

let basePath = CommandLine.arguments[1]
let url = URL(fileURLWithPath: basePath)
let outURL = URL(fileURLWithPath: basePath+".out/")

if !FileManager.default.fileExists(atPath: basePath + ".out/") {
    do {
        try FileManager.default.createDirectory(atPath: basePath + ".out/", withIntermediateDirectories: true, attributes: nil)
        
    } catch {
        print(error.localizedDescription);
    }
}

let instream = InputStream.init(url: url)!
instream.open()
var count = 0

//reuse a single buffer to process all frames
var _buffer: CVPixelBuffer?

//It would be nice if the image dimensions were in the header.
CVPixelBufferCreate(
    nil,
    1920,
    1080,
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    nil,
    &_buffer)


let buffer = _buffer!

CVPixelBufferLockBaseAddress(buffer, [])

let videoDecoder = LTVideoDecoder(codecType: kCMVideoCodecType_HEVC)

while true {
    do {
        let wrappedMsg = try BinaryDelimited.parse(messageType: ARC_WrappedMessage.self, from: instream)
        if(true) {
            
            if(wrappedMsg.colorImage.imageEncoding != .rawYuv && wrappedMsg.colorImage.imageEncoding != .hevc) {
                print("Sorry only Raw YUV and HEVC are supported.")
                exit(1)
            }
            
            if(wrappedMsg.colorImage.imageEncoding == .rawYuv) {
                let yuvurl = outURL.appendingPathComponent(String(count) + ".yuv")
                let jpgurl = outURL.appendingPathComponent(String(count) + ".jpg")
                try! wrappedMsg.colorImage.imageData.write(to: yuvurl)
                
                let data = wrappedMsg.colorImage.imageData
                
                data.withUnsafeBytes { (ptr: UnsafePointer<UInt32>) in
                    
                    //get offsets of the planes and bytes per row out of the data
                    let rawPtr = UnsafeRawPointer(ptr)
                    let offsets = [Int(ptr[0].byteSwapped),Int(ptr[2].byteSwapped)]
                    let bytesPerRows = [Int(ptr[1].byteSwapped),Int(ptr[3].byteSwapped)]
                    
                    //Why isn't this in the header!! Am I missing it?
                    let heights = [1080,540]
                    
                    
                    for plane in 0 ..< 2
                    {
                        let base = rawPtr
                        let dest        = CVPixelBufferGetBaseAddressOfPlane(buffer, plane)
                        let source = base+offsets[plane]
                        
                        //print(offset)
                        let height      = heights[plane]
                        let bytesPerRow = bytesPerRows[plane]

                        memcpy(dest, source, height * bytesPerRow)
                        
                        let ciImage = CIImage(cvPixelBuffer: buffer)
                        let context = CIContext.init()
                        let space = CGColorSpace(name: CGColorSpace.sRGB)
                        try! context.writeJPEGRepresentation(of: ciImage, to:jpgurl, colorSpace: space!, options: [:])
                    }
                }
            }
            else if(wrappedMsg.colorImage.imageEncoding == .hevc) {
                
                let jpgurl = outURL.appendingPathComponent(String(count) + ".jpg")
                
                let doneDecoding = DispatchSemaphore(value:0)
                
                //need to decode frame data
                
                let _ = videoDecoder.decode(
                    imageHeader: wrappedMsg.colorImage.imageHeader,
                    imageData: wrappedMsg.colorImage.imageData,
                    presentationTimeStamp: wrappedMsg.colorImage.timestampInSeconds.getCMTime(),
                    duration: 0.0.getCMTime())
                { (imageBuffer:CVImageBuffer?, videoFormatDescription:CMVideoFormatDescription) in
                    
                    //let (hours, minutes, seconds, milliseconds) = imageFrame.presentationTimeStamp.cmTime.secondsToHoursMinutesSecondsMilliseconds
                    //lt_log("Frame decoded! Timestamp: %d:%d:%d:%d", log: self.captureSessionLog, hours, minutes, seconds, milliseconds)
                    
                    //lt_log("Frame decoded with time: %.3f", log:self.captureSessionLog, CMTimeGetSeconds(imageFrame.presentationTimeStamp.cmTime))
                    
                    
                    
                    //imageFrame.deviceMotion =
                    
                    let ciImage = CIImage(cvPixelBuffer: imageBuffer!)

                    let context = CIContext.init()
                    let space = CGColorSpace(name: CGColorSpace.sRGB)
                    try! context.writeJPEGRepresentation(of: ciImage, to:jpgurl, colorSpace: space!, options: [:])
                    
                    
                    doneDecoding.signal()
                }
                
                doneDecoding.wait()
            }
            
            
          
            
        }
        count = count + 1
    } catch BinaryDelimited.Error.truncated {
        // End of file
        break
    }
    catch {
        print("Unexpected error: \(error).")
    }
}

instream.close()
