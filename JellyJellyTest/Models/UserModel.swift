//
//  UserModel.swift
//  JellyJellyTest
//
//  Created by Kavin's Macbook on 09/06/25.
//

import UIKit

    struct UserModel: Codable {
        let id: String?
//        let updatedAt: Date?
        let username: String?
        let avatarURL: String?
//        let usernameSet: Bool?
        let bio: String?
        let fullName: String?
//        let pinnedTalkID: String?
//        let defaultJellyPrivacy: String?
//        let defaultJellyVideoEnabled: Bool?
//        let defaultJellyLength: Int?
        let logoURL: String?
        let endVideoURL: String?
//        let deletedAt: String?
//        let hasAlphaAccess: Bool?
//        let isRewarder: Bool?
//        let rewardKey: String?
        let avatarLowResURL: String?

        enum CodingKeys: String, CodingKey {
            case id
//            case updatedAt = "updated_at"
            case username
            case avatarURL = "avatar_url"
//            case usernameSet = "username_set"
            case bio
            case fullName = "full_name"
//            case pinnedTalkID = "pinned_talk_id"
//            case defaultJellyPrivacy = "default_jelly_privacy"
//            case defaultJellyVideoEnabled = "default_jelly_video_enabled"
//            case defaultJellyLength = "default_jelly_length"
            case logoURL = "logo_url"
            case endVideoURL = "end_video_url"
//            case deletedAt = "deleted_at"
//            case hasAlphaAccess = "has_alpha_access"
//            case isRewarder = "is_rewarder"
//            case rewardKey = "reward_key"
            case avatarLowResURL = "avatar_low_res_url"
        }
    }

