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
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
    if let date = isoFormatter.date(from: metadataDateString) {
      // Extract timezone offset from the string
      if let range = metadataDateString.range(of: #"[+-]\d{4}"#, options: .regularExpression) {
        let offsetStr = String(metadataDateString[range]) // e.g., "+0900"
        let hours = Int(offsetStr.prefix(3)) ?? 0
        let minutes = Int(offsetStr.suffix(2)) ?? 0
        let secondsOffset = hours * 3600 + minutes * 60
        if let timezone = TimeZone(secondsFromGMT: secondsOffset) {
          let formatter = DateFormatter()
          formatter.timeZone = timezone
          formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
          dateString = formatter.string(from: date)
        }
      } else {
        // Fallback to UTC if no offset is found in string
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        dateString = formatter.string(from: date)
      }
    }
  } else if let date = creationDateItem.dateValue {
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
