# Building gzip16

gzip16 compiles nothing. `gzip.exe` is GNU gzip 1.2.4's 16-bit MS-DOS program, `GZIP.EXE`, as GNU released it in 1993, and `make` takes it, unchanged, from GNU's MS-DOS distribution and checks it. gzip16 exists so that GR-DOS ships that program from a repository of its own, with its license and its source, and so that a gzip16 port built from source could take its place later without GR-DOS changing.

## What it needs

- `make`, a POSIX shell, `curl`, `sha256sum`, `awk`, GNU `tar` and `git`;
- `7z`, to unpack the LHA archive (7-Zip, or p7zip's `7z`; `apt-get install p7zip-full`);
- for the tests: `gzip` and `cmp`, DOSBox-X, `mtools`, and QEMU (`qemu-system-i386`) for the GR-DOS tests. `make test` fails without `mtools`, which its disk-full step needs; `make test NO_DISKFULL=1` leaves that step out on purpose.

On Ubuntu 24.04, as CI uses: `sudo apt-get install p7zip-full dosbox-x qemu-system-x86 mtools`.

The build downloads what it needs into `build/`, and checks each download's SHA-256:

| What | Pinned by | From |
|---|---|---|
| `gzip-1.2.4.msdos.exe`, GNU's MS-DOS distribution | `upstream/SHA256SUMS` | <https://ftp.gnu.org/gnu/gzip/> |
| each file in it | `upstream/msdos.sha256` | the archive, unpacked |
| `gzip-1.2.4.tar.gz`, GNU gzip 1.2.4's source, for `make source` and releases | `upstream/SHA256SUMS` | <https://ftp.gnu.org/gnu/gzip/> |
| GR-DOS 0.06's 1.44 MB floppy, for `make test-grdos` | `scripts/fetch-grdos` | github.com/gr-dos/gr-dos releases |

`GNU_MIRROR` sets another GNU mirror (it must serve the same bytes).

## Commands

| Command | What it does |
|---|---|
| `make` | fetches `gzip-1.2.4.msdos.exe` (`scripts/fetch-upstream`), unpacks it (`scripts/extract`) and copies its `GZIP.EXE` to `gzip.exe` |
| `make test` | `tests/run.sh` under DOSBox-X on an emulated 8086, with the disk-full step on a floppy image |
| `make test-grdos` | the same steps on GR-DOS, booted in QEMU |
| `make source` | fetches `gzip-1.2.4.tar.gz` |
| `make clean` | removes what the build made, but not the downloads |

## How the program is taken

`gzip-1.2.4.msdos.exe` is an LHA (`-lh5-`) archive behind a DOS self-extractor ("LHA's SFX 2.11S", which renames itself `GZIP08.EXE`). The self-extractor is never run, and is not shipped: `scripts/extract` unpacks the archive on the host with `7z` and checks that it holds exactly these files, each with the SHA-256 `upstream/msdos.sha256` pins:

| File | Bytes | |
|---|---|---|
| `GZIP.EXE` | 39,910 | **the 16-bit real-mode program**, packed with LZEXE 0.91: `gzip.exe` |
| `GZIP386.EXE` | 121,868 | the 32-bit program, for a 386, with DJGPP 1.10's DOS extender: not used |
| `README`, `README.DOS` | 7,443, 2,270 | GNU's notes |
| `GZIP.DOC` | 16,045 | the manual page |
| `COPYING` | 18,321 | the GNU GPL version 2, with CR LF line ends; the same text as `COPYING` here |

So a changed upstream archive fails the build, and `GZIP386.EXE` can never be taken for `GZIP.EXE`; `scripts/extract` also checks that `GZIP.EXE` is an LZEXE-packed MZ program without the DOS extender's messages.

## The source

The program's source is GNU gzip 1.2.4's, `gzip-1.2.4.tar.gz`, which GNU publishes beside the MS-DOS distribution. Its `msdos/` directory has the DOS makefiles (`Makefile.msc` for Microsoft C, `Makefile.bor` and `doturboc.bat` for Borland and Turbo C) and the assembly `match.asm`. GNU's `README.DOS` says the 16-bit program was compiled with `-DSMALL_MEM`, but not with which compiler. gzip16 has not rebuilt it, and cannot rebuild it byte for byte, so the source shipped is GNU's, as GNU distributes it with this program.

Each release's source archive, `gzip16-V-src.tar.gz`, is this repository's tree at the release's tag with GNU's two files, unchanged, in its `upstream/`: `gzip-1.2.4.tar.gz` and `gzip-1.2.4.msdos.exe`. `scripts/fetch-upstream` takes them from there before it downloads, so a tree unpacked from the archive makes `gzip.exe` with no network.

## Releases

A release is made when a merge to `main` changes `VERSION` (`.github/workflows/release.yml`). It builds and tests, then:

1. `scripts/release-files build/release` makes the source archive, `GPL-2.0.txt` (`COPYING`) and the release notes, after checking that `gzip.exe` is the pinned `GZIP.EXE`, that the checkout has no changes, and that `dist16.source` names this `VERSION`'s archive;
2. `scripts/check-source` unpacks the archive, makes `gzip.exe` from it alone (`GZIP16_OFFLINE=1`), and compares it with the one released;
3. the release `vV` is published with `gzip.exe`, `gzip16-V-src.tar.gz` and `GPL-2.0.txt`.

When `VERSION` changes, `dist16.source`'s `source` line must change with it.

## GR-DOS

GR-DOS's `dist16` finds `gr-dos/gzip16` because its name ends in 16, and takes its release's `gzip.exe` as `GZIP.EXE`. Its license is GPL version 2 or later, one of `dist16`'s source licenses, so `dist16` checks `dist16.source` and the source archive it names, and ships the archive in the release ZIP's `SOURCE` (gr-dos/gr-dos, `docs/dist16.md`).
