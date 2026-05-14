#!/bin/bash
# c02 — The Voice / test.sh
#
# Tests tci_printf against libc printf.
# Copy this file into your working directory alongside libtci.a and all
# tci_*.c source files, then run:
#
#   bash test.sh

set -o pipefail

# ── colour ───────────────────────────────────────────────────────────────────

if [[ ! -t 1 ]]; then
    C_GREEN=""
    C_RED=""
    C_BOLD=""
    C_RESET=""
else
    C_GREEN="\033[0;32m"
    C_RED="\033[0;31m"
    C_BOLD="\033[1m"
    C_RESET="\033[0m"
fi

# ── state ─────────────────────────────────────────────────────────────────────

pass_count=0
fail_count=0
WORK_DIR=$(mktemp -d)

# ── cleanup ───────────────────────────────────────────────────────────────────

cleanup() {
    rm -f _runner _runner.c _runner_san
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ── helpers ───────────────────────────────────────────────────────────────────

hr() {
    echo "────────────────────────────────────────────────────────────────"
}

banner() {
    hr
    echo "  c02 — The Voice / test.sh"
    hr
}

pass() {
    local label="$1"
    printf "  ${C_GREEN}PASS${C_RESET}  %s\n" "$label"
    pass_count=$((pass_count + 1))
}

fail() {
    local label="$1"
    printf "  ${C_RED}FAIL${C_RESET}  %s\n" "$label"
    fail_count=$((fail_count + 1))
}

# ── pre-flight ────────────────────────────────────────────────────────────────

preflight() {
    local ok=1
    for tool in gcc make valgrind; do
        if ! command -v "$tool" &>/dev/null; then
            echo "error: $tool is not installed" >&2
            ok=0
        fi
    done
    if [[ ! -f Makefile ]]; then
        echo "error: Makefile not found in current directory" >&2
        ok=0
    fi
    if [[ $ok -eq 0 ]]; then
        exit 1
    fi
}

# ── embedded C test runner ────────────────────────────────────────────────────

write_runner() {
    cat > _runner.c << 'RUNNER_EOF'
#define _POSIX_C_SOURCE 200809L
#include "libtci.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>

static int g_pass;
static int g_fail;

static void check(const char *label, int ok)
{
    if (ok) {
        printf("  PASS  %s\n", label);
        g_pass++;
    } else {
        printf("  FAIL  %s\n", label);
        g_fail++;
    }
}

/*
 * Each test redirects stdout, calls tci_printf, restores stdout, then
 * compares output and return value against snprintf.
 *
 * ##__VA_ARGS__ is a GCC/Clang extension accepted in -std=c99 mode.
 */
#define TEST(label, fmt, ...) do {                                      \
    char    tci_buf[2048];                                               \
    char    libc_buf[2048];                                             \
    int     pipefd[2];                                                  \
    int     saved_fd;                                                   \
    int     tci_ret;                                                     \
    int     libc_ret;                                                   \
    ssize_t _n;                                                         \
    pipe(pipefd);                                                       \
    saved_fd = dup(STDOUT_FILENO);                                      \
    dup2(pipefd[1], STDOUT_FILENO);                                     \
    close(pipefd[1]);                                                   \
    tci_ret = tci_printf(fmt, ##__VA_ARGS__);                             \
    dup2(saved_fd, STDOUT_FILENO);                                      \
    close(saved_fd);                                                    \
    _n = read(pipefd[0], tci_buf, sizeof(tci_buf) - 1);                  \
    close(pipefd[0]);                                                   \
    tci_buf[_n > 0 ? _n : 0] = '\0';                                    \
    libc_ret = snprintf(libc_buf, sizeof(libc_buf), fmt, ##__VA_ARGS__);\
    check(label ": output",   strcmp(tci_buf, libc_buf) == 0);          \
    check(label ": retval",   tci_ret == libc_ret);                     \
} while (0)

/* ── %c ── */

static void test_percent_c(void)
{
    TEST("%c basic 'A'",       "%c",  'A');
    TEST("%c lowercase 'z'",   "%c",  'z');
    TEST("%c digit '0'",       "%c",  '0');
    TEST("%c space",           "%c",  ' ');
    TEST("%c width right",     "%5c", 'X');
    TEST("%c width left",      "%-5c", 'X');
}

/* ── %s ── */

static void test_percent_s(void)
{
    TEST("%s basic",           "%s",    "hello");
    TEST("%s empty",           "%s",    "");
    TEST("%s NULL",            "%s",    (char *)NULL);
    TEST("%s width right",     "%10s",  "hi");
    TEST("%s width left",      "%-10s", "hi");
    TEST("%s precision",       "%.3s",  "hello");
    TEST("%s width+precision", "%10.3s","hello");
}

/* ── %d ── */

static void test_percent_d(void)
{
    TEST("%d zero",     "%d",  0);
    TEST("%d positive", "%d",  100);
    TEST("%d negative", "%d",  -100);
    TEST("%d one",      "%d",  1);
    TEST("%d minus one","%d",  -1);
    TEST("%d INT_MAX",  "%d",  INT_MAX);
    TEST("%d INT_MIN",  "%d",  INT_MIN);
    TEST("%d width",    "%10d", 7);
    TEST("%d zero-pad", "%010d", 7);
    TEST("%d left",     "%-10d", 7);
    TEST("%d plus pos", "%+d",  7);
    TEST("%d plus neg", "%+d",  -7);
    TEST("%d space pos","% d",  7);
    TEST("%d space neg","% d",  -7);
    TEST("%d precision","%.5d", 7);
}

/* ── %i ── */

static void test_percent_i(void)
{
    TEST("%i zero",     "%i",  0);
    TEST("%i positive", "%i",  255);
    TEST("%i negative", "%i",  -255);
    TEST("%i INT_MIN",  "%i",  INT_MIN);
}

/* ── %u ── */

static void test_percent_u(void)
{
    TEST("%u zero",     "%u",  0u);
    TEST("%u positive", "%u",  100u);
    TEST("%u UINT_MAX", "%u",  UINT_MAX);
    TEST("%u width",    "%10u", 7u);
    TEST("%u zero-pad", "%010u", 7u);
    TEST("%u left",     "%-10u", 7u);
}

/* ── %x ── */

static void test_percent_x(void)
{
    TEST("%x zero",     "%x",   0u);
    TEST("%x byte",     "%x",   255u);
    TEST("%x UINT_MAX", "%x",   UINT_MAX);
    TEST("%x width",    "%10x", 255u);
    TEST("%x zero-pad", "%08x", 255u);
    TEST("%x left",     "%-10x", 255u);
    TEST("%x hash",     "%#x",  255u);
    TEST("%x hash zero","%#x",  0u);
    TEST("%x hash pad", "%#010x", 255u);
}

/* ── %X ── */

static void test_percent_X(void)
{
    TEST("%X zero",     "%X",   0u);
    TEST("%X byte",     "%X",   255u);
    TEST("%X UINT_MAX", "%X",   UINT_MAX);
    TEST("%X hash",     "%#X",  255u);
    TEST("%X hash pad", "%#010X", 255u);
}

/* ── %p ── */

static void test_percent_p(void)
{
    TEST("%p fixed addr",  "%p", (void *)0x1234);
    TEST("%p large addr",  "%p", (void *)0x7fff5fbff000);
    TEST("%p NULL",        "%p", (void *)NULL);
}

/* ── %% ── */

static void test_percent_pct(void)
{
    TEST("%% literal",       "100%%");
    TEST("%% with specifier","%d%%",  7);
    TEST("%% trailing text", "100%% done");
    TEST("%% only",          "%%%%");
}

/* ── mixed ── */

static void test_mixed(void)
{
    TEST("mixed s+d",    "%s: %d",    "score", 100);
    TEST("mixed d+d",    "x=%d y=%d", 3, 7);
    TEST("mixed no spec","hello\n");
    TEST("mixed literal+c", "char: %c!", 'Z');
    TEST("mixed s+x",    "%s=0x%x",   "val", 255u);
}

/* ── main ── */

int main(void)
{
    test_percent_c();
    test_percent_s();
    test_percent_d();
    test_percent_i();
    test_percent_u();
    test_percent_x();
    test_percent_X();
    test_percent_p();
    test_percent_pct();
    test_mixed();

    printf("\n%d / %d checks passed\n", g_pass, g_pass + g_fail);
    return (g_fail > 0 ? 1 : 0);
}
RUNNER_EOF
}

# ── checks ────────────────────────────────────────────────────────────────────

check_make() {
    echo
    echo "  check 1/5 — make re"
    make re > "$WORK_DIR/make.log" 2>&1
    if [[ $? -ne 0 ]]; then
        fail "make re"
        echo "         (see $WORK_DIR/make.log)"
        return 1
    fi
    if grep -qi 'warning' "$WORK_DIR/make.log"; then
        fail "make re: build has warnings"
        grep -i 'warning' "$WORK_DIR/make.log" | head -5
        return 1
    fi
    if [[ ! -f libtci.a ]]; then
        fail "make re: libtci.a not produced"
        return 1
    fi
    pass "make re"
    return 0
}

check_runner() {
    echo
    echo "  check 2/5 — compile test runner"
    gcc -Wall -Wextra -g -std=c99 \
        _runner.c -L. -ltci -I. -o _runner \
        > "$WORK_DIR/compile.log" 2>&1
    if [[ $? -ne 0 ]]; then
        fail "compile test runner"
        cat "$WORK_DIR/compile.log"
        return 1
    fi
    pass "compile test runner"
    return 0
}

check_correctness() {
    local summary
    local ec

    echo
    echo "  check 3/5 — correctness"
    ./_runner > "$WORK_DIR/runner.out" 2>&1
    ec=$?

    if grep -q 'FAIL' "$WORK_DIR/runner.out"; then
        grep 'FAIL' "$WORK_DIR/runner.out"
    fi

    summary=$(tail -1 "$WORK_DIR/runner.out")
    [[ -z "$summary" ]] && summary="(no output — runner crashed)"

    if [[ $ec -ne 0 ]]; then
        fail "correctness: $summary"
        return 1
    fi
    pass "correctness: $summary"
    return 0
}

check_valgrind() {
    echo
    echo "  check 4/5 — valgrind"
    valgrind --error-exitcode=1 --leak-check=full --quiet \
        ./_runner > "$WORK_DIR/vg.out" 2> "$WORK_DIR/vg.log"
    if [[ $? -ne 0 ]]; then
        fail "valgrind"
        cat "$WORK_DIR/vg.log"
        return 1
    fi
    pass "valgrind"
    return 0
}

check_sanitisers() {
    local san_flags="-fsanitize=address,undefined"
    local ec

    echo
    echo "  check 5/5 — sanitisers"

    gcc -Wall -Wextra -g -std=c99 $san_flags \
        tci_*.c _runner.c -I. -o _runner_san \
        > "$WORK_DIR/san_build.log" 2>&1
    if [[ $? -ne 0 ]]; then
        fail "sanitisers: build failed"
        cat "$WORK_DIR/san_build.log"
        return 1
    fi

    ./_runner_san > "$WORK_DIR/san_run.out" 2> "$WORK_DIR/san_run.log"
    ec=$?

    if [[ $ec -ne 0 ]] && grep -q 'ReserveShadowMemoryRange' "$WORK_DIR/san_run.log"; then
        san_flags="-fsanitize=undefined"
        printf "         (ASan shadow mapping unavailable on this system,"
        printf " retrying with UBSan only)\n"
        gcc -Wall -Wextra -g -std=c99 $san_flags \
            tci_*.c _runner.c -I. -o _runner_san \
            > "$WORK_DIR/san_build.log" 2>&1
        if [[ $? -ne 0 ]]; then
            fail "sanitisers: build failed"
            cat "$WORK_DIR/san_build.log"
            return 1
        fi
        ./_runner_san > "$WORK_DIR/san_run.out" 2> "$WORK_DIR/san_run.log"
        ec=$?
    fi

    if [[ $ec -ne 0 ]]; then
        fail "sanitisers ($san_flags)"
        cat "$WORK_DIR/san_run.log"
        return 1
    fi
    pass "sanitisers ($san_flags)"
    return 0
}

# ── help ──────────────────────────────────────────────────────────────────────

show_help() {
    cat << 'HELP_EOF'
c02 — The Voice / test.sh

Usage: bash test.sh [--help]

Runs 5 checks against your libtci.a and tci_*.c source files.

Checks:
  1. make re       Clean rebuild. libtci.a must be produced with no warnings.
  2. compile       Links an embedded test runner against libtci.a.
  3. correctness   Runs the test runner. Every check must pass.
                   tci_printf output and return value are compared against
                   libc printf for each format string.
  4. valgrind      Runs the test runner under valgrind. No leaks or errors.
  5. sanitisers    Recompiles tci_*.c directly with -fsanitize=address,undefined.
                   Runs the result. No sanitiser errors.
HELP_EOF
}

# ── main ──────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ $# -gt 0 ]]; then
    echo "error: unknown option: $1" >&2
    echo "usage: bash test.sh [--help]" >&2
    exit 1
fi

banner
preflight
write_runner

check_make || { echo; hr; printf "  make failed — fix build errors before continuing\n"; hr; exit 1; }

check_runner
check_correctness
check_valgrind
check_sanitisers

echo
hr
printf "  %d / %d checks passed\n" "$pass_count" "$((pass_count + fail_count))"
hr

if [[ $fail_count -eq 0 ]]; then
    echo
    printf "  ${C_GREEN}${C_BOLD}All checks passed.${C_RESET}"
    printf " tci_printf matches libc printf, clean and memory-safe.\n"
    echo "  Every byte it writes — the same output as the standard library,"
    echo "  written by hand, tested to the same standard."
    echo
    exit 0
else
    echo
    printf "  ${C_RED}%d check(s) failed.${C_RESET}\n" "$fail_count"
    echo
    exit 1
fi
