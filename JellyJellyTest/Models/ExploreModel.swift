import Foundation
//

struct JellyVideo: Codable {
    let id: String?
    let createdAt: String?
    let content: JellyContent?
    let type: String?
    let recordingId: String?
    let transcriptionId: String?
    let privacy: String?
    let updatedAt: String?
    let completed: Bool?
    let templateStyle: String?
    let numLikes: Int?
    let userId: String?
    let talkId: String?
    let fileName: String?
    let title: String?
    let summary: String?
//    let response: JellyResponse?
    let imageUrl: String?
    let savedBy: [String?]?
  //  let mediaLinks: MediaLinks?
  //  let metaData: [String: String]?  // or [String: AnyCodable] if dynamic
    
    enum CodingKeys: String, CodingKey {
           case id, type, privacy, completed, title, summary,content //, response
           case createdAt = "created_at"
           case updatedAt = "updated_at"
           case recordingId = "recording_id"
           case transcriptionId = "transcription_id"
           case templateStyle = "template_style"
           case numLikes = "num_likes"
           case userId = "user_id"
           case talkId = "talk_id"
           case fileName = "file_name"
           case imageUrl = "image_url"
           case savedBy = "saved_by"
//           case mediaLinks = "media_links"
//           case metaData = "meta_data"
       }
    
}

struct JellyContent: Codable {
    let url: String?
    let bucket: String?
    let thumbnails: [String]?
}

//struct JellyResponse: Codable {
//    let results: JellyResults?
//    let metadata: JellyMetadata?
//}
//
//struct JellyResults: Codable {
//    let channels: [JellyChannel]?
//}
//
//struct JellyChannel: Codable {
//    let alternatives: [JellyAlternative]?
//    let detectedLanguage: String?
//    let languageConfidence: Double?
//}
//
//struct JellyAlternative: Codable {
//    let words: [String]?
//    let confidence: Double?
//    let transcript: String?
//}
//
//struct JellyMetadata: Codable {
//    let models: [String]?
//    let sha256: String?
//    let created: String?
//    let channels: Int?
//    let duration: Double?
//    let modelInfo: [String: ModelInfo]?
//    let requestId: String?
//    let transactionKey: String?
//}
//
//struct ModelInfo: Codable {
//    let arch: String?
//    let name: String?
//    let version: String?
//}
//
//struct MediaLinks: Codable {
//    let p144: String?
//    let p240: String?
//    let p360: String?
//    let p540: String?
//    let p720: String?
//    let p1080: String?
//    let audio: String?
//    let master: String?
//
//    private enum CodingKeys: String, CodingKey {
//        case p144 = "144p"
//        case p240 = "240p"
//        case p360 = "360p"
//        case p540 = "540p"
//        case p720 = "720p"
//        case p1080 = "1080p"
//        case audio, master
//    }
//}
