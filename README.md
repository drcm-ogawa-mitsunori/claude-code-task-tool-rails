# Task Tool

ローカルで動かすことを想定した Rails 8 製のタスク管理ツールです。

## 必要なもの

- Ruby 3.4.10(`.ruby-version` を参照)
- Docker(開発用 MySQL の起動に使用)

## セットアップ

```bash
docker compose up -d   # MySQL 8.4 を起動
bundle install
bin/rails db:prepare   # データベース作成 + スキーマ読み込み
```

## 起動

```bash
bin/dev     # http://localhost:3000
bin/jobs    # Solid Queue のワーカー(バックグラウンドジョブを実行する場合)
```

## テスト・Lint

```bash
bin/rails test    # テストスイート
bin/rubocop       # Lint
bin/ci            # CI 相当を一括実行
```

## 構成メモ

- キャッシュは Solid Cache、ジョブキューは Solid Queue を使用し、それぞれ MySQL 上の専用データベース
  (`*_cache` / `*_queue`)に保存されます。
- DB 接続情報は `DB_HOST` / `DB_PORT` / `DB_USERNAME` / `DB_PASSWORD` で上書きできます
  (既定値は `docker-compose.yml` に合わせてあります)。

## ライセンス

MIT License(`LICENSE` を参照)
