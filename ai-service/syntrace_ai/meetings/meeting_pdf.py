"""
meeting_pdf.py
The approved meeting's requirements as a PDF: a header (project, meeting, date), then the notes the user
approved, heading by heading. Arabic words in it (a deadline said as "الخميس", a name) are shaped right to
left when uharfbuzz is installed. Fonts: DejaVu Sans (MEETING_PDF_FONT / MEETING_PDF_BOLD_FONT).
"""
import os
from datetime import datetime, timezone

import re

from syntrace_ai.meetings.document import sections
from syntrace_ai.meetings.notes import SECTIONS

REVIEW_MARK = re.compile(r"(?:; )?needs review(?=\))|\(needs review\)")


def _first(*paths):
    return next((p for p in paths if p and os.path.exists(p)), paths[-1])


# DejaVu Sans in the image (fonts-dejavu-core); Arial on a Windows machine; both have Arabic letters
FONT = _first(os.getenv("MEETING_PDF_FONT"), "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
              r"C:\Windows\Fonts\arial.ttf")
BOLD = _first(os.getenv("MEETING_PDF_BOLD_FONT"), "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              r"C:\Windows\Fonts\arialbd.ttf")


def build(project, title, date, notes):
    """-> the PDF as bytes."""
    from fpdf import FPDF
    pdf = FPDF(format="A4")
    pdf.set_margins(18, 16, 18)
    pdf.set_auto_page_break(True, margin=16)
    pdf.add_font("body", "", FONT)
    pdf.add_font("body", "B", BOLD if os.path.exists(BOLD) else FONT)
    try:
        pdf.set_text_shaping(True)   # Arabic letters joined and right to left
    except Exception:   # uharfbuzz missing: the English text is still right
        pass
    pdf.add_page()
    width = pdf.w - pdf.l_margin - pdf.r_margin
    pdf.set_font("body", "B", 17)
    pdf.multi_cell(width, 9, "Meeting Requirements", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("body", "", 10.5)
    header = [f"Project: {project or '-'}", f"Meeting: {title or '-'}", f"Date: {date or '-'}",
              f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d')}"]
    pdf.set_text_color(90, 90, 90)
    pdf.multi_cell(width, 6, "   |   ".join(header), new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0, 0, 0)
    pdf.ln(3)
    named = {title for _, title in SECTIONS} | {"Overview", "Topics discussed", "Out of scope"}
    for heading, lines in sections(notes):
        if heading and heading not in named:   # a topic under "Topics discussed": a smaller heading
            pdf.ln(1)
            pdf.set_font("body", "B", 11)
            pdf.multi_cell(width, 6.5, heading, new_x="LMARGIN", new_y="NEXT")
        elif heading:
            pdf.ln(2)
            pdf.set_font("body", "B", 12.5)
            pdf.multi_cell(width, 7, heading, new_x="LMARGIN", new_y="NEXT")
            pdf.set_draw_color(200, 200, 200)
            pdf.line(pdf.l_margin, pdf.get_y(), pdf.l_margin + width, pdf.get_y())
            pdf.ln(1.5)
        pdf.set_font("body", "", 10.5)
        for line in lines:
            line = REVIEW_MARK.sub("", line).replace(" ()", "").rstrip()   # approved: no review marks in the PDF
            pdf.set_x(pdf.l_margin)
            pdf.cell(5, 6, "•")
            pdf.multi_cell(width - 5, 6, line, new_x="LMARGIN", new_y="NEXT")
    return bytes(pdf.output())
