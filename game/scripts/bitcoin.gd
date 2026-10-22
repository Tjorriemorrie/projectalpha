class_name Bitcoin
extends RefCounted
## The game's money is bitcoin, shown with the bitcoin symbol. Every amount the player sees is written through
## format(), so the symbol and the number style live in one place.

const SYMBOL := "₿"


## An amount with the symbol and a comma between thousands: 1240 is "₿1,240", -50 is "−₿50". signed puts "+" before a
## gain, for changes such as "+₿154".
static func format(amount: int, signed: bool = false) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var prefix := "−" if amount < 0 else "+" if signed and amount > 0 else ""
	return "%s%s%s%s" % [prefix, SYMBOL, digits, grouped]
