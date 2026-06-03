# Chlipist 設計原則

## コア
- **DI & プロトコル**: シングルトン禁止。プロトコルに基づき、イニシャライザ経由で依存性を注入。
- **AppCoordinator**: メインロジックを統括。`AppDelegate` にロジックを書かない。
- **単一責任**: 1クラス1責任を徹底。

## レイヤー構造
- `Services/`: プロトコル経由でビジネスロジックやOS APIを操作。
- `UI/`: 表示のみ。上位への通知は Delegate か Combine を使用。
- `Models/`: 純粋なデータ構造とロジック。
- `Utility/`: 汎用ヘルパー（Robot, String等）。

## 制約
- **Carbon**: ホットキーに使用（アクセシビリティ権限回避のため）。
- **Combine**: 状態監視（`@Published`）に優先して使用。
- **品質**: `make lint` とビルドが通ること。
- **Xcode**: `project.pbxproj` のグループをファイル構成と同期。
