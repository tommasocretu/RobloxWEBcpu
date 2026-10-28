class_name LuaPrototype
extends RefCounted
## Prototipo compilato: istruzioni, costanti, sotto-funzioni e descrittori upvalue.
## Le istruzioni sono dizionari `{op, a, b, c, line}` per leggibilità; il costo è
## accettabile per gli script di un'esperienza RobloxWeb.

enum Op {
	LOADK,
	LOADNIL,
	LOADTRUE,
	LOADFALSE,
	LOAD_LOCAL,
	STORE_LOCAL,
	NEW_LOCAL,
	LOAD_UPVAL,
	STORE_UPVAL,
	LOAD_GLOBAL,
	STORE_GLOBAL,
	GET_INDEX,
	SET_INDEX,
	GET_FIELD,
	SET_FIELD,
	SET_ARRAY,
	SET_HASH,
	NEW_TABLE,
	DUP,
	POP,
	SWAP,
	PUSH_MARK,
	ADJUST,
	RETURN_MARK,
	ADD,
	SUB,
	MUL,
	DIV,
	MOD,
	POW,
	CONCAT,
	EQ,
	NE,
	LT,
	LE,
	GT,
	GE,
	UNM,
	NOT,
	LEN,
	JUMP,
	JUMP_IF_FALSE,
	JUMP_IF_TRUE,
	JUMP_IF_FALSE_KEEP,
	JUMP_IF_TRUE_KEEP,
	FOR_CHECK,
	CALL,
	CALL_MARK,
	VARARG,
	RETURN,
	CLOSURE,
	TFORRESULT,
}

var name := "script"
var instructions: Array = []
var constants: Array = []
var protos: Array = []
var num_params := 0
var is_vararg := false
var max_slots := 0
var upvalues: Array = []
