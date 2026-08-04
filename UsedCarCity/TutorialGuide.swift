import SwiftUI

// MARK: - ガイドキャラクター

/// プレイヤーに経営を教える案内役。見た目と語り口だけを持つ軽量な定義で、
/// 進行状態は `GuideProgress` が保持します。
struct GuideCharacter {
    let name: String
    let shortName: String
    let role: String
    let tagline: String

    static let nao = GuideCharacter(
        name: "浜岡 ナオ",
        shortName: "ナオ",
        role: "翠浜商工会 中古車部会アドバイザー",
        tagline: "元・全国チェーンの店長。土地選びから数字の読み方までお手伝いします。"
    )
}

/// アバターの表情。レッスンごとに切り替えます。
enum GuideExpression {
    case neutral
    case smile
    case point
    case think
    case cheer
    case alert
}

// MARK: - 案内モード

enum GuideMode: String, Codable, CaseIterable, Identifiable {
    /// 全レッスンを順番に案内する初心者向けモード。
    case full
    /// 経験者向け。マップやターン進行の説明を省き、経営判断の要点だけを案内します。
    case essentials
    /// 案内なし。ガイドは表示されません。
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "しっかり案内してほしい"
        case .essentials: "要点だけ教えてほしい"
        case .off: "案内は不要"
        }
    }

    var detail: String {
        switch self {
        case .full: "初めての方向け。土地選びから仕入れ・販売・店員への委任・PLの読み方まで、順番に一緒に進めます。"
        case .essentials: "経営判断に関わる要点だけを短く案内します。マップ操作やターン進行の説明は省きます。"
        case .off: "ガイドは表示しません。設定からいつでも呼び出せます。"
        }
    }

    var icon: String {
        switch self {
        case .full: "figure.wave"
        case .essentials: "bolt.fill"
        case .off: "xmark"
        }
    }
}

// MARK: - レッスン

enum GuideChapter: String, Codable, CaseIterable, Identifiable {
    case preparation
    case operation
    case organization
    case numbers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preparation: "第1章 開業準備"
        case .operation: "第2章 仕入れと販売"
        case .organization: "第3章 人に任せる"
        case .numbers: "第4章 数字を読む"
        }
    }

    var shortTitle: String {
        switch self {
        case .preparation: "開業準備"
        case .operation: "仕入れと販売"
        case .organization: "人に任せる"
        case .numbers: "数字を読む"
        }
    }

    var icon: String {
        switch self {
        case .preparation: "map.fill"
        case .operation: "car.2.fill"
        case .organization: "person.3.fill"
        case .numbers: "chart.line.uptrend.xyaxis"
        }
    }
}

enum GuideLessonID: String, Codable, CaseIterable, Identifiable {
    case welcome
    case readCity
    case chooseLocation
    case planStore
    case stockInventory
    case sellCar
    case advanceWeek
    case readWeeklyReport
    case hireStaff
    case delegateWork
    case readProfitLoss
    case graduate

    var id: String { rawValue }
    var lesson: GuideLesson { GuideCurriculum.lesson(for: self) }
}

/// レッスンの達成条件。`acknowledge` はプレイヤーの「次へ」や対象画面の確認で、
/// それ以外はゲーム状態から自動判定します。
enum GuideGoal {
    case acknowledge
    case plotSelected
    case storeOpened
    case inventoryStocked
    case weekAdvanced
    case staffAssigned
    case automationEnabled
}

/// ガイドカードから提供する誘導ボタン。
enum GuideAction: Equatable {
    case focusRecommendedPlot
    case openChosenPlot
    case openStore(panel: GuideStorePanel)
    case openWeeklyReport
    case openProfitLossLesson

    var title: String {
        switch self {
        case .focusRecommendedPlot: "おすすめ候補を見る"
        case .openChosenPlot: "選んだ区画を開く"
        case .openStore(panel: .team): "店員タブを開く"
        case .openStore(panel: .finance): "店舗の経営タブを開く"
        case .openStore: "店舗を開く"
        case .openWeeklyReport: "週間レポートを開く"
        case .openProfitLossLesson: "PLの読み方を開く"
        }
    }

    var icon: String {
        switch self {
        case .focusRecommendedPlot: "scope"
        case .openChosenPlot: "mappin.and.ellipse"
        case .openStore: "storefront.fill"
        case .openWeeklyReport: "doc.text.fill"
        case .openProfitLossLesson: "yensign.circle.fill"
        }
    }
}

/// 店舗画面のタブ。`StoreCommandCenterView` の内部タブへ誘導するために使います。
enum GuideStorePanel: String, Codable, Equatable {
    case store
    case team
    case market
    case finance
}

struct GuideLesson: Identifiable {
    let id: GuideLessonID
    let chapter: GuideChapter
    let title: String
    /// ふきだしのページ。1ページずつ読み進めます。
    let speech: [String]
    let objective: String?
    let tip: String?
    let expression: GuideExpression
    let goal: GuideGoal
    let action: GuideAction?
    /// 要点モードでも案内するレッスンかどうか。
    let isEssential: Bool
}

// MARK: - カリキュラム

enum GuideCurriculum {
    static let all: [GuideLesson] = [
        GuideLesson(
            id: .welcome,
            chapter: .preparation,
            title: "はじめまして",
            speech: [
                "はじめまして。翠浜商工会の浜岡ナオです。中古車店の立ち上げを、最初のひと月だけご一緒します。",
                "1ターンは1週間。10年＝520週で会社をどこまで伸ばせるかが、このゲームの勝負です。",
                "やることの順番はシンプルです。土地を選ぶ → 店を建てる → 車を仕入れる → 売る → 数字を読む。まずはこれだけ覚えてください。"
            ],
            objective: "「次へ」で案内を進めてください。",
            tip: "このカードはドラッグで移動できます。地図が見づらいときは右上のボタンで透過・最小化してください。",
            expression: .smile,
            goal: .acknowledge,
            action: nil,
            isEssential: false
        ),
        GuideLesson(
            id: .readCity,
            chapter: .preparation,
            title: "街の見方",
            speech: [
                "ここが翠浜市です。6つの地区があり、人口・所得・交通量・競合の強さがそれぞれ違います。",
                "画面右上のレイヤーボタンで「需要」「競合」「地価」などの色分けに切り替えられます。土地を選ぶ前に、需要と競合は必ず見てください。",
                "建物をタップすると区画の詳細が開きます。自社店舗は緑、競合はオレンジで表示されます。"
            ],
            objective: "レイヤーを切り替えて、街の需要と競合を眺めてみてください。",
            tip: "地区名は「駅周辺」「一般住宅街」など。同じ車種でも、地区が変われば売れ方が変わります。",
            expression: .point,
            goal: .acknowledge,
            action: nil,
            isEssential: false
        ),
        GuideLesson(
            id: .chooseLocation,
            chapter: .preparation,
            title: "創業地を選ぶ",
            speech: [
                "では創業地を決めましょう。光っている区画が候補です。どこを選んでも構いません。",
                "見るのは4つ。①周辺人口と客層 ②交通量と視認性 ③月額賃料 ④近くの競合。家族向けなら住宅街、台数を売るなら幹線道路沿いが向いています。",
                "賃料が高い場所は、その分だけ客足も多い。「安いから」で選ぶと、在庫は売れないのに賃料だけ出ていきます。"
            ],
            objective: "マップで区画をタップして、創業地を決めてください。",
            tip: "区画詳細では、視認性・出入り・交通量の差と、近隣に競合がいるかを確認しましょう。",
            expression: .point,
            goal: .plotSelected,
            action: .focusRecommendedPlot,
            isEssential: true
        ),
        GuideLesson(
            id: .planStore,
            chapter: .preparation,
            title: "出店を計画する",
            speech: [
                "区画詳細から出店計画へ進みます。決めるのは3つ、取得方法・店舗タイプ・資金計画です。",
                "賃貸は初期費用が軽い代わりに毎月の賃料が続きます。購入は現金を使いますが、土地は担保になって融資枠が増えます。最初は賃貸で十分です。",
                "店舗タイプで展示台数と設備が変わります。足りない資金は融資でまかなえますが、借りすぎると利息が利益を削ります。"
            ],
            objective: "区画詳細から出店計画を開き、3ステップで契約してください。",
            tip: "取扱車種や客層の方針は、開店後にいつでも変更できます。",
            expression: .think,
            goal: .storeOpened,
            action: .openChosenPlot,
            isEssential: true
        ),
        GuideLesson(
            id: .stockInventory,
            chapter: .operation,
            title: "販売車を仕入れる",
            speech: [
                "開店おめでとうございます。ただし、店に車がなければ1台も売れません。次は仕入れです。",
                "仕入れは、店舗買取・下取り・翠浜オートオークション・社員専用ネットAA・法人一括が中心です。仕入担当には、最低仕入台数と0〜10%の粗利率条件を指定できます。",
                "地区需要の高い車種から仕入れてください。需要とずれた在庫は値引きしないと動かず、現金が在庫に固定されます。"
            ],
            objective: "店舗画面から車を仕入れてください。",
            tip: "在庫は資産ではなく「まだ現金に戻っていないお金」です。回転しない在庫ほど経営を圧迫します。",
            expression: .point,
            goal: .inventoryStocked,
            action: .openStore(panel: .store),
            isEssential: true
        ),
        GuideLesson(
            id: .sellCar,
            chapter: .operation,
            title: "お客様と商談する",
            speech: [
                "在庫が入りました。今週の来店客と商談しましょう。",
                "値引きは「成約率」と「粗利」のトレードオフです。値引きなしなら粗利は残りますが断られやすい。大幅値引きは売れますが利益が消えます。",
                "オーナーが自分で商談できるのは週7件まで。断られることもありますが、それが普通です。"
            ],
            objective: "店舗画面の「店頭販売」から1台選び、値引き幅を決めて商談してください。",
            tip: "商談前のプレビューで、成約率と見込み粗利を比べられます。",
            expression: .neutral,
            goal: .acknowledge,
            action: .openStore(panel: .store),
            isEssential: true
        ),
        GuideLesson(
            id: .advanceWeek,
            chapter: .operation,
            title: "1週間を進める",
            speech: [
                "方針が決まったら、画面右上の「1週間進める」です。仕入れ・価格・広告・社員の働きをまとめて計算します。",
                "進める前に、在庫・価格・広告を確認する癖をつけてください。1週間は戻せません。"
            ],
            objective: "ヘッダーの「1週間進める」を押してください。",
            tip: nil,
            expression: .neutral,
            goal: .weekAdvanced,
            action: nil,
            isEssential: false
        ),
        GuideLesson(
            id: .readWeeklyReport,
            chapter: .operation,
            title: "週間レポートを読む",
            speech: [
                "週間レポートが出ました。実はここが一番大事です。",
                "見る順番は、販売台数 → 売上高 → 売上総利益 → 営業利益。そのあとに「なぜこの結果になったか」の要因リストを確認します。",
                "平均在庫週数も見てください。12週を超えた在庫は、資金を止めている滞留在庫です。"
            ],
            objective: "週間レポートを開いて、結果と要因を確認してください。",
            tip: "要因リストは需要との相性・立地・広告・競合の影響を台数換算で示しています。",
            expression: .think,
            goal: .acknowledge,
            action: .openWeeklyReport,
            isEssential: true
        ),
        GuideLesson(
            id: .hireStaff,
            chapter: .organization,
            title: "店員を採用して任せる",
            speech: [
                "オーナー1人で対応できるのは週7件。街の客足はそれ以上あります。ここから先は人に任せます。",
                "店員の担当は「販売」「仕入」「調査」「整備」の4つ。担当を割り当てた店員は、オーナーとは別枠で週10件を自動で処理します。",
                "給料は毎週出ていきます。客足と在庫が増えてから採用するのが基本です。"
            ],
            objective: "店舗画面の「店員」タブで採用し、担当を割り当ててください。",
            tip: "販売担当は成約、仕入担当は買取と仕入れを担います。担当なしの店員は動きません。",
            expression: .point,
            goal: .staffAssigned,
            action: .openStore(panel: .team),
            isEssential: true
        ),
        GuideLesson(
            id: .delegateWork,
            chapter: .organization,
            title: "業務を自動運用にする",
            speech: [
                "担当を決めたら、経営タブで販売・市場調査・整備・仕入を「社員運用」にします。",
                "仕入担当は登録した「仕入れ指示」に沿って4経路を回ります。指示がなければ動きません。",
                "店長を採用して「店長運用」にすると、店舗方針を守りながら社員配置と作業順を調整します。"
            ],
            objective: "「経営」タブで、いずれかの業務を社員運用にしてください。",
            tip: "価格指示、広告予算、商品化目標品質は店舗方針です。店長運用でも勝手に変更されません。",
            expression: .smile,
            goal: .automationEnabled,
            action: .openStore(panel: .finance),
            isEssential: true
        ),
        GuideLesson(
            id: .readProfitLoss,
            chapter: .numbers,
            title: "PL（損益計算書）の見方",
            speech: [
                "最後はPL＝損益計算書の読み方です。会社が儲かっているかは、ここでしか分かりません。",
                "上から順に、売上高 −売上原価 ＝売上総利益（粗利）。粗利は「1台あたりいくら抜けたか」の合計です。",
                "粗利から人件費・賃料・広告費・固定費・減価償却・支払利息を引いたものが営業利益。ここが本業の成績です。",
                "赤字なら順番に疑ってください。粗利率が低いのか（値引きしすぎ・仕入れが高い）、台数が足りないのか、固定費が重いのか。"
            ],
            objective: "「PLの読み方」を開いて、いまの数字で確認してください。",
            tip: "現金とPLは別物です。黒字でも在庫を買いすぎれば現金は減ります。",
            expression: .think,
            goal: .acknowledge,
            action: .openProfitLossLesson,
            isEssential: true
        ),
        GuideLesson(
            id: .graduate,
            chapter: .numbers,
            title: "ここからは自由経営",
            speech: [
                "ここまでで基本は全部です。おつかれさまでした。",
                "あとは自由経営。2店舗目、全国展開、企業価値の最大化——好きに攻めてください。",
                "困ったら設定からいつでも呼び出してください。それでは、良いご商売を。"
            ],
            objective: nil,
            tip: "設定 →「ガイド」から、章を選んで復習できます。",
            expression: .cheer,
            goal: .acknowledge,
            action: nil,
            isEssential: true
        )
    ]

    static func lesson(for id: GuideLessonID) -> GuideLesson {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    static func lessons(for mode: GuideMode) -> [GuideLesson] {
        switch mode {
        case .full: all
        case .essentials: all.filter(\.isEssential)
        case .off: []
        }
    }
}

// MARK: - 進行状態

/// セーブデータへ載るガイドの進行状態。
struct GuideProgress: Codable, Equatable {
    var mode: GuideMode
    var currentLessonID: GuideLessonID?
    var completedLessons: Set<GuideLessonID>
    var acknowledgedLessons: Set<GuideLessonID>
    /// 開始時の「チュートリアルは必要ですか」に回答済みかどうか。
    var hasChosenMode: Bool
    /// 読み進めているふきだしのページ番号。
    var speechPage: Int

    init(
        mode: GuideMode = .full,
        currentLessonID: GuideLessonID? = .welcome,
        completedLessons: Set<GuideLessonID> = [],
        acknowledgedLessons: Set<GuideLessonID> = [],
        hasChosenMode: Bool = false,
        speechPage: Int = 0
    ) {
        self.mode = mode
        self.currentLessonID = currentLessonID
        self.completedLessons = completedLessons
        self.acknowledgedLessons = acknowledgedLessons
        self.hasChosenMode = hasChosenMode
        self.speechPage = speechPage
    }

    /// 案内を使わない状態（過去のセーブや「案内は不要」を選んだ場合）。
    static let dismissed = GuideProgress(
        mode: .off,
        currentLessonID: nil,
        hasChosenMode: true
    )

    var isRunning: Bool { mode != .off && currentLessonID != nil }

    var lessons: [GuideLesson] { GuideCurriculum.lessons(for: mode) }

    var currentLesson: GuideLesson? { currentLessonID.map { $0.lesson } }

    var stepNumber: Int {
        guard let currentLessonID,
              let index = lessons.firstIndex(where: { $0.id == currentLessonID }) else { return lessons.count }
        return index + 1
    }

    var totalSteps: Int { max(1, lessons.count) }

    var progress: Double {
        guard !lessons.isEmpty else { return 1 }
        return Double(completedLessons.intersection(lessons.map(\.id)).count) / Double(lessons.count)
    }

    func nextLessonID(after id: GuideLessonID) -> GuideLessonID? {
        guard let index = lessons.firstIndex(where: { $0.id == id }),
              lessons.indices.contains(index + 1) else { return nil }
        return lessons[index + 1].id
    }
}
