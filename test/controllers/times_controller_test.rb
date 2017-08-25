require 'test_helper'

class TimesControllerTest < ActionDispatch::IntegrationTest

  test "text that bob would like to work" do
    # bob larrick's slack id is U0G8BER8A
    post times_add_url, params: { user_id: 'U0G8BER8A', text: %[1620 7 2017-8-23 || "Working on DataFunctions"] }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23 with note \"Working on DataFunctions\""
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use 1" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 2017-8-23]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use 2" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for #{Date.today.strftime("%Y-%m-%d")}"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use abc" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 I had a bad day]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for #{Date.today.strftime("%Y-%m-%d")} with note I had a bad day"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use 3" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 2017-8-23 || Working on DataFunctions]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23 with note Working on DataFunctions"
    assert_equal expected, @response.body
  end
  test "text that bob thinks people might use 4" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 2017-08-23 || 'Working on DataFunctions']
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23 with note 'Working on DataFunctions'"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use rarely 1" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 08-23 || 'Working on DataFunctions']
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23 with note 'Working on DataFunctions'"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use rarely 2" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 8-23 || 'Working on DataFunctions']
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23 with note 'Working on DataFunctions'"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use rarely 3" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 08-23 ]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23"
    assert_equal expected, @response.body
  end

  test "text that bob thinks people might use rarely 4" do
    # bob larrick's slack id is U0G8BER8A
    text = %[1620 7 8-23 ]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 7.0 added to 1620 (MyString) for 2017-08-23"
    assert_equal expected, @response.body
    entry = @controller.instance_variable_get(:@entry)
    assert_equal entry.kind, "time"
  end

  test "text that bob thinks people might use rarely abc" do
    # bob larrick's slack id is U0G8BER8A
    text = %[onsite 1234 8 spending time onsite]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 8.0 added to 1234 (Pickle Juice) for #{Date.today.strftime("%Y-%m-%d")} with note spending time onsite"
    assert_equal expected, @response.body
    entry = @controller.instance_variable_get(:@entry)
    assert_equal entry.kind, "onsite"
  end

  test "text that bob thinks people might use rarely def" do
    # bob larrick's slack id is U0G8BER8A
    text = %[onsite 1234 8 spending time onsite]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 8.0 added to 1234 (Pickle Juice) for #{Date.today.strftime("%Y-%m-%d")} with note spending time onsite"
    assert_equal expected, @response.body
    entry = @controller.instance_variable_get(:@entry)
    assert_equal entry.kind, "onsite"
  end

  test "text that bob thinks people might use rarely ghi" do
    # bob larrick's slack id is U0G8BER8A
    text = %[onsite 1234 8 ]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 8.0 added to 1234 (Pickle Juice) for #{Date.today.strftime("%Y-%m-%d")}"
    assert_equal expected, @response.body
    entry = @controller.instance_variable_get(:@entry)
    assert_equal entry.kind, "onsite"
  end

  test "text that bob thinks people might use rarely jkl" do
    # bob larrick's slack id is U0G8BER8A
    text = %[onsite 1234 8  8-23  || spending time onsite]
    post times_add_url, params: { user_id: 'U0G8BER8A', text: text }
    expected = "Thanks! 8.0 added to 1234 (Pickle Juice) for 2017-08-23 with note spending time onsite"
    assert_equal expected, @response.body
    entry = @controller.instance_variable_get(:@entry)
    assert_equal entry.kind, "onsite"
  end


end
