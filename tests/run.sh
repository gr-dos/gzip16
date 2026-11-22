#!/bin/sh
#
# Test gzip.exe, GNU gzip 1.2.4's 16-bit MS-DOS program, on DOS: under
# DOSBox-X on an emulated 8086, or on GR-DOS booted in QEMU.
#
# Fixtures are made on the host (with the host's gzip for the .gz files
# DOS is to decompress), one batch file, RUN.BAT, runs every DOS-side
# step, and the results are checked on the host afterwards, with the
# host's gzip for what DOS compressed. Step N records GZIP's exit status
# in RN.TXT (RC.BAT). DOS cannot redirect standard error, where gzip
# writes its messages, so they are not checked. RC.BAT uses goto rather
# than "if errorlevel N echo ... >file" because the DOSBox-X shell opens
# the redirection even when the test is false.
#
# Not tested, because it waits for an answer from the console: gzip
# without -f when its output file already exists asks "do you wish to
# overwrite (y or n)?" (docs/DOS.md).
#
# usage: tests/run.sh dosbox|grdos [path/to/gzip.exe]
#
#   dosbox  DOSBox-X, an 8086 (cputype=8086); with mtools, also the
#           disk-full steps, on a full 360 KB floppy in A:
#   grdos   GR-DOS (scripts/fetch-grdos) in QEMU: GR-DOS's floppy in A:,
#           the fixtures on a 1.44 MB floppy in B:, the steps run there
#
# Needs gzip and cmp on the host; dosbox-x, or qemu-system-i386, mtools
# and curl. Environment: DOSBOX (default dosbox-x), TIMEOUT (default 300
# seconds), GRDOS_IMG (default: fetched by scripts/fetch-grdos), KEEP=1 to
# keep the work directory.

set -u

[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: $0 dosbox|grdos [gzip.exe]" >&2; exit 2; }
mode=$1
top=$(cd "$(dirname "$0")/.." && pwd)
exe=${2:-$top/gzip.exe}
DOSBOX=${DOSBOX:-dosbox-x}
timeout=${TIMEOUT:-300}
LC_ALL=C
export LC_ALL

case $mode in
dosbox)
    command -v "$DOSBOX" >/dev/null || { echo "$DOSBOX not found" >&2; exit 2; } ;;
grdos)
    for t in qemu-system-i386 mformat mcopy; do
        command -v $t >/dev/null || { echo "$t not found" >&2; exit 2; }
    done ;;
*)
    echo "usage: $0 dosbox|grdos [gzip.exe]" >&2; exit 2 ;;
esac
command -v gzip >/dev/null || { echo "gzip not found on the host" >&2; exit 2; }
[ -f "$exe" ] || { echo "$exe not found" >&2; exit 2; }
case $exe in /*) ;; *) exe=$(pwd)/$exe ;; esac

work=$(mktemp -d "${TMPDIR:-/tmp}/gzip16.XXXXXX")
pass=0
fail=0

# ------------------------------------------------------------------
# fixtures: DOS files in d/, upper case; the host's own in work/

mkdir "$work/d" "$work/want"
cd "$work/d" || exit 2
cp "$exe" GZIP.EXE

# text with CR LF, text a few times over 64 KB, nothing, every byte value
# (NUL, Ctrl+Z, bare CR and LF among them), and random bytes over 64 KB,
# which do not compress
printf 'hello world\r\nsecond line\r\n' > ../want/hello.txt
awk 'BEGIN { for (i = 1; i <= 4000; i++) printf "line %d of a text file that compresses well\r\n", i }' \
    > ../want/big.txt
: > ../want/empty.txt
awk 'BEGIN { for (r = 0; r < 4; r++) for (i = 0; i < 256; i++) printf "%c", i }' > ../want/bin.dat
printf '\0\032\r\n\032\0' >> ../want/bin.dat
head -c 150000 /dev/urandom > ../want/rand.bin

cp ../want/hello.txt HELLO.TXT
cp ../want/hello.txt HELLO2.TXT
cp ../want/empty.txt EMPTY.TXT
cp ../want/bin.dat BIN.DAT
cp ../want/rand.bin RAND.BIN
cp ../want/big.txt BIG.TXT
cp ../want/big.txt B1.TXT
cp ../want/hello.txt N.TXT
cp ../want/hello.txt X.TXT
cp ../want/hello.txt F.TXT
cp ../want/hello.txt README
cp ../want/hello.txt AB.C
printf 'old\r\n' | gzip -n > F.TXZ

# made by the host's gzip: without a name (-n), with one (the default),
# a long one, two members, a large file, and a broken CRC, a truncated
# one and one that is not gzip at all
gzip -9nc ../want/bin.dat > HOST1.GZ
cp ../want/bin.dat "$work/named.dat"
(cd "$work" && gzip -c named.dat) > HOST2.GZ
cp ../want/hello.txt "$work/a-long-file-name.text"
(cd "$work" && gzip -c a-long-file-name.text) > LONG.GZ
gzip -nc ../want/hello.txt > HOST3.GZ
{ gzip -nc ../want/hello.txt; gzip -nc ../want/bin.dat; } > MULTI.GZ
gzip -9nc ../want/rand.bin > HOSTBIG.GZ
cp HOST3.GZ GOOD.GZ
cp HOST3.GZ CRC.GZ
size=$(wc -c < CRC.GZ)
printf '\377' | dd of=CRC.GZ bs=1 seek=$((size - 8)) conv=notrunc 2>/dev/null
cp CRC.GZ CRC2.GZ
head -c 20 HOSTBIG.GZ > TRUNC.GZ
printf 'not gzip data\r\n' > NOTGZ.GZ
cp HOST3.GZ Q.TXZ

cat > RC.BAT <<'EOF'
@echo off
if errorlevel 3 goto rc3
if errorlevel 2 goto rc2
if errorlevel 1 goto rc1
echo rc0 >R%1.TXT
goto end
:rc1
echo rc1 >R%1.TXT
goto end
:rc2
echo rc2 >R%1.TXT
goto end
:rc3
echo rc3 >R%1.TXT
:end
EOF

{
cat <<'EOF'
@echo off
GZIP HELLO.TXT
call rc 1
GZIP EMPTY.TXT
call rc 2
GZIP BIN.DAT
call rc 3
GZIP RAND.BIN
call rc 4
GZIP -9 BIG.TXT
call rc 5
GZIP -1 -c B1.TXT > B1.GZ
call rc 6
GZIP < HELLO2.TXT > STDIN.GZ
call rc 7
TYPE HELLO2.TXT | GZIP > PIPE.GZ
call rc 8
GZIP -d HOST1.GZ
call rc 9
GZIP -dN HOST2.GZ
call rc 10
GZIP -dN LONG.GZ
call rc 11
GZIP -dc MULTI.GZ > MULTI.OUT
call rc 12
GZIP -dc HOSTBIG.GZ > HOSTBIG.OUT
call rc 13
GZIP -d < HOST3.GZ > STDIN.OUT
call rc 14
GZIP -dc HOST3.GZ | GZIP -c > PIPE2.GZ
call rc 15
GZIP -t GOOD.GZ
call rc 16
GZIP -t CRC.GZ
call rc 17
GZIP -t NOTGZ.GZ
call rc 18
GZIP -t TRUNC.GZ
call rc 19
GZIP -dc TRUNC.GZ > TRUNC.OUT
call rc 20
GZIP -d CRC2.GZ
call rc 21
GZIP N.TXT
call rc 22
GZIP -d N.TXZ
call rc 23
GZIP X.TXT
call rc 24
GZIP -dN X.TXZ
call rc 25
GZIP -l GOOD.GZ > L.OUT
call rc 26
GZIP -f F.TXT
call rc 27
GZIP Q.TXZ
call rc 28
GZIP NOSUCH.TXT
call rc 29
GZIP README
call rc 30
GZIP AB.C
call rc 31
EOF
} > RUN.BAT

# the disk-full steps, under DOSBox-X: a 360 KB floppy holding a file
# of random bytes and a filler, with 10 KB free; compressing the file in
# place cannot finish, and must leave it as it was
full=0
if [ "$mode" = dosbox ] && command -v mformat >/dev/null && command -v mcopy >/dev/null &&
    command -v mdir >/dev/null; then
    head -c 100000 /dev/urandom > "$work/full.bin"
    mformat -C -f 360 -i "$work/fd.img" :: &&
    mcopy -i "$work/fd.img" "$work/full.bin" ::R.BIN &&
    free=$(mdir -i "$work/fd.img" :: | sed -n 's/^ *\([0-9 ]*\) bytes free.*/\1/p' | tr -d ' ') &&
    head -c $((free - 10240)) /dev/zero > "$work/filler.bin" &&
    mcopy -i "$work/fd.img" "$work/filler.bin" ::FILLER.BIN &&
    full=1
    cat >> RUN.BAT <<'EOF'
imgmount a ..\fd.img -t floppy >nul
GZIP A:\R.BIN
call rc 32
DIR A: > ADIR.TXT
imgmount -u a >nul
EOF
fi
# CR LF, as DOS batch files are
for f in RC.BAT RUN.BAT; do sed 's/$/\r/' $f > $f.tmp && mv $f.tmp $f; done

# ------------------------------------------------------------------
# run

ran=1
case $mode in
dosbox)
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 10 "$timeout" \
        "$DOSBOX" -defaultconf -silent -nogui -nomenu \
        -set "dosbox machine=cga" -set "cpu cputype=8086" \
        -set "cpu core=normal" -set "cpu cycles=max" \
        -c "mount c \"$work\"" -c "c:" -c "cd d" \
        -c "RUN.BAT" -c "exit" > "$work/dosbox.log" 2>&1 || ran=0
    ;;
grdos)
    img=${GRDOS_IMG:-$(cd "$top" && scripts/fetch-grdos)} || exit 2
    case $img in /*) ;; *) img=$top/$img ;; esac
    q=$work/qemu
    mkdir "$q"
    cp "$img" "$q/a.img"
    chmod u+w "$q/a.img"
    # AUTOEXEC.BAT reports to COM1 when it starts and ends, and records
    # MEM's report of the memory GZIP has; CTTY AUX sends the console to
    # COM1 in between.
    printf '@ECHO OFF\r\nPATH A:\\\r\nECHO GZIP16-GRDOS-BEGIN>AUX\r\nB:\r\nMEM > MEM.OUT\r\nCTTY AUX\r\nCALL RUN.BAT\r\nA:\r\nECHO GZIP16-GRDOS-END\r\n' \
        > "$q/AUTOEXEC.BAT"
    mcopy -o -i "$q/a.img" "$q/AUTOEXEC.BAT" ::AUTOEXEC.BAT
    printf 'FILES=20\r\nBUFFERS=20\r\n' > "$q/CONFIG.SYS"
    mcopy -o -i "$q/a.img" "$q/CONFIG.SYS" ::CONFIG.SYS
    mformat -C -f 1440 -i "$q/b.img" ::
    mcopy -i "$q/b.img" "$work"/d/* ::
    : > "$q/serial.log"
    qemu-system-i386 -display none -m 4 -no-reboot \
        -drive "file=$q/a.img,if=floppy,index=0,format=raw" \
        -drive "file=$q/b.img,if=floppy,index=1,format=raw" \
        -boot a -serial "file:$q/serial.log" -monitor none &
    pid=$!
    start=$(date +%s)
    until tr -d '\r' < "$q/serial.log" | grep -qx GZIP16-GRDOS-END; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "grdos: QEMU exited early" >&2; ran=0; break
        fi
        if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
            echo "grdos: no end after $timeout seconds" >&2; ran=0; break
        fi
        sleep 1
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$work/d"
    mkdir "$work/d"
    mcopy -s -n -i "$q/b.img" '::*' "$work/d/"
    ;;
esac
[ "$ran" = 1 ] || echo "FAIL: $mode did not finish RUN.BAT" >&2

# ------------------------------------------------------------------
# checks

ok()     { pass=$((pass + 1)); }
not_ok() { echo "FAIL: $*"; fail=$((fail + 1)); }

# rc STEP EXPECTED-STATUS
rc() {
    got=$(tr -d ' \r' < "R$1.TXT" 2>/dev/null | sed 's/^rc//')
    if [ "$got" = "$2" ]; then ok; else
        not_ok "step $1: exit status ${got:-missing}, expected $2"
    fi
}
# same WHAT FILE WANT: FILE is WANT, byte for byte
same() {
    if cmp -s "$2" "$3"; then ok; else not_ok "$1: $2 is not $3"; fi
}
# unzips WHAT FILE WANT: the host's gzip finds FILE sound, and its data WANT
unzips() {
    if gzip -t < "$2" 2>/dev/null && gzip -dc < "$2" 2>/dev/null | cmp -s - "$3"; then ok; else
        not_ok "$1: $2 does not decompress to $3 with the host's gzip"
    fi
}
absent()  { if [ -e "$2" ]; then not_ok "$1: $2 is there"; else ok; fi; }
present() { if [ -e "$2" ]; then ok; else not_ok "$1: $2 is not there"; fi; }
# name WHAT FILE NAME: the name FILE's header gives
name() {
    got=$(gzip -lN "$2" 2>/dev/null | awk 'NR == 2 { print $4 }')
    if [ "$got" = "$3" ]; then ok; else not_ok "$1: $2 is named ${got:-nothing}, expected $3"; fi
}

cd "$work/d" || exit 2
w=$work/want

# compressing, in place: FOO.EXT becomes FOO.EXZ, with the name in it
rc 1 0
unzips "step 1: text" HELLO.TXZ "$w/hello.txt"
absent "step 1: original removed" HELLO.TXT
name "step 1: name" HELLO.TXZ hello.txt
rc 2 0
unzips "step 2: empty file" EMPTY.TXZ "$w/empty.txt"
rc 3 0
unzips "step 3: NUL, Ctrl+Z, bare CR and LF" BIN.DAZ "$w/bin.dat"
rc 4 0
unzips "step 4: random bytes, over 64 KB" RAND.BIZ "$w/rand.bin"
rc 5 0
unzips "step 5: -9, over 64 KB" BIG.TXZ "$w/big.txt"
if [ "$(wc -c < BIG.TXZ)" -lt $(( $(wc -c < "$w/big.txt") / 4 )) ]; then ok; else
    not_ok "step 5: BIG.TXZ is $(wc -c < BIG.TXZ) bytes, not under a quarter of BIG.TXT"
fi
# -c, standard input, a pipe
rc 6 0
unzips "step 6: -1 -c" B1.GZ "$w/big.txt"
present "step 6: -c keeps the original" B1.TXT
rc 7 0
unzips "step 7: standard input to standard output" STDIN.GZ "$w/hello.txt"
rc 8 0
unzips "step 8: from a pipe" PIPE.GZ "$w/hello.txt"

# decompressing what the host's gzip made
rc 9 0
same "step 9: -d, FOO.GZ becomes FOO" HOST1 "$w/bin.dat"
absent "step 9: the .GZ removed" HOST1.GZ
rc 10 0
same "step 10: -dN, the stored name" NAMED.DAT "$w/bin.dat"
rc 11 0
same "step 11: -dN, a long stored name, made 8.3" A-LONG-F.TEX "$w/hello.txt"
rc 12 0
cat "$w/hello.txt" "$w/bin.dat" > "$work/multi.want"
same "step 12: two members" MULTI.OUT "$work/multi.want"
rc 13 0
same "step 13: over 64 KB" HOSTBIG.OUT "$w/rand.bin"
rc 14 0
same "step 14: standard input to standard output" STDIN.OUT "$w/hello.txt"
rc 15 0
unzips "step 15: through a pipe" PIPE2.GZ "$w/hello.txt"

# testing, and bad input: exit status 1, and nothing left behind
rc 16 0
rc 17 1
rc 18 1
rc 19 1
rc 20 1
rc 21 1
present "step 21: a broken .GZ kept" CRC2.GZ
absent "step 21: no output left" CRC2

# the 8.3 names: -d without -N makes FOO.TXZ FOO.TX, -dN restores FOO.TXT
rc 22 0
rc 23 0
same "step 23: -d, N.TXZ becomes N.TX" N.TX "$w/hello.txt"
rc 24 0
rc 25 0
same "step 25: -dN, X.TXZ becomes X.TXT" X.TXT "$w/hello.txt"

# -l, -f, an already compressed file (a warning, 2), a missing one
rc 26 0
if tr -d '\r' < L.OUT | grep -q 'uncompressed_name' &&
    tr -d '\r' < L.OUT | grep -Eq "^ +$(wc -c < GOOD.GZ) +$(wc -c < "$w/hello.txt") "; then ok; else
    not_ok "step 26: -l"; tr -d '\r' < L.OUT | sed 's/^/    /'
fi
rc 27 0
unzips "step 27: -f replaces an existing F.TXZ" F.TXZ "$w/hello.txt"
rc 28 2
same "step 28: Q.TXZ unchanged" Q.TXZ HOST3.GZ
rc 29 1
# no extension gets .GZ; a short one gets a z added
rc 30 0
unzips "step 30: README becomes README.GZ" README.GZ "$w/hello.txt"
rc 31 0
unzips "step 31: AB.C becomes AB.CZ" AB.CZ "$w/hello.txt"

if [ "$full" = 1 ]; then
    rc 32 1
    mcopy -n -i "$work/fd.img" ::R.BIN "$work/full.got"
    same "step 32: disk full, original kept" "$work/full.got" "$work/full.bin"
    if tr -d '\r' < ADIR.TXT | grep -q '^ *2 File(s)' &&
        tr -d '\r' < ADIR.TXT | grep -q ' 10,240 Bytes free'; then ok; else
        not_ok "step 32: files left on the full disk"; tr -d '\r' < ADIR.TXT | sed 's/^/    /'
    fi
elif [ "$mode" = dosbox ]; then
    echo "skipped: disk-full step (no mtools)"
fi

if [ "$mode" = grdos ] && [ -f MEM.OUT ]; then
    echo "GR-DOS MEM, before GZIP ran:"
    tr -d '\r' < MEM.OUT | grep -i -E 'conventional|largest|free' | sed 's/^/    /'
fi

# ------------------------------------------------------------------

echo "$mode: $pass passed, $fail failed"
if [ "$fail" -ne 0 ] || [ "${KEEP:-0}" = 1 ]; then
    echo "work directory: $work"
else
    rm -rf "$work"
fi
[ "$fail" -eq 0 ]
