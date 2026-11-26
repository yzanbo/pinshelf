## この版の主な変更（0.2.1-beta.1 から）

<!-- 出すたびに、この版の変更に書き直す（make publish が、リリースの説明の先頭に入れる） -->

### 新しく使えるようになったこと

- **アプリの中から更新できるようにしました**：新しい版を 1 日に 1 回確かめ、見つけると、メニューバーのアイコンに小さな丸を付けて、メニューのいちばん上で知らせます（画面には割り込みません）。メニューの「アップデートを確認…」からも確かめられ、そのまま入れ替えられます。更新のときは、「このまま開く」は要りません。**この版へは、これまでどおりダウンロードして入れ替えてください**（0.2.1 までの版には、この機能がないため）。次の版からは、アプリの中から更新できます
- **空になった棚を閉じるか、残すかを選べるようにしました**：設定の「棚」→「空になった棚」で、画面の端の棚・浮いた棚のそれぞれについて選べます（初期設定は、どちらも閉じる）。ポインタが棚の上にあるうちは閉じず、離れたら閉じます（そのあいだは ⌘Z で戻せます）。お気に入りの棚は、空になっても残ります

### 直したこと

- 画面の端の棚で、最後の 1 個を外したあと、ポインタを棚の上に置いたまま ⌘Z で戻すと、ポインタが離れても帯にたたまれず、開いたまま残ることがあったのを直しました

### 変わったこと

- **ネットワークに接続するようになりました**：新しい版の確認と、その更新のダウンロードのときだけ、GitHub に接続します。棚の中身や使い方は送りません。自動の確認は、設定の「一般」→「新しい版を自動で確かめる」で止められます
- 配る版から、デバッガをつなぐための許可（`get-task-allow`）を外しました
- **浮いた棚も、空になったら閉じるようにしました**：これまでは、中身をすべて取り出しても空の棚のまま残っていました。前の動きに戻すときは、設定の「棚」→「浮いた棚が空になったら、閉じる」をオフにします
- 自分で画面の端にしまった棚も、空になったら閉じます（これまでは件数 0 の帯のまま残っていました）

**English:** New — Pinshelf can now update itself: it checks GitHub once a day, shows a dot on the menu bar icon when a new version is found (no window pops up), and installs it from the menu ("アップデートを確認…"). Updates are verified with the author's EdDSA signature. This version still needs a manual install; later versions update in-app. The app now connects to GitHub only for these update checks and downloads. Settings → Shelf → "Empty shelves" lets you choose whether an emptied shelf closes, separately for screen-edge shelves and floating shelves (both close by default). A shelf stays open while the pointer is over it, so you can still undo with ⌘Z; favorites are always kept. Fixed — an edge shelf could stay open after undoing the removal of its last item. Changed — floating shelves (and shelves you docked to the screen edge yourself) now close when they become empty; turn the setting off to keep them.
