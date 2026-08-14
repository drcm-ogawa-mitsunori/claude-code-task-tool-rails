require "test_helper"

# Solid Cache / Solid Queue が MySQL 上で実際に動作することを確認する。
class SolidStackTest < ActionDispatch::IntegrationTest
  class EchoJob < ApplicationJob
    queue_as :default

    def perform(message)
      message
    end
  end

  test "Rails.cache が Solid Cache 経由で MySQL に読み書きできる" do
    assert_kind_of SolidCache::Store, Rails.cache

    key = "solid_stack_test/#{name}"
    Rails.cache.write(key, "cached value")

    assert_equal "cached value", Rails.cache.read(key)
    assert SolidCache::Entry.exists?, "Solid Cache のエントリが DB に保存されていること"
  ensure
    Rails.cache.delete(key) if key
  end

  test "Active Job が Solid Queue 経由で MySQL にジョブを登録する" do
    assert_kind_of ActiveJob::QueueAdapters::SolidQueueAdapter, ActiveJob::Base.queue_adapter

    assert_difference -> { SolidQueue::Job.count }, 1 do
      EchoJob.perform_later("hello")
    end

    job = SolidQueue::Job.order(:id).last
    assert_equal EchoJob.name, job.class_name
    assert_equal "default", job.queue_name
  end
end
