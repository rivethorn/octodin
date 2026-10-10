// dotenv reads `.env` files and exports them into the process environment.
//
// Call `load` once at the start of `main`, then use `os.get_env` as usual:
//
// 	package main
//
// 	import "core:os"
// 	import dotenv "path/to/dotenv"
//
// 	main :: proc() {
// 		_ = dotenv.load()
// 		port := os.get_env("PORT", context.allocator)
// 	}
//
// Supported file format (one `KEY=VALUE` pair per line):
//
// 	# full-line comments start with `#`
// 	PORT=8080
// 	export HOST=localhost # optional `export` prefix
// 	GREETING="hello world" # double quotes allow escapes and expansion
// 	LITERAL='no $expansion \n here' # single quotes and backticks are literal
// 	UNQUOTED=some value # trailing ` #` comment is stripped from unquoted values
// 	EMPTY=
// 	URL="https://${HOST}:${PORT}/api" # `$VAR` and `${VAR}` expand from
// 	                                   # earlier entries or the environment
// 	FALLBACK="${MISSING:-default}" # `:-` / `-` defaults are supported
//
// Rules:
//   - Blank lines and lines without `=` are ignored.
//   - Keys must match `[A-Za-z_][A-Za-z0-9_]*`; anything else is ignored.
//   - Existing environment variables are kept unless `override` is set.
//   - Double-quoted values may span multiple lines and understand the
//     escapes `\n \r \t \b \f \v \0 \\ \" \' \$ ` + backslash-backtick.
//   - A missing file is reported as `Error.File_Not_Found`, never a panic
//     (see `must_load` for the panicking variant).
package dotenv

import "base:runtime"
import "core:os"
import "core:strings"

// Error is the set of failures reported by `load`, `read` and `apply`.
Error :: enum {
	None,
	// File_Not_Found is returned when the file cannot be opened or read.
	File_Not_Found,
	// Set_Env_Failed is returned when a variable cannot be exported
	// into the process environment.
	Set_Env_Failed,
}

// load reads the file at `path`, parses it, and exports every variable into
// the process environment so values are visible through `os.get_env`.
//
// Variables already present in the environment are left untouched unless
// `override` is set. Returns how many variables were exported.
load :: proc(path: string = ".env", override := false) -> (applied: int, err: Error) {
	values, read_err := read(path)
	if read_err != .None {
		return 0, read_err
	}
	defer destroy(values)
	return apply(values, override)
}

// overload is `load` with overriding enabled: values from the file always
// win over variables already present in the environment.
overload :: proc(path: string = ".env") -> (applied: int, err: Error) {
	return load(path, true)
}

// must_load is `load` for programs where the file is required: it panics
// when the file cannot be loaded.
must_load :: proc(path: string = ".env", override := false) -> (applied: int) {
	n, err := load(path, override)
	if err != .None {
		panic(
			strings.concatenate(
				{"dotenv: unable to load file \"", path, "\""},
				context.temp_allocator,
			),
		)
	}
	return n
}

// read loads and parses the file at `path` without touching the process
// environment. The caller owns the returned map; free it with `destroy`.
read :: proc(
	path: string,
	allocator := context.allocator,
) -> (
	values: map[string]string,
	err: Error,
) {
	data, read_err := os.read_entire_file_from_path(path, context.allocator)
	if read_err != nil {
		return nil, .File_Not_Found
	}
	defer delete(data)
	return parse(string(data), allocator), .None
}

// parse converts `.env`-formatted `content` into a map without touching the
// process environment. The caller owns the returned map; free it with
// `destroy`. `$VAR` / `${VAR}` references expand against earlier entries
// first, then the process environment.
parse :: proc(content: string, allocator := context.allocator) -> (values: map[string]string) {
	values = make(map[string]string, allocator = allocator)
	text := content
	if strings.has_prefix(text, "\uFEFF") {
		text = text[len("\uFEFF"):]
	}
	entries := split_entries(text)
	defer delete(entries, context.temp_allocator)
	for entry in entries {
		key, value, ok := parse_entry(entry, values)
		if !ok {
			continue
		}
		set_map_value(&values, key, value, allocator)
	}
	return values
}

// apply exports every entry of `values` into the process environment.
//
// Variables already present in the environment are left untouched unless
// `override` is set. Returns how many variables were exported.
apply :: proc(values: map[string]string, override := false) -> (applied: int, err: Error) {
	for key, value in values {
		if !override {
			if _, found := os.lookup_env(key, context.temp_allocator); found {
				continue
			}
		}
		if os.set_env(key, value) != nil {
			return applied, .Set_Env_Failed
		}
		applied += 1
	}
	return applied, .None
}

// destroy frees a map returned by `parse` or `read`, including its keys and
// values. `allocator` must be the one the map was created with.
destroy :: proc(values: map[string]string, allocator := context.allocator) {
	for k, v in values {
		delete(k, allocator)
		delete(v, allocator)
	}
	delete(values)
}

// parse_entry parses a single logical line. The returned key/value strings
// are owned by the temporary allocator; the caller must clone them.
@(private)
parse_entry :: proc(
	entry: string,
	values: map[string]string,
) -> (
	key, value: string,
	ok: bool,
) {
	line := strings.trim_space(entry)
	if len(line) == 0 || line[0] == '#' {
		return "", "", false
	}
	if strings.has_prefix(line, "export") &&
	   len(line) > 6 &&
	   (line[6] == ' ' || line[6] == '\t') {
		line = strings.trim_space(line[6:])
	}
	eq := strings.index_byte(line, '=')
	if eq < 0 {
		return "", "", false
	}
	raw_key := strings.trim_space(line[:eq])
	if !is_valid_key(raw_key) {
		return "", "", false
	}
	parsed := parse_raw_value(strings.trim_space(line[eq + 1:]), values)
	return strings.clone(raw_key, context.temp_allocator),
		strings.clone(parsed, context.temp_allocator),
		true
}

// parse_raw_value unquotes, unescapes and expands a raw value. The result
// aliases `raw` or temporary memory; the caller must clone it.
@(private)
parse_raw_value :: proc(raw: string, values: map[string]string) -> string {
	if len(raw) == 0 {
		return ""
	}
	switch raw[0] {
	case '"':
		inner, _ := scan_quoted(raw)
		return expand_double_quoted(inner, values)
	case '\'', '`':
		inner, _ := scan_quoted(raw)
		return inner
	}
	return expand_unquoted(strings.trim_right_space(strip_inline_comment(raw)), values)
}

// scan_quoted returns the contents between the opening quote at `s[0]` and
// its matching close. Anything after the closing quote (e.g. a trailing
// comment) is ignored. Unterminated values yield the rest of the string.
@(private)
scan_quoted :: proc(s: string) -> (inner: string, closed: bool) {
	if s[0] == '"' {
		escaped := false
		for i := 1; i < len(s); i += 1 {
			c := s[i]
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == '"' {
				return s[1:i], true
			}
		}
		return s[1:], false
	}
	for i := 1; i < len(s); i += 1 {
		if s[i] == s[0] {
			return s[1:i], true
		}
	}
	return s[1:], false
}

// expand_double_quoted unescapes and expands a double-quoted value.
@(private)
expand_double_quoted :: proc(s: string, values: map[string]string) -> string {
	sb: strings.Builder
	strings.builder_init(&sb, context.temp_allocator)
	i := 0
	for i < len(s) {
		c := s[i]
		if c == '\\' && i + 1 < len(s) {
			n := s[i + 1]
			switch n {
			case 'n':
				strings.write_string(&sb, "\n")
			case 'r':
				strings.write_string(&sb, "\r")
			case 't':
				strings.write_string(&sb, "\t")
			case 'b':
				strings.write_string(&sb, "\b")
			case 'f':
				strings.write_string(&sb, "\f")
			case 'v':
				strings.write_string(&sb, "\v")
			case '0':
				strings.write_byte(&sb, 0)
			case '\\', '"', '\'', '$', '`':
				strings.write_byte(&sb, n)
			case:
				strings.write_byte(&sb, '\\')
				strings.write_byte(&sb, n)
			}
			i += 2
			continue
		}
		if c == '$' {
			i = write_expansion(&sb, s, i, values)
			continue
		}
		strings.write_byte(&sb, c)
		i += 1
	}
	return strings.to_string(sb)
}

// expand_unquoted expands `$VAR` / `${VAR}` in an unquoted value. `\$` and
// `\#` escape to literal `$` and `#`; other backslashes are kept as-is.
@(private)
expand_unquoted :: proc(s: string, values: map[string]string) -> string {
	if strings.index_byte(s, '$') < 0 && strings.index_byte(s, '\\') < 0 {
		return s
	}
	sb: strings.Builder
	strings.builder_init(&sb, context.temp_allocator)
	i := 0
	for i < len(s) {
		c := s[i]
		if c == '\\' && i + 1 < len(s) && (s[i + 1] == '$' || s[i + 1] == '#') {
			strings.write_byte(&sb, s[i + 1])
			i += 2
			continue
		}
		if c == '$' {
			i = write_expansion(&sb, s, i, values)
			continue
		}
		strings.write_byte(&sb, c)
		i += 1
	}
	return strings.to_string(sb)
}

// write_expansion writes the value of the `$VAR` / `${VAR}` reference at
// `s[i]` (where `s[i] == '$'`) and returns the index just past it.
@(private)
write_expansion :: proc(
	sb: ^strings.Builder,
	s: string,
	i: int,
	values: map[string]string,
) -> int {
	if i + 1 >= len(s) {
		strings.write_byte(sb, '$')
		return i + 1
	}
	if s[i + 1] == '{' {
		rest := s[i + 2:]
		end := strings.index_byte(rest, '}')
		if end < 0 {
			strings.write_byte(sb, '$')
			return i + 1
		}
		name, def, colon, has_default := split_default(rest[:end])
		val, found := lookup_variable(name, values)
		switch {
		case has_default && (!found || (colon && val == "")):
			strings.write_string(sb, def)
		case found:
			strings.write_string(sb, val)
		}
		return i + 2 + end + 1
	}
	if is_name_start(s[i + 1]) {
		j := i + 2
		for j < len(s) && is_name_char(s[j]) {
			j += 1
		}
		if val, found := lookup_variable(s[i + 1:j], values); found {
			strings.write_string(sb, val)
		}
		return j
	}
	strings.write_byte(sb, '$')
	return i + 1
}

// split_default splits `${name}`, `${name-default}` and `${name:-default}`.
@(private)
split_default :: proc(s: string) -> (name, def: string, colon, has_default: bool) {
	for i := 0; i < len(s); i += 1 {
		if s[i] == ':' && i + 1 < len(s) && s[i + 1] == '-' {
			return s[:i], s[i + 2:], true, true
		}
		if s[i] == '-' {
			return s[:i], s[i + 1:], false, true
		}
	}
	return s, "", false, false
}

// lookup_variable resolves a name against already-parsed entries first,
// then the process environment.
@(private)
lookup_variable :: proc(name: string, values: map[string]string) -> (value: string, found: bool) {
	if v, ok := values[name]; ok {
		return v, true
	}
	return os.lookup_env(name, context.temp_allocator)
}

// strip_inline_comment cuts an unquoted value at the first ` #` or tab-`#`.
@(private)
strip_inline_comment :: proc(s: string) -> string {
	for i := 0; i < len(s); i += 1 {
		if s[i] == '#' && i > 0 && (s[i - 1] == ' ' || s[i - 1] == '\t') {
			return s[:i]
		}
	}
	return s
}

// split_entries splits content into logical lines, keeping newlines that
// sit inside quotes (for multiline values) and cutting `#` comments that
// sit outside quotes.
@(private)
split_entries :: proc(content: string) -> (entries: []string) {
	lines: [dynamic]string
	lines.allocator = context.temp_allocator
	start, cut := 0, -1
	in_single, in_double, in_tick := false, false, false
	escaped, only_space := false, true
	i := 0
	for i < len(content) {
		c := content[i]
		switch {
		case in_double:
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == '"' {
				in_double = false
			}
			only_space = false
		case in_single:
			if c == '\'' {
				in_single = false
			}
			only_space = false
		case in_tick:
			if c == '`' {
				in_tick = false
			}
			only_space = false
		case c == '"' && cut < 0:
			in_double = true
			only_space = false
		case c == '\'' && cut < 0:
			in_single = true
			only_space = false
		case c == '`' && cut < 0:
			in_tick = true
			only_space = false
		case c == '#' &&
			(only_space || (i > 0 && (content[i - 1] == ' ' || content[i - 1] == '\t'))):
			if cut < 0 {
				cut = i
			}
			for i < len(content) && content[i] != '\n' {
				i += 1
			}
			continue
		case c == '\n':
			end := cut if cut >= 0 else i
			append(&lines, content[start:end])
			start = i + 1
			cut = -1
			only_space = true
		case c == ' ' || c == '\t' || c == '\r':
		case:
			only_space = false
		}
		i += 1
	}
	end := cut if cut >= 0 else len(content)
	append(&lines, content[start:end])
	return lines[:]
}

// is_valid_key reports whether a key matches `[A-Za-z_][A-Za-z0-9_]*`.
@(private)
is_valid_key :: proc(key: string) -> bool {
	c := key[0] if len(key) > 0 else 0
	if !(c == '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
		return false
	}
	for i := 1; i < len(key); i += 1 {
		c = key[i]
		if !(c == '_' ||
			   (c >= 'A' && c <= 'Z') ||
			   (c >= 'a' && c <= 'z') ||
			   (c >= '0' && c <= '9')) {
			return false
		}
	}
	return true
}

@(private)
is_name_start :: proc(c: byte) -> bool {
	return c == '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

@(private)
is_name_char :: proc(c: byte) -> bool {
	return is_name_start(c) || (c >= '0' && c <= '9')
}

// set_map_value inserts an owned copy of a key/value pair, freeing any
// previous entry stored under the same key.
@(private)
set_map_value :: proc(
	m: ^map[string]string,
	key, value: string,
	allocator: runtime.Allocator,
) {
	if _, found := m^[key]; found {
		for k, v in m^ {
			if k == key {
				delete(k, allocator)
				delete(v, allocator)
				delete_key(m, k)
				break
			}
		}
	}
	m[strings.clone(key, allocator)] = strings.clone(value, allocator)
}
