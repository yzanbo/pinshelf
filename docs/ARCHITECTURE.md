# コードの構成

```
Pinshelf/
├── App/            起動と、アプリ全体に関わるもの
│   ├── AppDelegate           起動・メニューバーのアイコンとメニューのつなぎ・終了の合図（killall）を受けて保存してから終わる
│   ├── AppCoordinator(+◯◯)  ドラッグの検出と棚をつなぐ本体。+Drag はドラッグに合わせて棚を出す（画面の端・振る・キー）、
│   │                         +Persistence は保存と復元、+Inbox はメニューバー・クリップボードから入れる、+ShelfLists はお気に入り・最近閉じた棚
│   ├── StatusItemController  メニューバーのアイコン（落とすと棚に入れる）とメニュー。新しい版があるときの印も出す
│   ├── SparkleUpdater        更新（Sparkle）。新しい版を確かめる・知らせる・入れ替える。Sparkle を読み込むのは、このファイルだけ
│   ├── HotKey                どこからでも使えるショートカット（Carbon の RegisterEventHotKey。アクセシビリティの権限は要らない）
│   ├── DockIcon・MainMenu    設定・お気に入り一覧・更新の画面を開いている間だけ Dock と上のメニューバーに出す、そのときのアプリのメニュー
│   ├── AppIcon               アプリのアイコンと 1 色の印。アイコンを出すところは、すべてここから使う
│   └── AppInfo               記録（Logger の subsystem）と、版・ビルド番号の読み出し
├── Monitoring/
│   └── DragMonitor           ほかのアプリで始まったドラッグも含めて、ドラッグの始まり・動き・終わりを見つける（権限なし）
├── Shelf/          棚
│   ├── Model/
│   │   ├── ShelfModel                画面に出す 1 つの棚の中身（選び方・ロック・スタック・元に戻す・ブックマーク）
│   │   ├── ShelfContentReaders       ドラッグのペーストボードから、棚に入れる中身を読む
│   │   ├── ClipboardImporter         クリップボードの中身を、棚に入れる形にする（画像は PNG のファイルにする）
│   │   └── ShelfItemContent+App      中身の名前・アイコン・開き方
│   ├── Windows/
│   │   ├── ShelfController(+◯◯)     棚 1 つ（浮いた棚も画面の端の棚も同じ）。+Docking は画面の端にしまう・たたむ・開く、
│   │   │                             +Resizing は縁で大きさを変える・標準の大きさ、+Identity は名前・色・お気に入りと保存の形式、
│   │   │                             +EmptyShelf は空になった棚を閉じる（設定の「空になった棚」）
│   │   ├── ShelfState                棚の見え方（置き方・名前・色・大きさなど。ShelfView が描く）
│   │   ├── ShelfPanel・ShelfHostingView  棚のウィンドウ（前面のアプリからフォーカスを奪わない）と、ポインタの動きを受ける中身のビュー
│   │   ├── EdgeShelfDriver           画面の端の棚を、ドラッグに合わせて出す
│   │   ├── PointerLeaveWatcher       開いた棚からポインタが離れたら、すぐに知らせる（帯にたたむため）
│   │   ├── WindowMoveTracker         棚のウィンドウをアニメーションで動かす・利用者が運び終えたのを見分ける
│   │   └── NSScreen+Containing       点のある画面を探す
│   ├── Views/
│   │   ├── ShelfView・ShelfHeader・ShelfMenu  棚・見出し（閉じる・しまう・お気に入りの ★・名前・元に戻す・…・ピン・たたむ）・見出しのメニュー
│   │   ├── ShelfItemsView・ShelfUnitTile      中身の一覧（空なら案内）と、1 つ分（またはスタック）
│   │   ├── EdgeTab                   画面の端の棚をたたんだときの、細い帯（件数を出す）
│   │   ├── ResizeHandles             大きさを変える縁と、光る縁
│   │   ├── ShelfMotion               ウィンドウの枠のアニメーションと、SwiftUI の中身のアニメーションをそろえる決まり
│   │   └── ShelfColor+UI             棚の色の表示名・色・メニューの丸
│   └── Interaction/
│       ├── ShelfInteraction          棚のウィンドウでの操作（Quick Look・キー操作・取り出し）をまとめてつなぐ
│       ├── ShelfKeyboard             棚のキー操作（⌘A・⌘V・⌘Z・⌘L・矢印・delete など）
│       ├── ShelfQuickLook            Quick Look のパネルに、棚で選んでいるものを見せる
│       ├── ShelfDragSource           棚から外へドラッグで取り出す（Finder と同じ移動・コピーの決まり）
│       └── ShelfDropDelegate         棚に落とされたものを受け取る（棚から棚へ移すときは、移す元と中身を伝える）
├── Favorites/      お気に入り一覧
│   ├── FavoritesWindowController・FavoritesListView  お気に入り一覧のウィンドウと、その中身（出す・お気に入りから削除）
│   └── FavoriteShelvesList   一覧に出すお気に入りの棚（棚が変わるたびに読み直す）
├── Settings/       設定画面
│   ├── SettingsWindowController  設定のウィンドウ（ツールバーのタブ）
│   ├── GeneralSettingsView・TriggerSettingsView・ShelfSettingsView・ContentsSettingsView・IgnoredAppsSettingsView
│   │                             タブごとの中身（一般・出し方・棚・中身・除外するアプリ）
│   └── SettingsComponents・SettingsLabels  設定の共通の部品（ⓘ の説明など）と、選択肢の表示名
├── Persistence/
│   └── ShelfPersistence      棚の中身をファイルに保存する（少し待ってまとめて保存）・起動時に読み込む
└── Assets.xcassets         アプリのアイコンと 1 色の印（make icon で書き出す。手で直さない）

PinshelfCore/       画面に依存しないロジック（Swift パッケージ。アプリには静的ライブラリとして組み込む。テストはここ）
├── ShakeDetector・ModifierTrigger・TriggerSettings  シェイクの判定・ドラッグ中に押すキー・棚の出し方の設定
├── EdgeGeometry・DockLayout   画面の端の帯と棚の位置・浮いた棚をしまうときの位置
├── Shelf・ShelfSelection      棚の中身（追加・重複・ロック・スタック・取り出したあとの扱い・元に戻す）と選び方
├── ShelfIdentity              棚の名前・色・お気に入りの仮の名前
├── ShelfSizing・ShelfGridLayout  棚の大きさ（縁でつかむところ・最小と最大・標準の大きさ）と、中身の列の数
├── ShelfSnapshot・ShelfSnapshotStore・BookmarkCoding  保存の形式（前の形式からの移し替えも）・JSON の読み書き・ブックマーク
├── ShelfBehavior・Clipboard   入れる棚・取り出したあとの扱いなどの設定、クリップボードのショートカット
├── LaunchAtLogin              ログイン時に起動（SMAppService）
├── AppUpdates                 更新の状態（使えるか・自動で確かめるか・知らせる新しい版）。更新そのものは AppUpdateService（アプリでは SparkleUpdater）が受け持つ
└── AppVersion                 版の見せ方（1.0.0 より前は β 版）

scripts/
├── make-app-icon.swift      アプリのアイコンと 1 色の印をコードで描いて、Assets.xcassets に書き出す（make icon）
├── create-dev-cert.sh       開発用の署名の証明書「Pinshelf Dev」を作る（make cert）
├── update-key.sh            更新ファイルの署名の鍵（EdDSA）を用意して、公開鍵を project.yml に書き込む（make update-key）
├── make-appcast.sh          更新ファイル（zip）に署名して、版の一覧（appcast.xml）を作る（make publish・make update-test）
├── publish-check.sh         公開の前に、鍵と Git の状態を確かめる（make publish）
├── update-test.sh           更新を手元で通しで試す準備をする（make update-test。update-test-key.swift は、その試験用の鍵を作る）
├── update-test-log.sh       更新の試験のあいだの macOS の記録を書き出す（make update-test-log）
├── readme-images/           README の見本の画像を作る（make readme-images。棚・帯はアプリと同じ部品で実際に出して写し、架空のデスクトップに並べる）
└── release-*.md             リリースの説明（β 版の注意・この版の変更・ダウンロードと開き方。make publish がつなげる）

appcast.xml         版の一覧（入れてもらったアプリが、ここを見て新しい版を知る。make publish が作り直す）
Vendor/Sparkle/     更新の仕組み（Sparkle）の配布物。make が取り寄せるので、リポジトリには入れない
project.yml         XcodeGen の設定（Pinshelf.xcodeproj はここから作るので、リポジトリには入れない）
Makefile            ビルド・起動・テスト・インストール・配布（README の「開発するとき」）
```

## 設計のメモ

### 棚はどれも同じ

- 浮いた棚も、画面の端の棚も、画面の端にしまった棚も、同じ `ShelfController` 1 つで扱う。違うのは置き方（`ShelfState.placement`）だけ
- 画面の端の棚は、`EdgeShelfDriver` がドラッグを始めたときに作って画面の端にしまうだけで、出たあとは、真ん中で作って画面の端にしまった棚とまったく同じに動く（運んだ場所にとどまる・帯の近くに来たら開く）
- 画面の端にしまった棚がすでにあれば、新しい画面の端の棚は作らない。振る・キーで出す棚は、いつも新しく開く

### ドラッグの見つけ方（権限なし）

アクセシビリティの権限を使わずに、ほかのアプリで始まったドラッグを見つける（`DragMonitor`）。

- マウスのボタンが押されたら（グローバルのイベント監視）、ドラッグ用のペーストボードの `changeCount` を覚え、ボタンが離されるまで位置を調べ続ける（60 回/秒）
- 押している間に `changeCount` が変わったら、何かがドラッグされ始めたと見なす
- 修飾キーで出すときは、押しているキーを調べるだけで、キーの入力は監視しない

### 画面の端の帯にたたむ

- ポインタが離れたらすぐにたたむ（`PointerLeaveWatcher`）。「ポインタが外へ出た」の知らせでその場で確かめ、知らせが届かないときのために 0.08 秒おきにも位置を調べる。棚の縁から 2pt までは棚の上とみなす
- メニュー・Quick Look・名前の入力・大きさの変更の間と、マウスのボタンを押している間（見出しをつかんで運んでいる・中身を取り出している）は、たたまない。ボタンを放したときに離れていれば、そこでたたむ

### 縁で大きさを変える

- つかめる範囲・大きさ・変えられる向きの計算は `PinshelfCore` の `ShelfSizing`。辺は 7pt、角は 12pt。角丸の外の透明なところもクリックを素通りさせない（角をつかめるように）
- macOS は、前面にないアプリがポインタの形を変えるのを許さない。そのため、ポインタの形が変わるのは棚がキーウィンドウのときだけで、ふだんは縁を光らせて見分ける（棚をキーにすると、キーボードの入力が棚に移ってしまうので、しない）
- 棚が開くアニメーションの途中でつかんでも、アニメーションに上書きされない（枠を変えるときは、長さ 0 のアニメーションで前のアニメーションを止める）
- 中身の列の数は、棚の横幅で決める（`ShelfGridLayout`）。中身が増えてスクロールバーが出ても、列は減らない

### 動き

- ウィンドウの枠の動き（`WindowMoveTracker`）と中身の動き（SwiftUI）は、同じ長さ・同じ速さの変わり方にそろえる（`ShelfMotion`）
- 帯にたたむときは、たたむとき用の速さの変わり方にする（`ShelfMotion.foldTimingFunction`。すぐに動き出し、少しだけ勢いをつけてから、画面の端に向かってなめらかに止まる）。開くときと同じ変わり方だと、はじめの 2 コマほどで半分以上縮み、棚が一瞬で消えたように見える。開くときを逆に再生すると、長く動かないあと最後の一瞬で一気にしまわれる。どちらも試して不自然だったので、分けた
- たたむときの棚と帯の入れ替わり（透明度）は、枠より遅らせる（`ShelfMotion.foldFadeAnimation`）。棚が端へ滑り込んでいる間は見えたままにし、端に近づくにつれて帯に入れ替える（枠と同じ速さで消すと、滑り込む動きが見える前に棚が消えてしまう）
- 帯と棚の切り替えは、どちらも出来上がりの大きさのまま置き、縮む・広がるウィンドウの枠で切り抜く。棚は画面の端と反対の側に寄せる（枠の内側の辺と一緒に動き、引き出しのように端へ滑り込む・端から滑り出る）。帯は画面の端の側に寄せる（枠が縮み切る前から画面の端に付いている）
- 帯と棚は、出す・消す（transition）ではなく、いつも置いたまま透明度で入れ替える（`ShelfView`）。SwiftUI は消えていく途中の部品の置き場所を消え始めたときのまま固定するので、transition だと枠が動いても寄せる位置についてこず、ウィンドウの左上に貼り付いたまま画面の端から離れて見えるため。見えていない側は、クリックを受けず（`allowsHitTesting`）、帯にたたんでいる間は棚の中身もつかまない（`ShelfInteraction.canGrabItems`）
- 消している途中で出し直したら、消すのをやめてその場から出し直す。「視差効果を減らす」がオンなら、短いフェードだけにする

### 保存

- 棚の中身は `~/Library/Containers/app.pinshelf.Pinshelf/Data/Library/Application Support/Pinshelf/shelves.json` に保存する（サンドボックスのコンテナの中）
- ファイルは security-scoped bookmark で覚えるので、再起動後も開け、移動・名前の変更にも追従する。ドロップで受け取ったファイルには今だけアクセスできるので、受け取ったらすぐブックマークにする
- 中身が変わったら 0.5 秒後にまとめて保存し、終了するときにも保存する。`make run`・`make stop` の `killall`（SIGTERM）も受けて、ふつうに終了する
- 保存ファイルが壊れていたら `shelves.broken-<時刻>.json` に移して、空の状態で始める
- 前の形式（画面の端の棚を別に保存していた・ピン留めと呼んでいた・大きさを配列で保存していた）で保存したものは、起動したときに今の形式に移す。保存のキーの名前は、前のまま残している
- 使い続けても容量が増え続けないよう、Pinshelf が自分で作るファイルは、どれも決まった基準で消す（棚に置いた元のファイルは消さない）
  - 最近閉じた棚: 10 個まで。古いものから一覧と保存ファイルから外す
  - クリップボードから入れた画像（`Pinshelf/Clipboard/` の PNG）: どの棚にも（最近閉じた棚・⌘Z で戻せる分にも）使わなくなったら、完全に消す（ゴミ箱には入れない）。棚が変わるたびに 2 秒待ってまとめて片付け、起動したときにも片付ける。書き出してから棚に置くまでの間に消さないよう、入れたばかりの画像は 1 分残し、そのあとでもう一度片付ける（`ClipboardFiles.cleanUpPlan`）
  - Quick Look でテキストを見るための一時ファイル（一時フォルダの `Pinshelf-QuickLook`）: 棚から外したテキストの分は次に選ぶ・見るときに、閉じた棚の分は閉じたときに消す。起動したとき・終了するときに、フォルダごと消す
  - 読めなかった保存ファイルの控え（`shelves.broken-<時刻>.json`）: 新しいものから 3 つだけ残す（`ShelfSnapshotStore.removeOldUnreadableFiles`）
  - 元に戻す（⌘Z）は、メモリの中だけ（棚ごとに 20 回分）。設定（UserDefaults）は決まった項目だけで、増え続けない

### メニューバー

- SwiftUI の `MenuBarExtra` はドロップを受けられないので、アイコンは AppKit の `NSStatusItem` で作る。あわせて、設定画面も自前のウィンドウで開く（メニューバー常駐のアプリで、設定画面が後ろに隠れないように）
- メニューの項目には右クリックのメニューを付けられないので、お気に入りの削除は「お気に入りから削除 ▸」の中から棚を選ぶ形にしている（右クリックで選ばれたことを見分けて小さなメニューを出す形も試したが、メニューが一度閉じてから出し直すため使いにくく、やめた）
- お気に入りから削除した棚は、出していればふつうの棚として残し、閉じて隠していれば閉じる（「最近閉じた棚」に入る）

### Dock と上のメニューバー

- ふだんはメニューバーだけに常駐し（`LSUIElement`）、設定・お気に入り一覧のウィンドウを開いている間だけ Dock に出す（`DockIcon`。Pinshot と同じ作り）。棚は重ねて出す部品なので、開いていても Dock には出さない
- 更新の画面は Sparkle のウィンドウで、開け閉めを自分では知れないので、確かめ始めてから確かめ終えるまで、名前付きの印で Dock に出しておく（`DockIcon.hold`・`release`）
- Dock に出ている間は、上のメニューバーに Pinshelf のメニュー（設定…・終了・編集・ウインドウを閉じる）が出る（`MainMenu`）。編集メニューがあるので、文字の欄でも ⌘C・⌘V・⌘A・⌘Z が効く
- 棚の ⌘A・⌘V・⌘Z などは、棚がメニューより先に受け取る（`ShelfPanel.performKeyEquivalent`。macOS は ⌘ の付いたキーを、キーウィンドウ → メニューの順に渡すため）
- 棚をクリックした直後の ⌘Q では終了しない（上のメニューバーには前のアプリが出ていて、そのアプリを終了するつもりで押すことが多いため。Pinshot と同じ）

### アイコン

- アプリのアイコンは、トレーに入れたカードを赤いピンで留めた絵（Pin + Shelf）。作りは Pinshot のアイコンにそろえ（白いものを赤いピンで留める）、背景の色（Pinshot は青、Pinshelf はオレンジ）で見分ける
- `scripts/make-app-icon.swift` がコードで描き、`make icon` で書き出す。色付きのアイコン（`AppIcon`。16〜1024 px の PNG）と、同じ絵を 1 色にした印（`AppSymbol`。PDF のテンプレート画像。メニューバー・画面の端の帯・空の棚）の 2 つ
- 1 色の印は、重なるところにすき間を空ける。カードは色付きのアイコンよりトレーから大きく出し（出ている分が少ないと、ただの箱に見える）、ピンはカードの内側に置く（上の辺からはみ出すと、人の頭に見える）
- メニューバーだけのときに設定したアイコンは、Dock に出たときに使われず、macOS が覚えている仮のアイコンで出ることがあるので、Dock に出すたびに設定し直す（`AppIcon.applyToApp`）。`make run`・`make install` は、起動の前にアプリを Launch Services に登録し直す（`lsregister -f`）

### ショートカットとログイン時に起動

- 「クリップボードから棚へ」のショートカットは、Carbon の `RegisterEventHotKey` で登録する（アクセシビリティの権限は要らない。Pinshot と同じ作り）。⌘⇧V は多くのアプリで「スタイルを合わせて貼り付け」なので、選べるものから外した
- ログイン時に起動は、`SMAppService` でアプリ自身をログイン項目に登録する（サンドボックスのままで使える）。利用者が選ぶまで登録しない（App Store の決まりに合わせる）
- システム設定の「ログイン項目」でも変えられるので、状態は保存せず、設定画面を開くたびに macOS に問い合わせる
- アプリの場所で登録するので、ふだん使うときは `make install` で `/Applications` に入れ、そのアプリで入れる（開発中の `build/` のアプリで入れると、そのアプリが起動する）

### 署名

- macOS は、アプリが同じものかを署名で見分ける。アドホック署名は、ビルドし直すたびに署名が変わる。`make cert` で作る自己署名の証明書「Pinshelf Dev」で署名すると、ビルドし直しても同じ署名になる（Pinshot と同じ作り）。ただし Pinshelf では、アドホック署名のままでも、棚のファイルのブックマーク・サンドボックスの保存場所・「ログイン時に起動」は引き継がれた（macOS 27.0.1 で確かめた。下の「更新」）
- Debug ではアプリのコードを `Pinshelf.debug.dylib` に分けて読み込むので、自前の証明書でも読み込めるよう、Debug だけ Hardened Runtime を切っている
- PinshelfCore は、埋め込むフレームワークにすると自前の証明書で署名したときに読み込みを断られることがあるので、静的ライブラリにしている
- 配る版（`make dist`）は、いつもアドホック署名。Apple の公証は受けていない
- 配る版（Release）には、デバッガをつなぐための許可（`get-task-allow`）を入れない（`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`。何もしないと、Xcode がビルドのときに足す）

### 更新

Developer ID に登録しない前提で、[Sparkle](https://sparkle-project.org) 2 を使う。検討の経緯と根拠は、ノート「更新の仕組みの方針」にまとめてある。

- **取り込み方**: 公式の配布物（`Sparkle.framework` と道具）を `make` が取り寄せ、決めてある SHA-256 と合うことを確かめて `Vendor/Sparkle` に置く。Swift パッケージにしないのは、取り寄せる版と中身を固定し、道具（`generate_appcast` など）も同じ配布物から使うため。Sparkle の版を上げるときは、`Makefile` の `SPARKLE_VERSION` と `SPARKLE_SHA256` を一緒に変える
- **本物かの確かめ**: 更新ファイル（zip）は、作者の EdDSA の鍵で署名する。アプリには公開鍵（`SUPublicEDKey`）を入れ、Sparkle が署名を確かめてから入れ替える。Apple の署名（アドホック）は版ごとに変わるので、確かめには使えない。公開鍵の入っていないビルドでは、更新の機能を出さない（`SparkleUpdater.start` が nil を返す）
- **「このまま開く」が要らない理由**: Sparkle が自分でダウンロードして確かめた版からは、ダウンロードのしるし（quarantine）を外す。だから、更新で入れた版は Gatekeeper に止められない（初めて入れるときは、ブラウザで落とした DMG にしるしが付くので、1 回要る）
- **サンドボックス**: サンドボックスの中からは自分を入れ替えられないので、Sparkle の入れ替え役（XPC サービス。`SUEnableInstallerLauncherService`）に任せ、それと通信する許可（`mach-lookup` の例外）を足している。ネット接続の許可（`network.client`）は、確認とダウンロードのため
- **ライブラリの検証**: Team ID のない署名（アドホック・自己署名）では、Hardened Runtime のままだと、埋め込んだ Sparkle の読み込みを断られる。`cs.disable-library-validation` で検証を切っている（切らないと、起動で落ちる）
- **知らせ方**: メニューバーに常駐するアプリなので、自動で見つけた新しい版は画面に割り込ませず、アイコンの印とメニューで知らせる（Sparkle の「控えめな知らせ」の作法。`standardUserDriverShouldHandleShowingScheduledUpdate` で、いつも自分で受け持つ）。メニューから選ぶと、Sparkle の更新の画面が前面に出る
- **画面の側との分け方**: Sparkle を読み込むのは `SparkleUpdater` だけ。メニューと設定は、`PinshelfCore` の `AppUpdates`（状態）を通して使う。Sparkle なしでアプリのコードをビルドする `make readme-images` と、テストのため
- **版の一覧**: `appcast.xml` をリポジトリの main に置き、アプリは `raw.githubusercontent.com` から読む（β 版は GitHub の「最新の版」に出ないので、Releases の latest は使えない）。載せるのは、いちばん新しい版だけ。この版の変更（`scripts/release-changes.md`）を、Markdown のまま埋め込む
- **版の比べ方**: Sparkle は `CFBundleVersion`（ビルド番号）で新旧を比べる。出すたびに必ず上げる
- **配る版の署名**: Pinshelf は許可（画面収録など）を使わないので、アドホック署名のまま配る。macOS 14 以降は、サンドボックスの保存場所もアプリの署名にひも付き、署名の違う版が開くと macOS が利用者に確認する（Apple の資料）。アドホック署名は版ごとに署名が変わるが、macOS はアドホック署名のアプリの保存場所の持ち主を「アプリの ID・署名者なし」と覚えるので（`secinitd` の記録の `signer:none`）、アドホック署名どうしなら、版が変わっても同じ持ち主として扱われる。通しの試験（macOS 27.0.1）で、確認が出ないこと、棚のファイルと「ログイン時に起動」が引き継がれることを確かめた。macOS の版が上がって変わったときは、決まった自己署名の証明書での署名に変える（`make update-test` と `make update-test-log` で確かめる）
- **記録**: 起動のたびに、版・「ログイン時に起動」の状態（`AppDelegate`）と、棚のファイルをどう戻せたか（ブックマークで・パスで・見つからず。`ShelfPersistence`）を、macOS の記録に 1 行ずつ残す。入れ替えのあとに引き継がれたかを、あとから確かめられる
- **ライセンス**: Sparkle のライセンス（MIT など）は、配るものに全文を含める決まり。`Pinshelf/Licenses/Sparkle.txt` として同梱する（`make` が、取り寄せた配布物から写す）

### 版とリリース

Pinshot と同じ決まりにしている。

- 版は `project.yml` の `CFBundleShortVersionString` と、ビルド番号 `CFBundleVersion` で決める。`make dist`・`make publish` も、ここから版を読む
- 1.0.0 より前は β 版。設定画面の版にも「（β 版）」と出る。正式版は 1.0.0 にする
- 出すたびに、版とビルド番号を上げ、`scripts/release-changes.md`（この版の変更）を書き直す
- `make publish BETA=1` で β 版としてプレリリースにする（タグは `v<版>-beta.1`。説明の先頭に `scripts/release-notes-beta.md` の注意が付く）。正式版は `BETA` を付けずに `make publish`
- リリースの説明は「この版の変更」＋「ダウンロードと開き方」（`scripts/release-notes.md`）をつなげたもの。`make publish` は GitHub CLI（`gh`）で Release を作る
- `make publish` は、Release を作る前に zip に署名して `appcast.xml` を作り直し、Release を作ったあと、`appcast.xml` だけをコミットしてプッシュする。先に、鍵がそろっているか・コミット済みで GitHub の main と同じかを確かめ、そろっていなければ何も作らずに止まる（`scripts/publish-check.sh`）
- 更新ファイルの署名の鍵（EdDSA）は、`make update-key` で一度だけ作る。秘密鍵はログインキーチェーンに入り、公開鍵を `project.yml` に書き込む。鍵は Pin シリーズで共通に使える。失くすと更新を届けられなくなるので、控え（`generate_keys -x`）を安全な場所に保管する
- DMG は、使える macOS では `diskutil image create` で作る（`hdiutil create` は macOS 26 で「使わなくなる」と警告が出るため）

### 言葉と見せ方の決まり

- 「お気に入り」（★）は、前は「ピン留め」と呼んでいたが、見出しのピン（画面の端で開いたままにする）と紛らわしいので改めた
- 見出しの ★ は、お気に入りかどうかがすぐ分かるよう、いつも出して、押すと切り替わるボタンにしている。名前の横ではなく左のボタンの並びに置くのは、いちばん狭い画面の端の棚（幅 150。元に戻すボタンも出ているとき）でも、ほかのボタンに重ならないようにするため。名前を置く場所が 16pt より狭いときは、名前（件数）を出さない
- 棚のメニューは、この棚のこと → 大きさ → すべての棚に効く設定 → 窓の操作、の順に並べ、まとまりごとに区切り線を入れる。サブメニューにするのは、選ぶものが多い「色」だけ。お気に入り・開いたままは、文言を変えずに ✓ の付く項目にする
- 「画面の端にしまう」（今この棚をしまう）と紛らわしくならないよう、すべての棚の設定は「画面の端まで運んだら、自動でしまう」とし、「すべての棚」の見出しの下にまとめる
- 設定画面では、スイッチの下に今の状態を言い直すだけの説明は置かない（説明は ⓘ の中）。選択肢の意味が分かりにくい項目にだけ、選んだものの説明を出す
- 設定画面のタブの絵は、項目の種類を表すものなので SF Symbol のまま。アプリを表すところ（メニューバー・帯・空の棚）は、アプリの印を使う

## テスト

- `make test`（または Xcode の ⌘U）で、`PinshelfCore` のテストを流す（シェイクの判定・棚の位置・棚の中身と選び方・保存の形式と移し替え・設定・大きさ・版の見せ方など）
- 画面の操作は、[TESTING.md](TESTING.md) の一覧で手で確かめる
