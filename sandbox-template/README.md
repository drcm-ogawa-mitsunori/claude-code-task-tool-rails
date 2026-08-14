# サンドボックステンプレート

Docker Sandboxes (sbx) で Claude Code を動かす際に使うカスタムテンプレートです。
Rails 8 の開発に必要なソフトウェアをプリインストールしてあります。

## 含まれるもの

ベースイメージ `docker/sandbox-templates:claude-code-docker`(Node.js / npm / Python / git
などに加え、microVM 内で動く **Docker Engine** を含む)に加えて:

| ソフトウェア | バージョン | 備考 |
| --- | --- | --- |
| Ruby | 3.4.10 | rbenv + ruby-build でインストール(YJIT 有効) |
| Rails | `~> 8.0` の最新 | `gem install rails` 済み |
| MySQL クライアント | apt 最新 | `default-libmysqlclient-dev`(mysql2 gem のビルド用)と `default-mysql-client`(mysql CLI) |
| libvips | apt 最新 | Active Storage の画像処理用 |

※ MySQL サーバー本体はイメージに含めていません。リポジトリルートの
`docker-compose.yml` で `docker compose up -d` して起動します。ベースイメージに
Docker Engine が含まれているため、この起動はサンドボックス内だけで完結します
(ホスト側の Docker は使いません)。

rbenv を使っているため、プロジェクトに `.ruby-version` を置けば別バージョンの Ruby も
`rbenv install <version>` で追加インストールできます。

※ システムテスト用のブラウザ(Chromium 等)は含めていません。Ubuntu の chromium は
snap 依存でコンテナに入れづらいため、必要になった時点で導入方法を検討してください。

## 利用手順(ホスト側で実行)

チームでの共有は**この Dockerfile まで**とし、ビルドしたイメージはコンテナレジストリに
push しません。各メンバーが自分のマシンでイメージをビルドし、サンドボックスランタイムに
取り込んで使います(自分の CPU アーキテクチャ向けにビルドされるため、Apple Silicon /
Intel の違いも意識する必要がありません)。

### 1. イメージをビルドする

リポジトリのルートで:

```bash
docker build -t rails8-sandbox:1.1 sandbox-template/
```

### 2. tar にエクスポートしてサンドボックスランタイムに取り込む

サンドボックスランタイムはホストの Docker とイメージストアを共有していないため、
`docker save` でエクスポートした tar ファイルを `sbx template load` で取り込みます。

```bash
docker save rails8-sandbox:1.1 -o rails8-sandbox.tar
sbx template load rails8-sandbox.tar
rm rails8-sandbox.tar

# 取り込まれたことを確認
sbx template ls
```

### 3. テンプレートを指定してサンドボックスを作成する

```bash
# サンドボックスを作成して Claude Code を起動
sbx run -t rails8-sandbox:1.1 claude

# もしくは作成のみ(-t は --template の短縮形)
sbx create -t rails8-sandbox:1.1 claude
```

Dockerfile を更新した場合は、タグを上げて手順 1〜2 を再実行してください。
不要になったテンプレートは `sbx template rm` で削除できます。

### 4. 既存サンドボックスの作り直し(1.0 から移行する場合)

`sbx template ls` の FLAVOR 列でベースイメージの種類が分かります。`claude-code`
(= 1.0 のイメージ)で作られたサンドボックスには Docker デーモンが存在せず、
`docker` CLI はあっても `docker compose` が動きません。フレーバーは
サンドボックス作成時に決まるため、途中で切り替えられません。既存サンドボックスは
一度削除して作り直してください。

```bash
sbx rm task-tool
sbx create --name task-tool -t rails8-sandbox:1.1 --clone --no-share-skills claude .
sbx run --name task-tool -- update
```

作り直すと GitHub トークンなどのサンドボックス単位のシークレットも消えるため、
`sbx secret set` をやり直す必要があります。

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

サンドボックス内で `docker compose up -d` した際に `mysql:8.4` の pull が
HTTP 403(`Blocked by network policy`)になる場合は、Docker Hub 側のドメインも
許可してください。

```bash
sbx policy allow network registry-1.docker.io,auth.docker.io,production.cloudflare.docker.com
```

## バージョン更新

Ruby / Rails のバージョンは `Dockerfile` 冒頭の `ARG RUBY_VERSION` /
`ARG RAILS_VERSION` で固定しています。更新する場合はここを書き換えて、
イメージのタグを上げた上で「利用手順」の 1〜2 を再実行してください
(レジストリへの push は行いません)。
