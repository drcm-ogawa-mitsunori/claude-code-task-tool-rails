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
# 含まれないため、存在しない項目は表示から省略する。

require "json"
require "time"

# 残り秒数を "3d4h" / "2h15m" / "45m" の形式に整形する
def format_duration(seconds)
  return nil if seconds.nil? || seconds.negative?

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
rescue ArgumentError
  nil
end

# レートリミット 1 枠分の表示を組み立てる
def format_rate_limit(label, window, now)
  return nil unless window.is_a?(Hash)

  used = window["used_percentage"]
  return nil unless used.is_a?(Numeric)

  text = "#{label}: #{used.round}%"
  resets_at = parse_resets_at(window["resets_at"])
  if resets_at
    remaining = format_duration(resets_at - now)
    text += " (リセットまで #{remaining})" if remaining
  end
  text
end

begin
  data = JSON.parse($stdin.read)
rescue JSON::ParserError
  puts "(statusline: 入力 JSON の解析に失敗)"
  exit 0
end

parts = []

model = data.dig("model", "display_name")
parts << "🤖 #{model}" if model

version = data["version"]
parts << "v#{version}" if version

project_dir = data.dig("workspace", "project_dir")
if project_dir
  home = begin
    Dir.home
  rescue StandardError
    nil
  end
  project_dir = project_dir.sub(/\A#{Regexp.escape(home)}/, "~") if home
  parts << "📁 #{project_dir}"
end

used_percentage = data.dig("context_window", "used_percentage")
parts << "🧠 #{used_percentage.round}%" if used_percentage.is_a?(Numeric)

cost = data.dig("cost", "total_cost_usd")
parts << format("💰 $%.2f", cost) if cost.is_a?(Numeric)

now = Time.now
parts << format_rate_limit("⏱ 5h", data.dig("rate_limits", "five_hour"), now)
parts << format_rate_limit("📅 7d", data.dig("rate_limits", "seven_day"), now)

puts parts.compact.join(" | ")
