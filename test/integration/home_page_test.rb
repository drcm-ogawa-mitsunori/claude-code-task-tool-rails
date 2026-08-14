require "test_helper"

class HomePageTest < ActionDispatch::IntegrationTest
  test "ルートパスでトップページが表示される" do
    get root_path

    assert_response :success
    assert_select "h1", "Task Tool"
    assert_select "title", "Task Tool"
  end

  test "ヘルスチェックが成功する" do
    get rails_health_check_path

    assert_response :success
  end
end
