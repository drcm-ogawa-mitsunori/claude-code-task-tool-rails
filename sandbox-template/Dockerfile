# syntax=docker/dockerfile:1
# Docker Sandboxes (sbx) 用カスタムテンプレート
# Rails 8 の開発に必要なソフトウェア一式をプリインストールしたイメージ。
# ビルド・登録手順は同ディレクトリの README.md を参照。
FROM docker/sandbox-templates:claude-code

# バージョンを上げる場合はここを変更する
ARG RUBY_VERSION=3.4.10
ARG RAILS_VERSION="~> 8.0"

# --- システムパッケージ(root で実行) ---
# Ruby のビルドに必要なライブラリと、本プロジェクトの構成
# (MySQL / Active Storage の画像処理 = libvips)に必要なパッケージ。
# default-libmysqlclient-dev は mysql2 gem のネイティブビルドに、
# default-mysql-client は動作確認用の mysql CLI として入れている。
# rustc は Ruby の YJIT を有効にしてビルドするために必要。
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      autoconf \
      build-essential \
      default-libmysqlclient-dev \
      default-mysql-client \
      libffi-dev \
      libgmp-dev \
      libreadline-dev \
      libssl-dev \
      libvips \
      libyaml-dev \
      pkg-config \
      rustc \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Ruby / Rails(agent ユーザーで実行) ---
# rbenv + ruby-build でインストールし、プロジェクトの .ruby-version による
# バージョン切り替えを可能にしておく。shims を PATH に通すことで
# シェルの初期化処理(rbenv init)に依存せず ruby / rails を実行できる。
USER agent
ENV RBENV_ROOT=/home/agent/.rbenv
ENV PATH=$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH

RUN git clone --depth 1 https://github.com/rbenv/rbenv.git "$RBENV_ROOT" \
    && git clone --depth 1 https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build" \
    && rbenv install "$RUBY_VERSION" \
    && rbenv global "$RUBY_VERSION"

RUN gem install rails -v "$RAILS_VERSION" --no-document \
    && rbenv rehash

# ログインシェル向けにも rbenv の PATH を通しておく(root で実行)
USER root
RUN printf '%s\n' \
      'export RBENV_ROOT="/home/agent/.rbenv"' \
      'case ":$PATH:" in' \
      '  *":$RBENV_ROOT/shims:"*) ;;' \
      '  *) export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH" ;;' \
      'esac' \
      > /etc/profile.d/rbenv.sh

USER agent
