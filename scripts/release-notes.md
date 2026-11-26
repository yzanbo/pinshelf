## ダウンロードと開き方

1. 下の `Pinshelf-<版>.dmg` をダウンロードして開き、`Pinshelf` を `Applications`（アプリケーションフォルダ）へドラッグします（`.zip` は展開して `Pinshelf.app` を入れる形です。中身は同じ）
2. Pinshelf を開くと「開発元を確認できない」と止められます（Apple の公証を受けていないため）。次のどちらかで開けます
   - システム設定 →「プライバシーとセキュリティ」の下の方にある「このまま開く」を押す
   - ターミナルで `xattr -dr com.apple.quarantine /Applications/Pinshelf.app` を実行してから開く
3. メニューバーに Pinshelf のアイコンが出ます。ファイルをドラッグし始めると、画面の端に棚が出ます（出し方は、メニューバーの「設定…」で変えられます）

入れたあとは、アプリの中から新しい版に更新できます（メニューバーのアイコン →「アップデートを確認…」。自動でも確かめます）。更新のときは、手順 2 は要りません。0.2.1 までの版から上げるときだけ、もう一度ここからダウンロードして入れ替えてください。

macOS 26 以降が必要です。ほかの権限（アクセシビリティなど）は求めません。

ソースからビルドする方法は [README](https://github.com/yzanbo/pinshelf#readme) を見てください。

---

**English:** Requires macOS 26 or later. Download the dmg (or zip), drag `Pinshelf.app` to Applications, then allow it in System Settings → Privacy & Security ("Open Anyway"), or run `xattr -dr com.apple.quarantine /Applications/Pinshelf.app`. The app is ad-hoc signed and not notarized. Once installed, it updates itself from the menu bar ("アップデートを確認…"); versions up to 0.2.1 need one more manual install.
