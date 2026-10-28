class_name LuaParser
extends RefCounted
## Parser ricorsivo discendente per il subset Lua 5.1 usato da RobloxWeb.
## Produce un AST di dizionari; ogni nodo ha `t` (tipo) e `line`.

const BIN_PREC := {
	"or": [1, 1],
	"and": [2, 1],
	"<": [3, 1], ">": [3, 1], "<=": [3, 1], ">=": [3, 1], "~=": [3, 1], "==": [3, 1],
	"..": [4, 0],
	"+": [5, 1], "-": [5, 1],
	"*": [6, 1], "/": [6, 1], "%": [6, 1],
	"^": [8, 0],
}
const UNARY_PREC := 7

var error_message := ""
var error_line := 0

var _tokens: Array = []
var _pos := 0


func parse(tokens: Array) -> Array:
	_tokens = tokens
	_pos = 0
	error_message = ""
	error_line = 0
	if _tokens.is_empty():
		_fail("token mancanti", 1)
		return []
	var chunk := _parse_block(["eof"])
	if not _failed():
		_expect_type("eof")
	return chunk


func _failed() -> bool:
	return error_message != ""


func _fail(message: String, line := 0) -> void:
	if not _failed():
		error_message = message
		error_line = line if line > 0 else _line()


func _token(offset := 0) -> Dictionary:
	var index := _pos + offset
	if index < 0:
		index = 0
	if index >= _tokens.size():
		return _tokens[_tokens.size() - 1]
	return _tokens[index]


func _line() -> int:
	return int(_token()["line"])


func _at_end() -> bool:
	return str(_token()["t"]) == "eof"


func _check_type(kind: String, value = null) -> bool:
	var token := _token()
	if str(token["t"]) != kind:
		return false
	return value == null or token["v"] == value


func _check_keyword(value: String) -> bool:
	return _check_type("keyword", value)


func _check_op(value: String) -> bool:
	return _check_type("op", value)


func _accept_keyword(value: String) -> bool:
	if _check_keyword(value):
		_pos += 1
		return true
	return false


func _accept_op(value: String) -> bool:
	if _check_op(value):
		_pos += 1
		return true
	return false


func _expect_keyword(value: String) -> bool:
	if _check_keyword(value):
		_pos += 1
		return true
	_fail("atteso \"%s\"" % value, _line())
	return false


func _expect_op(value: String) -> bool:
	if _check_op(value):
		_pos += 1
		return true
	_fail("atteso \"%s\"" % value, _line())
	return false


func _expect_type(kind: String, value = null) -> bool:
	if _check_type(kind, value):
		_pos += 1
		return true
	_fail("atteso %s" % kind, _line())
	return false


func _expect_name() -> String:
	if _check_type("name"):
		var value := str(_token()["v"])
		_pos += 1
		return value
	_fail("atteso un nome", _line())
	return ""


func _is_block_end(terminators: Array) -> bool:
	if _at_end():
		return true
	var token := _token()
	var kind := str(token["t"])
	if kind == "keyword" or kind == "op":
		return terminators.has(str(token["v"]))
	return false


func _parse_block(terminators: Array) -> Array:
	var statements: Array = []
	while not _at_end() and not _is_block_end(terminators):
		if _failed():
			break
		if _accept_op(";"):
			continue
		var statement := _parse_statement()
		if statement.is_empty():
			break
		statements.append(statement)
		if str(statement.get("t", "")) in ["return", "break"]:
			while _accept_op(";"):
				pass
			break
	return statements


func _parse_statement() -> Dictionary:
	var line := _line()
	var token := _token()
	if str(token["t"]) == "keyword":
		match str(token["v"]):
			"if":
				return _parse_if()
			"while":
				return _parse_while()
			"repeat":
				return _parse_repeat()
			"for":
				return _parse_for()
			"do":
				_pos += 1
				var body := _parse_block(["end"])
				_expect_keyword("end")
				return {"t": "do", "body": body, "line": line}
			"function":
				return _parse_function_statement()
			"local":
				return _parse_local()
			"return":
				_pos += 1
				var exprs: Array = []
				if not _at_end() and not _check_keyword("end") and not _check_keyword("else")\
						and not _check_keyword("elseif") and not _check_keyword("until"):
					exprs = _parse_expr_list()
				return {"t": "return", "exprs": exprs, "line": line}
			"break":
				_pos += 1
				return {"t": "break", "line": line}
	return _parse_expression_statement()


func _parse_if() -> Dictionary:
	var line := _line()
	_pos += 1
	var clauses: Array = []
	var condition := _parse_expr()
	_expect_keyword("then")
	var body := _parse_block(["elseif", "else", "end"])
	clauses.append({"cond": condition, "body": body})
	var fallback: Array = []
	while _accept_keyword("elseif"):
		var elseif_condition := _parse_expr()
		_expect_keyword("then")
		var elseif_body := _parse_block(["elseif", "else", "end"])
		clauses.append({"cond": elseif_condition, "body": elseif_body})
	if _accept_keyword("else"):
		fallback = _parse_block(["end"])
	_expect_keyword("end")
	return {"t": "if", "clauses": clauses, "else": fallback, "line": line}


func _parse_while() -> Dictionary:
	var line := _line()
	_pos += 1
	var condition := _parse_expr()
	_expect_keyword("do")
	var body := _parse_block(["end"])
	_expect_keyword("end")
	return {"t": "while", "cond": condition, "body": body, "line": line}


func _parse_repeat() -> Dictionary:
	var line := _line()
	_pos += 1
	var body := _parse_block(["until"])
	_expect_keyword("until")
	var condition := _parse_expr()
	return {"t": "repeat", "body": body, "cond": condition, "line": line}


func _parse_for() -> Dictionary:
	var line := _line()
	_pos += 1
	var first := _expect_name()
	if _accept_op("="):
		var start := _parse_expr()
		if not _expect_op(","):
			return {}
		var stop := _parse_expr()
		var step = null
		if _accept_op(","):
			step = _parse_expr()
		_expect_keyword("do")
		var body := _parse_block(["end"])
		_expect_keyword("end")
		return {
			"t": "fornum", "name": first, "start": start, "stop": stop,
			"step": step, "body": body, "line": line,
		}
	var names: Array = [first]
	while _accept_op(","):
		names.append(_expect_name())
	if not _expect_keyword("in"):
		return {}
	var exprs := _parse_expr_list()
	_expect_keyword("do")
	var body := _parse_block(["end"])
	_expect_keyword("end")
	return {"t": "forin", "names": names, "exprs": exprs, "body": body, "line": line}


func _parse_function_statement() -> Dictionary:
	var line := _line()
	_pos += 1
	var target := _parse_function_name()
	if target.is_empty():
		return {}
	var function_node := _parse_funcbody(line)
	if target.has("method_name"):
		var params: Array = function_node.get("params", [])
		params.insert(0, "self")
		function_node["params"] = params
		target["target"] = {"t": "index", "obj": target["target"], "key": _string_node(
			str(target["method_name"]), line
		), "line": line}
		target.erase("method_name")
	return {"t": "functiondecl", "target": target.get("target"), "func": function_node, "line": line}


func _parse_function_name() -> Dictionary:
	var line := _line()
	var name := _expect_name()
	if name == "":
		return {}
	var target := {"t": "name", "v": name, "line": line}
	var method_name := ""
	while _accept_op("."):
		var part := _expect_name()
		target = {"t": "index", "obj": target, "key": _string_node(part, line), "line": line}
	if _accept_op(":"):
		method_name = _expect_name()
	return {"target": target, "method_name": method_name}


func _parse_local() -> Dictionary:
	var line := _line()
	_pos += 1
	if _accept_keyword("function"):
		var name := _expect_name()
		var function_node := _parse_funcbody(line)
		return {"t": "localfunc", "name": name, "func": function_node, "line": line}
	var names: Array = [_expect_name()]
	while _accept_op(","):
		names.append(_expect_name())
	var exprs: Array = []
	if _accept_op("="):
		exprs = _parse_expr_list()
	return {"t": "local", "names": names, "exprs": exprs, "line": line}


func _parse_expression_statement() -> Dictionary:
	var line := _line()
	var expression := _parse_prefix_expression()
	if _failed():
		return {}
	if _check_op("=") or _check_op(","):
		var targets: Array = [expression]
		while _accept_op(","):
			targets.append(_parse_prefix_expression())
		for target in targets:
			if not _is_assignable(target):
				_fail("destinazione di assegnazione non valida", line)
				return {}
		if not _expect_op("="):
			return {}
		var exprs := _parse_expr_list()
		return {"t": "assign", "targets": targets, "exprs": exprs, "line": line}
	if str(expression.get("t", "")) != "call":
		_fail("istruzione non valida (attesa una chiamata o un'assegnazione)", line)
		return {}
	return {"t": "callstat", "call": expression, "line": line}


func _is_assignable(node: Dictionary) -> bool:
	return str(node.get("t", "")) in ["name", "index"]


func _parse_expr_list() -> Array:
	var exprs: Array = [_parse_expr()]
	while _accept_op(","):
		exprs.append(_parse_expr())
	return exprs


func _parse_expr(min_precedence := 1) -> Dictionary:
	var line := _line()
	var left: Dictionary
	var token := _token()
	if (str(token["t"]) == "op" and str(token["v"]) in ["-", "#"])\
			or (str(token["t"]) == "keyword" and str(token["v"]) == "not"):
		var op := str(token["v"])
		_pos += 1
		var operand := _parse_expr(UNARY_PREC)
		left = {"t": "unop", "op": op, "e": operand, "line": line}
	else:
		left = _parse_simple_expression()
	while not _failed():
		var next := _token()
		var next_kind := str(next["t"])
		if not (next_kind == "op" or (next_kind == "keyword" and str(next["v"]) in ["and", "or"])):
			break
		var op := str(next["v"])
		if not BIN_PREC.has(op):
			break
		var precedence: int = BIN_PREC[op][0]
		if precedence < min_precedence:
			break
		_pos += 1
		var right_min: int = precedence + 1 if int(BIN_PREC[op][1]) == 1 else precedence
		var right := _parse_expr(right_min)
		left = {"t": "binop", "op": op, "l": left, "r": right, "line": int(next["line"])}
	return left


func _parse_simple_expression() -> Dictionary:
	var line := _line()
	var token := _token()
	if str(token["t"]) == "keyword":
		match str(token["v"]):
			"nil":
				_pos += 1
				return {"t": "nil", "line": line}
			"true":
				_pos += 1
				return {"t": "true", "line": line}
			"false":
				_pos += 1
				return {"t": "false", "line": line}
			"function":
				_pos += 1
				return _parse_funcbody(line)
	if _check_type("number"):
		_pos += 1
		return {"t": "number", "v": float(token["v"]), "line": line}
	if _check_type("string"):
		_pos += 1
		return {"t": "string", "v": str(token["v"]), "line": line}
	if _check_op("..."):
		_pos += 1
		return {"t": "vararg", "line": line}
	if _check_op("{"):
		return _parse_table_constructor()
	if _check_type("name") or _check_op("("):
		return _parse_prefix_expression()
	_fail("espressione attesa", line)
	return {"t": "nil", "line": line}


func _parse_prefix_expression() -> Dictionary:
	var line := _line()
	var expression: Dictionary
	if _check_type("name"):
		expression = {"t": "name", "v": str(_token()["v"]), "line": line}
		_pos += 1
	elif _accept_op("("):
		var inner := _parse_expr()
		_expect_op(")")
		expression = {"t": "paren", "e": inner, "line": line}
	else:
		_fail("espressione di prefisso attesa", line)
		return {"t": "nil", "line": line}

	while not _failed():
		if _accept_op("."):
			var field := _expect_name()
			expression = {
				"t": "index", "obj": expression, "key": _string_node(field, line), "line": line,
			}
		elif _accept_op("["):
			var key := _parse_expr()
			_expect_op("]")
			expression = {"t": "index", "obj": expression, "key": key, "line": line}
		elif _accept_op(":"):
			var method_name := _expect_name()
			var args := _parse_call_args()
			expression = {
				"t": "call", "receiver": expression, "method": method_name,
				"args": args, "line": line,
			}
		elif _check_op("(") or _check_op("{") or _check_type("string"):
			var args := _parse_call_args()
			expression = {"t": "call", "fn": expression, "args": args, "line": line}
		else:
			break
	return expression


func _parse_call_args() -> Array:
	var line := _line()
	if _accept_op("("):
		var args: Array = []
		if not _check_op(")"):
			args = _parse_expr_list()
		_expect_op(")")
		return args
	if _check_op("{"):
		return [_parse_table_constructor()]
	if _check_type("string"):
		var value := str(_token()["v"])
		_pos += 1
		return [{"t": "string", "v": value, "line": line}]
	_fail("argomenti della chiamata attesi", line)
	return []


func _parse_funcbody(line: int) -> Dictionary:
	_expect_op("(")
	var params: Array = []
	var is_vararg := false
	if not _check_op(")"):
		if _check_op("..."):
			_pos += 1
			is_vararg = true
		else:
			params.append(_expect_name())
			while _accept_op(","):
				if _check_op("..."):
					_pos += 1
					is_vararg = true
					break
				params.append(_expect_name())
	_expect_op(")")
	var body := _parse_block(["end"])
	_expect_keyword("end")
	return {
		"t": "function", "params": params, "vararg": is_vararg,
		"body": body, "line": line,
	}


func _parse_table_constructor() -> Dictionary:
	var line := _line()
	_expect_op("{")
	var array: Array = []
	var hash: Array = []
	while not _check_op("}") and not _at_end():
		if _failed():
			break
		if _accept_op("["):
			var key := _parse_expr()
			_expect_op("]")
			if not _expect_op("="):
				break
			var value := _parse_expr()
			hash.append({"key": key, "value": value})
		elif _check_type("name") and str(_token(1)["t"]) == "op" and str(_token(1)["v"]) == "=":
			var key_name := str(_token()["v"])
			_pos += 1
			_pos += 1
			var value := _parse_expr()
			hash.append({"key": _string_node(key_name, line), "value": value})
		else:
			array.append(_parse_expr())
		if not (_accept_op(",") or _accept_op(";")):
			break
	_expect_op("}")
	return {"t": "table", "array": array, "hash": hash, "line": line}


func _string_node(value: String, line: int) -> Dictionary:
	return {"t": "string", "v": value, "line": line}
