//
//  ARCViewerApp.swift
//  Shared
//

import SwiftUI
import SwiftProtobuf
import FlatBuffers

extension OutputStream {
  func write(data: Data) -> Int {
    return data.withUnsafeBytes {
      write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
    }
  }
}

@main
struct ARCViewerApp: App {
    
    func writeTestARCFileFlatBuffers(fileUrl:URL)
    {
        let outstream = OutputStream.init(url: fileUrl, append: false)!
        outstream.open()
        if let asset = NSDataAsset(name: "TestImage") {
            
            // Write the image twice
            for _ in 1...2 {
                
                var builder = FlatBufferBuilder(initialSize: Int32(asset.data.count) * 2 + 100)
                let imageDataOffset = builder.createVector([Byte](asset.data))
                let serializedImage = arcfile_Image.createImage(&builder, imageEncoding: arcfile_Encoding.jpg, imageTimestamp: 0.0, vectorOfImageData: imageDataOffset)
                builder.finish(offset: serializedImage)
                let buf:Data = builder.data

                var headerBuilder = FlatBufferBuilder()
                let header = arcfile_Header.createHeader(&headerBuilder, entrySize: UInt32(buf.count))
                headerBuilder.finish(offset: header)
                
                _ = outstream.write(data: headerBuilder.data)
                _ = outstream.write(data: builder.data)
                
            }

        }
        outstream.close()
    }
    
    func readTestARCFileFlatBuffers(fileUrl:URL)
    {
        let instream = InputStream.init(url: fileUrl)!
        instream.open()
        
        while true {
            do {
                
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 20)
                let bytesRead = instream.read(buffer, maxLength: 20)
                let headerData = Data(bytes: buffer, count: 20)

                if bytesRead < 20 {
                    break
                }
                
                let header = arcfile_Header.getRootAsHeader(bb: ByteBuffer.init(data: headerData))
                
                let imageDataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(header.entrySize))
                instream.read(imageDataBuffer, maxLength: Int(header.entrySize))
                let imageData = Data(bytes: imageDataBuffer, count: Int(header.entrySize))

                let image = arcfile_Image.getRootAsImage(bb: ByteBuffer.init(data: imageData))

                print("Got image with \(image.imageData.count) bytes")
            }
                
        }

        instream.close()
    }
    
    func writeTestARCFileProtobuf(fileUrl:URL)
    {
        let outstream = OutputStream.init(url: fileUrl, append: false)!
        outstream.open()
        if let asset = NSDataAsset(name: "TestImage") {
            
            var image = ARC_ColorImage()
            image.imageEncoding = ARC_ImageEncoding.jpg
            image.timestampInSeconds = 0
            image.imageData = asset.data
            
            var wrappedMsg = ARC_WrappedMessage()
            wrappedMsg.colorImage = image
            
            // Write the image twice
            try! BinaryDelimited.serialize(message: wrappedMsg, to: outstream)
            try! BinaryDelimited.serialize(message: wrappedMsg, to: outstream)
        }
        outstream.close()
    }
    
    func readTestARCFileProtobuf(fileUrl:URL)
    {
        let instream = InputStream.init(url: fileUrl)!
        instream.open()
        
        while true {
            do {
                let wrappedMsg = try BinaryDelimited.parse(messageType: ARC_WrappedMessage.self, from: instream)
                print("Got image with \(wrappedMsg.colorImage.imageData.count) bytes")
            } catch BinaryDelimited.Error.truncated {
                // End of file
                break
            }
            catch {
                print("Unexpected error: \(error).")
            }
        }

        instream.close()
    }
    
    init() {
        
        // Will save to sandboxed app Container ...
        let url:URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pbUrl = url.appendingPathComponent("testProtobuf.arc")
        let fbUrl = url.appendingPathComponent("testFlatBuffers.arc")
        
        print("Protobuf ARC: \(pbUrl.path)")
        print("FlatBuffers ARC: \(fbUrl.path)")

        writeTestARCFileProtobuf(fileUrl: pbUrl)
        writeTestARCFileFlatBuffers(fileUrl: fbUrl)
                                    
        readTestARCFileProtobuf(fileUrl:pbUrl)
        readTestARCFileFlatBuffers(fileUrl:fbUrl)
        print("got here")

    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
