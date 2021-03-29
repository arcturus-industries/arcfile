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
var written = false
var count = 0

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

while true {
    do {
        let wrappedMsg = try BinaryDelimited.parse(messageType: ARC_WrappedMessage.self, from: instream)
        if(true) {
            let yuvurl = outURL.appendingPathComponent(String(count) + ".yuv")
            let jpgurl = outURL.appendingPathComponent(String(count) + ".jpg")
            try! wrappedMsg.colorImage.imageData.write(to: yuvurl)
            
            
            
            
            
            let data = wrappedMsg.colorImage.imageData
            
            data.withUnsafeBytes { (ptr: UnsafePointer<UInt32>) in
                
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
