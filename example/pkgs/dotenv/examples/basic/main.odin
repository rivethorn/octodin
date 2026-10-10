package main

import "core:fmt"
import "core:os"
import dotenv "../.."

main :: proc() {
	applied, err := dotenv.load()
	if err != .None {
		fmt.printfln("note: no .env file loaded (%v)", err)
	} else {
		fmt.printfln("loaded %d variable(s) from .env", applied)
	}
	fmt.printfln("HOST=%s", os.get_env("HOST", context.temp_allocator))
	fmt.printfln("PORT=%s", os.get_env("PORT", context.temp_allocator))
	fmt.printfln("GREETING=%s", os.get_env("GREETING", context.temp_allocator))
}
