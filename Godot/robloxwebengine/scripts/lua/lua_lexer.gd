class_name LuaLexer
extends RefCounted
## Lexer Lua 5.1 (subset): nomi, numeri, stringhe corte/lunghe, commenti,
## operatori e parole chiave. Su errore espone `error_message` e `error_line`.

const KEYWORDS := [
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function",
	"if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
	"true", "until", "while",
]

var error_message := ""
var error_line := 0

var _source := ""
var _length := 0
var _pos := 0
var _line := 1
var _tokens: Array = []


func tokenize(source: String) -> Array:
	_source = source
	_length = source.length()
	_pos = 0
	_line = 1
	_tokens = []
	error_message = ""
	error_line = 0
	while _pos < _length:
		_skip_space_and_comments()
		if _pos >= _length:
			break
		if _failed():
			break
		var start_line := _line
		var c := _source[_pos]
		if _is_alpha(c) or c == "_":
			_read_name(start_line)
		elif _is_digit(c) or (c == "." and _peek(1).is_valid_int()):
			_read_number(start_line)
		elif c == "\"" or c == "'":
			_read_string(c, start_line)
		elif c == "[" and _long_bracket_level(_pos) >= 0:
			_read_long_string(start_line)
		else:
			_read_operator(start_line)
	_tokens.append({"t": "eof", "v": "", "line": _line})
	return _tokens


func _failed() -> bool:
	return error_message != ""


func _fail(message: String, line: int) -> void:
	if not _failed():
		error_message = message
		error_line = line


func _peek(offset: int) -> String:
	var index := _pos + offset
	if index < 0 or index >= _length:
		return ""
	return _source[index]


func _is_alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _is_hex_digit(c: String) -> bool:
	return _is_digit(c) or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")


func _skip_space_and_comments() -> void:
	while _pos < _length:
		var c := _source[_pos]
		if c == "\n":
			_line += 1
			_pos += 1
		elif c == " " or c == "\t" or c == "\r" or c == "\f" or c == "\v":
			_pos += 1
		elif c == "-" and _peek(1) == "-":
			_pos += 2
			var level := _long_bracket_level(_pos)
			if level >= 0:
				_skip_long_bracket(level)
			else:
				while _pos < _length and _source[_pos] != "\n":
					_pos += 1
		else:
			return


func _long_bracket_level(index: int) -> int:
	## Ritorna il livello di `[=*[` a partire da index, oppure -1.
	if index >= _length or _source[index] != "[":
		return -1
	var i := index + 1
	var level := 0
	while i < _length and _source[i] == "=":
		level += 1
		i += 1
	if i < _length and _source[i] == "[":
		return level
	return -1


func _skip_long_bracket(level: int) -> void:
	## Consuma `[=*[ ... ]=*]`; `_pos` punta alla parentesi aperta.
	_pos += level + 2
	while _pos < _length:
		if _source[_pos] == "\n":
			_line += 1
			_pos += 1
			continue
		if _source[_pos] == "]" and _closing_long_bracket(level):
			return
		_pos += 1
	_fail("commento lungo non terminato", _line)


func _closing_long_bracket(level: int) -> bool:
	var i := _pos + 1
	var seen := 0
	while i < _length and _source[i] == "=":
		seen += 1
		i += 1
	if seen == level and i < _length and _source[i] == "]":
		_pos = i + 1
		return true
	return false


func _read_name(line: int) -> void:
	var start := _pos
	while _pos < _length:
		var c := _source[_pos]
		if not (_is_alpha(c) or _is_digit(c) or c == "_"):
			break
		_pos += 1
	var text := _source.substr(start, _pos - start)
	var kind := "keyword" if KEYWORDS.has(text) else "name"
	_tokens.append({"t": kind, "v": text, "line": line})


func _read_number(line: int) -> void:
	var start := _pos
	if _source[_pos] == "0" and (_peek(1) == "x" or _peek(1) == "X"):
		_pos += 2
		var digits := ""
		while _pos < _length and _is_hex_digit(_source[_pos]):
			digits += _source[_pos]
			_pos += 1
		if digits == "":
			_fail("numero esadecimale non valido", line)
			return
		_tokens.append({"t": "number", "v": float(digits.hex_to_int()), "line": line})
		return
	var seen_dot := false
	while _pos < _length:
		var c := _source[_pos]
		if _is_digit(c):
			_pos += 1
		elif c == "." and not seen_dot:
			seen_dot = true
			_pos += 1
		else:
			break
	if _pos < _length and (_source[_pos] == "e" or _source[_pos] == "E"):
		_pos += 1
		if _pos < _length and (_source[_pos] == "+" or _source[_pos] == "-"):
			_pos += 1
		var exponent_start := _pos
		while _pos < _length and _is_digit(_source[_pos]):
			_pos += 1
		if exponent_start == _pos:
			_fail("esponente non valido", line)
			return
	var text := _source.substr(start, _pos - start)
	if not text.is_valid_float():
		_fail("numero non valido: %s" % text, line)
		return
	_tokens.append({"t": "number", "v": text.to_float(), "line": line})


func _read_string(quote: String, line: int) -> void:
	_pos += 1
	var output := ""
	while _pos < _length:
		var c := _source[_pos]
		if c == quote:
			_pos += 1
			_tokens.append({"t": "string", "v": output, "line": line})
			return
		if c == "\n":
			_fail("stringa non terminata", line)
			return
		if c == "\\":
			_pos += 1
			if _pos >= _length:
				break
			var escaped := _source[_pos]
			match escaped:
				"n":
					output += "\n"
				"t":
					output += "\t"
				"r":
					output += "\r"
				"a":
					output += "\u0007"
				"b":
					output += "\b"
				"f":
					output += "\f"
				"v":
					output += "\u000b"
				"\\":
					output += "\\"
				"\"":
					output += "\""
				"'":
					output += "'"
				"\n":
					output += "\n"
					_line += 1
				"x":
					var hex := _source.substr(_pos + 1, 2)
					if hex.length() == 2 and hex.is_valid_hex_number(false):
						output += char(hex.hex_to_int())
						_pos += 2
					else:
						_fail("escape esadecimale non valido", line)
						return
				_:
					if _is_digit(escaped):
						var digits := escaped
						var extra := 0
						while extra < 2 and _pos + 1 < _length and _is_digit(_source[_pos + 1]):
							_pos += 1
							digits += _source[_pos]
							extra += 1
						output += char(digits.to_int())
					else:
						output += escaped
			_pos += 1
			continue
		output += c
		_pos += 1
	_fail("stringa non terminata", line)


func _read_long_string(line: int) -> void:
	var level := _long_bracket_level(_pos)
	_pos += level + 2
	if _pos < _length and _source[_pos] == "\n":
		_line += 1
		_pos += 1
	var start := _pos
	var content := ""
	while _pos < _length:
		if _source[_pos] == "]" and _closing_long_bracket(level):
			content = _source.substr(start, _pos - (level + 2) - start)
			_tokens.append({"t": "string", "v": content, "line": line})
			return
		if _source[_pos] == "\n":
			_line += 1
		_pos += 1
	_fail("stringa lunga non terminata", line)


func _read_operator(line: int) -> void:
	var three := _source.substr(_pos, 3)
	if three == "...":
		_pos += 3
		_tokens.append({"t": "op", "v": "...", "line": line})
		return
	var two := _source.substr(_pos, 2)
	if two in ["..", "==", "~=", "<=", ">="]:
		_pos += 2
		_tokens.append({"t": "op", "v": two, "line": line})
		return
	var c := _source[_pos]
	if c in ["+", "-", "*", "/", "%", "^", "#", "=", "<", ">", "(", ")", "{", "}",
			"[", "]", ";", ":", ",", "."]:
		_pos += 1
		_tokens.append({"t": "op", "v": c, "line": line})
		return
	_fail("carattere non riconosciuto: %s" % c, line)
