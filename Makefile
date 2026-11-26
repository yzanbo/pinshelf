DERIVED_DATA := build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/Pinshelf.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/Pinshelf.app
# アプリの識別名（Launch Services に、まだ動いていると思われていないかを調べるのに使う）
BUNDLE_ID := app.pinshelf.Pinshelf
# make install で入れる場所
INSTALL_DIR ?= /Applications
# アプリの版（project.yml の CFBundleShortVersionString）。1.0.0 より前は β 版
VERSION := $(shell sed -n 's/.*CFBundleShortVersionString: *"\(.*\)"/\1/p' project.yml)
# β 版として出すときは BETA=1 のように番号を渡す（タグは v0.1.0-beta.1、GitHub ではプレリリースにする）
BETA ?=
RELEASE_NAME := $(VERSION)$(if $(BETA),-beta.$(BETA))
DIST_BASE := dist/Pinshelf-$(RELEASE_NAME)
DIST_ZIP := $(DIST_BASE).zip
DIST_DMG := $(DIST_BASE).dmg

# 「Pinshelf Dev」の証明書があればそれで署名する（なければその場の署名＝アドホック署名）。
# 毎回同じ証明書で署名すると、ビルドし直しても同じ署名になる（make cert で一度だけ作る。なくても困らない: docs/ARCHITECTURE.md の「署名」）
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q '"Pinshelf Dev"' && echo "Pinshelf Dev" || echo "-")
# Launch Services（アプリの場所とアイコンを覚えている macOS の仕組み）に、アプリを登録し直す道具。
# アイコンを変えたあとも Finder・Dock が前のアイコン（アイコンを入れる前の仮のもの）を出し続けないよう、起動・インストールの前に使う
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
# $(call register_app,アプリの場所): アプリを Launch Services に登録し直す（失敗しても止めない）
register_app = touch "$(1)"; $(LSREGISTER) -f "$(1)" >/dev/null 2>&1 || true
# xcodebuild に足す引数（ふだんは空）
XCODEBUILD_FLAGS ?=

XCODEBUILD := xcodebuild -project Pinshelf.xcodeproj -scheme Pinshelf -sdk macosx \
	-derivedDataPath $(DERIVED_DATA) CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" $(XCODEBUILD_FLAGS)

# 更新の仕組み（Sparkle）。公式の配布物を取り寄せて Vendor/Sparkle に置く（リポジトリには入れない）。
# 版を上げるときは、SPARKLE_VERSION と SPARKLE_SHA256（配布物 Sparkle-版.tar.xz の SHA-256）を一緒に変える
SPARKLE_VERSION := 2.10.1
SPARKLE_SHA256 := 1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
SPARKLE_DIR := Vendor/Sparkle
SPARKLE_BIN := $(SPARKLE_DIR)/bin
# 取り寄せた版の印（版を上げると名前が変わり、取り寄せ直す）
SPARKLE_STAMP := $(SPARKLE_DIR)/.version-$(SPARKLE_VERSION)
# 更新ファイルの署名を確かめる公開鍵（project.yml の SUPublicEDKey。make update-key が書き込む）
UPDATE_PUBLIC_KEY := $(shell sed -n 's/^ *SUPublicEDKey: *"\(.*\)"/\1/p' project.yml)
# 配る更新ファイル（zip）を置く場所。版の一覧（appcast.xml）の中のダウンロード元になる
RELEASE_DOWNLOAD_URL := https://github.com/yzanbo/pinshelf/releases/download/v$(RELEASE_NAME)/

.PHONY: generate build release dist publish publish-check run stop install uninstall test clean cert icon readme-images \
	sparkle update-key update-test update-test-log

# アイコンを描くスクリプトをビルドする場所
ICON_TOOL_DIR := $(DERIVED_DATA)/icon-tool

# project.yml から Pinshelf.xcodeproj を作る（ファイルを足したときも、これで入る）
generate: $(SPARKLE_STAMP)
	xcodegen generate

# Sparkle（更新の仕組み）を取り寄せる。ビルドの前に自動で行うので、ふだんは自分で呼ばなくてよい。
# 取り寄せたファイルは、決めてある SHA-256 と合うことを確かめてから使う（合わなければ止まる）
sparkle: $(SPARKLE_STAMP)

$(SPARKLE_STAMP):
	rm -rf "$(SPARKLE_DIR)"
	mkdir -p "$(SPARKLE_DIR)"
	curl -fsSL -o "$(SPARKLE_DIR)/Sparkle.tar.xz" \
		"https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz"
	echo "$(SPARKLE_SHA256)  $(SPARKLE_DIR)/Sparkle.tar.xz" | shasum -a 256 -c -
	@# 使うものだけ取り出す: アプリに入れるフレームワーク・署名と版の一覧の道具・ライセンス
	tar -xJf "$(SPARKLE_DIR)/Sparkle.tar.xz" -C "$(SPARKLE_DIR)" ./Sparkle.framework ./bin ./LICENSE
	rm "$(SPARKLE_DIR)/Sparkle.tar.xz"
	@# Sparkle のライセンスは、配るものに全文を含める決まりなので、アプリに同梱するファイルへ写す（リポジトリに入れる）
	mkdir -p Pinshelf/Licenses
	cp "$(SPARKLE_DIR)/LICENSE" Pinshelf/Licenses/Sparkle.txt
	touch "$@"

# 開発用（Debug）にビルドする
build: generate
	@echo "署名: $(SIGN_IDENTITY)"
	$(XCODEBUILD) -configuration Debug build

# 配布用（Release）にビルドする。Intel と Apple Silicon の両方で動く形にする
release: generate
	@echo "署名: $(SIGN_IDENTITY)"
	$(XCODEBUILD) -configuration Release ONLY_ACTIVE_ARCH=NO build

# GitHub の Releases に置く DMG と zip を作る（dist/Pinshelf-版.dmg・.zip・.sha256）。
# DMG は、開くと Pinshelf.app とアプリケーションフォルダが並び、ドラッグで入れられる形にする。
# 配る版は、いつもアドホック署名にする（アドホック署名どうしなら、更新しても保存場所・棚のファイル・
# 「ログイン時に起動」が引き継がれることを確かめてある: docs/ARCHITECTURE.md の「更新」）
dist:
	$(MAKE) release SIGN_IDENTITY=-
	mkdir -p dist
	ditto -c -k --sequesterRsrc --keepParent "$(RELEASE_APP)" "$(DIST_ZIP)"
	rm -rf dist/dmg-root
	mkdir -p dist/dmg-root
	ditto "$(RELEASE_APP)" dist/dmg-root/Pinshelf.app
	ln -s /Applications dist/dmg-root/Applications
	@# macOS 26 以降は diskutil image で作る（hdiutil create は「使わなくなる」と警告が出るため）。ない版では hdiutil で作る
	rm -f "$(DIST_DMG)"
	if diskutil image create from -h >/dev/null 2>&1; then \
		diskutil image create from --format UDZO --volumeName "Pinshelf" dist/dmg-root "$(DIST_DMG)"; \
	else \
		hdiutil create -volname "Pinshelf" -srcfolder dist/dmg-root -ov -format UDZO "$(DIST_DMG)"; \
	fi
	rm -rf dist/dmg-root
	cd dist && shasum -a 256 "Pinshelf-$(RELEASE_NAME).dmg" "Pinshelf-$(RELEASE_NAME).zip" > "Pinshelf-$(RELEASE_NAME).sha256"
	@echo ""
	@echo "$(DIST_DMG) と $(DIST_ZIP) を作りました（版: $(RELEASE_NAME)）"

# DMG と zip を作り、GitHub に Release（タグ v版）を作ってアップロードする（GitHub CLI を使う）。
# 説明は「この版の変更」（scripts/release-changes.md。出すたびに書き直す）と「ダウンロードと開き方」をつなげる。
# β 版のときは、説明の先頭に β 版の注意を付け、プレリリースにする。
#
# 入れてもらったアプリに更新を届けるため、zip に EdDSA の鍵で署名して、版の一覧（appcast.xml）を作り直す。
# Release を作ったあと、appcast.xml だけをコミットしてプッシュする（アプリは、main の appcast.xml を見て新しい版を知る）
publish: publish-check dist
	( $(if $(BETA),cat scripts/release-notes-beta.md; echo;) cat scripts/release-changes.md; echo; cat scripts/release-notes.md ) > dist/release-notes.md
	./scripts/make-appcast.sh "$(DIST_ZIP)" scripts/release-changes.md "$(RELEASE_DOWNLOAD_URL)" appcast.xml
	gh release create "v$(RELEASE_NAME)" "$(DIST_DMG)" "$(DIST_ZIP)" "$(DIST_BASE).sha256" \
		--target main --title "Pinshelf $(RELEASE_NAME)$(if $(BETA), (β 版))" $(if $(BETA),--prerelease) \
		--notes-file dist/release-notes.md
	git add appcast.xml
	git commit -q -m "chore: 版の一覧（appcast）を $(RELEASE_NAME) にする" -- appcast.xml
	git push origin main
	@echo ""
	@echo "$(RELEASE_NAME) を公開しました。入れてもらったアプリには、appcast.xml を通して新しい版が届きます。"

# 公開の前に確かめる（そろっていなければ、何も作らずに止める）
# - 更新ファイルに署名する鍵があり、アプリに入れる公開鍵（project.yml）と合っている（合わない鍵で署名すると、更新が届かなくなる）
# - コミットしていない変更がなく、GitHub の main と同じ（Release のタグは GitHub の main に付き、appcast.xml のプッシュで手元の main も送るため）
publish-check: $(SPARKLE_STAMP)
	./scripts/publish-check.sh "$(UPDATE_PUBLIC_KEY)"

# 更新ファイルの署名に使う鍵（EdDSA）を用意して、公開鍵を project.yml に書き込む（最初の 1 回だけ）。
# 秘密鍵は、この Mac のログインキーチェーンに入る（途中で、キーチェーンへのアクセスを聞かれたら許可する）
update-key: $(SPARKLE_STAMP)
	./scripts/update-key.sh

# 更新を、手元で通しで試す（docs/TESTING.md の「更新を通しで試す」）。
# ふだんの Pinshelf とは別の ID の試験用アプリを 2 つの版で作り、新しい版を手元のサーバーから配る（止めるときは control + C）
update-test: generate
	./scripts/update-test.sh $(XCODEBUILD_FLAGS)

# 更新の試験のあいだの macOS の記録を、build/update-test/system.log に書き出す
# （確認の画面が出たかの裏取りと、うまくいかないときの手がかりに使う）。
# いつからの記録かは SINCE="2026-11-26 19:50:00" のように渡す（なければ、直近 30 分）
update-test-log:
	./scripts/update-test-log.sh

# 動いている Pinshelf を終了してから、ビルドした新しい版を起動する。
# 終了した直後は、Launch Services がまだ「動いている」と思っていて、open が
# 「_LSOpenURLsWithCompletionHandler() failed with error -600」で失敗することがあるので、少し待ってやり直す
# （何度やっても起動できないときだけ、最後の open のエラーをそのまま出す）
run: build stop
	@$(call register_app,$(APP))
	@for i in 1 2 3 4 5; do open "$(APP)" 2>/dev/null && exit 0; sleep 0.5; done; open "$(APP)"

# 動いている Pinshelf を終了する。棚を保存してから終わるので、終わり切るまで（最大 5 秒）待つ。
# そのあと、Launch Services がアプリの終了に気づくまで（最大 3 秒）待つ
stop:
	-@killall Pinshelf 2>/dev/null; \
	for i in $$(seq 1 50); do pgrep -x Pinshelf >/dev/null || break; sleep 0.1; done; \
	for i in $$(seq 1 30); do lsappinfo find bundleid=$(BUNDLE_ID) | grep -q . || break; sleep 0.1; done

# 配布用にビルドして、アプリケーションフォルダに入れる（前の版は置き換える）。
# 「ログイン時に起動」は、ここに入れたアプリで入れる
install: release stop
	mkdir -p "$(INSTALL_DIR)/Pinshelf.app"
	rsync -a --delete "$(RELEASE_APP)/" "$(INSTALL_DIR)/Pinshelf.app/"
	@$(call register_app,$(INSTALL_DIR)/Pinshelf.app)
	@echo ""
	@echo "$(INSTALL_DIR)/Pinshelf.app に入れました。アプリケーションフォルダから Pinshelf を開いてください。"

# アプリケーションフォルダから Pinshelf を消す（設定と棚の中身は残る）
uninstall: stop
	rm -rf "$(INSTALL_DIR)/Pinshelf.app"

# テストを動かす（アプリは起動しない）
test:
	cd PinshelfCore && swift test $(SWIFT_TEST_FLAGS)

clean:
	rm -rf $(DERIVED_DATA) PinshelfCore/.build build/update-test

# アプリのアイコンを描き直す（scripts/make-app-icon.swift を変えたとき。Pinshelf/Assets.xcassets に書き出す）
icon:
	mkdir -p $(ICON_TOOL_DIR)
	swiftc -O -module-cache-path $(ICON_TOOL_DIR)/cache scripts/make-app-icon.swift -o $(ICON_TOOL_DIR)/make-app-icon
	$(ICON_TOOL_DIR)/make-app-icon

# README の見本の画像を作り直す（棚の見た目を変えたとき。docs/images に書き出す。Pinshot と同じ考え方）。
# 棚・帯・お気に入り一覧はアプリと同じ部品で実際に出して写すので、作っている間、画面に棚やウィンドウが少しのあいだ出る
README_TOOL_DIR := $(DERIVED_DATA)/readme-images
README_TOOL_APP := $(README_TOOL_DIR)/ReadmeImages.app
SWIFT_TARGET := $(shell uname -m)-apple-macos26.0
SWIFT_PLUGINS := $(shell xcode-select -p)/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins
# swiftc に足す引数（ふだんは空）
SWIFTC_FLAGS ?=
readme-images:
	mkdir -p "$(README_TOOL_APP)/Contents/MacOS" "$(README_TOOL_APP)/Contents/Resources"
	cp scripts/readme-images/Info.plist "$(README_TOOL_APP)/Contents/Info.plist"
	xcrun actool Pinshelf/Assets.xcassets --compile "$(README_TOOL_APP)/Contents/Resources" --platform macosx \
		--minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist "$(README_TOOL_DIR)/assets-info.plist" >/dev/null
	@# 画面に依存しないロジック（PinshelfCore）を、静的ライブラリにする
	xcrun swiftc -parse-as-library -emit-library -static -emit-module -module-name PinshelfCore -swift-version 6 \
		-target $(SWIFT_TARGET) -module-cache-path "$(README_TOOL_DIR)/module-cache" $(SWIFTC_FLAGS) \
		-emit-module-path "$(README_TOOL_DIR)/PinshelfCore.swiftmodule" -o "$(README_TOOL_DIR)/libPinshelfCore.a" \
		PinshelfCore/Sources/PinshelfCore/*.swift
	@# アプリのコード（入口の AppDelegate と、Sparkle を読み込む SparkleUpdater を除く）と、画像を作るプログラムを一緒にビルドする（アプリと同じ設定で）
	find Pinshelf -name '*.swift' ! -name AppDelegate.swift ! -name SparkleUpdater.swift > "$(README_TOOL_DIR)/sources.txt"
	echo scripts/readme-images/main.swift >> "$(README_TOOL_DIR)/sources.txt"
	xcrun swiftc -swift-version 6 -target $(SWIFT_TARGET) -default-isolation MainActor \
		-enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances \
		-plugin-path "$(SWIFT_PLUGINS)" -module-cache-path "$(README_TOOL_DIR)/module-cache" $(SWIFTC_FLAGS) \
		-I "$(README_TOOL_DIR)" -L "$(README_TOOL_DIR)" -lPinshelfCore @"$(README_TOOL_DIR)/sources.txt" \
		-o "$(README_TOOL_APP)/Contents/MacOS/ReadmeImages"
	"$(README_TOOL_APP)/Contents/MacOS/ReadmeImages" docs/images

# 開発用の署名の証明書「Pinshelf Dev」を作る（一度だけ。途中でパスワードを聞かれる）
cert:
	./scripts/create-dev-cert.sh
