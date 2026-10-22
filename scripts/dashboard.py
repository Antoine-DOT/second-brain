#!/usr/bin/env python3
"""Regenerates the dashboard in Home.md from the tracking fields, and Library.md.

A page is tracked when its frontmatter has `tracked: true`. Fields read:
area, status, next_step, due (YYYY-MM-DD), open_questions (JSON list), reviewed.
Only the block between the dashboard:start / dashboard:end markers is rewritten.
"""
import datetime
import json
import pathlib
import re

VAULT = pathlib.Path(__file__).resolve().parent.parent
HOME = VAULT / "Home.md"
START, END = "<!-- dashboard:start -->", "<!-- dashboard:end -->"
AREAS = [("Business", "🏢 Business"), ("Clients", "👥 Clients"), ("Projects", "📂 Projects"), ("Personal", "🌱 Personal")]
STATUS = {"active": "🟢 active", "waiting": "🟡 waiting", "paused": "⏸️ paused", "done": "✅ done"}
ORDER = {"active": 0, "waiting": 1, "paused": 2, "done": 3}


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    data = {}
    for line in (m.group(1).split("\n") if m else []):
        k, sep, v = line.partition(":")
        if not sep:
            continue
        v = v.strip()
        if v.startswith("[") or v.startswith('"'):
            try:
                v = json.loads(v)
            except ValueError:
                pass
        data[k.strip()] = v
    return data


def title(text, fallback):
    m = re.search(r"^# (.+)$", text, re.M)
    t = m.group(1) if m else fallback
    return re.sub(r"^[^\wÀ-ÿ]+", "", t).strip()


def link(rel, name, table=False):
    return f"[[{rel}{chr(92) if table else ''}|{name}]]"


def inbox_items():
    """Non-empty lines written after the marker in Inbox.md."""
    path = VAULT / "Inbox.md"
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    _, sep, rest = text.partition("<!-- inbox:start -->")
    return [l for l in rest.split("\n") if l.strip()] if sep else []


def when(d, today):
    try:
        date = datetime.date.fromisoformat(str(d))
    except ValueError:
        return str(d)
    delta = (date - today).days
    tag = "today" if delta == 0 else (f"in {delta} d" if delta > 0 else f"⚠️ {-delta} d overdue")
    return f"{date:%b %d} ({tag})"


def main():
    today = datetime.date.today()
    items = []
    for path in sorted((VAULT / "wiki").rglob("*.md")):
        text = path.read_text(encoding="utf-8")
        fm = frontmatter(text)
        if str(fm.get("tracked", "")).lower() != "true":
            continue
        rel = path.relative_to(VAULT).with_suffix("").as_posix()
        items.append({**fm, "rel": rel, "name": title(text, path.stem)})

    out = [START, f"_Dashboard generated on {today:%Y-%m-%d} from tracked pages. Don't edit this block by hand: update the page, then run `python3 scripts/dashboard.py`._", ""]

    pending = inbox_items()
    if pending:
        out += [f"> [!todo] 📥 [[Inbox]]: {len(pending)} item(s) to triage. Start an agent session and it will file them.", ""]

    dated = sorted((i for i in items if i.get("due") and i.get("status") != "done"), key=lambda i: str(i["due"]))
    out.append("## 📅 Upcoming deadlines")
    out += [f"- **{when(i['due'], today)}**: {link(i['rel'], i['name'])}, {i.get('next_step', '')}" for i in dated] or ["_None._"]
    out.append("")

    for key, heading in AREAS:
        rows = sorted((i for i in items if i.get("area") == key), key=lambda i: (ORDER.get(i.get("status"), 9), i["name"]))
        if not rows:
            continue
        out += [f"## {heading}", "| Topic | Status | Next step | Due |", "|---|---|---|---|"]
        for i in rows:
            due = when(i["due"], today) if i.get("due") else ""
            out.append(f"| {link(i['rel'], i['name'], True)} | {STATUS.get(i.get('status'), i.get('status', ''))} | {i.get('next_step', '')} | {due} |")
        out.append("")

    questions = [(i, q) for i in items for q in (i.get("open_questions") or []) if isinstance(i.get("open_questions"), list)]
    out.append("## 💭 Open questions")
    out += [f"- {q} ({link(i['rel'], i['name'])})" for i, q in questions] or ["_None._"]
    out.append("")

    log = (VAULT / "wiki" / "log.md").read_text(encoding="utf-8")
    recent = re.findall(r"^## \[(\d{4}-\d{2}-\d{2})\] (\w+) \| (.+)$", log, re.M)[-5:][::-1]
    out.append("## 🕘 Latest updates")
    out += [f"- {d} · {op} · {t}" for d, op, t in recent]
    out.append(END)

    home = HOME.read_text(encoding="utf-8")
    block = "\n".join(out)
    if START in home and END in home:
        home = home[: home.index(START)] + block + home[home.index(END) + len(END):]
    else:
        lines = home.split("\n", 2)
        home = "\n".join(lines[:2]) + "\n" + block + "\n\n" + (lines[2] if len(lines) > 2 else "")
    HOME.write_text(home, encoding="utf-8")
    print(f"dashboard: {len(items)} tracked pages, {len(dated)} deadlines, {len(questions)} open questions")
    library(today)


def library(today):
    """Generates Library.md entirely from `library: true` sources and topic pages."""
    sources, captures = [], []
    for path in sorted((VAULT / "wiki" / "sources").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        fm = frontmatter(text)
        if str(fm.get("library", "")).lower() != "true":
            continue
        rel = path.relative_to(VAULT).with_suffix("").as_posix()
        name = fm.get("title") or title(text, path.stem)
        heads = re.findall(r"^### 📌 (.*?)(?: · (\d{4}-\d{2}-\d{2}))?$", text, re.M)
        sources.append({**fm, "rel": rel, "name": name, "n": len(heads)})
        captures += [(d, rel, name, where) for where, d in heads if d]

    topics = []
    for path in sorted((VAULT / "wiki" / "concepts").glob("*.md")):
        text = path.read_text(encoding="utf-8")
        if "topic" not in str(frontmatter(text).get("tags", "")):
            continue
        refs = set(re.findall(r"\[\[(wiki/)?sources/([^\]|#]+)", text))
        lines = re.findall(r"^- .+\[\[(?:wiki/)?sources/", text, re.M)
        topics.append((len(lines), len(refs), path.relative_to(VAULT).with_suffix("").as_posix(), title(text, path.stem)))

    out = ["# 📚 Library", "",
           f"_Page generated on {today:%Y-%m-%d} by `scripts/dashboard.py`: don't edit it by hand. To add something, tell the agent \"note this: …\"._", ""]
    for state, heading in [("in progress", "📖 In progress"), ("finished", "✅ Finished"), ("to read", "🔖 To read / to watch")]:
        rows = [s for s in sources if s.get("reading", "in progress") == state]
        if not rows:
            continue
        out += [f"## {heading}", "| Work | Type | Author | Captures | Topics |", "|---|---|---|---:|---|"]
        for s in sorted(rows, key=lambda s: -s["n"]):
            subj = s.get("topics") if isinstance(s.get("topics"), list) else []
            subj_links = ", ".join(link(x, x.split("/")[-1], True) for x in subj)
            out.append(f"| {link(s['rel'], s['name'], True)} | {s.get('type', '')} | {s.get('author', '')} | {s['n']} | {subj_links} |")
        out.append("")
    if not sources:
        out += ["_Empty for now. First capture: \"note this: in *Title*, p. 27, they say \"…\"\"._", ""]

    out += ["## 🧩 Topics", "| Topic | Quotes and ideas | Sources |", "|---|---:|---:|"]
    out += [f"| {link(rel, name, True)} | {n} | {k} |" for n, k, rel, name in sorted(topics, reverse=True)] or ["| _none_ | | |"]
    out += ["", "## 🕘 Latest captures"]
    out += [f"- {d} · {link(rel, name)} · {where}" for d, rel, name, where in sorted(captures, reverse=True)[:10]] or ["_None._"]
    (VAULT / "Library.md").write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"library: {len(sources)} works, {len(captures)} captures, {len(topics)} topics")


if __name__ == "__main__":
    main()
