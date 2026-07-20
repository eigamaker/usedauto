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
        self.usedMarketDelayWeeks = usedMarketDelayWeeks ?? (launchTurn == 0 ? 0 : 16)
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
        VehicleCatalogEntry(id: "voltra-aurexs", maker: "ヴォルトラ", modelName: "AUREX S", category: .imported, baseWholesalePrice: 980, referenceRetailPrice: 1_480, qualityBaseline: 0.93, popularity: 1.17, launchTurn: 30, powertrain: .electric, usedMarketDelayWeeks: 24),

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
        VehicleCatalogEntry(id: "aoba-picoev", maker: "アオバ", modelName: "PICO EV", category: .kei, baseWholesalePrice: 112, referenceRetailPrice: 164, qualityBaseline: 0.91, popularity: 1.18, launchTurn: 260, powertrain: .electric, usedMarketDelayWeeks: 24),
        VehicleCatalogEntry(id: "seika-comet2", maker: "セイカ", modelName: "COMET II", category: .compact, baseWholesalePrice: 146, referenceRetailPrice: 208, qualityBaseline: 0.91, popularity: 1.16, launchTurn: 286),
        VehicleCatalogEntry(id: "hinode-familiaev", maker: "ヒノデ", modelName: "FAMILIA EV", category: .minivan, baseWholesalePrice: 252, referenceRetailPrice: 368, qualityBaseline: 0.93, popularity: 1.18, launchTurn: 312, powertrain: .electric, usedMarketDelayWeeks: 26),
        VehicleCatalogEntry(id: "seika-terrae", maker: "セイカ", modelName: "TERRA E", category: .suv, baseWholesalePrice: 440, referenceRetailPrice: 640, qualityBaseline: 0.93, popularity: 1.18, launchTurn: 338, powertrain: .electric, usedMarketDelayWeeks: 28),
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
                let year = 2030 + yearIndex
                let inflation = 1.0 + Double(yearIndex) * 0.024
                let segmentPremium: Double = category == .imported ? 1.16 : 1.0
                let technologyPremium: Double = powertrain == .electric ? 1.14 : powertrain == .hybrid ? 1.07 : 1.0
                let wholesale = max(45, Int(Double(category.purchaseCost) * 1.06 * inflation * segmentPremium * technologyPremium))
                let retail = Int(Double(wholesale) * (category == .imported ? 1.48 : 1.40))
                let popularity = 0.94 + Double((makerIndex * 7 + yearIndex * 11) % 25) / 100.0
                let delay = 14 + (makerIndex * 3 + yearIndex * 5) % 19 + (powertrain == .electric ? 6 : 0)
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

    init(id: UUID, storeID: UUID, preference: BuyerVehiclePreference, budget: Int, minimumQuality: Double, minimumModelYear: Int = 0, maximumMileage: Int = .max, priceSensitivity: Double, generatedTurn: Int, tradeInVehicle: TradeInVehicle? = nil) {
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

enum CustomerFocus: String, Codable, CaseIterable, Identifiable {
    case family, value, young, affluent, business
    var id: String { rawValue }
    var name: String {
        switch self {
        case .family: "ファミリー"
        case .value: "価格重視"
        case .young: "若年層"
        case .affluent: "高所得層"
        case .business: "法人・事業者"
        }
    }
}

enum StoreConcept: String, Codable, CaseIterable, Identifiable {
    case general, localValue, family, outdoor, affluent, business
    var id: String { rawValue }

    var name: String {
        switch self {
        case .general: "総合中古車店"
        case .localValue: "地域・価格重視"
        case .family: "ファミリー専門"
        case .outdoor: "アウトドア専門"
        case .affluent: "輸入車・富裕層専門"
        case .business: "商用車・法人専門"
        }
    }

    var icon: String {
        switch self {
        case .general: "car.2.fill"
        case .localValue: "car.side.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .outdoor: "tent.fill"
        case .affluent: "sparkles"
        case .business: "truck.box.fill"
        }
    }

    var summary: String {
        switch self {
        case .general: "幅広い需要に対応。突出した強みは少ない"
        case .localValue: "軽・コンパクトを素早く査定し、地域の買い替え需要を回す"
        case .family: "家族が滞在しやすい店舗で軽からSUVまで比較販売する"
        case .outdoor: "ミニバン・SUV・ピックアップに改造価値を加える"
        case .affluent: "少数の富裕層へ高額輸入車と一部SUVを提案する"
        case .business: "法人へ商用車を販売し、営業車の一括放出も仕入れる"
        }
    }

    var targetCategories: Set<VehicleCategory> {
        switch self {
        case .general: Set(VehicleCategory.allCases)
        case .localValue: [.kei, .compact]
        case .family: [.kei, .compact, .minivan, .suv]
        case .outdoor: [.minivan, .suv, .pickup]
        case .affluent: [.imported, .suv]
        case .business: [.commercial, .pickup]
        }
    }

    var minimumGridCells: Int {
        switch self {
        case .family, .outdoor, .business: 2
        case .general, .localValue, .affluent: 1
        }
    }

    var defaultFacilities: Set<StoreFacility> {
        switch self {
        case .general: []
        case .localValue: [.quickAppraisal]
        case .family: [.kidsSpace]
        case .outdoor: [.customWorkshop]
        case .affluent: [.importLounge]
        case .business: [.corporateDesk]
        }
    }
}

enum StoreFacility: String, Codable, CaseIterable, Identifiable, Hashable {
    case quickAppraisal
    case kidsSpace
    case corporateDesk
    case importLounge
    case customWorkshop

    var id: String { rawValue }
    var name: String {
        switch self {
        case .quickAppraisal: "クイック査定場"
        case .kidsSpace: "キッズスペース"
        case .corporateDesk: "法人営業窓口"
        case .importLounge: "輸入車商談ラウンジ"
        case .customWorkshop: "カスタム工房"
        }
    }
    var icon: String {
        switch self {
        case .quickAppraisal: "checkmark.seal.fill"
        case .kidsSpace: "figure.2.and.child.holdinghands"
        case .corporateDesk: "briefcase.fill"
        case .importLounge: "sparkles"
        case .customWorkshop: "wrench.and.screwdriver.fill"
        }
    }
    var summary: String {
        switch self {
        case .quickAppraisal: "地域の買取客を増やし、査定精度を補助"
        case .kidsSpace: "家族が落ち着いて比較でき、ファミリー商談を後押し"
        case .corporateDesk: "法人客と営業車・リース満了車の一括取引を開拓"
        case .importLounge: "富裕層の紹介と高額輸入車の商談を後押し"
        case .customWorkshop: "カスタムとキャンピングカー改造を可能にする"
        }
    }
    var installationCost: Int {
        switch self {
        case .quickAppraisal: 320
        case .kidsSpace: 480
        case .corporateDesk: 650
        case .importLounge: 900
        case .customWorkshop: 1_400
        }
    }
    var monthlyCost: Int {
        switch self {
        case .quickAppraisal: 12
        case .kidsSpace: 18
        case .corporateDesk: 24
        case .importLounge: 36
        case .customWorkshop: 48
        }
    }
    var minimumGridCells: Int {
        switch self {
        case .kidsSpace, .corporateDesk, .customWorkshop: 2
        case .quickAppraisal, .importLounge: 1
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
    case development, competitorEntry, competitorExit, priceWar, competitorAcquisition, landPrice, demand, fuelPrice, storeGrowth, auction, expansion, customerClaim, staffPoaching, milestone

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
        case .storeGrowth: "storefront.fill"
        case .auction: "gavel.fill"
        case .expansion: "globe.asia.australia.fill"
        case .customerClaim: "exclamationmark.bubble.fill"
        case .staffPoaching: "person.crop.circle.badge.minus"
        case .milestone: "trophy.fill"
        }
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
    case restored
    case custom

    var name: String {
        switch self {
        case .stock: "ノーマル"
        case .restored: "レストア済"
        case .custom: "カスタムカー"
        }
    }
}

enum WorkshopProjectKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case restoration
    case customization
    case camperConversion

    var id: String { rawValue }
    var name: String {
        switch self {
        case .restoration: "商品化・レストア"
        case .customization: "カスタム製作"
        case .camperConversion: "キャンピングカー改造"
        }
    }
    var icon: String {
        switch self {
        case .restoration: "wrench.and.screwdriver.fill"
        case .customization: "paintbrush.pointed.fill"
        case .camperConversion: "tent.fill"
        }
    }
}

struct VehicleWorkshopProject: Codable, Hashable {
    let kind: WorkshopProjectKind
    let totalWeeks: Int
    var remainingWeeks: Int
    let cost: Int
    let qualityGain: Int
}

struct WorkshopProjectPreview: Hashable {
    let kind: WorkshopProjectKind
    let cost: Int
    let weeks: Int
    let qualityGain: Int
    let resultingQuality: Int
    let projectedSalePrice: Int
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

    init(id: UUID = UUID(), modelID: String, category: VehicleCategory, count: Int, averageCost: Int? = nil, quality: Double = 0.75, modelYear: Int, mileage: Int, acquiredTurn: Int, productState: VehicleProductState = .stock, workshopProject: VehicleWorkshopProject? = nil, vehicleIssue: VehicleIssueRecord? = nil) {
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
    }

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }

    var isRareClassic: Bool { VehicleCatalog.entry(id: modelID)?.isRareClassic == true }
    var isInWorkshop: Bool { workshopProject != nil }
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
    let resolvedTurn: Int

    var vehicleName: String {
        VehicleCatalog.entry(id: modelID)?.fullName ?? modelID
    }
}

enum ProcurementSource: String, Codable, Hashable {
    case auction, dealerTrade, fleetPurchase
    var name: String {
        switch self { case .auction: "オークション"; case .dealerTrade: "業者間取引"; case .fleetPurchase: "法人一括仕入れ" }
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
    let marketingAbility: Int
    let serviceAbility: Int
    let monthlySalary: Int

    var overallAbility: Int {
        (staffingAbility + salesAbility + marketingAbility + serviceAbility) / 4
    }
}

enum EmployeeTrainingFocus: String, Codable, CaseIterable, Identifiable {
    case sales
    case appraisal

    var id: String { rawValue }
    var name: String { self == .sales ? "営業" : "査定" }
}

struct StoreEmployee: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    var salesSkill: Int
    var appraisalSkill: Int
    var salesExperience: Int
    var appraisalExperience: Int
    var monthlySalary: Int
    var tenureWeeks: Int
    var lastTrainingTurn: Int?

    init(id: UUID = UUID(), name: String, salesSkill: Int, appraisalSkill: Int, monthlySalary: Int, salesExperience: Int = 0, appraisalExperience: Int = 0, tenureWeeks: Int = 0, lastTrainingTurn: Int? = nil) {
        self.id = id
        self.name = name
        self.salesSkill = salesSkill
        self.appraisalSkill = appraisalSkill
        self.salesExperience = salesExperience
        self.appraisalExperience = appraisalExperience
        self.monthlySalary = monthlySalary
        self.tenureWeeks = tenureWeeks
        self.lastTrainingTurn = lastTrainingTurn
    }

    var overallSkill: Int { (salesSkill + appraisalSkill) / 2 }
    var rankName: String {
        switch overallSkill {
        case 82...: "エース"
        case 70...: "シニア"
        case 58...: "中堅"
        default: "新人"
        }
    }
}

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let plotID: Int
    var plotIDs: [Int]
    var type: StoreType
    var acquisition: AcquisitionMode
    var focus: CustomerFocus
    var concept: StoreConcept
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

    init(name: String, plotID: Int, plotIDs: [Int]? = nil, type: StoreType, acquisition: AcquisitionMode, focus: CustomerFocus, concept: StoreConcept = .general, facilities: Set<StoreFacility>? = nil, inventory: [InventoryBatch], employees: [StoreEmployee] = [], openingMonthsRemaining: Int? = nil) {
        id = UUID()
        self.name = name
        self.plotID = plotID
        self.plotIDs = plotIDs ?? [plotID]
        self.type = type
        self.acquisition = acquisition
        self.focus = focus
        self.concept = concept
        self.facilities = facilities ?? concept.defaultFacilities
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
        lastSales = 0
        lastRevenue = 0
        lastProfit = 0
        satisfaction = 70
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
    }

    var inventoryCount: Int { inventory.reduce(0) { $0 + $1.count } }
    var staff: Int { employees.count }
    var employeeMonthlyPayroll: Int { employees.reduce(0) { $0 + $1.monthlySalary } }
    var facilityMonthlyCost: Int { facilities.reduce(0) { $0 + $1.monthlyCost } }
    var facilityInvestment: Int { facilities.reduce(0) { $0 + $1.installationCost } }
    var averageSalesSkill: Double? {
        employees.isEmpty ? nil : Double(employees.reduce(0) { $0 + $1.salesSkill }) / Double(employees.count)
    }
    var averageAppraisalSkill: Double? {
        employees.isEmpty ? nil : Double(employees.reduce(0) { $0 + $1.appraisalSkill }) / Double(employees.count)
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
    var plotIDs: [Int]
    var strength: Double
    var category: VehicleCategory
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
