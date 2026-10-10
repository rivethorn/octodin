#+feature dynamic-literals
package dotenv_tests

import "core:os"
import "core:strings"
import "core:testing"
import dotenv ".."

// expect_parsed parses `content` and checks it against `expected`.
@(private="file")
expect_parsed :: proc(t: ^testing.T, content: string, expected: map[string]string) {
	defer delete(expected)
	values := dotenv.parse(content)
	defer dotenv.destroy(values)
	testing.expect_value(t, len(values), len(expected))
	for k, want in expected {
		got, found := values[k]
		testing.expect(t, found, "expected key to be parsed")
		testing.expect_value(t, got, want)
	}
}

@(test)
test_parse_basic :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_BASIC_A=hello\nDOTENV_BASIC_B=8080\nDOTENV_BASIC_EMPTY=\n",
		{"DOTENV_BASIC_A" = "hello", "DOTENV_BASIC_B" = "8080", "DOTENV_BASIC_EMPTY" = ""},
	)
}

@(test)
test_parse_comments_and_blank :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"# full line comment\n\n   # indented comment\nDOTENV_CMT_A=1\n\nDOTENV_CMT_B=2 # trailing\nno-equals-here\n",
		{"DOTENV_CMT_A" = "1", "DOTENV_CMT_B" = "2"},
	)
}

@(test)
test_parse_comment_with_quote :: proc(t: ^testing.T) {
	// A quote character inside a comment must not corrupt later lines.
	expect_parsed(
		t,
		"# it's a comment\nDOTENV_QC_A=ok\n# say \"hi\"\nDOTENV_QC_B=also-ok\n",
		{"DOTENV_QC_A" = "ok", "DOTENV_QC_B" = "also-ok"},
	)
}

@(test)
test_parse_export_prefix :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"export DOTENV_EXP_A=1\nexport   DOTENV_EXP_B=2\nDOTENV_EXP_C=3\n",
		{"DOTENV_EXP_A" = "1", "DOTENV_EXP_B" = "2", "DOTENV_EXP_C" = "3"},
	)
}

@(test)
test_parse_whitespace :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"  DOTENV_WS_A  =  spaced  \n\tDOTENV_WS_B\t=\ttabs\t\n",
		{"DOTENV_WS_A" = "spaced", "DOTENV_WS_B" = "tabs"},
	)
}

@(test)
test_parse_quotes :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_QU_D=\"hello world\"\nDOTENV_QU_S='hello $WORLD \\n'\nDOTENV_QU_T=`hello $WORLD \\n`\nDOTENV_QU_H=\"keep # hash\"\nDOTENV_QU_TC=\"val\" # trailing comment\n",
		{
			"DOTENV_QU_D" = "hello world",
			"DOTENV_QU_S" = "hello $WORLD \\n",
			"DOTENV_QU_T" = "hello $WORLD \\n",
			"DOTENV_QU_H" = "keep # hash",
			"DOTENV_QU_TC" = "val",
		},
	)
}

@(test)
test_parse_double_quote_escapes :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_ESC_A=\"a\\nb\\tc\\\\d\\\"e\\$f\"\nDOTENV_ESC_B=\"tab\\there\"\n",
		{"DOTENV_ESC_A" = "a\nb\tc\\d\"e$f", "DOTENV_ESC_B" = "tab\there"},
	)
}

@(test)
test_parse_inline_comments :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_IC_A=bare # stripped\nDOTENV_IC_B=keep#nospace\nDOTENV_IC_C=val\t# tab comment\n",
		{"DOTENV_IC_A" = "bare", "DOTENV_IC_B" = "keep#nospace", "DOTENV_IC_C" = "val"},
	)
}

@(test)
test_parse_invalid_keys :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"1DOTENV_BAD=1\nDOTENV_HAS SPACE=2\nDOTENV-HAS-DASH=3\n=4\nDOTENV_GOOD=yes\n",
		{"DOTENV_GOOD" = "yes"},
	)
}

@(test)
test_parse_duplicates_last_wins :: proc(t: ^testing.T) {
	expect_parsed(t, "DOTENV_DUP=first\nDOTENV_DUP=second\n", {"DOTENV_DUP" = "second"})
}

@(test)
test_parse_expansion_from_file :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_EX_BASE=world\nDOTENV_EX_A=hello $DOTENV_EX_BASE\nDOTENV_EX_B=\"${DOTENV_EX_BASE}!\"\nDOTENV_EX_C=${DOTENV_EX_MISSING}\nDOTENV_EX_D=prefix-${DOTENV_EX_MISSING}-suffix\n",
		{
			"DOTENV_EX_BASE"  = "world",
			"DOTENV_EX_A"     = "hello world",
			"DOTENV_EX_B"     = "world!",
			"DOTENV_EX_C"     = "",
			"DOTENV_EX_D"     = "prefix--suffix",
		},
	)
}

@(test)
test_parse_expansion_defaults :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_DF_A=${DOTENV_DF_MISSING:-fallback}\nDOTENV_DF_B=${DOTENV_DF_MISSING-fallback}\nDOTENV_DF_EMPTY=\nDOTENV_DF_C=${DOTENV_DF_EMPTY:-fallback}\nDOTENV_DF_D=${DOTENV_DF_EMPTY-fallback}\n",
		{
			"DOTENV_DF_A" = "fallback",
			"DOTENV_DF_B" = "fallback",
			"DOTENV_DF_EMPTY" = "",
			"DOTENV_DF_C" = "fallback",
			"DOTENV_DF_D" = "",
		},
	)
}

@(test)
test_parse_expansion_escapes :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_ES_BASE=x\nDOTENV_ES_A=\\$DOTENV_ES_BASE\nDOTENV_ES_B=\"$DOTENV_ES_BASE\"\nDOTENV_ES_C=lone-$-here\n",
		{"DOTENV_ES_BASE" = "x", "DOTENV_ES_A" = "$DOTENV_ES_BASE", "DOTENV_ES_B" = "x", "DOTENV_ES_C" = "lone-$-here"},
	)
}

@(test)
test_parse_expansion_from_environment :: proc(t: ^testing.T) {
	os.set_env("DOTENV_TEST_EXT", "outer")
	defer os.unset_env("DOTENV_TEST_EXT")
	expect_parsed(
		t,
		"DOTENV_ENV_A=got-$DOTENV_TEST_EXT\nDOTENV_ENV_B=${DOTENV_TEST_EXT:-nope}\n",
		{"DOTENV_ENV_A" = "got-outer", "DOTENV_ENV_B" = "outer"},
	)
}

@(test)
test_parse_expansion_file_shadows_environment :: proc(t: ^testing.T) {
	os.set_env("DOTENV_TEST_SHADOW", "outer")
	defer os.unset_env("DOTENV_TEST_SHADOW")
	expect_parsed(
		t,
		"DOTENV_TEST_SHADOW=inner\nDOTENV_SH_USE=$DOTENV_TEST_SHADOW\n",
		{"DOTENV_TEST_SHADOW" = "inner", "DOTENV_SH_USE" = "inner"},
	)
}

@(test)
test_parse_multiline_double_quoted :: proc(t: ^testing.T) {
	expect_parsed(
		t,
		"DOTENV_ML=\"line1\nline2\"\nDOTENV_ML_AFTER=done\n",
		{"DOTENV_ML" = "line1\nline2", "DOTENV_ML_AFTER" = "done"},
	)
}

@(test)
test_parse_crlf_and_bom :: proc(t: ^testing.T) {
	content := strings.concatenate(
		{"\uFEFF", "DOTENV_BOM_A=1\r\nDOTENV_BOM_B=2\r\n"},
		context.temp_allocator,
	)
	expect_parsed(t, content, {"DOTENV_BOM_A" = "1", "DOTENV_BOM_B" = "2"})
}

// write_temp_env writes `content` to a unique file in the OS temp dir.
@(private="file")
write_temp_env :: proc(t: ^testing.T, name, content: string) -> string {
	dir, dir_err := os.temp_directory(context.temp_allocator)
	testing.expect(t, dir_err == nil, "failed to locate temp dir")
	path := strings.concatenate({dir, "/odin_dotenv_", name, ".env"}, context.temp_allocator)
	err := os.write_entire_file(path, content)
	testing.expect(t, err == nil, "failed to write temp .env file")
	return strings.clone(path)
}

@(test)
test_load_file :: proc(t: ^testing.T) {
	path := write_temp_env(t, "load", "DOTENV_LOAD_A=alpha\nDOTENV_LOAD_B=\"beta gamma\"\n")
	defer delete(path)
	defer os.remove(path)
	defer os.unset_env("DOTENV_LOAD_A")
	defer os.unset_env("DOTENV_LOAD_B")

	applied, err := dotenv.load(path)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, applied, 2)
	testing.expect_value(t, os.get_env("DOTENV_LOAD_A", context.temp_allocator), "alpha")
	testing.expect_value(t, os.get_env("DOTENV_LOAD_B", context.temp_allocator), "beta gamma")
}

@(test)
test_load_missing_file :: proc(t: ^testing.T) {
	applied, err := dotenv.load("/definitely/not/here/odin-dotenv-missing.env")
	testing.expect_value(t, err, dotenv.Error.File_Not_Found)
	testing.expect_value(t, applied, 0)
}

@(test)
test_load_keeps_existing_by_default :: proc(t: ^testing.T) {
	path := write_temp_env(t, "keep", "DOTENV_KEEP_A=from-file\nDOTENV_KEEP_B=from-file\n")
	defer delete(path)
	defer os.remove(path)
	defer os.unset_env("DOTENV_KEEP_A")
	defer os.unset_env("DOTENV_KEEP_B")

	os.set_env("DOTENV_KEEP_A", "from-env")

	applied, err := dotenv.load(path)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, applied, 1) // only B is new
	testing.expect_value(t, os.get_env("DOTENV_KEEP_A", context.temp_allocator), "from-env")
	testing.expect_value(t, os.get_env("DOTENV_KEEP_B", context.temp_allocator), "from-file")
}

@(test)
test_load_override_replaces :: proc(t: ^testing.T) {
	path := write_temp_env(t, "override", "DOTENV_OVER_A=from-file\n")
	defer delete(path)
	defer os.remove(path)
	defer os.unset_env("DOTENV_OVER_A")

	os.set_env("DOTENV_OVER_A", "from-env")

	applied, err := dotenv.load(path, true)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, applied, 1)
	testing.expect_value(t, os.get_env("DOTENV_OVER_A", context.temp_allocator), "from-file")
}

@(test)
test_overload_replaces :: proc(t: ^testing.T) {
	path := write_temp_env(t, "overload", "DOTENV_OL_A=from-file\n")
	defer delete(path)
	defer os.remove(path)
	defer os.unset_env("DOTENV_OL_A")

	os.set_env("DOTENV_OL_A", "from-env")

	applied, err := dotenv.overload(path)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, applied, 1)
	testing.expect_value(t, os.get_env("DOTENV_OL_A", context.temp_allocator), "from-file")
}

@(test)
test_read_does_not_touch_environment :: proc(t: ^testing.T) {
	path := write_temp_env(t, "read", "DOTENV_READ_A=zzz\n")
	defer delete(path)
	defer os.remove(path)

	os.unset_env("DOTENV_READ_A")
	values, err := dotenv.read(path)
	defer dotenv.destroy(values)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, values["DOTENV_READ_A"], "zzz")
	_, found := os.lookup_env("DOTENV_READ_A", context.temp_allocator)
	testing.expect(t, !found, "read must not export into the environment")
}

@(test)
test_apply_counts_only_exported :: proc(t: ^testing.T) {
	os.set_env("DOTENV_AP_A", "keep-me")
	defer os.unset_env("DOTENV_AP_A")
	defer os.unset_env("DOTENV_AP_B")

	values := map[string]string {
		"DOTENV_AP_A" = "new",
		"DOTENV_AP_B" = "fresh",
	}
	defer delete(values)

	applied, err := dotenv.apply(values)
	testing.expect_value(t, err, dotenv.Error.None)
	testing.expect_value(t, applied, 1)
	testing.expect_value(t, os.get_env("DOTENV_AP_A", context.temp_allocator), "keep-me")
	testing.expect_value(t, os.get_env("DOTENV_AP_B", context.temp_allocator), "fresh")
}
