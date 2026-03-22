---
name: rdm
description: "Redmine CLIツール。チケットの一覧・作成・更新・削除、工数記録、プロジェクト管理、検索など、Redmine操作全般に使用。トリガー: 'rdm', 'redmine', 'チケット', '工数', 'イシュー', 'プロジェクト一覧'等。"
---

# rdm — Claude Code スキル

[Claude Code](https://claude.ai/code) 用のスキルです。`rdm` CLIを通じてRedmineを操作します。

## 使用タイミング

- チケットの一覧表示・作成・更新・削除を依頼されたとき
- 工数の記録・確認を依頼されたとき
- プロジェクト、バージョン、メンバーシップ、ユーザー、グループについて聞かれたとき
- Redmine操作全般（検索、ステータス確認、クエリ等）
- 「rdm」と言われたとき、または `/rdm` が実行されたとき

## セットアップ

gemをインストール後、認証を行います：

```bash
rdm login
```

`~/.rdm/config.yml` が存在しない場合、初回実行時に自動作成されます。

## コマンドリファレンス

### 認証・ステータス
```bash
rdm login                              # 対話式ログイン（URL + APIキー）
rdm login --url URL --api-key KEY      # 非対話式
rdm login --profile staging --url URL --api-key KEY  # プロファイル指定
rdm status                             # 接続情報の表示
rdm logout                             # 認証情報のクリア
rdm me                                 # 現在のユーザー情報
```

### チケット（Issues）
```bash
rdm issues list                                     # 未完了チケット一覧
rdm issues list --project-id ID --status open       # プロジェクト・ステータスで絞込
rdm issues list --assigned-to-id me --sort updated_on:desc  # 自分の担当チケット
rdm issues show 123                                 # チケット詳細
rdm issues show 123 --include journals,relations    # 履歴付き
rdm issues create --project-id ID --tracker-id N --subject "タイトル"
rdm issues update 123 --status-id 3 --notes "対応完了"
rdm issues delete 123 --confirm
rdm issues copy 123 --project-id other-project --link
rdm issues move 123 --project-id other-project
rdm issues journals 123                             # チケット履歴
rdm issues relations 123                            # 関連チケット
rdm issues add-watcher --issue-id 123 --user-id 5  # ウォッチャー追加
rdm issues add-relation --issue-id 123 --issue-to-id 456 --type blocks  # 関連追加
```

### プロジェクト
```bash
rdm projects list
rdm projects list --status active --include trackers,enabled_modules
rdm projects show myproject
rdm projects create --name "新規プロジェクト" --identifier new-proj
rdm projects update myproject --description "説明を更新"
rdm projects delete myproject --confirm
```

### 工数（Time Entries）
```bash
rdm time list --project-id ID --from 2025-01-01 --to 2025-01-31
rdm time list --user-id me                          # 自分の工数
rdm time show 456
rdm log --hours 2 --activity-id 9 --issue-id 123 --comments "調査作業"
rdm time update 456 --hours 3
rdm time delete 456
rdm time bulk-log --file entries.json               # JSONファイルから一括登録
```

### ユーザー
```bash
rdm users list
rdm users list --status 1 --name "tanaka"
rdm users show 5 --include groups,memberships
rdm users show me                                   # 自分の情報
rdm users create --login jdoe --firstname John --lastname Doe --mail j@example.com
```

### バージョン
```bash
rdm versions list --project-id myproject
rdm versions show 10
rdm versions create --project-id myproject --name "v2.0" --status open --due-date 2025-06-01
rdm versions update 10 --status closed
```

### グループ・メンバーシップ
```bash
rdm groups list
rdm groups show 3 --include users
rdm groups create --name "開発チーム" --user-ids 1,2,3
rdm memberships list --project-id myproject
rdm memberships create --project-id myproject --user-id 5 --role-ids 3,4
```

### クエリ・カスタムフィールド
```bash
rdm queries list --project-id myproject
rdm custom-fields list
```
注: クエリとカスタムフィールドの作成・更新・削除にはExtended API Redmineプラグインが必要です。

### リファレンスデータ
```bash
rdm trackers       # トラッカー一覧
rdm statuses       # ステータス一覧
rdm priorities     # 優先度一覧
rdm activities     # 作業分類一覧
rdm roles          # ロール一覧
rdm search "キーワード" --project-id myproject  # 全文検索
```

### 共通オプション
```bash
--format json|table|csv    # 出力形式（デフォルト: TTYならtable、パイプならjson）
--profile NAME             # 使用するプロファイル
--debug                    # HTTPリクエスト/レスポンスの詳細表示
--limit N                  # ページネーション件数
--offset N                 # ページネーションオフセット
```

## 出力形式

- **table形式**（TTYのデフォルト）: 人間が読みやすいカラム表示
- **JSON形式**（パイプ時のデフォルト）: Redmine APIのレスポンスそのまま
- **CSV形式**: スプレッドシート向け

JSON固定: `rdm issues list --format json`
パイプ処理: `rdm issues list --format json | jq '.[] | .id'`

## 環境変数

ログインなしで設定を上書き：
```bash
RDM_URL=https://redmine.example.com RDM_API_KEY=key rdm issues list
```

利用可能: `RDM_URL`, `RDM_API_KEY`, `RDM_PROFILE`, `RDM_CONFIG`, `RDM_FORMAT`, `RDM_TIMEOUT`, `RDM_DEBUG`

## エラーコード

| 終了コード | 意味 |
|-----------|------|
| 0 | 成功 |
| 1 | 一般エラー（接続、サーバー、タイムアウト） |
| 2 | 認証・認可エラー |
| 3 | リソースが見つからない |
| 4 | バリデーションエラー |

## Claude向けヒント

- 「チケット123を確認して」→ `rdm issues show 123`
- 「チケット123に2時間記録して」→ `rdm log --hours 2 --activity-id 9 --issue-id 123`
- 一括操作には `--format json` を使い、jqで処理する
- 操作前に `rdm status` で接続確認
- `rdm me` で現在のユーザーIDを取得してフィルタに使用
- 削除系コマンドには必ず `--confirm` が必要
- 認証エラーの場合は `rdm login` を提案
