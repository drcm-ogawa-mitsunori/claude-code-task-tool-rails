# frozen_string_literal: true

# Claude Code の statusline スクリプト(issue #27)
#
# Claude Code が stdin に渡すセッション情報の JSON を整形し、
# 1 行のステータス文字列を stdout に出力する。
# 表示内容: モデル名 / Claude Code バージョン / プロジェクトルート /
#           コンテキストウィンドウ使用率 / セッション累計コスト /
#           レートリミット使用率と次のリセットまでの時間(5時間枠・7日枠)
#
# rate_limits などのフィールドはセッション直後やログイン方式によっては
# 含まれないため、期待する型・値でない項目は表示から省略する
# (スキーマ逸脱でクラッシュしてステータスラインが消えるより、部分表示を優先する)。

require "json"
require "time"

# これを超える残り時間は単位の齟齬(ミリ秒 epoch など)とみなして表示しない
MAX_DURATION_SECONDS = 30 * 24 * 60 * 60

# Infinity / NaN は is_a?(Numeric) を通過して round などでクラッシュするため弾く
def finite_number?(value)
  value.is_a?(Numeric) && (!value.is_a?(Float) || value.finite?)
end

# 途中のノードが Hash でない入力でも安全にたどれる dig
def dig_value(data, *keys)
  keys.reduce(data) { |node, key| node.is_a?(Hash) ? node[key] : nil }
end

# 残り秒数を "3d4h" / "2h15m" / "45m" の形式に整形する
def format_duration(seconds)
  return nil if seconds.nil? || seconds.negative? || seconds > MAX_DURATION_SECONDS

  total_minutes = seconds.to_i / 60
  days = total_minutes / (60 * 24)
  hours = (total_minutes % (60 * 24)) / 60
  minutes = total_minutes % 60

  if days.positive?
    "#{days}d#{hours}h"
  elsif hours.positive?
    "#{hours}h#{minutes}m"
  else
    "#{minutes}m"
  end
end

# resets_at(Unix 時刻または日時文字列)を Time に変換する
def parse_resets_at(value)
  case value
  when Numeric then Time.at(value)
  when String then Time.parse(value)
  end
rescue StandardError
  nil
end

# レートリミット 1 枠分の表示を組み立てる
def format_rate_limit(label, window, now)
  used = dig_value(window, "used_percentage")
  return nil unless finite_number?(used)

  text = "#{label}: #{used.round}%"
  resets_at = parse_resets_at(dig_value(window, "resets_at"))
  if resets_at
    remaining = format_duration(resets_at - now)
    text += " (リセットまで #{remaining})" if remaining
  end
  text
end

# ホームディレクトリ配下のパスを ~ 表記に短縮する
def shorten_home(path)
  home = begin
    Dir.home
  rescue StandardError
    nil
  end
  return path unless home.is_a?(String) && !home.empty?

  if path == home
    "~"
  elsif path.start_with?("#{home}/")
    "~#{path.delete_prefix(home)}"
  else
    path
  end
end

$stdin.set_encoding(Encoding::UTF_8)

data = begin
  JSON.parse($stdin.read)
rescue StandardError
  nil
end
data = {} unless data.is_a?(Hash)

parts = []

model = dig_value(data, "model", "display_name")
parts << "🤖 #{model}" if model.is_a?(String) && !model.empty?

version = data["version"]
parts << "v#{version}" if version.is_a?(String) && !version.empty?

project_dir = dig_value(data, "workspace", "project_dir")
parts << "📁 #{shorten_home(project_dir)}" if project_dir.is_a?(String) && !project_dir.empty?

used_percentage = dig_value(data, "context_window", "used_percentage")
parts << "🧠 #{used_percentage.round}%" if finite_number?(used_percentage)

cost = dig_value(data, "cost", "total_cost_usd")
parts << format("💰 $%.2f", cost) if finite_number?(cost)

now = Time.now
parts << format_rate_limit("⏱ 5h", dig_value(data, "rate_limits", "five_hour"), now)
parts << format_rate_limit("📅 7d", dig_value(data, "rate_limits", "seven_day"), now)

parts.compact!
puts parts.empty? ? "(statusline: 表示できる情報がありません)" : parts.join(" | ")
