# gzip16

GNU gzip 1.2.4 for 16-bit MS-DOS: `GZIP.EXE`, for an 8088 or later, and GR-DOS. It compresses and decompresses gzip files, as `gzip` makes them on other systems.

```dos
GZIP REPORT.TXT          makes REPORT.TXZ
GZIP -dN REPORT.TXZ      gives back REPORT.TXT
GZIP -dc ARCHIVE.GZ > ARCHIVE.TAR
```

This is **GNU's own MS-DOS program**, `GZIP.EXE` from GNU's 1993 MS-DOS distribution, [`gzip-1.2.4.msdos.exe`](https://ftp.gnu.org/gnu/gzip/gzip-1.2.4.msdos.exe), unchanged. gzip16 fetches it, checks it against pinned checksums, tests it on an 8086 and on GR-DOS, and releases it with its license and source. It is not a new port, and not GR-DOS's code.

- **Manual:** [`docs/DOS.md`](docs/DOS.md): commands, 8.3 file names (use `-dN`), memory (about 306 KB free), exit status, limits.
- **Download:** `gzip.exe` from the [latest release](https://github.com/gr-dos/gzip16/releases/latest), with its source.
- **Building:** [`BUILDING.md`](BUILDING.md): how the program is taken from GNU's distribution, and where its source is.

## License

GPL version 2 or any later version ([`COPYING`](COPYING)), as GNU gzip 1.2.4 is; authors and notices are in [`NOTICE`](NOTICE). Each release carries the source: GNU gzip 1.2.4's `gzip-1.2.4.tar.gz`, unchanged.
