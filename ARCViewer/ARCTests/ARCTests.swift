//
//  ARCTests.swift
//  ARCTests
//
//  Created by Aaron Bryden on 3/26/21.
//
import SwiftProtobuf
import FlatBuffers
import CryptoKit


extension OutputStream {
  func write(data: Data) -> Int {
    return data.withUnsafeBytes {
      write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
    }
  }
}

import XCTest

class ARCTests: XCTestCase {

    
    func writeTestARCFileFlatBuffers(fileUrl:URL) throws -> SHA256Digest
    {
        let outstream = OutputStream.init(url: fileUrl, append: false)!
        outstream.open()
        if let asset = NSDataAsset(name: "TestImage") {
            let hash = SHA256.hash(data: asset.data)

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
            outstream.close()
            return hash

        }
        else {
            outstream.close()
            fatalError("Test data file not present.")
        }
     
    }
    
    func readTestARCFileFlatBuffers(fileUrl:URL) -> [SHA256Digest]
    {
        let instream = InputStream.init(url: fileUrl)!
        instream.open()
        var hashes = [SHA256Digest]()
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
                let sampleData = Data(bytes: imageDataBuffer, count: Int(header.entrySize))

                let image = arcfile_Image.getRootAsImage(bb: ByteBuffer.init(data: sampleData))
                
                let p = UnsafeBufferPointer(start:image.imageData, count:image.imageData.count)
                let imageData = Data(buffer:p)
                
                hashes.append(SHA256.hash(data: imageData))

                print("Got image with \(image.imageData.count) bytes")
            }
                
        }

        instream.close()
        return hashes
    }
    
    func writeTestARCFileProtobuf(fileUrl:URL) -> SHA256Digest
    {
        let outstream = OutputStream.init(url: fileUrl, append: false)!
        
        outstream.open()
        if let asset = NSDataAsset(name: "TestImage") {
            let hash = SHA256.hash(data: asset.data)
            var image = ARC_ColorImage()
            image.imageEncoding = ARC_ImageEncoding.jpg
            image.timestampInSeconds = 0
            image.imageData = asset.data
            
            var wrappedMsg = ARC_WrappedMessage()
            wrappedMsg.colorImage = image
            
            // Write the image twice
            try! BinaryDelimited.serialize(message: wrappedMsg, to: outstream)
            try! BinaryDelimited.serialize(message: wrappedMsg, to: outstream)
            outstream.close()
            return hash
        }
        else {
            outstream.close()
            fatalError()
        }
        
    }
    
    func readTestARCFileProtobuf(fileUrl:URL) ->[SHA256Digest]
    {
        let instream = InputStream.init(url: fileUrl)!
        instream.open()
        var hashes = [SHA256Digest]()
        while true {
            do {
                let wrappedMsg = try BinaryDelimited.parse(messageType: ARC_WrappedMessage.self, from: instream)
                hashes.append(SHA256.hash(data: wrappedMsg.colorImage.imageData))
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
        return hashes
    }
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testProtoBuf() throws {
        let url:URL = FileManager.default.temporaryDirectory
        let pbUrl = url.appendingPathComponent("testProtobuf.arc")
        print(pbUrl)
        let inputHash = writeTestARCFileProtobuf(fileUrl: pbUrl)
        let outputHashes = readTestARCFileProtobuf(fileUrl: pbUrl)
        print(inputHash)
        print(outputHashes)
        for outputHash in outputHashes {
            XCTAssert(inputHash.description == outputHash.description)
        }
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testFlatBuf() throws {
        let url:URL = FileManager.default.temporaryDirectory
        let fbUrl = url.appendingPathComponent("testFlatBuf.arc")
        print(fbUrl)
        let inputHash = try writeTestARCFileFlatBuffers(fileUrl: fbUrl)
        let outputHashes = readTestARCFileFlatBuffers(fileUrl: fbUrl)
        print(inputHash)
        print(outputHashes)
        for outputHash in outputHashes {
            XCTAssert(inputHash.description == outputHash.description)
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
