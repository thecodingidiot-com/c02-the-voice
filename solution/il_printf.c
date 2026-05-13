#include "idiotlib.h"
#include <stdarg.h>
#include <unistd.h>
#include <stdint.h>

typedef struct s_fmt
{
    int  minus;
    int  zero;
    int  plus;
    int  space;
    int  hash;
    int  width;
    int  precision;
    int  has_precision;
}   t_fmt;

static int  il_putchar_fd(char c, int fd);
static int  il_putstr_fd(char *s, int fd);
static int  il_putnbr_base(unsigned long n, const char *base, int fd);
static int  pad_chars(char c, int n, int fd);
static int  il_print_char(int c, t_fmt *f);
static int  il_print_str(char *s, t_fmt *f);
static int  il_print_ptr(void *ptr);
static int  il_print_signed(int n, t_fmt *f);
static int  il_print_unsigned(unsigned int n, const char *base, t_fmt *f);
static int  parse_fmt(const char *fmt, int i, t_fmt *f, va_list *args);
static int  dispatch_fmt(char spec, va_list *args, t_fmt *f);

static int  il_putchar_fd(char c, int fd)
{
    write(fd, &c, 1);
    return (1);
}

static int  il_putstr_fd(char *s, int fd)
{
    int  len;

    if (!s)
        return (il_putstr_fd("(null)", fd));
    len = (int)il_strlen(s);
    write(fd, s, len);
    return (len);
}

static int  il_putnbr_base(unsigned long n, const char *base, int fd)
{
    char  buf[64];
    int   blen;
    int   len;
    int   i;
    char  tmp;

    blen = (int)il_strlen(base);
    len = 0;
    if (n == 0) {
        buf[len++] = base[0];
    }
    while (n > 0) {
        buf[len++] = base[n % blen];
        n /= blen;
    }
    i = 0;
    while (i < len / 2) {
        tmp = buf[i];
        buf[i] = buf[len - 1 - i];
        buf[len - 1 - i] = tmp;
        i++;
    }
    write(fd, buf, len);
    return (len);
}

static int  pad_chars(char c, int n, int fd)
{
    int  i;

    i = 0;
    while (i < n) {
        write(fd, &c, 1);
        i++;
    }
    return (n > 0 ? n : 0);
}

static int  il_print_char(int c, t_fmt *f)
{
    int  pad;
    int  count;

    pad = f->width > 1 ? f->width - 1 : 0;
    count = 0;
    if (!f->minus)
        count += pad_chars(' ', pad, 1);
    count += il_putchar_fd((unsigned char)c, 1);
    if (f->minus)
        count += pad_chars(' ', pad, 1);
    return (count);
}

static int  il_print_str(char *s, t_fmt *f)
{
    int  slen;
    int  pad;
    int  count;

    if (!s)
        s = "(null)";
    slen = (int)il_strlen(s);
    if (f->has_precision && f->precision < slen)
        slen = f->precision;
    pad = f->width > slen ? f->width - slen : 0;
    count = 0;
    if (!f->minus)
        count += pad_chars(' ', pad, 1);
    count += (int)write(1, s, slen);
    if (f->minus)
        count += pad_chars(' ', pad, 1);
    return (count);
}

static int  il_print_ptr(void *ptr)
{
    int  count;

    if (!ptr)
        return (il_putstr_fd("(nil)", 1));
    count = (int)write(1, "0x", 2);
    count += il_putnbr_base((uintptr_t)ptr, "0123456789abcdef", 1);
    return (count);
}

static int  il_print_signed(int n, t_fmt *f)
{
    char  buf[20];
    int   len;
    long  val;
    char  sign;
    int   prec_pad;
    int   content;
    int   pad;
    int   count;
    int   i;
    char  tmp;

    val = n;
    sign = 0;
    if (val < 0) {
        sign = '-';
        val = -val;
    } else if (f->plus) {
        sign = '+';
    } else if (f->space) {
        sign = ' ';
    }
    len = 0;
    if (val == 0)
        buf[len++] = '0';
    while (val > 0) {
        buf[len++] = "0123456789"[val % 10];
        val /= 10;
    }
    i = 0;
    while (i < len / 2) {
        tmp = buf[i];
        buf[i] = buf[len - 1 - i];
        buf[len - 1 - i] = tmp;
        i++;
    }
    prec_pad = 0;
    if (f->has_precision && f->precision > len)
        prec_pad = f->precision - len;
    content = (sign ? 1 : 0) + prec_pad + len;
    pad = f->width > content ? f->width - content : 0;
    count = 0;
    if (!f->minus && !(f->zero && !f->has_precision))
        count += pad_chars(' ', pad, 1);
    if (sign)
        count += il_putchar_fd(sign, 1);
    if (!f->minus && f->zero && !f->has_precision)
        count += pad_chars('0', pad, 1);
    count += pad_chars('0', prec_pad, 1);
    count += (int)write(1, buf, len);
    if (f->minus)
        count += pad_chars(' ', pad, 1);
    return (count);
}

static int  il_print_unsigned(unsigned int n, const char *base, t_fmt *f)
{
    char          buf[20];
    int           len;
    unsigned long val;
    int           blen;
    const char   *prefix;
    int           prefix_len;
    int           prec_pad;
    int           content;
    int           pad;
    int           count;
    int           i;
    char          tmp;

    val = (unsigned long)n;
    blen = (int)il_strlen(base);
    prefix = "";
    prefix_len = 0;
    if (f->hash && n != 0) {
        if (blen == 16 && base[10] == 'a')
            prefix = "0x";
        else if (blen == 16)
            prefix = "0X";
        prefix_len = (int)il_strlen(prefix);
    }
    len = 0;
    if (val == 0)
        buf[len++] = base[0];
    while (val > 0) {
        buf[len++] = base[val % blen];
        val /= blen;
    }
    i = 0;
    while (i < len / 2) {
        tmp = buf[i];
        buf[i] = buf[len - 1 - i];
        buf[len - 1 - i] = tmp;
        i++;
    }
    prec_pad = 0;
    if (f->has_precision && f->precision > len)
        prec_pad = f->precision - len;
    content = prefix_len + prec_pad + len;
    pad = f->width > content ? f->width - content : 0;
    count = 0;
    if (!f->minus && !(f->zero && !f->has_precision))
        count += pad_chars(' ', pad, 1);
    if (prefix_len)
        count += (int)write(1, prefix, prefix_len);
    if (!f->minus && f->zero && !f->has_precision)
        count += pad_chars('0', pad, 1);
    count += pad_chars('0', prec_pad, 1);
    count += (int)write(1, buf, len);
    if (f->minus)
        count += pad_chars(' ', pad, 1);
    return (count);
}

static int  parse_fmt(const char *fmt, int i, t_fmt *f, va_list *args)
{
    il_memset(f, 0, sizeof(*f));
    f->precision = -1;
    while (fmt[i] == '-' || fmt[i] == '0' || fmt[i] == '+'
            || fmt[i] == ' ' || fmt[i] == '#') {
        if (fmt[i] == '-') f->minus = 1;
        if (fmt[i] == '0') f->zero  = 1;
        if (fmt[i] == '+') f->plus  = 1;
        if (fmt[i] == ' ') f->space = 1;
        if (fmt[i] == '#') f->hash  = 1;
        i++;
    }
    if (fmt[i] == '*') {
        f->width = va_arg(*args, int);
        if (f->width < 0) { f->minus = 1; f->width = -f->width; }
        i++;
    } else {
        while (fmt[i] >= '0' && fmt[i] <= '9')
            f->width = f->width * 10 + (fmt[i++] - '0');
    }
    if (fmt[i] == '.') {
        f->has_precision = 1;
        f->precision = 0;
        i++;
        if (fmt[i] == '*') {
            f->precision = va_arg(*args, int);
            if (f->precision < 0) { f->has_precision = 0; f->precision = -1; }
            i++;
        } else {
            while (fmt[i] >= '0' && fmt[i] <= '9')
                f->precision = f->precision * 10 + (fmt[i++] - '0');
        }
    }
    if (f->minus)
        f->zero = 0;  /* - overrides 0 */
    if (f->plus)
        f->space = 0;  /* + overrides space */
    return (i);
}

static int  dispatch_fmt(char spec, va_list *args, t_fmt *f)
{
    if (spec == 'c')
        return (il_print_char(va_arg(*args, int), f));
    if (spec == 's')
        return (il_print_str(va_arg(*args, char *), f));
    if (spec == 'p')
        return (il_print_ptr(va_arg(*args, void *)));
    if (spec == 'd' || spec == 'i')
        return (il_print_signed(va_arg(*args, int), f));
    if (spec == 'u')
        return (il_print_unsigned(va_arg(*args, unsigned int),
                "0123456789", f));
    if (spec == 'x')
        return (il_print_unsigned(va_arg(*args, unsigned int),
                "0123456789abcdef", f));
    if (spec == 'X')
        return (il_print_unsigned(va_arg(*args, unsigned int),
                "0123456789ABCDEF", f));
    if (spec == '%')
        return (il_putchar_fd('%', 1));
    return (il_putchar_fd('%', 1) + il_putchar_fd(spec, 1));
}

int     il_printf(const char *fmt, ...)
{
    va_list  args;
    int      count;
    int      i;
    t_fmt    f;

    va_start(args, fmt);
    count = 0;
    i = 0;
    while (fmt[i]) {
        if (fmt[i] == '%' && fmt[i + 1]) {
            i++;
            i = parse_fmt(fmt, i, &f, &args);
            count += dispatch_fmt(fmt[i], &args, &f);
        } else {
            count += il_putchar_fd(fmt[i], 1);
        }
        i++;
    }
    va_end(args);
    return (count);
}
