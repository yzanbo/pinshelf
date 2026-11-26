## この版の主な変更（0.2.0-beta.1 から）

<!-- 出すたびに、この版の変更に書き直す（make publish が、リリースの説明の先頭に入れる） -->

### 直したこと

- **狭い画面の端の棚で、角が四角く切れることがあったのを直しました**：中身をほかへ取り出したあと（見出しに元に戻すボタンが出たとき）に、棚が枠より広く描かれ、角丸の角と右端のボタンが欠けていました。見出しのボタンが入りきらないときは、浮かせるボタンを省きます（見出しのダブルクリック・… のメニューでも浮かせられます）
- **空になった画面の端の棚が残ることがあったのを直しました**：中身をほかのアプリへ移して空になったときに、件数 0 の帯が残ることがありました。空になった画面の端の棚は、帯にたたんでいてもすぐに閉じます。ピンで開いたままにしている棚も、空になったら閉じます（ポインタが棚の上にあるうちは閉じず、離れたら閉じます。お気に入りの棚は残ります）

### 変わったこと

- **押せるボタンに、ポインタを乗せると指の形になるようにしました**：棚の見出しのボタンと、中身にポインタを乗せたときに出るボタン（外す・スタックを分ける）です。macOS の決まりで、棚を一度押したあとに効きます

**English:** Fixed — on the narrowest screen-edge shelf, the rounded corners and the rightmost header button could be cut off after dragging an item out (when the undo button appeared); the float button is now hidden when the header is too narrow. An emptied screen-edge shelf no longer leaves a "0" tab behind, and pinned (keep-open) edge shelves now close when they become empty (favorites stay). Changed — clickable buttons on the shelf show the pointing-hand cursor (after the shelf has been clicked once).
