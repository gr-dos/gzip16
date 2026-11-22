# Make gzip.exe, the DOS command GZIP: GNU gzip 1.2.4's 16-bit MS-DOS
# program, as GNU released it in 1993. Nothing is compiled: the program
# is taken, unchanged, from GNU's MS-DOS distribution, and checked
# (BUILDING.md).
#   make              fetch gzip-1.2.4.msdos.exe from the GNU archive
#                     (scripts/fetch-upstream), unpack it on the host
#                     (scripts/extract), and copy its GZIP.EXE to gzip.exe
#   make test         run the tests (tests/run.sh) under DOSBox-X, on an 8086,
#                     with the disk-full step (NO_DISKFULL=1 leaves it out)
#   make test-grdos   run them on GR-DOS, in QEMU
#   make source       fetch gzip-1.2.4.tar.gz, GNU gzip 1.2.4's source

MSDOS = build/upstream/gzip-1.2.4.msdos.exe
SRC   = build/upstream/gzip-1.2.4.tar.gz

gzip.exe: build/msdos/GZIP.EXE
	cp $< $@

build/msdos/GZIP.EXE: $(MSDOS) scripts/extract upstream/msdos.sha256
	scripts/extract $(MSDOS) build/msdos

build/upstream/%: upstream/SHA256SUMS scripts/fetch-upstream
	scripts/fetch-upstream $* build/upstream >/dev/null

source: $(SRC)

test: gzip.exe
	sh tests/run.sh dosbox $(CURDIR)/gzip.exe

test-grdos: gzip.exe
	sh tests/run.sh grdos $(CURDIR)/gzip.exe

clean:
	rm -rf build/msdos build/release gzip.exe

.PHONY: source test test-grdos clean
