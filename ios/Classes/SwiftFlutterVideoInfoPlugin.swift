import AVFoundation
import Flutter
import MobileCoreServices
import UIKit

public class SwiftFlutterVideoInfoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_video_info", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterVideoInfoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getVidInfo" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments else {
      return
    }

    if let myArgs = args as? [String: Any],
       let path = myArgs["path"] as? String
    {
      getVidInfo(path: path, result: result)
    }
  }

private func getVidInfo(path: String, result: FlutterResult) {
  let url = URL(fileURLWithPath: path)
  let asset = AVURLAsset(url: url)
  let fileManager = FileManager.default
  let isFileExist = fileManager.fileExists(atPath: path)

  // Handle creation date with original timezone
  var dateString: String = ""
  if let creationDateItem = asset.creationDate {
    if let metadataDateString = creationDateItem.value as? String {
      // Try parsing the date string with timezone (e.g., "2023-01-01T12:00:00+0900")
      let isoFormatter = ISO8601DateFormatter()
      isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      if let date = isoFormatter.date(from: metadataDateString) {
        // Extract timezone from the string or use device's current as fallback
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" // Include offset in output
        formatter.timeZone = TimeZone.current // Replace with parsed timezone if available
        dateString = formatter.string(from: date)
      }
    } else if let date = creationDateItem.dateValue {
      // Fallback to UTC if no timezone info is in metadata
      let formatter = DateFormatter()
      formatter.timeZone = TimeZone(identifier: "UTC")
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
      dateString = formatter.string(from: date)
    }
  }

  let durationTime = round(CMTimeGetSeconds(asset.duration) * 1000)
  let tracks = asset.tracks(withMediaType: .video)
  let fps = tracks.first?.nominalFrameRate
  let size = tracks.first?.naturalSize
  let mimetype = mimeTypeForPath(path: path)
  let orientation = asset.orientation

  var fileSize: UInt64 = 0
  do {
    let attr = try FileManager.default.attributesOfItem(atPath: path)
    fileSize = attr[FileAttributeKey.size] as! UInt64
  } catch {
    print("Error: \(error)")
  }

  var jsonObj = [String: Any]()
  jsonObj["path"] = path
  jsonObj["mimetype"] = mimetype
  jsonObj["author"] = ""
  jsonObj["date"] = dateString.isEmpty ? "" : dateString
  jsonObj["width"] = size?.width
  jsonObj["height"] = size?.height
  jsonObj["location"] = asset.metadata.first(where: { $0.identifier == .quickTimeMetadataLocationISO6709 })?.value?.description
  jsonObj["framerate"] = fps
  jsonObj["duration"] = durationTime
  jsonObj["filesize"] = fileSize
  jsonObj["orientation"] = orientation
  jsonObj["isfileexist"] = isFileExist

  do {
    let jsonData = try JSONSerialization.data(withJSONObject: jsonObj)
    let jsonStr = String(bytes: jsonData, encoding: .utf8)!
    result(jsonStr)
  } catch let e {
    result(e)
  }
}

  private func mimeTypeForPath(path: String) -> String {
    let url = NSURL(fileURLWithPath: path)
    let pathExtension = url.pathExtension

    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
      if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
        return mimetype as String
      }
    }
    return "application/octet-stream"
  }
}

extension AVURLAsset {
  var orientation: String {
    guard let tf = tracks(withMediaType: AVMediaType.video).first?.preferredTransform else {
      return ""
    }

    if tf.a == 0, tf.b == 1.0, tf.d == 0 {
      return "90"
    } else if tf.a == 0, tf.b == -1.0, tf.d == 0 {
      return "270"
    } else if tf.a == 1.0, tf.b == 0, tf.c == 0 {
      return "0"
    } else if tf.a == -1.0, tf.b == 0, tf.c == 0 {
      return "180"
    }
    return ""
  }
}
