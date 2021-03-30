//
//  Extensions.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/29/21.
//

import Foundation

extension OutputStream {
    func write(data: Data) -> Int {
        return data.withUnsafeBytes {
            write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
        }
    }
}
