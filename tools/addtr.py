#!/usr/bin/env python3
"""Add or replace translations in i18n_pt.gd / i18n_es.gd.
    python3 tools/addtr.py lines.txt
Each line of lines.txt: English ¦ Português ¦ Español   (blank lines and # comments skipped)
A key that's already there gets its translation replaced; new keys go at the end of the table.
Rules: no dashes in game text (1.17), keep %s / %d in the same order.
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def esc(s: str) -> str:
	return json.dumps(s, ensure_ascii=False)


def apply(path: pathlib.Path, pairs: list) -> int:
	src = path.read_text(encoding="utf-8")
	n = 0
	for en, tr in pairs:
		line = "\t%s: %s," % (esc(en), esc(tr))
		pat = re.compile(r"^\t" + re.escape(esc(en)) + r": .*,$", re.M)
		if pat.search(src):
			src = pat.sub(lambda _m: line, src, count=1)
		else:
			k = src.rstrip().rfind("}")
			src = src[:k] + line + "\n" + src[k:]
		n += 1
	path.write_text(src, encoding="utf-8")
	return n


def main() -> None:
	pt, es = [], []
	for raw in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
		if not raw.strip() or raw.lstrip().startswith("#"):
			continue
		parts = [p.strip() for p in raw.split("¦")]
		if len(parts) != 3:
			sys.exit("bad line: " + raw)
		for p in parts:
			if " - " in p or "—" in p or "–" in p:
				sys.exit("dash in game text: " + raw)
		pt.append((parts[0], parts[1]))
		es.append((parts[0], parts[2]))
	print("pt", apply(ROOT / "i18n_pt.gd", pt), "es", apply(ROOT / "i18n_es.gd", es))


main()
