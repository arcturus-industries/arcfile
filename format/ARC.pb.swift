// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: ARC.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

//https://developers.google.com/protocol-buffers/docs/proto3
//https://github.com/apple/swift-protobuf/blob/master/Documentation/PLUGIN.md

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

enum ARC_ImageEncoding: SwiftProtobuf.Enum {
  typealias RawValue = Int
  case h264 // = 0

  ///aka H265
  case hevc // = 1
  case jpg // = 2
  case png // = 3
  case rawYuv // = 4
  case rawRgb // = 5
  case rawYcbcr // = 6
  case UNRECOGNIZED(Int)

  init() {
    self = .h264
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .h264
    case 1: self = .hevc
    case 2: self = .jpg
    case 3: self = .png
    case 4: self = .rawYuv
    case 5: self = .rawRgb
    case 6: self = .rawYcbcr
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .h264: return 0
    case .hevc: return 1
    case .jpg: return 2
    case .png: return 3
    case .rawYuv: return 4
    case .rawRgb: return 5
    case .rawYcbcr: return 6
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension ARC_ImageEncoding: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static var allCases: [ARC_ImageEncoding] = [
    .h264,
    .hevc,
    .jpg,
    .png,
    .rawYuv,
    .rawRgb,
    .rawYcbcr,
  ]
}

#endif  // swift(>=4.2)

struct ARC_WrappedMessage {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var wrappedMessage: ARC_WrappedMessage.OneOf_WrappedMessage? = nil

  var colorImage: ARC_ColorImage {
    get {
      if case .colorImage(let v)? = wrappedMessage {return v}
      return ARC_ColorImage()
    }
    set {wrappedMessage = .colorImage(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_WrappedMessage: Equatable {
    case colorImage(ARC_ColorImage)

  #if !swift(>=4.1)
    static func ==(lhs: ARC_WrappedMessage.OneOf_WrappedMessage, rhs: ARC_WrappedMessage.OneOf_WrappedMessage) -> Bool {
      switch (lhs, rhs) {
      case (.colorImage(let l), .colorImage(let r)): return l == r
      }
    }
  #endif
  }

  init() {}
}

struct ARC_ColorImage {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var imageEncoding: ARC_ImageEncoding = .h264

  var imageHeader: [Data] = []

  var imageData: Data = SwiftProtobuf.Internal.emptyData

  var timestampInSeconds: Double = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension ARC_ImageEncoding: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "H264"),
    1: .same(proto: "HEVC"),
    2: .same(proto: "JPG"),
    3: .same(proto: "PNG"),
    4: .same(proto: "RAW_YUV"),
    5: .same(proto: "RAW_RGB"),
    6: .same(proto: "RAW_YCBCR"),
  ]
}

extension ARC_WrappedMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "ARC_WrappedMessage"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "color_image"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1:
        var v: ARC_ColorImage?
        if let current = self.wrappedMessage {
          try decoder.handleConflictingOneOf()
          if case .colorImage(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {self.wrappedMessage = .colorImage(v)}
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if case .colorImage(let v)? = self.wrappedMessage {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ARC_WrappedMessage, rhs: ARC_WrappedMessage) -> Bool {
    if lhs.wrappedMessage != rhs.wrappedMessage {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ARC_ColorImage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "ARC_ColorImage"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "image_encoding"),
    2: .standard(proto: "image_header"),
    3: .standard(proto: "image_data"),
    4: .standard(proto: "timestamp_in_seconds"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularEnumField(value: &self.imageEncoding)
      case 2: try decoder.decodeRepeatedBytesField(value: &self.imageHeader)
      case 3: try decoder.decodeSingularBytesField(value: &self.imageData)
      case 4: try decoder.decodeSingularDoubleField(value: &self.timestampInSeconds)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.imageEncoding != .h264 {
      try visitor.visitSingularEnumField(value: self.imageEncoding, fieldNumber: 1)
    }
    if !self.imageHeader.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.imageHeader, fieldNumber: 2)
    }
    if !self.imageData.isEmpty {
      try visitor.visitSingularBytesField(value: self.imageData, fieldNumber: 3)
    }
    if self.timestampInSeconds != 0 {
      try visitor.visitSingularDoubleField(value: self.timestampInSeconds, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ARC_ColorImage, rhs: ARC_ColorImage) -> Bool {
    if lhs.imageEncoding != rhs.imageEncoding {return false}
    if lhs.imageHeader != rhs.imageHeader {return false}
    if lhs.imageData != rhs.imageData {return false}
    if lhs.timestampInSeconds != rhs.timestampInSeconds {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
