//
//  ARCViewerApp.swift
//  Shared
//

import SwiftUI
import SwiftProtobuf

@main
struct ARCViewerApp: App {
    
    func writeTestARCFile(fileUrl:URL)
    {
        let outstream = OutputStream.init(url: fileUrl, append: false)!
        outstream.open()
        if let asset = NSDataAsset(name: "TestImage") {
            var image = ARC_ColorImage()
            image.imageEncoding = ARC_ImageEncoding.jpg
            image.timestampInSeconds = 0
            image.imageData = asset.data
            
            // Write the image twice
            try! BinaryDelimited.serialize(message: image, to: outstream)
            try! BinaryDelimited.serialize(message: image, to: outstream)
        }
        outstream.close()
    }
    
    func readTestARCFile(fileUrl:URL)
    {
        let instream = InputStream.init(url: fileUrl)!
        instream.open()
        
        while true {
            do {
                let image = try BinaryDelimited.parse(messageType: ARC_ColorImage.self, from: instream)
                print("Got image with \(image.imageData.count) bytes")
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
        var fileUrl:URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileUrl.appendPathComponent("test.arc")
        print("Writing to & reading from " + fileUrl.path)

        writeTestARCFile(fileUrl:fileUrl)
        readTestARCFile(fileUrl:fileUrl)
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
