extends GdUnitTestSuite
## Unit tests for Bitcoin.format: the symbol, commas between thousands, and signs.


func test_writes_the_symbol_before_the_amount() -> void:
	assert_str(Bitcoin.format(0)).is_equal("₿0")
	assert_str(Bitcoin.format(25)).is_equal("₿25")
	assert_str(Bitcoin.format(500)).is_equal("₿500")


func test_puts_commas_between_thousands() -> void:
	assert_str(Bitcoin.format(1240)).is_equal("₿1,240")
	assert_str(Bitcoin.format(1234567)).is_equal("₿1,234,567")


func test_signs_losses_and_signed_gains() -> void:
	assert_str(Bitcoin.format(-50)).is_equal("−₿50")
	assert_str(Bitcoin.format(154, true)).is_equal("+₿154")
	assert_str(Bitcoin.format(0, true)).is_equal("₿0")
	assert_str(Bitcoin.format(-1500, true)).is_equal("−₿1,500")
