# c02-the-voice

Companion repository for **c02 — The Voice** at
[thecodingidiot.com](https://thecodingidiot.com).

---

## Follow my journey

Working through c02 alongside the implementation pages? Build `tci_printf`
step by step, then run the tester.

Clone this repository and copy `test.sh` into your working directory:

```bash
git clone https://github.com/thecodingidiot-com/c02-the-voice.git
cp c02-the-voice/test.sh ~/c02-practice/
cd ~/c02-practice
make re
bash test.sh
```

All 5 checks must pass before the chapter is complete.

---

## Follow your journey

Building `tci_printf` independently? Here is the full project brief.

**Target:** extend libtci (from c01) with a variadic output function.

**Mandatory specifiers:** `%c`, `%s`, `%p`, `%d`, `%i`, `%u`, `%x`, `%X`,
`%%`

**Signature:**

```c
int tci_printf(const char *fmt, ...);
```

Returns the number of characters written, matching libc `printf` exactly.
Must not call `printf`, `puts`, or any other output function — `write()` is
the only permitted output primitive.

**Compile flags:** `gcc -Wall -Wextra -g -std=c99`

**Bonus:** flags (`-`, `0`, `+`, space, `#`), field width, precision.

**Start from libtci.** Add `tci_printf.c` to the Makefile and implement it
alongside the existing 29 functions. `make re` must produce `libtci.a` with
no warnings.

Build and test your own version first. Use `solution/` to compare once you
are done, not before.

---

## What the tester checks

1. **make re** — clean rebuild; `libtci.a` produced; no compiler warnings.
2. **compile** — links an embedded test runner against your `libtci.a`.
3. **correctness** — runs the test runner; every check must pass.
   - `tci_printf` output is compared byte-for-byte against `snprintf`.
   - Return values are compared against `snprintf` for every format string.
4. **valgrind** — runs the test runner under valgrind; no leaks or errors.
5. **sanitisers** — recompiles `tci_*.c` with `-fsanitize=address,undefined`
   and runs the result; no sanitiser errors.

---

## License

MIT License. See [LICENSE](LICENSE).
