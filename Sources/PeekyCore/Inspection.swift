import Foundation

/// 미리보기 한 번에 표시할 모든 정보의 루트 모델.
public struct Inspection: Sendable {
    public let source: Source
    public let bundle: BundleInfo?
    public let signing: SigningInfo?
    public let profile: ProvisioningProfile?
    public let entitlements: Entitlements?
    public let plugins: [BundleInfo]
    public let warnings: [String]

    public init(
        source: Source,
        bundle: BundleInfo? = nil,
        signing: SigningInfo? = nil,
        profile: ProvisioningProfile? = nil,
        entitlements: Entitlements? = nil,
        plugins: [BundleInfo] = [],
        warnings: [String] = []
    ) {
        self.source = source
        self.bundle = bundle
        self.signing = signing
        self.profile = profile
        self.entitlements = entitlements
        self.plugins = plugins
        self.warnings = warnings
    }

    public enum Source: Sendable, Equatable {
        case app(URL)
        case appex(URL)
        case ipa(URL)
        case xcarchive(URL)
        case profile(URL)
    }
}

public struct BundleInfo: Sendable {
    public let url: URL
    public let bundleIdentifier: String?
    public let displayName: String?
    public let executableName: String?
    public let shortVersion: String?
    public let buildVersion: String?
    public let minimumOSVersion: String?
    public let platforms: [String]
    public let extensionPointIdentifier: String?
    public let extensionPrincipalClass: String?

    public init(
        url: URL,
        bundleIdentifier: String? = nil,
        displayName: String? = nil,
        executableName: String? = nil,
        shortVersion: String? = nil,
        buildVersion: String? = nil,
        minimumOSVersion: String? = nil,
        platforms: [String] = [],
        extensionPointIdentifier: String? = nil,
        extensionPrincipalClass: String? = nil
    ) {
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.executableName = executableName
        self.shortVersion = shortVersion
        self.buildVersion = buildVersion
        self.minimumOSVersion = minimumOSVersion
        self.platforms = platforms
        self.extensionPointIdentifier = extensionPointIdentifier
        self.extensionPrincipalClass = extensionPrincipalClass
    }
}

public struct SigningInfo: Sendable {
    public let identifier: String?
    public let teamIdentifier: String?
    public let signingIdentity: String?
    public let certificateChain: [Certificate]
    public let isAdHoc: Bool

    public init(
        identifier: String? = nil,
        teamIdentifier: String? = nil,
        signingIdentity: String? = nil,
        certificateChain: [Certificate] = [],
        isAdHoc: Bool = false
    ) {
        self.identifier = identifier
        self.teamIdentifier = teamIdentifier
        self.signingIdentity = signingIdentity
        self.certificateChain = certificateChain
        self.isAdHoc = isAdHoc
    }

    public struct Certificate: Sendable {
        public let commonName: String
        public let organization: String?
        public let notBefore: Date?
        public let notAfter: Date?

        public init(commonName: String, organization: String? = nil, notBefore: Date? = nil, notAfter: Date? = nil) {
            self.commonName = commonName
            self.organization = organization
            self.notBefore = notBefore
            self.notAfter = notAfter
        }
    }
}

public struct ProvisioningProfile: Sendable {
    public let uuid: String?
    public let name: String?
    public let appIDName: String?
    public let teamName: String?
    public let teamIdentifier: [String]
    public let creationDate: Date?
    public let expirationDate: Date?
    public let devicesCount: Int?
    public let provisionsAllDevices: Bool
    public let platform: [String]

    public init(
        uuid: String? = nil,
        name: String? = nil,
        appIDName: String? = nil,
        teamName: String? = nil,
        teamIdentifier: [String] = [],
        creationDate: Date? = nil,
        expirationDate: Date? = nil,
        devicesCount: Int? = nil,
        provisionsAllDevices: Bool = false,
        platform: [String] = []
    ) {
        self.uuid = uuid
        self.name = name
        self.appIDName = appIDName
        self.teamName = teamName
        self.teamIdentifier = teamIdentifier
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.devicesCount = devicesCount
        self.provisionsAllDevices = provisionsAllDevices
        self.platform = platform
    }
}

public struct Entitlements: @unchecked Sendable {
    /// 파싱된 entitlements plist. 생성 후 immutable로만 다루므로 `@unchecked Sendable`.
    public let raw: [String: Any]

    public init(raw: [String: Any]) {
        self.raw = raw
    }
}
