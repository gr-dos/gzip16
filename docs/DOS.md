# GZIP on DOS

`GZIP.EXE` is GNU gzip 1.2.4's 16-bit MS-DOS program, as GNU released it in 1993. This page describes how that program behaves on DOS, as `tests/run.sh` checks it under DOSBox-X on an emulated 8086 and on GR-DOS. `GZIP.DOC`, GNU's manual page, is in `gzip-1.2.4.msdos.exe` and in `gzip-1.2.4.tar.gz` (as `gzip.1`).

## Requirements

- **CPU:** an 8088 or 8086, or later. It is a real-mode program, with no DOS extender, DPMI or 386 code. (GNU's distribution also has `GZIP386.EXE`, a 32-bit DJGPP build for a 386, which gzip16 does not ship.)
- **Memory:** about **306 KB of free conventional memory**. Its header asks DOS for 272,736 bytes more than its 39,878-byte image, and it is the same for compressing and for decompressing. Under DOSBox-X it runs with a 342 KB DOS memory limit and not with 338 KB. On GR-DOS in QEMU, 585,952 bytes are free for it.
- **Disk:** 39,910 bytes (40 KB on a FAT disk with 512-byte, 1 KB or 2 KB clusters).

## Commands

One program both compresses and decompresses. There is no `GUNZIP.EXE` or `ZCAT.EXE`: use `GZIP -d` and `GZIP -dc` (GNU's `README.DOS` suggests copying `GZIP.EXE` to those names, and that works too).

```dos
GZIP FILE.TXT            compress FILE.TXT to FILE.TXZ, and delete FILE.TXT
GZIP -9 FILE.TXT         the same, compressing best (-1 is fastest; -6 is the default)
GZIP -c FILE.TXT > F.GZ  compress to standard output, keeping FILE.TXT
GZIP -dN FILE.TXZ        decompress, restoring the name stored in it: FILE.TXT
GZIP -d ARCHIVE.GZ       decompress ARCHIVE.GZ to ARCHIVE
GZIP -dc FILE.TXZ | MORE decompress to standard output
GZIP -t FILE.TXZ         test it
GZIP -l FILE.TXZ         list its sizes and ratio
```

Standard input and output work, and so do pipes (`TYPE A.TXT | GZIP > A.GZ`, `GZIP -dc A.GZ | GZIP -c > B.GZ`). The options, as `GZIP.DOC` describes them: `-a -c -d -f -h -l -L -n -N -q -r -S .suf -t -v -V` and `-1` to `-9`. `-h`, `-V`, `-L` and every message go to standard error, which DOS cannot redirect.

## File names

DOS names are 8.3, so gzip cannot always add `.gz`. A name with no extension gets `.GZ`; otherwise gzip adds a `z` to the extension, and when it already has three letters, the `z` takes the place of the last one:

| Compressing | gives |
|---|---|
| `README` | `README.GZ` |
| `AB.C` | `AB.CZ` |
| `HELLO.TXT` | `HELLO.TXZ` |
| `BIN.DAT` | `BIN.DAZ` |

The compressed file keeps the original name (in lower case) in its header, as `gzip` on other systems does.

Decompressing removes the suffix it finds, `.gz`, `-gz`, `.z`, `-z`, `_z` or `.Z`, so `ARCHIVE.GZ` becomes `ARCHIVE`. But **`GZIP -d HELLO.TXZ` makes `HELLO.TX`**: the letter the `z` replaced is lost. **Use `-N`** (`GZIP -dN HELLO.TXZ`), which takes the name stored in the file: `HELLO.TXT`. A long stored name is cut to 8.3, so a file made on another system as `a-long-file-name.text` comes back as `A-LONG-F.TEX`. To make `-N` the default, as GNU's `README.DOS` suggests, put `SET GZIP=-N` in `AUTOEXEC.BAT`.

## When the output file exists

Without `-f`, **gzip asks** "already exists; do you wish to overwrite (y or n)?" when the file it would write is already there, and **waits for an answer from the console**, even in a batch file. Use `-f` to replace it without asking, or `-c` with redirection.

## Exit status

| Status | Meaning |
|---|---|
| 0 | done |
| 1 | an error: a file that is not there, not gzip data, a bad CRC, a truncated file, a full disk |
| 2 | a warning: for example a file that already has the `z` suffix, left unchanged |

On an error, gzip deletes the file it was writing and keeps its input: a broken `FOO.GZ` is kept, and no `FOO` is left. When the disk fills while compressing in place, the original is kept, unchanged, and nothing is left on the disk. With `-c`, what was written before the error stays in the redirected output, which the shell, not gzip, made.

## Compatibility

- Files it makes decompress with any gzip. They are not byte for byte what another gzip makes: this program was built with `SMALL_MEM`, which compresses slightly less well.
- It decompresses what modern gzip makes, including files of several members (`cat A.GZ B.GZ`) and files over 64 KB.
- Its time stamps are local time; it ignores `TZ`.
- It knows nothing of features after 1993: there is no `-k` (use `-c`), no `--rsyncable`, and no multi-threading.
