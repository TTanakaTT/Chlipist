# chlips

macOS向けクリップボード履歴管理アプリ。  
Windows の「Win + V」と似た挙動を macOS で実現します。

## 機能

- コピー（⌘C）のたびにテキスト履歴を最大 50 件蓄積
- **⌘⇧V** を押すと、マウスカーソル付近にフローティングパネルが表示される
- リストから選択すると直前にフォーカスしていたアプリへ自動ペースト
- 上位 10 件には **1〜9 / 0** キーのショートカットを表示・割り当て
- メニューバーアイコンからも履歴パネルを呼び出し・履歴クリアが可能

## 動作環境

- macOS 13 Ventura 以降
- ディベロッパー登録不要（コード署名なしでビルド可能）

## ビルド方法

### Xcode で開く

1. `chlips.xcodeproj` を Xcode 15 以降で開く
2. ターゲット「chlips」を選択
3. **Product > Build** (⌘B) でビルド
4. **Product > Run** (⌘R) で実行

コード署名は無効化済みのため、Apple Developer アカウントは不要です。

### コマンドラインビルド（xcodebuild）

```bash
xcodebuild -project chlips.xcodeproj \
           -scheme chlips \
           -configuration Release \
           -derivedDataPath ./.build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           build
```

ビルド成果物は `./.build/Build/Products/Release` に生成されます。

```bash
rsync -a ./.build/Build/Products/Release/chlips.app /Applications
```

Applicationsへ移動。

## 初回起動時の設定

アプリ起動後、以下の権限を付与してください：

1. **アクセシビリティ権限** — 他のアプリへの ⌘V シミュレーションに必要  
   「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で **chlips** を追加してください。  
   初回起動時に自動でダイアログが表示されます。

> **補足**: グローバルホットキー（⌘⇧V）の登録には Carbon API を使用しているため、  
> アクセシビリティ権限なしでも **ホットキーによるパネル表示** は動作します。  
> ペーストのシミュレーションにのみアクセシビリティ権限が必要です。

## ファイル構成

```
chlips/
├── chlips.xcodeproj/
│   └── project.pbxproj         # Xcode プロジェクト定義
└── chlips/
    ├── main.swift               # アプリエントリーポイント
    ├── AppDelegate.swift        # ステータスバー・権限チェック
    ├── ClipboardManager.swift   # NSPasteboard ポーリング・履歴管理
    ├── HotKeyManager.swift      # Carbon API によるグローバルホットキー登録
    ├── ClipboardHistoryWindowController.swift  # 履歴パネル UI
    ├── Info.plist               # アプリ設定（LSUIElement=YES など）
    ├── chlips.entitlements      # エンタイトルメント（署名なし用）
    └── Assets.xcassets/         # アセットカタログ
```

## ライセンス

個人利用目的のサンプルコードです。
