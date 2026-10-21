#if DEBUG
import Foundation

/// Stages the App Store screenshots: launched with `-ScreenshotStage <stage>`,
/// Send skips discovery and fills the list, offer, and transfer with sample
/// devices instead. Driven by `Assets/App Store/capture.sh` and `capture-mac.sh`.
enum ScreenshotStage: String {
    case devices
    case offer
    case transfer
    case pair
    case settings

    static let current = UserDefaults.standard.string(forKey: "ScreenshotStage").flatMap(Self.init)

    private static var japanese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static func t(_ en: String, _ ja: String) -> String { japanese ? ja : en }

    @MainActor
    func apply(to model: AppModel) {
        let peers: [(name: String, kind: DeviceKind, paired: Bool, stale: Bool)] = [
            (Self.t("Himari's iPad Pro", "ヒマリのiPad Pro"), .ipad, true, false),
            (Self.t("Chihiro's MacBook Pro", "チヒロのMacBook Pro"), .mac, true, false),
            (Self.t("Utaha's Workstation", "ウタハのワークステーション"), .windows, true, false),
            (Self.t("Hare's Pixel", "ハレのPixel"), .androidPhone, false, false),
            (Self.t("Kotama's iPhone", "コタマのiPhone"), .iphone, false, true),
            (Self.t("Hibiki's MacBook Air", "ヒビキのMacBook Air"), .mac, false, false),
            (Self.t("Kotori's iPhone", "コトリのiPhone"), .iphone, false, false),
            (Self.t("Maki's Pixel", "マキのPixel"), .androidPhone, false, true),
        ]
        for (index, peer) in peers.enumerated() {
            let rid = "screenshot-\(index)"
            model.registry.sighted(rid: rid, displayName: peer.name, deviceKind: peer.kind)
            if peer.paired {
                model.registry.attach(corePeerID: "SCREENSHOT-\(index)", toRID: rid, trusted: true)
            }
            if peer.stale {
                model.registry.stageStale(rid: rid)
            }
        }

        switch self {
        case .devices, .pair, .settings:
            break
        case .offer:
            model.transfers.handle(event: .incomingOffer(
                transferID: TransferID(raw: "screenshot-offer"),
                from: PeerRef(id: "SCREENSHOT-HIBIKI", displayName: peers[5].name,
                              deviceType: .laptop, fingerprint: "signal pocket violet raven crisp atlas"),
                trusted: false,
                manifest: [
                    FileMeta(id: 1, name: Self.t("Millennium Science Fair.jpg", "ミレニアムサイエンスフェア.jpg"),
                             size: 4_812_000, mime: "image/jpeg"),
                    FileMeta(id: 2, name: Self.t("Veritas Briefing.pdf", "ヴェリタス報告書.pdf"),
                             size: 1_240_000, mime: "application/pdf"),
                    FileMeta(id: 3, name: Self.t("Drone Test Flight.mp4", "ドローン試験飛行.mp4"),
                             size: 186_400_000, mime: "video/mp4"),
                ]
            ))
        case .transfer:
            let files: [(String, Int64, Int64)] = [
                (Self.t("Avant-garde-kun Schematics.pdf", "アバンギャルド君設計図.pdf"), 28_600_000, 28_600_000),
                (Self.t("Prototype Render.png", "試作機レンダリング.png"), 12_300_000, 12_300_000),
                (Self.t("Field Test Recording.mov", "実地試験記録.mov"), 2_140_000_000, 1_268_000_000),
            ]
            let transfer = Transfer(
                id: TransferID(raw: "screenshot-transfer"),
                peer: PeerRef(id: "SCREENSHOT-2", displayName: peers[2].name,
                              deviceType: .desktop, fingerprint: ""),
                direction: .incoming,
                files: files.enumerated().map { index, file in
                    var staged = Transfer.File(id: UInt32(index + 1), name: file.0, size: file.1, mime: "")
                    staged.bytes = file.2
                    staged.status = file.2 == file.1 ? .completed : .transferring
                    return staged
                },
                state: .transferring,
                peerWasPaired: true
            )
            transfer.rate = 92_400_000
            transfer.eta = 10
            model.transfers.stage(transfer)
            // The progress lives in the sheet the offer turned into.
            model.transfers.pendingOffer = transfer
        }
    }
}
#endif
