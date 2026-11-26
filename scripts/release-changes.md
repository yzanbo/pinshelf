## この版の主な変更（0.2.1-beta.1 から）

<!-- 出すたびに、この版の変更に書き直す（make publish が、リリースの説明の先頭に入れる） -->

### 新しく使えるようになったこと

- **空になった棚を閉じるか、残すかを選べるようにしました**：設定の「棚」→「空になった棚」で、画面の端の棚・浮いた棚のそれぞれについて選べます（初期設定は、どちらも閉じる）。ポインタが棚の上にあるうちは閉じず、離れたら閉じます（そのあいだは ⌘Z で戻せます）。お気に入りの棚は、空になっても残ります

### 直したこと

- 画面の端の棚で、最後の 1 個を外したあと、ポインタを棚の上に置いたまま ⌘Z で戻すと、ポインタが離れても帯にたたまれず、開いたまま残ることがあったのを直しました

### 変わったこと

- **浮いた棚も、空になったら閉じるようにしました**：これまでは、中身をすべて取り出しても空の棚のまま残っていました。前の動きに戻すときは、設定の「棚」→「浮いた棚が空になったら、閉じる」をオフにします
- 自分で画面の端にしまった棚も、空になったら閉じます（これまでは件数 0 の帯のまま残っていました）

**English:** New — Settings → Shelf → "Empty shelves" lets you choose whether an emptied shelf closes, separately for screen-edge shelves and floating shelves (both close by default). A shelf stays open while the pointer is over it, so you can still undo with ⌘Z; favorites are always kept. Fixed — an edge shelf could stay open after undoing the removal of its last item. Changed — floating shelves (and shelves you docked to the screen edge yourself) now close when they become empty; turn the setting off to keep them.
