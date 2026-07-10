"""CLI helper for run.bat: prints one value from stem-splitter.ini.

Usage: read_ini.py <ini-path> <section> <key>
Prints the value (stripped), or an empty line if the file/section/key is
missing - run.bat falls back to its own default in that case.
"""
import configparser
import sys


def main() -> None:
    ini_path, section, key = sys.argv[1], sys.argv[2], sys.argv[3]

    parser = configparser.ConfigParser(interpolation=None)
    parser.read(ini_path, encoding="utf-8-sig")
    value = parser.get(section, key, fallback="") if parser.has_section(section) else ""
    print(value.strip())


if __name__ == "__main__":
    main()
