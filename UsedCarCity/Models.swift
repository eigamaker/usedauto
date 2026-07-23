import Foundation
import SwiftUI

enum DistrictKind: String, Codable, CaseIterable, Identifiable {
    case downtown, suburb, station, industrial, emerging, highway
    var id: String { rawValue }

    var name: String {
        switch self {
        case .downtown: "都心商業"
        case .suburb: "一般住宅街"
        case .station: "駅周辺"
        case .industrial: "工業地区"
        case .emerging: "高級住宅街"
        case .highway: "幹線・IC周辺"
        }
    }

    var shortName: String {
        switch self {
        case .downtown: "都心"
        case .suburb: "一般住宅"
        case .station: "駅前"
        case .industrial: "工業"
        case .emerging: "高級住宅"
        case .highway: "幹線IC"
        }
    }

    var symbol: String {
        switch self {
        case .downtown: "building.2.fill"
        case .suburb: "house.and.flag.fill"
        case .station: "tram.fill"
        case .industrial: "gearshape.2.fill"
        case .emerging: "tree.fill"
        case .highway: "road.lanes"
        }
    }

    var color: Color {
        switch self {
        case .downtown: Color(red: 0.55, green: 0.37, blue: 0.73)
        case .suburb: Color(red: 0.19, green: 0.57, blue: 0.43)
        case .station: Color(red: 0.22, green: 0.48, blue: 0.72)
        case .industrial: Color(red: 0.45, green: 0.48, blue: 0.50)
        case .emerging: Color(red: 0.39, green: 0.67, blue: 0.27)
        case .highway: Color(red: 0.85, green: 0.50, blue: 0.18)
        }
    }
}

enum TutorialStep: String, Codable, CaseIterable, Identifiable {
    case chooseLocation
    case buildStore
    case purchaseInventory
    case setPrice
    case runFirstMonth
    case reviewFirstResult
    case completed

    var id: String { rawValue }

    var number: Int {
        switch self {
        case .chooseLocation: 1
        case .buildStore: 2
        case .purchaseInventory: 3
        case .setPrice, .runFirstMonth: 4
        case .reviewFirstResult, .completed: 5
        }
    }

    var progress: Double { Double(number) / 5.0 }

    var title: String {
        switch self {
        case .chooseLocation: "創業地を選ぶ"
        case .buildStore: "店舗を計画する"
        case .purchaseInventory: "販売車を仕入れる"
        case .setPrice: "最初の販売商談"
        case .runFirstMonth: "最初の1週間を営業する"
        case .reviewFirstResult: "経営結果を確認する"
        case .completed: "チュートリアル完了"
        }
    }

    var instruction: String {
        switch self {
        case .chooseLocation: "光っている候補地をタップ。客層、交通量、賃料を比べて最初の店を置く場所を選びましょう。"
        case .buildStore: "選んだ土地の詳細から出店計画へ進み、取得方法・店舗タイプ・資金計画を決めて契約します。運営方針はオーナーがいつでも設定できます。"
        case .purchaseInventory: "店舗画面で地域需要を確認し、売りたい車種を3台仕入れましょう。支払った金額と在庫が本番データに反映されます。"
        case .setPrice: "店舗の店頭販売から1台を選び、お客様との値下げ交渉を始めましょう。"
        case .runFirstMonth: "店舗の「店頭販売」で値引き幅を選んで商談し、右上の「1週間進める」を押して最初の結果を確定しましょう。商談は不成立になることもあります。"
        case .reviewFirstResult: "販売台数、売上、営業利益と、その数字になった理由を確認しましょう。"
        case .completed: "ここからは自由経営です。街の変化を見ながら会社を育ててください。"
        }
    }

    var icon: String {
        switch self {
        case .chooseLocation: "mappin.and.ellipse"
        case .buildStore: "hammer.fill"
        case .purchaseInventory: "car.2.fill"
        case .setPrice: "tag.fill"
        case .runFirstMonth: "play.fill"
        case .reviewFirstResult: "chart.bar.fill"
        case .completed: "checkmark.seal.fill"
        }
    }
}

enum VehicleCategory: String, Codable, CaseIterable, Identifiable {
    case kei, compact, minivan, suv, imported, pickup, commercial
    var id: String { rawValue }

    var name: String {
        switch self {
        case .kei: "軽自動車"
        case .compact: "コンパクト"
        case .minivan: "ミニバン"
        case .suv: "SUV"
        case .imported: "輸入車"
        case .pickup: "ピックアップトラック"
        case .commercial: "商用車"
        }
    }

    var icon: String {
        switch self {
        case .commercial: "truck.box.fill"
        case .imported: "globe.europe.africa.fill"
        case .pickup: "truck.pickup.side.fill"
        default: "car.side.fill"
        }
    }

    var purchaseCost: Int {
        switch self {
        case .kei: 75
        case .compact: 105
        case .minivan: 180
        case .suv: 330
        case .imported: 720
        case .pickup: 235
        case .commercial: 145
        }
    }
}

enum VehiclePowertrain: String, Codable, CaseIterable, Identifiable, Hashable {
    case gasoline
    case hybrid
    case electric
    case diesel

    var id: String { rawValue }
    var name: String {
        switch self {
        case .gasoline: "ガソリン"
        case .hybrid: "ハイブリッド"
        case .electric: "EV"
        case .diesel: "ディーゼル"
        }
    }
    var icon: String {
        switch self {
        case .gasoline: "fuelpump.fill"
        case .hybrid: "leaf.fill"
        case .electric: "bolt.car.fill"
        case .diesel: "engine.combustion.fill"
        }
    }
}

struct VehicleCatalogEntry: Identifiable, Codable, Hashable {
    let id: String
    let maker: String
    let modelName: String
    let category: VehicleCategory
    let baseWholesalePrice: Int
    let referenceRetailPrice: Int
    let qualityBaseline: Double
    let popularity: Double
    let launchTurn: Int
    let powertrain: VehiclePowertrain
    let usedMarketDelayWeeks: Int

    init(id: String, maker: String, modelName: String, category: VehicleCategory, baseWholesalePrice: Int, referenceRetailPrice: Int, qualityBaseline: Double, popularity: Double, launchTurn: Int, powertrain: VehiclePowertrain = .gasoline, usedMarketDelayWeeks: Int? = nil) {
        self.id = id
        self.maker = maker
        self.modelName = modelName
        self.category = category
        self.baseWholesalePrice = baseWholesalePrice
        self.referenceRetailPrice = referenceRetailPrice
        self.qualityBaseline = qualityBaseline
        self.popularity = popularity
        self.launchTurn = launchTurn
        self.powertrain = powertrain
        self.usedMarketDelayWeeks = usedMarketDelayWeeks ?? (launchTurn == 0 ? 0 : 12)
    }

    var fullName: String { "\(maker) \(modelName)" }
    var usedMarketTurn: Int { launchTurn + usedMarketDelayWeeks }
    var isEV: Bool { powertrain == .electric }

    /// 輸入車ではメーカー自体の指名力も需要に影響する。
    var marqueAppeal: Double {
        guard category == .imported else { return 1 }
        return switch maker {
        case "ロッサ": 1.10
        case "ヴォルトラ": 1.06
        case "ノルド": 1.00
        default: 0.96
        }
    }

    var customerDemandIndex: Double { popularity * marqueAppeal }

    var classicProductionYears: ClosedRange<Int>? {
        switch id {
        case "aoba-sprint70": 1972...1979
        case "yamato-falconrs": 1970...1977
        case "hokuto-trailclassic": 1981...1989
        case "rossa-stellagt": 1974...1986
        default: nil
        }
    }

    var isRareClassic: Bool { classicProductionYears != nil }

    /// 1.0以上はカスタム市場で特に人気のあるベース車。
    var customAppeal: Double {
        switch id {
        case "aoba-basic", "aoba-basicneo": 1.22
        case "koyo-lino", "koyo-linox", "koyo-linog": 1.04
        case "hokuto-ridge", "hokuto-ridgex", "hokuto-ridgez": 1.30
        case "seika-terra", "seika-terrae": 1.02
        case "hokuto-trail", "hokuto-trailx", "hokuto-trailpro": 1.36
        case "yamato-porter", "yamato-porter2", "yamato-porter3": 0.96
        case "aoba-sprint70": 1.34
        case "yamato-falconrs": 1.48
        case "hokuto-trailclassic": 1.52
        case "rossa-stellagt": 1.42
        default: 0.48
        }
    }

    var isPopularCustomBase: Bool { customAppeal >= 0.85 }
}

enum VehicleCatalog {
    private static let coreModels: [VehicleCatalogEntry] = [
        VehicleCatalogEntry(id: "aoba-pico", maker: "アオバ", modelName: "PICO", category: .kei, baseWholesalePrice: 70, referenceRetailPrice: 98, qualityBaseline: 0.73, popularity: 1.05, launchTurn: 0),
        VehicleCatalogEntry(id: "hoshi-minto", maker: "ホシノ", modelName: "MINTO", category: .kei, baseWholesalePrice: 79, referenceRetailPrice: 112, qualityBaseline: 0.78, popularity: 0.96, launchTurn: 0),
        VehicleCatalogEntry(id: "aoba-basic", maker: "アオバ", modelName: "BASIC", category: .kei, baseWholesalePrice: 48, referenceRetailPrice: 72, qualityBaseline: 0.64, popularity: 1.07, launchTurn: 0),
        VehicleCatalogEntry(id: "aoba-pico2", maker: "アオバ", modelName: "PICO II", category: .kei, baseWholesalePrice: 86, referenceRetailPrice: 124, qualityBaseline: 0.84, popularity: 1.14, launchTurn: 12),

        VehicleCatalogEntry(id: "koyo-lino", maker: "コーヨー", modelName: "LINO", category: .compact, baseWholesalePrice: 98, referenceRetailPrice: 138, qualityBaseline: 0.75, popularity: 1.04, launchTurn: 0, powertrain: .hybrid),
        VehicleCatalogEntry(id: "seika-comet", maker: "セイカ", modelName: "COMET", category: .compact, baseWholesalePrice: 112, referenceRetailPrice: 156, qualityBaseline: 0.81, popularity: 0.98, launchTurn: 0),
        VehicleCatalogEntry(id: "hinode-value", maker: "ヒノデ", modelName: "VALUE", category: .compact, baseWholesalePrice: 56, referenceRetailPrice: 82, qualityBaseline: 0.69, popularity: 0.96, launchTurn: 0),
        VehicleCatalogEntry(id: "aoba-basicneo", maker: "アオバ", modelName: "BASIC NEO", category: .compact, baseWholesalePrice: 63, referenceRetailPrice: 94, qualityBaseline: 0.75, popularity: 1.15, launchTurn: 8),
        VehicleCatalogEntry(id: "koyo-linox", maker: "コーヨー", modelName: "LINO X", category: .compact, baseWholesalePrice: 121, referenceRetailPrice: 172, qualityBaseline: 0.86, popularity: 1.13, launchTurn: 16),

        VehicleCatalogEntry(id: "hinode-familia", maker: "ヒノデ", modelName: "FAMILIA", category: .minivan, baseWholesalePrice: 170, referenceRetailPrice: 238, qualityBaseline: 0.77, popularity: 1.08, launchTurn: 0, powertrain: .hybrid),
        VehicleCatalogEntry(id: "yamato-grandia", maker: "ヤマト", modelName: "GRANDIA", category: .minivan, baseWholesalePrice: 193, referenceRetailPrice: 274, qualityBaseline: 0.83, popularity: 0.96, launchTurn: 0),
        VehicleCatalogEntry(id: "hinode-familia2", maker: "ヒノデ", modelName: "FAMILIA II", category: .minivan, baseWholesalePrice: 206, referenceRetailPrice: 298, qualityBaseline: 0.88, popularity: 1.16, launchTurn: 20),

        VehicleCatalogEntry(id: "hokuto-ridge", maker: "ホクト", modelName: "RIDGE", category: .suv, baseWholesalePrice: 280, referenceRetailPrice: 410, qualityBaseline: 0.79, popularity: 1.10, launchTurn: 0),
        VehicleCatalogEntry(id: "seika-terra", maker: "セイカ", modelName: "TERRA", category: .suv, baseWholesalePrice: 360, referenceRetailPrice: 540, qualityBaseline: 0.84, popularity: 1.02, launchTurn: 0, powertrain: .hybrid),
        VehicleCatalogEntry(id: "hokuto-ridgex", maker: "ホクト", modelName: "RIDGE X", category: .suv, baseWholesalePrice: 410, referenceRetailPrice: 600, qualityBaseline: 0.89, popularity: 1.18, launchTurn: 24),

        VehicleCatalogEntry(id: "nord-velar", maker: "ノルド", modelName: "VELAR", category: .imported, baseWholesalePrice: 680, referenceRetailPrice: 980, qualityBaseline: 0.84, popularity: 1.04, launchTurn: 0),
        VehicleCatalogEntry(id: "voltra-aurex", maker: "ヴォルトラ", modelName: "AUREX", category: .imported, baseWholesalePrice: 780, referenceRetailPrice: 1_180, qualityBaseline: 0.91, popularity: 0.94, launchTurn: 0, powertrain: .electric),
        VehicleCatalogEntry(id: "rossa-luce", maker: "ロッサ", modelName: "LUCE", category: .imported, baseWholesalePrice: 720, referenceRetailPrice: 1_080, qualityBaseline: 0.88, popularity: 1.08, launchTurn: 0),
        VehicleCatalogEntry(id: "voltra-aurexs", maker: "ヴォルトラ", modelName: "AUREX S", category: .imported, baseWholesalePrice: 980, referenceRetailPrice: 1_480, qualityBaseline: 0.93, popularity: 1.17, launchTurn: 30, powertrain: .electric, usedMarketDelayWeeks: 16),

        VehicleCatalogEntry(id: "hokuto-trail", maker: "ホクト", modelName: "TRAIL", category: .pickup, baseWholesalePrice: 225, referenceRetailPrice: 318, qualityBaseline: 0.79, popularity: 1.06, launchTurn: 0),
        VehicleCatalogEntry(id: "yamato-ranger", maker: "ヤマト", modelName: "RANGER", category: .pickup, baseWholesalePrice: 248, referenceRetailPrice: 352, qualityBaseline: 0.82, popularity: 0.98, launchTurn: 0, powertrain: .diesel),
        VehicleCatalogEntry(id: "hokuto-trailx", maker: "ホクト", modelName: "TRAIL X", category: .pickup, baseWholesalePrice: 272, referenceRetailPrice: 392, qualityBaseline: 0.87, popularity: 1.16, launchTurn: 26),

        VehicleCatalogEntry(id: "yamato-porter", maker: "ヤマト", modelName: "PORTER", category: .commercial, baseWholesalePrice: 136, referenceRetailPrice: 188, qualityBaseline: 0.76, popularity: 1.03, launchTurn: 0, powertrain: .diesel),
        VehicleCatalogEntry(id: "koyo-worka", maker: "コーヨー", modelName: "WORKA", category: .commercial, baseWholesalePrice: 154, referenceRetailPrice: 216, qualityBaseline: 0.80, popularity: 0.98, launchTurn: 0, powertrain: .diesel),
        VehicleCatalogEntry(id: "yamato-porter2", maker: "ヤマト", modelName: "PORTER II", category: .commercial, baseWholesalePrice: 168, referenceRetailPrice: 238, qualityBaseline: 0.86, popularity: 1.12, launchTurn: 28),

        // Very rare collector cars. Their prices represent the collector market,
        // not the price when they were new, and they only enter normal play rarely.
        VehicleCatalogEntry(id: "aoba-sprint70", maker: "アオバ", modelName: "SPRINT 70", category: .compact, baseWholesalePrice: 410, referenceRetailPrice: 680, qualityBaseline: 0.55, popularity: 0.58, launchTurn: 0),
        VehicleCatalogEntry(id: "hokuto-trailclassic", maker: "ホクト", modelName: "TRAIL CLASSIC", category: .pickup, baseWholesalePrice: 530, referenceRetailPrice: 860, qualityBaseline: 0.57, popularity: 0.66, launchTurn: 0),
        VehicleCatalogEntry(id: "rossa-stellagt", maker: "ロッサ", modelName: "STELLA GT", category: .imported, baseWholesalePrice: 920, referenceRetailPrice: 1_480, qualityBaseline: 0.49, popularity: 0.60, launchTurn: 0),

        // The catalog continues to refresh throughout the ten-year game.
        VehicleCatalogEntry(id: "aoba-pico3", maker: "アオバ", modelName: "PICO III", category: .kei, baseWholesalePrice: 96, referenceRetailPrice: 139, qualityBaseline: 0.88, popularity: 1.16, launchTurn: 52),
        VehicleCatalogEntry(id: "koyo-linog", maker: "コーヨー", modelName: "LINO G", category: .compact, baseWholesalePrice: 132, referenceRetailPrice: 188, qualityBaseline: 0.89, popularity: 1.15, launchTurn: 78),
        VehicleCatalogEntry(id: "hinode-familia3", maker: "ヒノデ", modelName: "FAMILIA III", category: .minivan, baseWholesalePrice: 224, referenceRetailPrice: 326, qualityBaseline: 0.90, popularity: 1.17, launchTurn: 104),
        VehicleCatalogEntry(id: "hokuto-ridgez", maker: "ホクト", modelName: "RIDGE Z", category: .suv, baseWholesalePrice: 420, referenceRetailPrice: 610, qualityBaseline: 0.91, popularity: 1.19, launchTurn: 130),
        VehicleCatalogEntry(id: "nord-velar2", maker: "ノルド", modelName: "VELAR II", category: .imported, baseWholesalePrice: 820, referenceRetailPrice: 1_220, qualityBaseline: 0.93, popularity: 1.16, launchTurn: 182),
        VehicleCatalogEntry(id: "yamato-ranger2", maker: "ヤマト", modelName: "RANGER II", category: .pickup, baseWholesalePrice: 294, referenceRetailPrice: 426, qualityBaseline: 0.90, popularity: 1.15, launchTurn: 208),
        VehicleCatalogEntry(id: "koyo-worka2", maker: "コーヨー", modelName: "WORKA II", category: .commercial, baseWholesalePrice: 184, referenceRetailPrice: 262, qualityBaseline: 0.89, popularity: 1.14, launchTurn: 234),
        VehicleCatalogEntry(id: "aoba-picoev", maker: "アオバ", modelName: "PICO EV", category: .kei, baseWholesalePrice: 112, referenceRetailPrice: 164, qualityBaseline: 0.91, popularity: 1.18, launchTurn: 260, powertrain: .electric, usedMarketDelayWeeks: 16),
        VehicleCatalogEntry(id: "seika-comet2", maker: "セイカ", modelName: "COMET II", category: .compact, baseWholesalePrice: 146, referenceRetailPrice: 208, qualityBaseline: 0.91, popularity: 1.16, launchTurn: 286),
        VehicleCatalogEntry(id: "hinode-familiaev", maker: "ヒノデ", modelName: "FAMILIA EV", category: .minivan, baseWholesalePrice: 252, referenceRetailPrice: 368, qualityBaseline: 0.93, popularity: 1.18, launchTurn: 312, powertrain: .electric, usedMarketDelayWeeks: 16),
        VehicleCatalogEntry(id: "seika-terrae", maker: "セイカ", modelName: "TERRA E", category: .suv, baseWholesalePrice: 440, referenceRetailPrice: 640, qualityBaseline: 0.93, popularity: 1.18, launchTurn: 338, powertrain: .electric, usedMarketDelayWeeks: 16),
        VehicleCatalogEntry(id: "rossa-luce2", maker: "ロッサ", modelName: "LUCE II", category: .imported, baseWholesalePrice: 960, referenceRetailPrice: 1_440, qualityBaseline: 0.94, popularity: 1.17, launchTurn: 390),
        VehicleCatalogEntry(id: "hokuto-trailpro", maker: "ホクト", modelName: "TRAIL PRO", category: .pickup, baseWholesalePrice: 326, referenceRetailPrice: 472, qualityBaseline: 0.92, popularity: 1.16, launchTurn: 416),
        VehicleCatalogEntry(id: "yamato-porter3", maker: "ヤマト", modelName: "PORTER III", category: .commercial, baseWholesalePrice: 204, referenceRetailPrice: 292, qualityBaseline: 0.91, popularity: 1.15, launchTurn: 442)
    ]

    static let all: [VehicleCatalogEntry] = coreModels + makeAnnualModels()

    static func entry(id: String) -> VehicleCatalogEntry? {
        return all.first(where: { $0.id == id })
    }

    static func releasedNewCars(through turn: Int) -> [VehicleCatalogEntry] {
        all.filter { $0.launchTurn <= turn }
    }

    static func available(through turn: Int) -> [VehicleCatalogEntry] {
        all.filter { $0.usedMarketTurn <= turn }
    }

    static var rareClassics: [VehicleCatalogEntry] { all.filter(\.isRareClassic) }

    private struct AnnualLine {
        let makerID: String
        let maker: String
        let names: [String]
        let categories: [VehicleCategory]
        let initialPowertrain: VehiclePowertrain
        let electrificationYear: Int
    }

    private static func makeAnnualModels() -> [VehicleCatalogEntry] {
        let lines: [AnnualLine] = [
            AnnualLine(makerID: "aoba", maker: "アオバ", names: ["PICO", "BASIC"], categories: [.kei, .compact], initialPowertrain: .gasoline, electrificationYear: 4),
            AnnualLine(makerID: "hoshi", maker: "ホシノ", names: ["MINTO", "LUMI"], categories: [.kei, .compact], initialPowertrain: .gasoline, electrificationYear: 5),
            AnnualLine(makerID: "koyo", maker: "コーヨー", names: ["LINO", "WORKA"], categories: [.compact, .commercial], initialPowertrain: .hybrid, electrificationYear: 6),
            AnnualLine(makerID: "seika", maker: "セイカ", names: ["COMET", "TERRA"], categories: [.compact, .suv], initialPowertrain: .hybrid, electrificationYear: 3),
            AnnualLine(makerID: "hinode", maker: "ヒノデ", names: ["FAMILIA", "CIVIA"], categories: [.minivan, .compact], initialPowertrain: .hybrid, electrificationYear: 4),
            AnnualLine(makerID: "hokuto", maker: "ホクト", names: ["RIDGE", "TRAIL"], categories: [.suv, .pickup], initialPowertrain: .gasoline, electrificationYear: 7),
            AnnualLine(makerID: "yamato", maker: "ヤマト", names: ["GRANDIA", "RANGER", "PORTER"], categories: [.minivan, .pickup, .commercial], initialPowertrain: .diesel, electrificationYear: 6),
            AnnualLine(makerID: "nord", maker: "ノルド", names: ["VELAR", "ARCTIC"], categories: [.imported], initialPowertrain: .hybrid, electrificationYear: 3),
            AnnualLine(makerID: "voltra", maker: "ヴォルトラ", names: ["AUREX", "ION"], categories: [.imported], initialPowertrain: .electric, electrificationYear: 0),
            AnnualLine(makerID: "rossa", maker: "ロッサ", names: ["LUCE", "STELLA"], categories: [.imported], initialPowertrain: .gasoline, electrificationYear: 8)
        ]
        var models: [VehicleCatalogEntry] = []
        for yearIndex in 0..<10 {
            for (makerIndex, line) in lines.enumerated() {
                let category = line.categories[yearIndex % line.categories.count]
                let baseName = line.names[yearIndex % line.names.count]
                let launchTurn = yearIndex * 48 + 2 + makerIndex * 4
                guard launchTurn < 480 else { continue }
                let powertrain: VehiclePowertrain
                if line.initialPowertrain == .electric || yearIndex >= line.electrificationYear {
                    powertrain = .electric
                } else if line.initialPowertrain == .diesel && [.commercial, .pickup].contains(category) {
                    powertrain = .diesel
                } else if yearIndex >= max(1, line.electrificationYear - 3) {
                    powertrain = .hybrid
                } else {
                    powertrain = line.initialPowertrain
                }
                let year = 2026 + yearIndex
                let inflation = 1.0 + Double(yearIndex) * 0.024
                let segmentPremium: Double = category == .imported ? 1.16 : 1.0
                let technologyPremium: Double = powertrain == .electric ? 1.14 : powertrain == .hybrid ? 1.07 : 1.0
                let wholesale = max(45, Int(Double(category.purchaseCost) * 1.06 * inflation * segmentPremium * technologyPremium))
                let retail = Int(Double(wholesale) * (category == .imported ? 1.48 : 1.40))
                let popularity = 0.94 + Double((makerIndex * 7 + yearIndex * 11) % 25) / 100.0
                let delay = 12 + (makerIndex * 3 + yearIndex * 5) % 5 + (powertrain == .electric ? 2 : 0)
                models.append(VehicleCatalogEntry(
                    id: "annual-\(line.makerID)-\(year)",
                    maker: line.maker,
                    modelName: "\(baseName) \(String(year).suffix(2))",
                    category: category,
                    baseWholesalePrice: wholesale,
                    referenceRetailPrice: retail,
                    qualityBaseline: min(0.96, 0.84 + Double(yearIndex) * 0.009 + Double(makerIndex % 3) * 0.015),
                    popularity: popularity,
                    launchTurn: launchTurn,
                    powertrain: powertrain,
                    usedMarketDelayWeeks: delay
                ))
            }
        }
        return models
    }
}

enum SaleNegotiationStrategy: String, CaseIterable, Identifiable {
    case holdPrice
    case smallDiscount
    case closeDeal

    var id: String { rawValue }
    var name: String {
        switch self {
        case .holdPrice: "価格を維持"
        case .smallDiscount: "3%値引き"
        case .closeDeal: "7%値引き"
        }
    }
    var detail: String {
        switch self {
        case .holdPrice: "粗利優先・離脱しやすい"
        case .smallDiscount: "粗利と成約率のバランス"
        case .closeDeal: "成約優先・粗利は下がる"
        }
    }
    var discountRate: Double {
        switch self {
        case .holdPrice: 0
        case .smallDiscount: 0.03
        case .closeDeal: 0.07
        }
    }
    var baseCloseChance: Double {
        switch self {
        case .holdPrice: 0.32
        case .smallDiscount: 0.56
        case .closeDeal: 0.76
        }
    }
}

struct SaleNegotiationResult {
    let succeeded: Bool
    let salePrice: Int
    let grossProfit: Int
    let closeChance: Double
    let tradeInAcquired: Bool
    let tradeInAllowance: Int
    let tradeInRepairCost: Int
    let customerCashSettlement: Int
    let tradeInVehicleName: String?

    init(succeeded: Bool, salePrice: Int, grossProfit: Int, closeChance: Double, tradeInAcquired: Bool = false, tradeInAllowance: Int = 0, tradeInRepairCost: Int = 0, customerCashSettlement: Int = 0, tradeInVehicleName: String? = nil) {
        self.succeeded = succeeded
        self.salePrice = salePrice
        self.grossProfit = grossProfit
        self.closeChance = closeChance
        self.tradeInAcquired = tradeInAcquired
        self.tradeInAllowance = tradeInAllowance
        self.tradeInRepairCost = tradeInRepairCost
        self.customerCashSettlement = customerCashSettlement
        self.tradeInVehicleName = tradeInVehicleName
    }
}

struct TradeInVehicle: Codable, Hashable {
    let modelID: String
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    let quality: Double
    let appraisedValue: Int
    let repairCost: Int

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }

    var conditionScore: Int { Int((quality * 100).rounded()) }
    var repairQualityGain: Int { conditionScore < 75 ? 4 : 3 }
    var qualityAfterRepair: Double { Double(min(94, conditionScore + repairQualityGain)) / 100.0 }
}

struct TradeInSalePreview {
    let salePrice: Int
    let saleGrossProfit: Int
    let allowance: Int
    let repairCost: Int
    let customerCashSettlement: Int
    let expectedTradeInSalePrice: Int
    let expectedTradeInGrossProfit: Int
    let closeChance: Double

    var cashImpact: Int { customerCashSettlement - repairCost }
    var requiredDealerCash: Int { max(0, -cashImpact) }
}

enum BuyerVehiclePreference: Codable, Hashable {
    case category(VehicleCategory)
    case maker(category: VehicleCategory, maker: String)
    case exactModel(String)
    case budgetFirst

    var name: String {
        switch self {
        case .category(let category): category.name
        case .maker(_, let maker): "\(maker)指定"
        case .exactModel(let modelID): VehicleCatalog.entry(id: modelID)?.fullName ?? "車種指定"
        case .budgetFirst: "予算優先"
        }
    }

    var icon: String {
        switch self {
        case .category(let category): category.icon
        case .maker(let category, _): category.icon
        case .exactModel(let modelID): VehicleCatalog.entry(id: modelID)?.category.icon ?? "car.side.fill"
        case .budgetFirst: "yensign.circle.fill"
        }
    }

    var customerDescription: String {
        switch self {
        case .category(let category): "\(category.name)を探しているお客様"
        case .maker(let category, let maker): "\(maker)の\(category.name)を指名するお客様"
        case .exactModel(let modelID): "\(VehicleCatalog.entry(id: modelID)?.fullName ?? modelID)を指名するお客様"
        case .budgetFirst: "予算内の車を探しているお客様"
        }
    }

    var category: VehicleCategory? {
        switch self {
        case .category(let category), .maker(let category, _): category
        case .exactModel(let modelID): VehicleCatalog.entry(id: modelID)?.category
        case .budgetFirst: nil
        }
    }

    var preferredMaker: String? {
        switch self {
        case .maker(_, let maker): maker
        case .exactModel(let modelID): VehicleCatalog.entry(id: modelID)?.maker
        case .category, .budgetFirst: nil
        }
    }

    var preferredModelID: String? {
        guard case .exactModel(let modelID) = self else { return nil }
        return modelID
    }
}

struct BuyerLead: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let preference: BuyerVehiclePreference
    let budget: Int
    let minimumQuality: Double
    let minimumModelYear: Int
    let maximumMileage: Int
    let priceSensitivity: Double
    let generatedTurn: Int
    let tradeInVehicle: TradeInVehicle?
    let purpose: CustomerPurpose
    let competitorOffer: CompetitorOfferBenchmark?

    init(id: UUID, storeID: UUID, preference: BuyerVehiclePreference, budget: Int, minimumQuality: Double, minimumModelYear: Int = 0, maximumMileage: Int = .max, priceSensitivity: Double, generatedTurn: Int, tradeInVehicle: TradeInVehicle? = nil, purpose: CustomerPurpose = .general, competitorOffer: CompetitorOfferBenchmark? = nil) {
        self.id = id
        self.storeID = storeID
        self.preference = preference
        self.budget = budget
        self.minimumQuality = minimumQuality
        self.minimumModelYear = minimumModelYear
        self.maximumMileage = maximumMileage
        self.priceSensitivity = priceSensitivity
        self.generatedTurn = generatedTurn
        self.tradeInVehicle = tradeInVehicle
        self.purpose = purpose
        self.competitorOffer = competitorOffer
    }

    var desiredCategory: VehicleCategory? { preference.category }

    var vehicleRequirementDescription: String {
        let yearText = minimumModelYear > 0 ? "\(minimumModelYear)年式以降" : "年式不問"
        let mileageText = maximumMileage < Int.max ? "走行\(maximumMileage.formatted())km以下" : "走行距離不問"
        return "\(yearText)・\(mileageText)・品質\(Int(minimumQuality * 100))以上"
    }
}

enum PurchaseNegotiationOutcome {
    case purchased(price: Int)
    case rejected(walkedAway: Bool)
    case unavailable
}

enum PurchaseInspectionResult: Equatable {
    case unavailable
    case noIssueDetected
    case issueFound(VehicleIssueKind)
}

struct NationalCity: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let population: Int
    let incomeIndex: Double
    let landPriceIndex: Double
    let competitionIndex: Double
    let growthRate: Double
    let primaryDemand: [VehicleCategory]
    let expansionCost: Int
    let shippingMonths: Int
    let shippingCostPerVehicle: Int
    let mapX: Double
    let mapY: Double

    var marketLabel: String {
        primaryDemand.prefix(2).map(\.name).joined(separator: "・")
    }
}

struct RegionalOperation: Identifiable, Codable, Hashable {
    var cityID: String
    var officeLevel: Int
    var franchiseStores: Int
    var acquiredStores: Int
    var brandStrength: Double
    var advertisingBudget: Int
    var inventory: [InventoryBatch]
    var lastSales: Int
    var lastRevenue: Int
    var lastProfit: Int

    var id: String { cityID }
    var networkStores: Int { franchiseStores + acquiredStores }
    var inventoryCount: Int { inventory.reduce(0) { $0 + $1.count } }

    init(cityID: String, officeLevel: Int = 1) {
        self.cityID = cityID
        self.officeLevel = officeLevel
        franchiseStores = 0
        acquiredStores = 0
        brandStrength = 0.55
        advertisingBudget = 80
        inventory = []
        lastSales = 0
        lastRevenue = 0
        lastProfit = 0
    }
}

struct IntercityShipment: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceStoreID: UUID
    let destinationCityID: String
    let modelID: String
    let category: VehicleCategory
    let count: Int
    let unitCost: Int
    let quality: Double
    let modelYear: Int
    let mileage: Int
    let acquiredTurn: Int
    let vehicleIssue: VehicleIssueRecord?
    var monthsRemaining: Int
}

enum CustomerPurpose: String, Codable, CaseIterable, Identifiable, Hashable {
    case general, family, outdoor, camper, work, corporate
    var id: String { rawValue }
    var name: String {
        switch self {
        case .general: "一般・価格重視"
        case .family: "ファミリー"
        case .outdoor: "アウトドア"
        case .camper: "キャンピング"
        case .work: "職人・配送"
        case .corporate: "法人"
        }
    }
}

enum VehicleConditionBand: String, Codable, CaseIterable, Identifiable, Hashable {
    case normal, rough, faulty
    var id: String { rawValue }
    var name: String {
        switch self {
        case .normal: "通常車"
        case .rough: "低品質車"
        case .faulty: "故障車"
        }
    }
}

struct StoreMarketPolicy: Codable, Hashable {
    var priorityCategories: Set<VehicleCategory> = []
    var targetPurpose: CustomerPurpose = .general
    var acceptedConditions: Set<VehicleConditionBand> = [.normal]

    mutating func normalize() {
        if priorityCategories.count > 3 {
            priorityCategories = Set(priorityCategories.sorted { $0.rawValue < $1.rawValue }.prefix(3))
        }
        if acceptedConditions.isEmpty { acceptedConditions = [.normal] }
    }
}

enum StoreFacility: String, Codable, CaseIterable, Identifiable, Hashable {
    case quickAppraisal
    case kidsSpace
    case corporateDesk
    case importLounge
    case serviceWorkshop
    case customWorkshop

    var id: String { rawValue }
    var name: String {
        switch self {
        case .quickAppraisal: "クイック査定場"
        case .kidsSpace: "キッズスペース"
        case .corporateDesk: "法人営業窓口"
        case .importLounge: "輸入車商談ラウンジ"
        case .serviceWorkshop: "整備工場"
        case .customWorkshop: "カスタム工房"
        }
    }
    var icon: String {
        switch self {
        case .quickAppraisal: "checkmark.seal.fill"
        case .kidsSpace: "figure.2.and.child.holdinghands"
        case .corporateDesk: "briefcase.fill"
        case .importLounge: "sparkles"
        case .serviceWorkshop: "wrench.adjustable.fill"
        case .customWorkshop: "wrench.and.screwdriver.fill"
        }
    }
    var summary: String {
        switch self {
        case .quickAppraisal: "地域の買取客を増やし、査定精度を補助"
        case .kidsSpace: "家族が落ち着いて比較でき、ファミリー商談を後押し"
        case .corporateDesk: "法人客と営業車・リース満了車の一括取引を開拓"
        case .importLounge: "富裕層の紹介と高額輸入車の商談を後押し"
        case .serviceWorkshop: "2ベイで故障修理と完全再生を行う"
        case .customWorkshop: "カスタムとキャンピングカー改造を可能にする"
        }
    }
    var installationCost: Int {
        switch self {
        case .quickAppraisal: 320
        case .kidsSpace: 480
        case .corporateDesk: 650
        case .importLounge: 900
        case .serviceWorkshop: 950
        case .customWorkshop: 1_400
        }
    }
    var monthlyCost: Int {
        switch self {
        case .quickAppraisal: 12
        case .kidsSpace: 18
        case .corporateDesk: 24
        case .importLounge: 36
        case .serviceWorkshop: 34
        case .customWorkshop: 48
        }
    }
    var minimumGridCells: Int {
        switch self {
        case .kidsSpace, .corporateDesk, .serviceWorkshop, .customWorkshop: 2
        case .quickAppraisal, .importLounge: 1
        }
    }
    var workshopBays: Int {
        switch self {
        case .serviceWorkshop, .customWorkshop: 2
        default: 0
        }
    }
}

enum StoreType: String, Codable, CaseIterable, Identifiable {
    case small, standard, roadside, premium, service
    var id: String { rawValue }
    var name: String {
        switch self {
        case .small: "小型販売店"
        case .standard: "標準店"
        case .roadside: "大型ロードサイド店"
        case .premium: "輸入車ショールーム"
        case .service: "整備併設店"
        }
    }
    var icon: String {
        switch self {
        case .small: "storefront"
        case .standard: "storefront.fill"
        case .roadside: "building.2.crop.circle.fill"
        case .premium: "sparkles.rectangle.stack.fill"
        case .service: "wrench.and.screwdriver.fill"
        }
    }
    var capacity: Int {
        switch self { case .small: 15; case .standard: 35; case .roadside: 70; case .premium: 12; case .service: 30 }
    }
    var buildCost: Int {
        switch self { case .small: 2400; case .standard: 5200; case .roadside: 9800; case .premium: 7200; case .service: 7600 }
    }
    var monthlyFixedCost: Int {
        switch self { case .small: 105; case .standard: 220; case .roadside: 410; case .premium: 330; case .service: 340 }
    }
    var constructionMonths: Int {
        switch self {
        case .small: 1
        case .standard, .premium: 2
        case .roadside, .service: 3
        }
    }
    func renovationMonths(from current: StoreType) -> Int {
        max(1, min(2, constructionMonths - (current.constructionMonths > 1 ? 1 : 0)))
    }
    var serviceQuality: Double {
        switch self { case .small: 0.85; case .standard: 1.0; case .roadside: 1.05; case .premium: 1.18; case .service: 1.30 }
    }
    var requiredGridCells: Int {
        switch self {
        case .small, .premium: 1
        case .standard, .service: 2
        case .roadside: 3
        }
    }
    var baseWorkshopBays: Int { self == .service ? 2 : 0 }

    var footprintName: String { "\(requiredGridCells)セル" }
}

enum AcquisitionMode: String, Codable, CaseIterable, Identifiable {
    case purchase, lease
    var id: String { rawValue }
    var name: String { self == .purchase ? "購入" : "賃借" }
}

enum StoreTrafficLevel: Int, CaseIterable, Equatable {
    case quiet
    case light
    case steady
    case busy
    case packed

    static func from(visitorCount: Int) -> StoreTrafficLevel {
        switch max(0, visitorCount) {
        case 0: .quiet
        case 1...2: .light
        case 3...5: .steady
        case 6...9: .busy
        default: .packed
        }
    }

    var name: String {
        switch self {
        case .quiet: "閑散"
        case .light: "ゆっくり"
        case .steady: "通常"
        case .busy: "にぎわい"
        case .packed: "混雑"
        }
    }

    var icon: String {
        switch self {
        case .quiet: "moon.zzz.fill"
        case .light: "person.fill"
        case .steady: "person.2.fill"
        case .busy: "person.3.fill"
        case .packed: "figure.walk.motion"
        }
    }
}

enum MapLayer: String, CaseIterable, Identifiable {
    case normal, demand, vehicleDemand, price, traffic, competition, growth, profit
    var id: String { rawValue }
    var name: String {
        switch self {
        case .normal: "通常"
        case .demand: "客足・需要"
        case .vehicleDemand: "車種別需要"
        case .price: "土地価格"
        case .traffic: "交通量"
        case .competition: "競合密度"
        case .growth: "人口成長"
        case .profit: "収益予測"
        }
    }
    var icon: String {
        switch self {
        case .normal: "map.fill"
        case .demand: "person.3.fill"
        case .vehicleDemand: "car.side.fill"
        case .price: "yensign.circle.fill"
        case .traffic: "car.2.fill"
        case .competition: "flag.2.crossed.fill"
        case .growth: "chart.line.uptrend.xyaxis"
        case .profit: "chart.bar.fill"
        }
    }
}

struct DevelopmentProject: Codable, Hashable {
    var title: String
    var monthsRemaining: Int
    var populationBoost: Int
    var trafficBoost: Double
}

enum CityEventKind: String, Codable, Hashable {
    case development, competitorEntry, competitorExit, priceWar, competitorAcquisition, landPrice, demand, fuelPrice, economy, storeGrowth, auction, expansion, customerClaim, staffPoaching, milestone

    var icon: String {
        switch self {
        case .development: "building.2.crop.circle.fill"
        case .competitorEntry: "flag.fill"
        case .competitorExit: "door.left.hand.open"
        case .priceWar: "tag.fill"
        case .competitorAcquisition: "building.2.crop.circle.fill"
        case .landPrice: "yensign.arrow.trianglehead.counterclockwise.rotate.90"
        case .demand: "person.3.fill"
        case .fuelPrice: "fuelpump.fill"
        case .economy: "chart.line.uptrend.xyaxis"
        case .storeGrowth: "storefront.fill"
        case .auction: "gavel.fill"
        case .expansion: "globe.asia.australia.fill"
        case .customerClaim: "exclamationmark.bubble.fill"
        case .staffPoaching: "person.crop.circle.badge.minus"
        case .milestone: "trophy.fill"
        }
    }
}

enum MarketShockKind: String, Codable, Hashable, CaseIterable {
    case war
    case oilDemandSurge
    case oilProductionHalt
    case economicBoom
    case financialCrisis

    var title: String {
        switch self {
        case .war: "産油地域で戦争が発生"
        case .oilDemandSurge: "世界の石油需要が急増"
        case .oilProductionHalt: "原油採掘が停止"
        case .economicBoom: "世界景気が拡大"
        case .financialCrisis: "金融市場が急落"
        }
    }

    var detail: String {
        switch self {
        case .war: "供給不安でガソリン価格が大幅に上昇し、株式市場と自動車需要にも下押し圧力がかかります"
        case .oilDemandSurge: "世界的な需要増で原油が不足し、ガソリン価格の上昇が続きます"
        case .oilProductionHalt: "主要油田の操業停止により供給が細り、ガソリン価格が急騰します"
        case .economicBoom: "企業業績と消費意欲が上向き、日経平均と中古車需要が大きく伸びます"
        case .financialCrisis: "株価と消費意欲が急速に冷え込み、中古車の来店需要も落ち込みます"
        }
    }

    var durationWeeks: Int {
        switch self {
        case .war: 8
        case .oilDemandSurge, .oilProductionHalt, .financialCrisis: 7
        case .economicBoom: 8
        }
    }

    var gasolineWeeklyChange: Double {
        switch self {
        case .war: 3.6
        case .oilDemandSurge: 3.0
        case .oilProductionHalt: 4.2
        case .economicBoom: 0.4
        case .financialCrisis: -1.2
        }
    }

    var nikkeiWeeklyChange: Double {
        switch self {
        case .war: -2_800
        case .oilDemandSurge: 350
        case .oilProductionHalt: -900
        case .economicBoom: 3_200
        case .financialCrisis: -4_200
        }
    }

    var demandWeeklyChange: Double {
        switch self {
        case .war: -0.009
        case .oilDemandSurge: 0.002
        case .oilProductionHalt: -0.004
        case .economicBoom: 0.010
        case .financialCrisis: -0.018
        }
    }

    var eventKind: CityEventKind {
        switch self {
        case .war, .oilDemandSurge, .oilProductionHalt: .fuelPrice
        case .economicBoom, .financialCrisis: .economy
        }
    }

    var isPositive: Bool { self == .economicBoom }
}

struct ActiveMarketShock: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: MarketShockKind
    var remainingWeeks: Int

    init(id: UUID = UUID(), kind: MarketShockKind, remainingWeeks: Int? = nil) {
        self.id = id
        self.kind = kind
        self.remainingWeeks = remainingWeeks ?? kind.durationWeeks
    }
}

struct CityEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let turn: Int
    let kind: CityEventKind
    let title: String
    let detail: String
    let district: DistrictKind?
    let plotID: Int?
    let isPositive: Bool

    init(turn: Int, kind: CityEventKind, title: String, detail: String, district: DistrictKind? = nil, plotID: Int? = nil, isPositive: Bool = true) {
        id = UUID()
        self.turn = turn
        self.kind = kind
        self.title = title
        self.detail = detail
        self.district = district
        self.plotID = plotID
        self.isPositive = isPositive
    }
}

struct District: Identifiable, Codable, Hashable {
    let kind: DistrictKind
    var population: Int
    var incomeIndex: Double
    var trafficIndex: Double
    var growthRate: Double
    var competition: Double
    var demands: [VehicleCategory: Double]
    var supplies: [VehicleCategory: Double]
    var id: DistrictKind { kind }
}

enum PlotOccupant: Codable, Hashable {
    case available
    case player(storeID: UUID)
    case competitor(name: String)
    case unavailable
}

enum ParcelStructure: String, Codable, CaseIterable, Hashable {
    case commercial
    case office
    case apartment
    case home
    case villa
    case factory
    case warehouse
    case roadside
    case vacant

    var name: String {
        switch self {
        case .commercial: "商業ビル"
        case .office: "オフィスビル"
        case .apartment: "集合住宅"
        case .home: "一般住宅"
        case .villa: "高級住宅"
        case .factory: "工場"
        case .warehouse: "物流倉庫"
        case .roadside: "ロードサイド店舗"
        case .vacant: "更地"
        }
    }

    var demolitionCost: Int {
        switch self {
        case .home: 40
        case .villa: 60
        case .commercial, .office, .apartment: 90
        case .warehouse, .roadside: 120
        case .factory: 160
        case .vacant: 0
        }
    }

    var icon: String {
        switch self {
        case .commercial, .roadside: "storefront.fill"
        case .office: "building.2.fill"
        case .apartment: "building.fill"
        case .home, .villa: "house.fill"
        case .factory: "gearshape.2.fill"
        case .warehouse: "shippingbox.fill"
        case .vacant: "square.dashed"
        }
    }
}

/// The visible, current use of a city parcel. Unlike `ParcelStructure`, which
/// records the pre-acquisition structure for pricing and demolition rules,
/// this state follows the parcel through construction, operation, and
/// demolition and is the authority used by the grid renderer.
enum CityParcelUseState: Codable, Hashable {
    case ambientBuilding(assetID: CityAssetID)
    case surfaceParking
    case vacant
    case construction(storeID: UUID, targetAssetID: CityAssetID)
    case playerFacility(storeID: UUID, assetID: CityAssetID)
    case displayParking(storeID: UUID)

    var isVacant: Bool {
        if case .vacant = self { return true }
        return false
    }

    var isUnderConstruction: Bool {
        if case .construction = self { return true }
        return false
    }
}

struct LandPlot: Identifiable, Codable, Hashable {
    let id: Int
    let district: DistrictKind
    let localNumber: Int
    let area: Int
    var visibility: Double
    let access: Double
    let traffic: Double
    var price: Int
    var monthlyRent: Int
    var growth: Double
    var occupant: PlotOccupant
    var isForLease: Bool
    var isForSale: Bool
    var structure: ParcelStructure
    var currentUse: CityParcelUseState = .vacant
    var lastPriceChange: Double = 0
    var development: DevelopmentProject? = nil
}

enum VehicleProductState: String, Codable, Hashable {
    case stock
    case serviced
    case repaired
    case refurbished
    case camper
    case workCargo
    case outdoor

    static var restored: Self { .refurbished }
    static var custom: Self { .outdoor }

    var name: String {
        switch self {
        case .stock: "ノーマル"
        case .serviced: "基本整備済"
        case .repaired: "修理済"
        case .refurbished: "完全再生"
        case .camper: "キャンピング仕様"
        case .workCargo: "職人・配送仕様"
        case .outdoor: "アウトドア仕様"
        }
    }

    var purpose: CustomerPurpose? {
        switch self {
        case .camper: .camper
        case .workCargo: .work
        case .outdoor: .outdoor
        default: nil
        }
    }
}

enum WorkshopProjectKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case basicService
    case repair
    case refurbishment
    case camperConversion
    case workConversion
    case outdoorConversion

    static var restoration: Self { .refurbishment }
    static var customization: Self { .outdoorConversion }

    var id: String { rawValue }
    var name: String {
        switch self {
        case .basicService: "基本整備"
        case .repair: "故障修理"
        case .refurbishment: "完全再生"
        case .camperConversion: "キャンピングカー改造"
        case .workConversion: "職人・配送仕様"
        case .outdoorConversion: "アウトドア仕様"
        }
    }
    var icon: String {
        switch self {
        case .basicService: "checkmark.seal.fill"
        case .repair: "wrench.adjustable.fill"
        case .refurbishment: "wrench.and.screwdriver.fill"
        case .camperConversion: "tent.fill"
        case .workConversion: "shippingbox.fill"
        case .outdoorConversion: "mountain.2.fill"
        }
    }
}

enum MechanicalFaultSeverity: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, minor, major, immobile
    var id: String { rawValue }
    var name: String {
        switch self {
        case .none: "故障なし"
        case .minor: "軽度故障"
        case .major: "重大故障"
        case .immobile: "不動"
        }
    }
    var requiredWork: Int {
        switch self { case .none: 0; case .minor: 2; case .major: 5; case .immobile: 8 }
    }
}

struct VehicleConditionProfile: Codable, Hashable {
    var exterior: Int
    var interior: Int
    var mechanical: Int

    init(exterior: Int, interior: Int, mechanical: Int) {
        self.exterior = min(100, max(0, exterior))
        self.interior = min(100, max(0, interior))
        self.mechanical = min(100, max(0, mechanical))
    }

    var score: Int { (exterior + interior + mechanical) / 3 }
    var quality: Double { Double(score) / 100 }
    var band: VehicleConditionBand {
        score >= 68 ? .normal : score >= 48 ? .rough : .faulty
    }
}

struct VehicleWorkshopProject: Codable, Hashable {
    let kind: WorkshopProjectKind
    let requiredWork: Int
    var remainingWork: Int
    let cost: Int
    let qualityGain: Int
    let startedTurn: Int
    var priority: Int
    let outsourced: Bool
    var outsourcedWeeksRemaining: Int

    var totalWeeks: Int { max(1, requiredWork) }
    var remainingWeeks: Int { outsourced ? outsourcedWeeksRemaining : max(0, remainingWork) }
}

struct WorkshopProjectPreview: Hashable {
    let kind: WorkshopProjectKind
    let cost: Int
    let requiredWork: Int
    let estimatedWeeks: Int
    let qualityGain: Int
    let resultingQuality: Int
    let projectedSalePrice: Int
    let outsourced: Bool
    var weeks: Int { estimatedWeeks }
}

enum VehicleIssueKind: String, Codable, Hashable {
    case repairedHistory
    case odometerRollback

    var name: String {
        switch self {
        case .repairedHistory: "修復歴あり"
        case .odometerRollback: "メーター改ざん"
        }
    }

    var detail: String {
        switch self {
        case .repairedHistory: "骨格部位の修復歴が確認されました"
        case .odometerRollback: "実走行距離と表示値に不整合があります"
        }
    }

    var disclosedValueFactor: Double { self == .repairedHistory ? 0.78 : 0.68 }
    var compensationRate: Double { self == .repairedHistory ? 0.18 : 0.27 }
    var reputationPenalty: Double { self == .repairedHistory ? 0.06 : 0.09 }
}

enum VehicleIssueStatus: String, Codable, Hashable {
    case hidden
    case disclosed
}

struct VehicleIssueRecord: Codable, Hashable {
    let kind: VehicleIssueKind
    var status: VehicleIssueStatus
}

struct PendingCustomerClaim: Identifiable, Codable, Hashable {
    let id: UUID
    let customerID: UUID
    let storeID: UUID
    let vehicleName: String
    let issue: VehicleIssueKind
    let salePrice: Int
    let compensationCost: Int
    let dueTurn: Int
}

struct InventoryBatch: Identifiable, Codable, Hashable {
    let id: UUID
    var modelID: String
    var category: VehicleCategory
    var count: Int
    var averageCost: Int
    var quality: Double
    var modelYear: Int
    var mileage: Int
    var acquiredTurn: Int
    var productState: VehicleProductState
    var workshopProject: VehicleWorkshopProject?
    var vehicleIssue: VehicleIssueRecord?
    var condition: VehicleConditionProfile
    var fault: MechanicalFaultSeverity
    var faultRevealed: Bool
    var corporateReservationID: UUID?

    init(id: UUID = UUID(), modelID: String, category: VehicleCategory, count: Int, averageCost: Int? = nil, quality: Double = 0.75, modelYear: Int, mileage: Int, acquiredTurn: Int, productState: VehicleProductState = .stock, workshopProject: VehicleWorkshopProject? = nil, vehicleIssue: VehicleIssueRecord? = nil, condition: VehicleConditionProfile? = nil, fault: MechanicalFaultSeverity = .none, faultRevealed: Bool = true, corporateReservationID: UUID? = nil) {
        self.id = id
        self.modelID = modelID
        self.category = category
        self.count = count
        self.averageCost = averageCost ?? category.purchaseCost
        self.quality = quality
        self.modelYear = modelYear
        self.mileage = mileage
        self.acquiredTurn = acquiredTurn
        self.productState = productState
        self.workshopProject = workshopProject
        self.vehicleIssue = vehicleIssue
        let score = Int((quality * 100).rounded())
        self.condition = condition ?? VehicleConditionProfile(exterior: score, interior: score, mechanical: score)
        self.fault = fault
        self.faultRevealed = faultRevealed
        self.corporateReservationID = corporateReservationID
    }

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }

    var isRareClassic: Bool { VehicleCatalog.entry(id: modelID)?.isRareClassic == true }
    var isInWorkshop: Bool { workshopProject != nil }
    var isReserved: Bool { corporateReservationID != nil }
    var disclosedIssue: VehicleIssueKind? {
        guard vehicleIssue?.status == .disclosed else { return nil }
        return vehicleIssue?.kind
    }
}

enum AuctionVenue: String, Codable, CaseIterable, Identifiable {
    case east, port, premium
    var id: String { rawValue }

    var name: String {
        switch self {
        case .east: "東部オートオークション"
        case .port: "湾岸業販センター"
        case .premium: "都心プレミアAA"
        }
    }
    var specialty: String {
        switch self {
        case .east: "軽・コンパクト"
        case .port: "商用車・SUV・ピックアップ"
        case .premium: "輸入車・高価格SUV"
        }
    }
    var fee: Int { switch self { case .east: 7; case .port: 9; case .premium: 16 } }
    var shippingCost: Int { switch self { case .east: 5; case .port: 12; case .premium: 18 } }
    var shippingMonths: Int { switch self { case .east: 1; case .port: 1; case .premium: 2 } }
    var tint: Color { switch self { case .east: .indigo; case .port: .teal; case .premium: .purple } }
}

struct AuctionListing: Identifiable, Codable, Hashable {
    let id: UUID
    let venue: AuctionVenue
    let modelID: String
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    let quality: Double
    let reservePrice: Int
    let marketPrice: Int
    let seller: String
    let createdTurn: Int

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct BidReservation: Identifiable, Codable, Hashable {
    let id: UUID
    let listingID: UUID
    var storeID: UUID
    var maxPrice: Int
    let resultTurn: Int
}

enum AuctionBidResultStatus: String, Codable, Hashable {
    case won
    case exceededLimit
    case insufficientFunds

    var name: String {
        switch self {
        case .won: "落札"
        case .exceededLimit: "不落札"
        case .insufficientFunds: "資金不足"
        }
    }
}

struct AuctionBidResult: Identifiable, Codable, Hashable {
    let id: UUID
    let listingID: UUID
    let storeID: UUID
    let venue: AuctionVenue
    let modelID: String
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    let maxPrice: Int
    let hammerPrice: Int
    let totalCost: Int
    let status: AuctionBidResultStatus
    let winningCompetitorID: UUID?
    let resolvedTurn: Int

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct CompetitorAuctionPurchase: Identifiable, Codable, Hashable {
    let id: UUID
    let listingID: UUID
    let competitorID: UUID
    let modelID: String
    let category: VehicleCategory
    let modelYear: Int
    let mileage: Int
    let hammerPrice: Int
    let purchasedTurn: Int

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

enum ProcurementSource: String, Codable, Hashable, CaseIterable, Identifiable {
    case storePurchase, tradeIn, auction, dealerTrade, corporateLot
    var id: String { rawValue }
    var name: String {
        switch self {
        case .storePurchase: "店舗買取"
        case .tradeIn: "下取り"
        case .auction: "オークション"
        case .dealerTrade: "業者間取引"
        case .corporateLot: "法人一括"
        }
    }
}

struct InboundShipment: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let source: ProcurementSource
    let modelID: String?
    let category: VehicleCategory
    let count: Int
    let unitCost: Int
    let quality: Double
    let modelYear: Int?
    let mileage: Int?
    let acquiredTurn: Int
    var monthsRemaining: Int

    var vehicleName: String {
        guard let modelID else { return category.name }
        return VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct ProcurementQuote: Hashable {
    let source: ProcurementSource
    let modelID: String?
    let category: VehicleCategory
    let count: Int
    let unitCost: Int
    let fee: Int
    let weeks: Int
    let quality: Double
    let availabilityLabel: String

    var totalCost: Int { unitCost * count + fee }
    var vehicleName: String {
        guard let modelID else { return category.name }
        return VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct BusinessExpertise: Codable, Hashable {
    var categories: [VehicleCategory: Double] = [:]
    var purposes: [CustomerPurpose: Double] = [:]
    var productization: [WorkshopProjectKind: Double] = [:]
    var procurementSources: [ProcurementSource: Double] = [:]

    mutating func add(category: VehicleCategory? = nil, purpose: CustomerPurpose? = nil, project: WorkshopProjectKind? = nil, source: ProcurementSource? = nil, points: Double) {
        if let category { categories[category] = min(100, (categories[category] ?? 0) + points) }
        if let purpose { purposes[purpose] = min(100, (purposes[purpose] ?? 0) + points) }
        if let project { productization[project] = min(100, (productization[project] ?? 0) + points) }
        if let source { procurementSources[source] = min(100, (procurementSources[source] ?? 0) + points) }
    }

    func category(_ category: VehicleCategory) -> Double { categories[category] ?? 0 }
    func purpose(_ purpose: CustomerPurpose) -> Double { purposes[purpose] ?? 0 }
    func project(_ kind: WorkshopProjectKind) -> Double { productization[kind] ?? 0 }
    func source(_ source: ProcurementSource) -> Double { procurementSources[source] ?? 0 }
}

struct CompetitorOfferBenchmark: Codable, Hashable {
    let competitorID: UUID
    let price: Int
    let quality: Double
    let category: VehicleCategory
    let purpose: CustomerPurpose
}

struct CompetitorInventoryBucket: Identifiable, Codable, Hashable {
    let id: UUID
    var category: VehicleCategory
    var purpose: CustomerPurpose
    var count: Int
    var averageCost: Int
    var averageQuality: Double
    var productState: VehicleProductState
    var averageAgeWeeks: Int

    init(id: UUID = UUID(), category: VehicleCategory, purpose: CustomerPurpose = .general, count: Int, averageCost: Int, averageQuality: Double, productState: VehicleProductState = .stock, averageAgeWeeks: Int = 0) {
        self.id = id
        self.category = category
        self.purpose = purpose
        self.count = count
        self.averageCost = averageCost
        self.averageQuality = averageQuality
        self.productState = productState
        self.averageAgeWeeks = averageAgeWeeks
    }
}

struct CompetitorBranch: Identifiable, Codable, Hashable {
    var id: Int { plotID }
    let plotID: Int
    var capacity: Int
    var inventory: [CompetitorInventoryBucket]
    var priceIndex: Double
    var advertising: Int
    var reputation: Double
    var facilities: Set<StoreFacility>
    var marketPolicy: StoreMarketPolicy
    var expertise: BusinessExpertise
    var lastRevenue: Int
    var lastProfit: Int
    var currentRevenue: Int = 0
    var currentProfit: Int = 0

    var inventoryCount: Int { inventory.reduce(0) { $0 + $1.count } }
}

enum CorporateOpportunityKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case fleetDisposal
    case fleetPurchase
    var id: String { rawValue }
    var name: String { self == .fleetDisposal ? "法人売却ロット" : "法人購入依頼" }
}

struct CorporateOpportunity: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: CorporateOpportunityKind
    let district: DistrictKind
    let category: VehicleCategory
    let purpose: CustomerPurpose
    let count: Int
    let unitPrice: Int
    let quality: Double
    let createdTurn: Int
    let dueTurn: Int
    var playerStoreID: UUID?
    var playerUnitPrice: Int?
    var reservedInventoryIDs: [UUID]
    var resolved: Bool
    var winnerName: String?
}

struct AuctionConsignment: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let venue: AuctionVenue
    let modelID: String?
    let category: VehicleCategory
    let count: Int
    let expectedUnitPrice: Int
    var monthsRemaining: Int

    var vehicleName: String {
        guard let modelID else { return category.name }
        return VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct StoreManager: Codable, Hashable {
    let name: String
    let staffingAbility: Int
    let salesAbility: Int
    let procurementAbility: Int
    let researchAbility: Int
    let serviceAbility: Int
    let monthlySalary: Int

    var overallAbility: Int {
        (staffingAbility + salesAbility + procurementAbility + researchAbility + serviceAbility) / 5
    }
    var marketingAbility: Int { researchAbility }

    init(name: String, staffingAbility: Int, salesAbility: Int, procurementAbility: Int, researchAbility: Int, serviceAbility: Int, monthlySalary: Int) {
        self.name = name
        self.staffingAbility = staffingAbility
        self.salesAbility = salesAbility
        self.procurementAbility = procurementAbility
        self.researchAbility = researchAbility
        self.serviceAbility = serviceAbility
        self.monthlySalary = monthlySalary
    }

    init(name: String, staffingAbility: Int, salesAbility: Int, procurementAbility: Int, marketingAbility: Int, serviceAbility: Int, monthlySalary: Int) {
        self.init(name: name, staffingAbility: staffingAbility, salesAbility: salesAbility, procurementAbility: procurementAbility, researchAbility: marketingAbility, serviceAbility: serviceAbility, monthlySalary: monthlySalary)
    }
}

enum EmployeeTrainingFocus: String, Codable, CaseIterable, Identifiable {
    case sales
    case procurement
    case research
    case service

    static var appraisal: Self { .procurement }
    static var marketing: Self { .research }
    static var marketResearch: Self { .research }

    var id: String { rawValue }
    var name: String {
        switch self {
        case .sales: "販売"
        case .procurement: "仕入・査定"
        case .research: "調査"
        case .service: "整備"
        }
    }
}

enum EmployeeAssignment: String, Codable, CaseIterable, Identifiable {
    case unassigned
    case sales
    case procurement
    case research
    case service

    static var marketingResearch: Self { .research }

    var id: String { rawValue }
    var name: String {
        switch self {
        case .unassigned: "未配置"
        case .sales: "販売"
        case .procurement: "買取・査定"
        case .research: "調査・集客"
        case .service: "整備"
        }
    }
    var icon: String {
        switch self {
        case .unassigned: "person.crop.circle.badge.questionmark"
        case .sales: "person.line.dotted.person.fill"
        case .procurement: "car.badge.gearshape"
        case .research: "chart.line.uptrend.xyaxis"
        case .service: "wrench.and.screwdriver.fill"
        }
    }
}

enum EmployeeCompensationType: String, Codable, CaseIterable, Identifiable {
    case fixed
    case balanced
    case performance

    var id: String { rawValue }
    var name: String {
        switch self {
        case .fixed: "固定給型"
        case .balanced: "バランス型"
        case .performance: "成果型"
        }
    }
    var salaryFactor: Double {
        switch self {
        case .fixed: 1.0
        case .balanced: 0.9
        case .performance: 0.8
        }
    }
    var commissionRate: Int {
        switch self {
        case .fixed: 0
        case .balanced: 5
        case .performance: 10
        }
    }
}

struct EmployeeWeeklyPerformance: Codable, Hashable {
    var handled = 0
    var successes = 0
    var grossProfit = 0
    var commission = 0
    var issuesFound = 0
    var servicesCompleted = 0

    var summary: String {
        if servicesCompleted > 0 { return "整備\(servicesCompleted)台" }
        if handled > 0 { return "対応\(handled)件・成功\(successes)件・粗利\(grossProfit.currency)" }
        return "実績なし"
    }
}

enum SalesAutomationPolicy: String, Codable, CaseIterable, Identifiable {
    case profit
    case balanced
    case volume

    var id: String { rawValue }
    var name: String { switch self { case .profit: "利益重視"; case .balanced: "バランス"; case .volume: "件数重視" } }
    var strategy: SaleNegotiationStrategy { switch self { case .profit: .holdPrice; case .balanced: .smallDiscount; case .volume: .closeDeal } }
}

enum ProcurementAutomationPolicy: String, Codable, CaseIterable, Identifiable {
    case profit
    case balanced
    case volume

    var id: String { rawValue }
    var name: String { switch self { case .profit: "利益重視"; case .balanced: "バランス"; case .volume: "件数重視" } }
    var offerPercent: Int { switch self { case .profit: 88; case .balanced: 94; case .volume: 100 } }
}

enum MarketingAutomationPolicy: String, Codable, CaseIterable, Identifiable {
    case buyers
    case balanced
    case sellers

    var id: String { rawValue }
    var name: String { switch self { case .buyers: "販売客重視"; case .balanced: "バランス"; case .sellers: "買取客重視" } }
}

enum ServiceAutomationPolicy: String, Codable, CaseIterable, Identifiable {
    case cost
    case balanced
    case quality

    var id: String { rawValue }
    var name: String { switch self { case .cost: "コスト重視"; case .balanced: "バランス"; case .quality: "品質重視" } }
}

struct StoreEmployee: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    var salesSkill: Int
    var procurementSkill: Int
    var researchSkill: Int
    var serviceSkill: Int
    var salesExperience: Int
    var procurementExperience: Int
    var researchExperience: Int
    var serviceExperience: Int
    var monthlySalary: Int
    var commissionRate: Int
    var assignment: EmployeeAssignment
    var recentCommissions: [Int]
    var currentWeekPerformance: EmployeeWeeklyPerformance
    var lastWeekPerformance: EmployeeWeeklyPerformance
    var tenureWeeks: Int
    var lastTrainingTurn: Int?

    init(
        id: UUID = UUID(),
        name: String,
        salesSkill: Int,
        procurementSkill: Int,
        researchSkill: Int,
        serviceSkill: Int,
        monthlySalary: Int,
        commissionRate: Int = 0,
        assignment: EmployeeAssignment = .unassigned,
        salesExperience: Int = 0,
        procurementExperience: Int = 0,
        researchExperience: Int = 0,
        serviceExperience: Int = 0,
        recentCommissions: [Int] = [],
        currentWeekPerformance: EmployeeWeeklyPerformance = EmployeeWeeklyPerformance(),
        lastWeekPerformance: EmployeeWeeklyPerformance = EmployeeWeeklyPerformance(),
        tenureWeeks: Int = 0,
        lastTrainingTurn: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.salesSkill = salesSkill
        self.procurementSkill = procurementSkill
        self.researchSkill = researchSkill
        self.serviceSkill = serviceSkill
        self.salesExperience = salesExperience
        self.procurementExperience = procurementExperience
        self.researchExperience = researchExperience
        self.serviceExperience = serviceExperience
        self.monthlySalary = monthlySalary
        self.commissionRate = commissionRate
        self.assignment = assignment
        self.recentCommissions = Array(recentCommissions.suffix(4))
        self.currentWeekPerformance = currentWeekPerformance
        self.lastWeekPerformance = lastWeekPerformance
        self.tenureWeeks = tenureWeeks
        self.lastTrainingTurn = lastTrainingTurn
    }

    init(
        id: UUID = UUID(),
        name: String,
        salesSkill: Int,
        appraisalSkill: Int,
        procurementSkill: Int? = nil,
        marketingSkill: Int? = nil,
        serviceSkill: Int? = nil,
        marketResearchSkill: Int? = nil,
        monthlySalary: Int,
        commissionRate: Int = 0,
        assignment: EmployeeAssignment = .unassigned,
        recentCommissions: [Int] = [],
        currentWeekPerformance: EmployeeWeeklyPerformance = EmployeeWeeklyPerformance(),
        lastWeekPerformance: EmployeeWeeklyPerformance = EmployeeWeeklyPerformance(),
        tenureWeeks: Int = 0,
        lastTrainingTurn: Int? = nil
    ) {
        self.init(
            id: id, name: name, salesSkill: salesSkill,
            procurementSkill: procurementSkill ?? appraisalSkill,
            researchSkill: marketResearchSkill ?? marketingSkill ?? (salesSkill + appraisalSkill) / 2,
            serviceSkill: serviceSkill ?? appraisalSkill,
            monthlySalary: monthlySalary, commissionRate: commissionRate, assignment: assignment,
            recentCommissions: recentCommissions, currentWeekPerformance: currentWeekPerformance,
            lastWeekPerformance: lastWeekPerformance, tenureWeeks: tenureWeeks, lastTrainingTurn: lastTrainingTurn
        )
    }

    init(
        id: UUID = UUID(),
        name: String,
        salesSkill: Int,
        appraisalSkill: Int,
        procurementSkill: Int,
        marketingSkill: Int,
        serviceSkill: Int,
        marketResearchSkill: Int,
        compensation: EmployeeCompensationType,
        assignment: EmployeeAssignment = .unassigned,
        recentCommissions: [Int] = []
    ) {
        let values = [salesSkill, appraisalSkill, procurementSkill, marketingSkill, serviceSkill, marketResearchSkill]
        let topTwo = values.sorted(by: >).prefix(2)
        let topAverage = topTwo.reduce(0, +) / max(1, topTwo.count)
        let totalAverage = values.reduce(0, +) / values.count
        let marketValue = Double(topAverage) * 0.6 + Double(totalAverage) * 0.4
        let marketSalary = min(68, max(28, Int((12 + marketValue * 0.52).rounded())))
        self.init(
            id: id,
            name: name,
            salesSkill: salesSkill,
            procurementSkill: (appraisalSkill + procurementSkill) / 2,
            researchSkill: (marketingSkill + marketResearchSkill) / 2,
            serviceSkill: serviceSkill,
            monthlySalary: Int((Double(marketSalary) * compensation.salaryFactor).rounded()),
            commissionRate: compensation.commissionRate,
            assignment: assignment,
            recentCommissions: recentCommissions
        )
    }

    var skills: [Int] { [salesSkill, procurementSkill, researchSkill, serviceSkill] }
    var marketValueSkill: Int {
        let topTwo = skills.sorted(by: >).prefix(2)
        let topAverage = topTwo.reduce(0, +) / max(1, topTwo.count)
        let totalAverage = skills.reduce(0, +) / skills.count
        return Int((Double(topAverage) * 0.6 + Double(totalAverage) * 0.4).rounded())
    }
    var overallSkill: Int { marketValueSkill }
    var marketMonthlySalary: Int { min(68, max(28, Int((12 + Double(marketValueSkill) * 0.52).rounded()))) }
    var compensationType: EmployeeCompensationType {
        commissionRate >= 10 ? .performance : commissionRate >= 5 ? .balanced : .fixed
    }
    var recentTotalCompensation: Int { monthlySalary + recentCommissions.reduce(0, +) }
    var salesComposite: Double { Double(salesSkill) * 0.8 + Double(researchSkill) * 0.2 }
    var procurementComposite: Double { Double(procurementSkill) * 0.8 + Double(salesSkill) * 0.2 }
    var appraisalComposite: Double { Double(procurementSkill) * 0.8 + Double(researchSkill) * 0.2 }
    var marketingComposite: Double { Double(researchSkill) * 0.8 + Double(salesSkill) * 0.2 }
    var researchComposite: Double { Double(researchSkill) }
    var serviceComposite: Double { Double(serviceSkill) }
    var appraisalSkill: Int {
        get { procurementSkill }
        set { procurementSkill = newValue }
    }
    var marketingSkill: Int {
        get { researchSkill }
        set { researchSkill = newValue }
    }
    var marketResearchSkill: Int {
        get { researchSkill }
        set { researchSkill = newValue }
    }
    var appraisalExperience: Int {
        get { procurementExperience }
        set { procurementExperience = newValue }
    }
    var marketingExperience: Int {
        get { researchExperience }
        set { researchExperience = newValue }
    }
    var marketResearchExperience: Int {
        get { researchExperience }
        set { researchExperience = newValue }
    }
    var rankName: String {
        switch overallSkill {
        case 82...: "エース"
        case 70...: "シニア"
        case 58...: "中堅"
        default: "新人"
        }
    }
}

enum CustomerReviewChannel: String, Codable, Hashable {
    case buyer
    case seller

    var name: String {
        switch self {
        case .buyer: "販売客"
        case .seller: "買取客"
        }
    }
}

enum CustomerReviewMetric: Hashable {
    case salesPrice
    case vehicle
    case purchaseOffer
    case service
}

struct CustomerReview: Identifiable, Codable, Hashable {
    let id: UUID
    let customerID: UUID
    let createdTurn: Int
    let channel: CustomerReviewChannel
    let salesPriceScore: Int?
    let vehicleScore: Int?
    let purchaseOfferScore: Int?
    let serviceScore: Int
    let overallScore: Int
    let comment: String

    init(
        id: UUID = UUID(),
        customerID: UUID,
        createdTurn: Int,
        channel: CustomerReviewChannel,
        salesPriceScore: Int? = nil,
        vehicleScore: Int? = nil,
        purchaseOfferScore: Int? = nil,
        serviceScore: Int,
        overallScore: Int,
        comment: String
    ) {
        self.id = id
        self.customerID = customerID
        self.createdTurn = createdTurn
        self.channel = channel
        self.salesPriceScore = salesPriceScore
        self.vehicleScore = vehicleScore
        self.purchaseOfferScore = purchaseOfferScore
        self.serviceScore = serviceScore
        self.overallScore = overallScore
        self.comment = comment
    }
}

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let plotID: Int
    var plotIDs: [Int]
    var type: StoreType
    var acquisition: AcquisitionMode
    var marketPolicy: StoreMarketPolicy
    var pendingMarketPolicy: StoreMarketPolicy?
    var expertise: BusinessExpertise
    var facilities: Set<StoreFacility>
    var inventory: [InventoryBatch]
    var employees: [StoreEmployee]
    var advertising: Int
    var priceIndex: Double
    var reputation: Double
    var serviceAllocation: Double
    var delegateStaff: Bool
    var delegatePricing: Bool
    var delegateProcurement: Bool
    var delegateMarketing: Bool
    var delegateService: Bool
    var autoSales: Bool
    var autoProcurement: Bool
    var autoMarketing: Bool
    var autoService: Bool
    var salesPolicy: SalesAutomationPolicy
    var procurementPolicy: ProcurementAutomationPolicy
    var marketingPolicy: MarketingAutomationPolicy
    var servicePolicy: ServiceAutomationPolicy
    var lastSales: Int
    var lastRevenue: Int
    var lastProfit: Int
    var satisfaction: Int
    var causes: [ResultCause]
    var openingMonthsRemaining: Int?
    var pendingType: StoreType?
    var renovationMonthsRemaining: Int?
    var manager: StoreManager?
    var pendingManualSales: Int
    var pendingManualRevenue: Int
    var pendingManualCOGS: Int
    var pendingManualNegotiations: Int
    var pendingPurchaseNegotiations: Int
    var weeklyBuyerArrivals: Int
    var weeklySellerArrivals: Int
    var loyalCustomers: Int
    var customerReviews: [CustomerReview]

    init(name: String, plotID: Int, plotIDs: [Int]? = nil, type: StoreType, acquisition: AcquisitionMode, marketPolicy: StoreMarketPolicy = StoreMarketPolicy(), facilities: Set<StoreFacility> = [], inventory: [InventoryBatch], employees: [StoreEmployee] = [], openingMonthsRemaining: Int? = nil) {
        id = UUID()
        self.name = name
        self.plotID = plotID
        self.plotIDs = plotIDs ?? [plotID]
        self.type = type
        self.acquisition = acquisition
        self.marketPolicy = marketPolicy
        pendingMarketPolicy = nil
        expertise = BusinessExpertise()
        self.facilities = facilities
        self.inventory = inventory
        self.employees = employees
        advertising = 80
        priceIndex = 1.0
        reputation = 0.65
        serviceAllocation = 0.35
        delegateStaff = false
        delegatePricing = false
        delegateProcurement = false
        delegateMarketing = false
        delegateService = false
        autoSales = false
        autoProcurement = false
        autoMarketing = false
        autoService = false
        salesPolicy = .balanced
        procurementPolicy = .balanced
        marketingPolicy = .balanced
        servicePolicy = .balanced
        lastSales = 0
        lastRevenue = 0
        lastProfit = 0
        satisfaction = 0
        causes = []
        self.openingMonthsRemaining = openingMonthsRemaining
        pendingType = nil
        renovationMonthsRemaining = nil
        manager = nil
        pendingManualSales = 0
        pendingManualRevenue = 0
        pendingManualCOGS = 0
        pendingManualNegotiations = 0
        pendingPurchaseNegotiations = 0
        weeklyBuyerArrivals = 0
        weeklySellerArrivals = 0
        loyalCustomers = 0
        customerReviews = []
    }

    var inventoryCount: Int { inventory.reduce(0) { $0 + $1.count } }
    var staff: Int { employees.count }
    var employeeMonthlyPayroll: Int { employees.reduce(0) { $0 + $1.monthlySalary } }
    var facilityMonthlyCost: Int { facilities.reduce(0) { $0 + $1.monthlyCost } }
    var facilityInvestment: Int { facilities.reduce(0) { $0 + $1.installationCost } }
    var workshopBays: Int { type.baseWorkshopBays + facilities.reduce(0) { $0 + $1.workshopBays } }
    var weeklyWorkshopLabor: Int {
        employees.filter { $0.assignment == .service }.reduce(0) {
            $0 + min(4, max(1, Int((Double($1.serviceSkill) / 25).rounded())))
        }
    }
    var derivedBusinessName: String {
        let bestCategory = expertise.categories.max(by: { $0.value < $1.value })
        let bestPurpose = expertise.purposes.max(by: { $0.value < $1.value })
        let bestProject = expertise.productization.max(by: { $0.value < $1.value })
        let bestSource = expertise.procurementSources.max(by: { $0.value < $1.value })
        let choices: [(Double, String)] = [
            bestCategory.map { ($0.value, "\($0.key.name)に強い店") },
            bestPurpose.map { ($0.value, "\($0.key.name)に強い店") },
            bestProject.map { ($0.value, "\($0.key.name)に強い店") },
            bestSource.map { ($0.value, "\($0.key.name)に強い店") }
        ].compactMap { $0 }
        guard let best = choices.max(by: { $0.0 < $1.0 }), best.0 >= 15 else { return "総合中古車店" }
        return best.1
    }
    var isOperational: Bool { openingMonthsRemaining == nil }
    var isRenovating: Bool { pendingType != nil && renovationMonthsRemaining != nil }
    var hasManager: Bool { manager != nil }
    var manualSalesThisWeek: Int { pendingManualSales }
    var manualNegotiationsThisWeek: Int { pendingManualNegotiations }
    var purchaseNegotiationsThisWeek: Int { pendingPurchaseNegotiations }
    var buyerArrivalsThisWeek: Int { weeklyBuyerArrivals }
    var sellerArrivalsThisWeek: Int { weeklySellerArrivals }
    var weeklyVisitorCount: Int { buyerArrivalsThisWeek + sellerArrivalsThisWeek }
    var trafficLevel: StoreTrafficLevel { .from(visitorCount: weeklyVisitorCount) }
    var usedOpportunitiesThisWeek: Int { manualNegotiationsThisWeek + purchaseNegotiationsThisWeek }
    var reviewCount: Int { customerReviews.count }
    var averageReviewScore: Int? {
        guard !customerReviews.isEmpty else { return nil }
        return Int((Double(customerReviews.reduce(0) { $0 + $1.overallScore }) / Double(customerReviews.count)).rounded())
    }
    var reviewRating: Double? { averageReviewScore.map { Double($0) / 20 } }
    var reviewRatingText: String { reviewRating.map { String(format: "%.1f", $0) } ?? "未評価" }

    func reviewScore(for metric: CustomerReviewMetric) -> Int? {
        let values: [Int] = customerReviews.compactMap { review in
            switch metric {
            case .salesPrice: review.salesPriceScore
            case .vehicle: review.vehicleScore
            case .purchaseOffer: review.purchaseOfferScore
            case .service: review.serviceScore
            }
        }
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    func customerReviewAttraction(for channel: CustomerReviewChannel) -> Double {
        let reviews = customerReviews.filter { $0.channel == channel }
        guard !reviews.isEmpty else { return 1 }
        let average = Double(reviews.reduce(0) { $0 + $1.overallScore }) / Double(reviews.count)
        let confidence = min(1, Double(reviews.count) / 10)
        return min(1.28, max(0.68, 1 + (average - 70) / 100 * confidence))
    }

    var reviewManagementAdvice: String {
        guard !customerReviews.isEmpty else {
            return "まだ来店客の評価はありません。最初の接客・査定・価格提示が店舗の評判を作ります"
        }
        let salesPrice = reviewScore(for: .salesPrice)
        let vehicle = reviewScore(for: .vehicle)
        let purchase = reviewScore(for: .purchaseOffer)
        let service = reviewScore(for: .service)
        if let purchase, purchase >= 85, lastProfit < 0 {
            return "高額買取で買取客の評判は高い一方、利益を圧迫しています。査定精度と買取上限を見直しましょう"
        }
        if let salesPrice, salesPrice < 60 {
            return "販売価格への低評価が客足を下げています。価格指数・値引き方針・付加価値のバランスを見直しましょう"
        }
        if let vehicle, vehicle < 60 {
            return "車両品質・品揃えへの不満が目立ちます。整備品質と地域需要に合う在庫を優先しましょう"
        }
        if let service, service < 60 {
            return "接客・未対応への不満が客足を下げています。担当者配置と週間対応枠を増やしましょう"
        }
        if let purchase, purchase < 60 {
            return "買取価格への評価が低く、売却客を競合へ逃しています。採算を守りつつ提示条件を改善しましょう"
        }
        return "口コミは安定しています。高評価項目を維持しながら、最も低い項目を次の改善対象にしましょう"
    }
    var visualTier: Int {
        let profitTier = lastProfit >= 500 ? 2 : lastProfit >= 120 ? 1 : 0
        let reputationTier = reputation >= 0.95 ? 1 : 0
        return min(4, max(1, 1 + profitTier + reputationTier))
    }
}

struct ResultCause: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let effect: Double
    init(_ title: String, _ effect: Double) { id = UUID(); self.title = title; self.effect = effect }
}

struct Competitor: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var strategy: String
    var colorHex: String
    var cash: Int
    var branches: [CompetitorBranch]
    var strength: Double
    var category: VehicleCategory
    var salesAbility: Int
    var procurementAbility: Int
    var researchAbility: Int
    var serviceAbility: Int
    var expertise: BusinessExpertise
    var profitableSegmentWeeks: [VehicleCategory: Int]
    var targetInventoryShare: [VehicleCategory: Double]

    var plotIDs: [Int] {
        get { branches.map(\.plotID) }
        set {
            let existing = Dictionary(uniqueKeysWithValues: branches.map { ($0.plotID, $0) })
            branches = newValue.map { plotID in
                existing[plotID] ?? CompetitorBranch(
                    plotID: plotID, capacity: 24, inventory: [], priceIndex: 1,
                    advertising: 90, reputation: 0.68, facilities: [],
                    marketPolicy: StoreMarketPolicy(priorityCategories: [category], targetPurpose: .general, acceptedConditions: [.normal]),
                    expertise: BusinessExpertise(), lastRevenue: 0, lastProfit: 0
                )
            }
        }
    }

    init(id: UUID = UUID(), name: String, strategy: String, colorHex: String, cash: Int, plotIDs: [Int], strength: Double, category: VehicleCategory, salesAbility: Int = 70, procurementAbility: Int = 70, researchAbility: Int = 70, serviceAbility: Int = 65, expertise: BusinessExpertise = BusinessExpertise(), profitableSegmentWeeks: [VehicleCategory: Int] = [:], targetInventoryShare: [VehicleCategory: Double] = [:]) {
        self.id = id
        self.name = name
        self.strategy = strategy
        self.colorHex = colorHex
        self.cash = cash
        self.branches = []
        self.strength = strength
        self.category = category
        self.salesAbility = salesAbility
        self.procurementAbility = procurementAbility
        self.researchAbility = researchAbility
        self.serviceAbility = serviceAbility
        self.expertise = expertise
        self.profitableSegmentWeeks = profitableSegmentWeeks
        self.targetInventoryShare = targetInventoryShare.isEmpty ? [category: 0.55] : targetInventoryShare
        self.plotIDs = plotIDs
    }
}

enum PriceWarResponse: String, Codable, CaseIterable, Identifiable, Hashable {
    case counterSale
    case brandDefense

    var id: String { rawValue }
    var name: String {
        switch self {
        case .counterSale: "対抗セール"
        case .brandDefense: "ブランド防衛"
        }
    }
    var detail: String {
        switch self {
        case .counterSale: "期間中は売価を4%下げ、成約率と集客を回復"
        case .brandDefense: "広告と保証訴求で価格を維持し、評判を上げる"
        }
    }
    var icon: String {
        switch self {
        case .counterSale: "tag.fill"
        case .brandDefense: "shield.checkered"
        }
    }
}

struct PriceWarChallenge: Identifiable, Codable, Hashable {
    let id: UUID
    let competitorID: UUID
    let district: DistrictKind
    let startedTurn: Int
    let expiresTurn: Int
    let intensity: Double
    var response: PriceWarResponse?

    init(id: UUID = UUID(), competitorID: UUID, district: DistrictKind, startedTurn: Int, expiresTurn: Int, intensity: Double, response: PriceWarResponse? = nil) {
        self.id = id
        self.competitorID = competitorID
        self.district = district
        self.startedTurn = startedTurn
        self.expiresTurn = expiresTurn
        self.intensity = intensity
        self.response = response
    }

    func isActive(at turn: Int) -> Bool { turn >= startedTurn && turn < expiresTurn }
    func remainingWeeks(at turn: Int) -> Int { max(0, expiresTurn - turn) }
}

struct RivalTalentOffer: Identifiable, Hashable {
    let competitorID: UUID
    let employee: StoreEmployee
    let signingCost: Int

    var id: UUID { employee.id }
}

struct CompetitorAcquisitionOffer: Identifiable, Hashable {
    let competitorID: UUID
    let plotID: Int
    let cost: Int

    var id: Int { plotID }
}

struct MonthlyReport: Identifiable, Codable, Hashable {
    let id: UUID
    let year: Int
    let month: Int
    var week: Int
    let sales: Int
    let revenue: Int
    let grossProfit: Int
    let operatingProfit: Int
    let cashChange: Int
    let averageInventoryWeeks: Double
    let headline: String
    let notes: [String]
}

enum BusinessMilestoneID: String, Codable, CaseIterable, Identifiable, Hashable {
    case salesFoundation
    case annualSales100
    case districtLeader
    case nationalExpansion
    case lifetimeSales500

    var id: String { rawValue }
    var title: String {
        switch self {
        case .salesFoundation: "累計販売25台"
        case .annualSales100: "年間販売100台"
        case .districtLeader: "地区シェアNo.1"
        case .nationalExpansion: "企業価値4.5億円"
        case .lifetimeSales500: "累計販売500台"
        }
    }
    var detail: String {
        switch self {
        case .salesFoundation: "地域店としての販売基盤を築く"
        case .annualSales100: "同一年内に100台を販売する"
        case .districtLeader: "いずれかの地区で競合各社を上回る"
        case .nationalExpansion: "全国展開に耐える企業規模へ成長する"
        case .lifetimeSales500: "長期経営で確かな販売実績を残す"
        }
    }
    var reward: String {
        switch self {
        case .salesFoundation: "地域表彰・報奨金250万円"
        case .annualSales100: "銀行の融資上限+1億円"
        case .districtLeader: "店舗評判と全国認知が上昇"
        case .nationalExpansion: "全国事業マップを解放"
        case .lifetimeSales500: "殿堂表彰・ブランド力上昇"
        }
    }
    var icon: String {
        switch self {
        case .salesFoundation: "car.2.fill"
        case .annualSales100: "banknote.fill"
        case .districtLeader: "medal.fill"
        case .nationalExpansion: "globe.asia.australia.fill"
        case .lifetimeSales500: "trophy.fill"
        }
    }
}

struct CareerStatistics: Codable, Hashable {
    var totalSales: Int = 0
    var totalRevenue: Int = 0
    var totalOperatingProfit: Int = 0
    var bestWeeklySales: Int = 0
    var profitableWeeks: Int = 0
    var salesByYear: [Int: Int] = [:]
    var completedMilestones: Set<BusinessMilestoneID> = []

    var bestAnnualSales: Int { salesByYear.values.max() ?? 0 }
}

struct MilestoneStatus: Identifiable, Hashable {
    let id: BusinessMilestoneID
    let current: Int
    let target: Int
    let isCompleted: Bool

    var progress: Double { isCompleted ? 1 : min(1, Double(current) / Double(max(1, target))) }
    var progressText: String {
        switch id {
        case .districtLeader: isCompleted ? "達成" : "未達成"
        case .nationalExpansion: "\(current.currency) / \(target.currency)"
        default: "\(current.formatted()) / \(target.formatted())台"
        }
    }
}

enum EndingRank: String, CaseIterable, Hashable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var title: String {
        switch self {
        case .s: "全国を代表する中古車グループ"
        case .a: "地域を牽引する優良企業"
        case .b: "堅実に成長した有力店"
        case .c: "地域に根付いた中古車店"
        case .d: "再建途上の販売会社"
        }
    }
}

struct EndingEvaluation: Hashable {
    let rank: EndingRank
    let totalScore: Int
    let assetScore: Int
    let brandScore: Int
    let salesScore: Int
}

struct PurchaseCase: Identifiable, Codable, Hashable {
    let id: UUID
    let storeID: UUID
    let modelID: String
    let category: VehicleCategory
    let lotCount: Int
    let modelYear: Int
    let mileage: Int
    var exterior: Int
    var interior: Int
    var mechanical: Int
    let askingPrice: Int
    let appraisedPrice: Int
    let repairCost: Int
    let expectedSalePrice: Int
    let expectedDays: Int
    let demand: Double
    var appraisalAccuracy: Int
    var negotiationAttempts: Int
    let hiddenIssue: VehicleIssueKind?
    var issueRevealed: Bool
    let condition: VehicleConditionProfile
    let fault: MechanicalFaultSeverity
    var faultRevealed: Bool
    let competitorOffer: CompetitorOfferBenchmark?

    init(id: UUID, storeID: UUID, modelID: String, category: VehicleCategory, lotCount: Int, modelYear: Int, mileage: Int, exterior: Int, interior: Int, mechanical: Int, askingPrice: Int, appraisedPrice: Int, repairCost: Int, expectedSalePrice: Int, expectedDays: Int, demand: Double, appraisalAccuracy: Int, negotiationAttempts: Int, hiddenIssue: VehicleIssueKind?, issueRevealed: Bool, condition: VehicleConditionProfile? = nil, fault: MechanicalFaultSeverity = .none, faultRevealed: Bool = true, competitorOffer: CompetitorOfferBenchmark? = nil) {
        self.id = id
        self.storeID = storeID
        self.modelID = modelID
        self.category = category
        self.lotCount = lotCount
        self.modelYear = modelYear
        self.mileage = mileage
        self.exterior = exterior
        self.interior = interior
        self.mechanical = mechanical
        self.askingPrice = askingPrice
        self.appraisedPrice = appraisedPrice
        self.repairCost = repairCost
        self.expectedSalePrice = expectedSalePrice
        self.expectedDays = expectedDays
        self.demand = demand
        self.appraisalAccuracy = appraisalAccuracy
        self.negotiationAttempts = negotiationAttempts
        self.hiddenIssue = hiddenIssue
        self.issueRevealed = issueRevealed
        self.condition = condition ?? VehicleConditionProfile(exterior: exterior, interior: interior, mechanical: mechanical)
        self.fault = fault
        self.faultRevealed = faultRevealed
        self.competitorOffer = competitorOffer
    }

    var revealedIssue: VehicleIssueKind? { issueRevealed ? hiddenIssue : nil }
    var expectedSaleAfterAppraisal: Int {
        guard let revealedIssue else { return expectedSalePrice }
        return Int(Double(expectedSalePrice) * revealedIssue.disclosedValueFactor)
    }
    var expectedGrossProfit: Int { (expectedSaleAfterAppraisal - askingPrice - repairCost) * lotCount }
    var conditionScore: Int { (exterior + interior + mechanical) / 3 }
    var repairQualityGain: Int { conditionScore < 75 ? 4 : 3 }
    var qualityAfterRepairScore: Int { min(94, conditionScore + repairQualityGain) }
    var negotiations: Int { negotiationAttempts }
    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

struct FinanceSnapshot: Codable, Hashable {
    var revenue: Int = 0
    var costOfSales: Int = 0
    var personnel: Int = 0
    var rent: Int = 0
    var advertising: Int = 0
    var depreciation: Int = 0
    var customerClaims: Int = 0
    var operatingProfit: Int = 0
    var landAssets: Int = 0
    var buildingAssets: Int = 0
    var inventoryAssets: Int = 0
    var debt: Int = 0
    var operatingCF: Int = 0
    var investingCF: Int = 0
    var financingCF: Int = 0
}

struct FourWeekForecast: Hashable {
    let salesLow: Int
    let salesHigh: Int
    let grossProfitLow: Int
    let grossProfitHigh: Int
    let operatingProfitLow: Int
    let operatingProfitHigh: Int
    let endingCashLow: Int
    let endingCashHigh: Int
    let inventoryCapital: Int
    let estimatedInventoryMarketValue: Int
    let bottleneck: String
}

/// A store-specific view of the market. This is derived from the live market
/// state, so it deliberately is not part of saved-game data.
struct MarketIntelligenceReport: Hashable {
    let horizonWeeks: Int
    let accuracyPercent: Int
    let gasolineRange: ClosedRange<Int>
    let nikkeiRange: ClosedRange<Int>
    let demandRange: ClosedRange<Int>
    let shortTermOutlook: String
    let longTermOutlook: String
    let recommendedAction: String
    let upcomingEvent: MarketShockKind?
}

struct VehicleMarketForecast: Hashable {
    let horizonWeeks: Int
    let retailPriceRange: ClosedRange<Int>
    let auctionPriceRange: ClosedRange<Int>
    let directionPercent: Int
}
