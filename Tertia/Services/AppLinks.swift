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

    static let privacyPolicy = URL(
        string: "https://boatneck-pickle-bfa.notion.site/Tertia-Privacy-Policy-35117d63a01a80c2bbd1f6f7d11dc55e"
    )!

    static let support = URL(
        string: "https://boatneck-pickle-bfa.notion.site/Tertia-Support-35117d63a01a805b83ebf44c47ff8314"
    )!
}
