// Thanks to Vikas Reddy who generously allowed us to use this code
// Taken from code created by Vikas Reddy with permission
//
//  Created by Vikas Reddy on 6/22/20.
//

import Foundation
import os.log
import AVFoundation

import CryptoKit
import CoreMotion

public func arc_log(_ item: @autoclosure () -> String, log:OSLog) {
    #if DEBUG
    os_log("%@", log:log, item())
    #endif
}

public func arc_assert(_ boolExpression:@autoclosure () -> Bool, _ message:String) {
    #if DEBUG
    assert(boolExpression(), message)
    #endif
}

public func arc_assertion_failure(_ message:String = "") {
    #if DEBUG
    assertionFailure(message)
    #endif
}


////https://www.hackingwithswift.com/example-code/system/how-to-find-the-users-documents-directory
//public func getDocumentsDirectory() -> URL {
//    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//    let documentsDirectory = paths[0]
//    return documentsDirectory
//}

public func Get_SHA256_Hash_String(messageData: Data) -> String {
    return SHA256.hash(data: messageData).description
}

public func RunAndCheckOSStatus(_ codeToRun: () -> OSStatus, errorCode: ((OSStatus) -> Void)? = nil) {
    let status = codeToRun()
    
    if (status != noErr) {
        if(errorCode != nil) {
            errorCode!(status)
        } else {
            assertionFailure(SecCopyErrorMessageString(status, nil)! as String)
        }
    }
    return
}

public func RunAndCheckOSStatus(_ codeToRun: () -> OSStatus) {
    return RunAndCheckOSStatus(codeToRun, errorCode: nil)
}

extension CMTime {
    
    var secondsToHoursMinutesSecondsMilliseconds: (Int, Int, Int, Int) {
        let millisecondsInASecond = 1000
        let millisecondsInAMinute = millisecondsInASecond * 60
        let millisecondsInAnHour = millisecondsInAMinute * 60
        
        
        let totalMilliseconds = Int((Double(millisecondsInASecond) * seconds).rounded(FloatingPointRoundingRule.toNearestOrAwayFromZero))
        
        var remainingMilliseconds:Int
        
        let hours = totalMilliseconds / millisecondsInAnHour
        remainingMilliseconds = totalMilliseconds - hours * millisecondsInAnHour
        
        let minutes = remainingMilliseconds / millisecondsInAMinute
        remainingMilliseconds = remainingMilliseconds - minutes * millisecondsInAMinute
        
        let seconds = remainingMilliseconds / millisecondsInASecond
        remainingMilliseconds = remainingMilliseconds - seconds * millisecondsInASecond
        
        let milliseconds = remainingMilliseconds
        
        return (hours, minutes, seconds, milliseconds)
    }
}

extension Float64 {
    public func getCMTime() -> CMTime {
        return CMTimeMakeWithSeconds(self, preferredTimescale: 1000) //preferredTimescale is effectively "resolution"
    }
}



extension URL {
    public var creationDate: Date? {
        return (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
    
    public var modificationDate: Date? {
        return (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}



//From here: https://forums.swift.org/t/floatingpoint-equality/6233/6
precedencegroup FauxTwoPartOperatorPrecedence {
  associativity: right
  higherThan: BitwiseShiftPrecedence
}
public struct VaE<T> {
  var value: T
  var epsilon: T
}
infix operator +- : FauxTwoPartOperatorPrecedence // `±` is typed "shift-opt-=", at least with macOS's default QWERTY US keyboard layout
public func +- <T: BinaryFloatingPoint> (value: T, epsilon: T) -> VaE<T> {
  return VaE(value: value, epsilon: epsilon)
}
public func == <T: BinaryFloatingPoint> (lhs: T, rhs: VaE<T>) -> Bool {
  return lhs <= (rhs.value + rhs.epsilon) && lhs >= (rhs.value - rhs.epsilon)
}

//from here: https://stackoverflow.com/posts/29991529/revisions
public func IsRunningViaTests() -> Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}


//Inspired by: https://stackoverflow.com/questions/14222435/ios-c-convert-integer-into-four-character-string?lq=1#comment52636181_25625744
extension OSType {
    var unicodeStringValue: String {
        get {
            var stringValue = ""
            var value = self
            for _ in 0..<4
            {
                let test:Unicode.Scalar = Unicode.Scalar(value & 255)!
                stringValue = String(test) + stringValue
                value = value / 256
            }
            return stringValue
        }
    }
}

public typealias StateResetter = ()->Void

public class ResettableState
{
    private var stateResetter:StateResetter
    
    init(stateResetter:@escaping StateResetter) {
        self.stateResetter = stateResetter
    }
    
    public func resetState() {
        self.stateResetter()
    }
}


public protocol Queue {
associatedtype Element
//enqueue：add an object to the end of the Queue
mutating func enqueue(_ element: Element)
//dequeue：delete the object at the beginning of the Queue
mutating func dequeue() -> Element?
//isEmpty：check if the Queue is nil
var isEmpty: Bool { get }
//peek：return the object at the beginning of the Queue without removing it
var peek: Element? { get }
    var count: Int { get}
}

public struct QueueStack<T>: Queue {
    private var enqueueStack = [T]()
    private var dequeueStack = [T]()
    
    public var isEmpty: Bool {
        return dequeueStack.isEmpty && enqueueStack.isEmpty
    }
    
    public var peek: T? {
        return !dequeueStack.isEmpty ? dequeueStack.last : enqueueStack.first
    }
    
    public var count: Int {
        return enqueueStack.count + dequeueStack.count
    }
    
    public mutating func enqueue(_ element: T) {
        enqueueStack.append(element)
    }
    
    @discardableResult
    public mutating func dequeue() -> T? {
        if dequeueStack.isEmpty {
            dequeueStack = enqueueStack.reversed()
            enqueueStack.removeAll()
        }
        return dequeueStack.popLast()
    }
}

extension simd_float3x3 {
    public var ltDescription:String {
        get {
            return String(
                format: """
                \n%.2f, %.2f, %.2f\n\
                %.2f, %.2f, %.2f\n\
                %.2f, %.2f, %.2f\n
                """,
                self.columns.0[0], self.columns.1[0], self.columns.2[0],
                self.columns.0[1], self.columns.1[1], self.columns.2[1],
                self.columns.0[2], self.columns.1[2], self.columns.2[2]
            )
        }
    }
}

extension simd_float4x4 {
    public func flatArrayColumnAligned() -> Array<Float> {
        return Array<Float>(
            arrayLiteral:
            /*column 0*/    self[0,0],      self[0,1],      self[0,2],  self[0,3],
            /*column 1*/    self[1,0],      self[1,1],      self[1,2],  self[1,3],
            /*column 2*/    self[2,0],      self[2,1],      self[2,2],  self[2,3],
            /*column 3*/    self[3,0],      self[3,1],      self[3,2],  self[3,3]
            )
    }
    
    public var ltDescription:String {
        get {
            return String(
                format: """
                \n[%.2f, %.2f, %.2f, %.2f],\n\
                [%.2f, %.2f, %.2f, %.2f],\n\
                [%.2f, %.2f, %.2f, %.2f],\n\
                [%.2f, %.2f, %.2f, %.2f],\n
                """,
                self.columns.0[0], self.columns.1[0], self.columns.2[0], self.columns.3[0],
                self.columns.0[1], self.columns.1[1], self.columns.2[1], self.columns.3[1],
                self.columns.0[2], self.columns.1[2], self.columns.2[2], self.columns.3[2],
                self.columns.0[3], self.columns.1[3], self.columns.2[3], self.columns.3[3])
        }
    }
    
    //https://d3cw3dd2w32x2b.cloudfront.net/wp-content/uploads/2015/01/matrix-to-quat.pdf
    public func transform6DoFMatrixToRotationUnitQuaternion() -> vector_float4 {
        
        let m00 = self.columns.0[0]
        let m01 = self.columns.1[0]
        let m02 = self.columns.2[0]
        
        let m10 = self.columns.0[1]
        let m11 = self.columns.1[1]
        let m12 = self.columns.2[1]
        
        let m20 = self.columns.0[2]
        let m21 = self.columns.1[2]
        let m22 = self.columns.2[2]
        
        var t:Float
        
        var q:vector_float4
        
        if (m22 < 0) {
            if (m00 > m11)
            {
                t = 1 + m00 - m11 - m22
                q = vector_float4( t, m01+m10, m20+m02, m12-m21 )
            }
            else {
                t = 1 - m00 + m11 - m22
                q = vector_float4( m01+m10, t, m12+m21, m20-m02 );
                
            }
        } else {
            if (m00 < -m11) {
                t = 1 - m00 - m11 + m22;
                q = vector_float4( m20+m02, m12+m21, t, m01-m10 );
            }
            else {
                t = 1 + m00 + m11 + m22;
                q = vector_float4( m12-m21, m20-m02, m01-m10, t );
            }
        }
        
        let scalar = 0.5 / sqrt(t)
        q = q * scalar
        
        let x = q[0]
        let y = q[1]
        let z = q[2]
        let w = q[3]
        
        return vector_float4(w,x,y,z)
    }
}

extension simd_float3x3 {
    public func prettyPrint() -> String {
        return String(
                    format:"%.2f, %.2f, %.2f\n%.2f, %.2f, %.2f\n%.2f, %.2f, %.2f\n",
                    self.columns.0[0], self.columns.1[0], self.columns.2[0],
                    self.columns.0[1], self.columns.1[1], self.columns.2[1],
                    self.columns.0[2], self.columns.1[2], self.columns.2[2]
                )
            
    }
    
    //https://d3cw3dd2w32x2b.cloudfront.net/wp-content/uploads/2015/01/matrix-to-quat.pdf
    public func transform6DoFMatrixToRotationUnitQuaternion() -> vector_float4 {
        
        let m00 = self.columns.0[0]
        let m01 = self.columns.1[0]
        let m02 = self.columns.2[0]
        
        let m10 = self.columns.0[1]
        let m11 = self.columns.1[1]
        let m12 = self.columns.2[1]
        
        let m20 = self.columns.0[2]
        let m21 = self.columns.1[2]
        let m22 = self.columns.2[2]
        
        var t:Float
        
        var q:vector_float4
        
        if (m22 < 0) {
            if (m00 > m11)
            {
                t = 1 + m00 - m11 - m22
                q = vector_float4( t, m01+m10, m20+m02, m12-m21 )
            }
            else {
                t = 1 - m00 + m11 - m22
                q = vector_float4( m01+m10, t, m12+m21, m20-m02 );
                
            }
        } else {
            if (m00 < -m11) {
                t = 1 - m00 - m11 + m22;
                q = vector_float4( m20+m02, m12+m21, t, m01-m10 );
            }
            else {
                t = 1 + m00 + m11 + m22;
                q = vector_float4( m12-m21, m20-m02, m01-m10, t );
            }
        }
        
        let scalar = 0.5 / sqrt(t)
        q = q * scalar
        
        let x = q[0]
        let y = q[1]
        let z = q[2]
        let w = q[3]
        
        return vector_float4(w,x,y,z)
    }
}

extension CMRotationMatrix {
    public func flat6DoFTransformArrayColumnAligned() -> Array<Float> {
        return Array<Float>(arrayLiteral:
            /*column 0*/    Float(self.m11),    Float(self.m12),    Float(self.m13),    0,
            /*column 1*/    Float(self.m21),    Float(self.m22),    Float(self.m23),    0,
            /*column 2*/    Float(self.m31),    Float(self.m32),    Float(self.m33),    0,
            /*column 3*/    0,                  0,                  0,                  1
            )
    }
}

extension Array where Element == Float {
    
    public func getSimd_Float4x4() -> simd_float4x4 {
        
        return simd_float4x4(
            Array<SIMD4>(arrayLiteral:
             SIMD4(arrayLiteral: self[0],self[1],self[2],self[3]),
             SIMD4(arrayLiteral: self[4],self[5],self[6],self[7]),
             SIMD4(arrayLiteral: self[8],self[9],self[10],self[11]),
             SIMD4(arrayLiteral: self[12],self[13],self[14],self[15])
                    )
            )
    }
}



//https://forums.swift.org/t/floatingpoint-equality/6233/3
public func equal_within_numerical_precision<T:FloatingPoint>(_ a:T, _ b:T) -> Bool
{
    return b.nextDown ... b.nextUp ~= a
}


public extension AVCaptureDevice {
    
    
    func wrapLockAndUnlockForConfiguration(closure: (() -> Void)) -> Bool {

        
        do {
            try self.lockForConfiguration()
        } catch _ {
            return false
        }
        
        closure()
        self.unlockForConfiguration()
        return true
    }
}




public class ARCConvenienceObserver: NSObject
{
    
    private var observations = Array<NSKeyValueObservation>()
    
    
    public func addObservation(observation:NSKeyValueObservation) {
        observations.append(observation)
    }
    
}


public func getGitHashCode() -> String? {
    return Bundle.main.infoDictionary!["GIT_COMMIT_HASH"] as! String?
}

public extension DispatchTime {
    var seconds:Double {
        get {
            return Double(self.uptimeNanoseconds) * 1e-9
        }
    }
}


public func ARCMiscUtilsCreateDepthTextures(textureCache:CVMetalTextureCache, depthMap:CVImageBuffer, confidenceMap:CVImageBuffer) -> (CVMetalTexture, CVMetalTexture) {
    
    let depthTexture = ARCMiscUtilsCreateTexture(textureCache: textureCache, fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
    let confidenceTexture = ARCMiscUtilsCreateTexture(textureCache: textureCache, fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)
    
    return (depthTexture!, confidenceTexture!)
}

public func ARCMiscUtilsCreateYandCbCrImageTextures(textureCache:CVMetalTextureCache, imageBuffer: CVImageBuffer) -> (CVMetalTexture, CVMetalTexture) {
    // Create two textures (Y and CbCr) from the provided frame's captured image
    assert(CVPixelBufferGetPlaneCount(imageBuffer) == 2)
    
    let capturedImageTextureY = ARCMiscUtilsCreateTexture(textureCache: textureCache, fromPixelBuffer: imageBuffer, pixelFormat:.r8Unorm, planeIndex:0)!
    let capturedImageTextureCbCr = ARCMiscUtilsCreateTexture(textureCache: textureCache, fromPixelBuffer: imageBuffer, pixelFormat:.rg8Unorm, planeIndex:1)!

    return (capturedImageTextureY, capturedImageTextureCbCr)
}

public func ARCMiscUtilsCreateTexture(textureCache:CVMetalTextureCache, fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
    
    var texture: CVMetalTexture? = nil
    
    //let textureAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String : Int(maxBufferCount)] as CFDictionary
    //kCVMetalTextureCacheMaximumTextureAgeKey
    let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
    
    if status != kCVReturnSuccess {
        texture = nil
    }
    
    return texture
}

public func ARCMiscUtilsCreateTextureCache(metalDevice:MTLDevice) -> CVMetalTextureCache
{
    var textureCache: CVMetalTextureCache?
    CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
    return textureCache!
}


public extension CVMetalTexture {
    var metalTexture:MTLTexture {
        get {
            
            let temp = CVMetalTextureGetTexture(self)
            
            return temp!
        }
    }
}


public typealias Float2 = SIMD2<Float>
public typealias Float3 = SIMD3<Float>

public extension Float {
    static let degreesToRadian = Float.pi / 180
}

public extension matrix_float3x3 {
    mutating func copy(from affine: CGAffineTransform) {
        columns.0 = Float3(Float(affine.a), Float(affine.c), Float(affine.tx))
        columns.1 = Float3(Float(affine.b), Float(affine.d), Float(affine.ty))
        columns.2 = Float3(0, 0, 1)
    }
}
