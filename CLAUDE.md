# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## ドキュメント方針

- 本リポジトリのドキュメントは基本的にすべて**日本語**で記述する(この CLAUDE.md も含む)。

## プロジェクト概要

- **Rails 8** を使って開発する、**ローカルで動かすことを想定したタスクツール**。
- DB には **MySQL** を使う(リポジトリルートの `docker-compose.yml` で `docker compose up -d` して起動する)。
- ビューも Rails が担保する(API モードではなく、Hotwire (Turbo / Stimulus) + importmap + Propshaft の Rails 8 標準構成)。
- キャッシュは **Solid Cache**、ジョブキューは **Solid Queue** を使う(いずれも MySQL 上の専用データベースを使用)。
- ローカル利用前提のため、Docker デプロイ関連(Kamal / Thruster / Dockerfile)は導入していない。

## 開発フロー

1. **pull する**: リモートの更新を反映するため、作業開始前にまず pull する。
2. **対応 issue の確認・作成**: 依頼内容に対応する open issue が存在するか確認する。存在しない場合は、実行計画の初期に「issue 作成」を含め、実装に着手する前に issue を作成する(開発経緯が issue を見ればすべて分かる状態を保つため)。
3. **ベースブランチ**: 具体的な指示が無い限りは `main` ブランチをベースとする。
4. **計画 → GO サイン待ち**: 指示を受け取り、実装方針が決まったら計画を表示して GO サインを待つ。**GO サインが出てから実装を開始する**。
5. **DB(docker compose)の起動**: DB を使った修正や対応の場合、`docker compose` が立ち上がっていない場合は立ち上げる(リポジトリルートで `docker compose up -d`。状態は `docker compose ps` で確認する)。**複数のセッションで並行して開発している可能性があるため、開発が完了しても `docker compose` は止めない**(`docker compose down` / `docker compose stop` を実行しない)。
6. **git worktree で隔離**: 並列実装を可能とするため、実装時は `git worktree` を使って実装場所を隔離する。
7. **テストコードの作成**: アプリケーションコードに手を入れた場合、必ずテストコードを書く(詳細は「テスト方針」を参照)。
8. **レビューの実施**: テストコード記載後、レビューを実施する(詳細は「レビュー方針」を参照)。
9. **プッシュして PR 作成**: 実装完了後、ブランチをプッシュして Pull Request を作成する。

## テスト方針

アプリケーションコードに手を入れた場合、必ずテストコードを書く。

- **インテグレーションテストを必須**とし、インテグレーションテストでケースを網羅する。
- インテグレーションテストの網羅性でカバーできていれば、ユニットテストは不要。
- ただし、インテグレーションテストで網羅できていない部分が出てくる場合は、ユニットテストも記載する。

## レビュー方針

アプリケーションコードに手を入れた場合、テストコード記載後に以下のレビューを実施する。

- Claude Code の `/code-review` コマンドでコードレビューを実施する。
- Claude Code の `/security-review` コマンドでセキュリティレビューを実施する。
- レビューでの指摘事項に対応してから PR を作成する。

## ブランチ命名規則

- 新機能開発系: `feature/xxx`
- 不具合修正系: `bugfix/xxx`

## コミット・プルリクエスト規約

どの issue への対応なのかを明示するため、以下のルールに従う。

### コミットメッセージ

- `(#issue番号): メッセージ` をテンプレートとする。
  - 例: issue #1 への対応で CLAUDE.md の中身を日本語にしたコミット -> `(#1): CLAUDE.md を日本語ベースに変更`

### プルリクエスト

- PR 作成時、どの issue に対応したものかを PR の説明文に記述する(例: `対応 issue: #1`)。

## セットアップ

```bash
docker compose up -d   # MySQL 8.4 を起動(リポジトリルート)
bundle install
bin/rails db:prepare   # 各データベースの作成とスキーマ読み込み
```

## よく使うコマンド

| 目的 | コマンド |
| --- | --- |
| アプリの起動 | `bin/dev`(http://localhost:3000) |
| Solid Queue のワーカー起動 | `bin/jobs` |
| テストスイート実行 | `bin/rails test` |
| 単一テストファイル実行 | `bin/rails test test/integration/home_page_test.rb` |
| 単一テストケース実行 | `bin/rails test test/integration/home_page_test.rb:4`(行番号指定) |
| システムテスト実行 | `bin/rails test:system`(実行には Chrome が必要。現時点でテストは未作成) |
| Lint(RuboCop / rails-omakase) | `bin/rubocop`(自動修正は `bin/rubocop -a`) |
| セキュリティスキャン | `bin/brakeman`、`bin/bundler-audit`、`bin/importmap audit` |
| CI 相当を一括実行 | `bin/ci` |

## アーキテクチャ

- **Rails 8.1 / Ruby 3.4**、フロントエンドは importmap + Hotwire、アセットは Propshaft。
- **データベース(MySQL)は用途ごとに分割**している(`config/database.yml`)。
  - `primary`: アプリ本体(`task_tool_development` など)
  - `cache`: Solid Cache 用(`db/cache_schema.rb`)
  - `queue`: Solid Queue 用(`db/queue_schema.rb`)
  - development / test / production のすべてで Solid Cache・Solid Queue を有効にしている
    (`config/environments/*.rb` の `cache_store` / `active_job.queue_adapter`)。
- 接続情報は環境変数 `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` で上書きできる。
  既定値はリポジトリルートの `docker-compose.yml` に合わせてある。
- ルート(`/`)は `HomeController#index`。ヘルスチェックは `/up`。
