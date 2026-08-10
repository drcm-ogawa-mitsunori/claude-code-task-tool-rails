# サンドボックステンプレート

Docker Sandboxes (sbx) で Claude Code を動かす際に使うカスタムテンプレートです。
Rails 8 の開発に必要なソフトウェアをプリインストールしてあります。

## 含まれるもの

ベースイメージ `docker/sandbox-templates:claude-code`(Node.js / npm / Python / git などを含む)に加えて:

| ソフトウェア | バージョン | 備考 |
| --- | --- | --- |
| Ruby | 3.4.10 | rbenv + ruby-build でインストール(YJIT 有効) |
| Rails | `~> 8.0` の最新 | `gem install rails` 済み |
| SQLite3 | apt 最新 | Rails 8 のデフォルト DB(`libsqlite3-dev` 含む) |
| libvips | apt 最新 | Active Storage の画像処理用 |

rbenv を使っているため、プロジェクトに `.ruby-version` を置けば別バージョンの Ruby も
`rbenv install <version>` で追加インストールできます。

※ システムテスト用のブラウザ(Chromium 等)は含めていません。Ubuntu の chromium は
snap 依存でコンテナに入れづらいため、必要になった時点で導入方法を検討してください。

## ビルドとレジストリへの push(ホスト側で実行)

チームで共有するため、コンテナレジストリに push して使います。メンバーの環境が
Apple Silicon / Intel で混在する可能性があるため、マルチアーキテクチャでビルドします。

```bash
cd sandbox-template

# 例: GitHub Container Registry を使う場合
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<org>/rails8-sandbox:latest \
  --push .
```

自分だけで試す場合はローカルビルドでも使えます(ローカルイメージはそのまま参照可能):

```bash
docker build -t rails8-sandbox:local sandbox-template/
```

## テンプレートとしての利用(ホスト側で実行)

`sbx` はテンプレートを `--template` フラグで指定します。

```bash
# サンドボックスを作成して Claude Code を起動
sbx run --template ghcr.io/<org>/rails8-sandbox:latest claude

# もしくは作成のみ
sbx create --template ghcr.io/<org>/rails8-sandbox:latest claude
```

イメージは初回利用時に pull されローカルにキャッシュされます。2 回目以降は
キャッシュが再利用されます。

## サンドボックスのネットワーク許可(重要)

サンドボックスにはアウトバウンド通信の firewall があり、デフォルトでは以下が
ブロックされます。Rails 開発では gem の取得が必要になるため、各メンバーは
ホスト側で次のコマンドを一度実行しておいてください。

```bash
# bundle install / gem install に必要
sbx policy allow network index.rubygems.org

# サンドボックス内で rbenv install(Ruby のソースビルド)を行う場合のみ必要
sbx policy allow network cache.ruby-lang.org
```

※ `rubygems.org` 本体はデフォルトで許可されていますが、bundler が利用する
`index.rubygems.org` は別ドメインのため個別の許可が必要です。

## バージョン更新

Ruby / Rails のバージョンは `Dockerfile` 冒頭の `ARG RUBY_VERSION` /
`ARG RAILS_VERSION` で固定しています。更新する場合はここを書き換えて
再ビルド・再 push してください。
