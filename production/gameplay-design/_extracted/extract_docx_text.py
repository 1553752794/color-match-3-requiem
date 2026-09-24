from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_extracted"


def cell_text(cell) -> str:
    return " / ".join(
        part.strip() for part in cell.text.replace("\r", "\n").split("\n") if part.strip()
    )


for docx_path in sorted(ROOT.glob("*.docx")):
    doc = Document(str(docx_path))
    lines: list[str] = [f"# {docx_path.stem}", ""]

    for paragraph in doc.paragraphs:
        text = paragraph.text.strip()
        if text:
            lines.append(text)

    for index, table in enumerate(doc.tables, start=1):
        lines.append("")
        lines.append(f"## Table {index}")
        for row in table.rows:
            cells = [cell_text(cell) for cell in row.cells]
            if any(cells):
                lines.append(" | ".join(cells))

    output_path = OUT / f"{docx_path.stem}.md"
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{docx_path.name}: {len(doc.paragraphs)} paragraphs, {len(doc.tables)} tables")
