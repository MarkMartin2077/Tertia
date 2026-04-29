//
//  AppLinks.swift
//  Tertia
//
//  External URLs surfaced from the app — Terms of Service, Privacy Policy,
//  Support. The matching values are also entered into App Store Connect.
//  Placeholders stay nil until each page is hosted.
//

import Foundation

enum AppLinks {
    static let termsOfService = URL(
        string: "https://boatneck-pickle-bfa.notion.site/Tertia-Terms-of-Service-35117d63a01a8079b78af0699781c70d"
    )!

    /// Pending — populate once the policy page is published.
    static let privacyPolicy: URL? = nil

    /// Pending — populate once the support page is published.
    static let support: URL? = nil
}
