#!/usr/bin/env python3
"""TurfGo Mobile App Audit Report Generator"""

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.platypus.flowables import Flowable
from reportlab.pdfgen import canvas

# ── Brand colours ──────────────────────────────────────────────────────────────
BRAND_GREEN   = colors.HexColor("#00C96A")
DARK_GREEN    = colors.HexColor("#00854A")
DARKER_GREEN  = colors.HexColor("#005C34")
BLACK         = colors.HexColor("#1A1A1A")
DARK_GRAY     = colors.HexColor("#2C2C2C")
MID_GRAY      = colors.HexColor("#555555")
LIGHT_GRAY    = colors.HexColor("#F5F5F5")
ROW_ALT       = colors.HexColor("#F0FFF8")   # very pale green for alternating rows
TABLE_HEADER  = colors.HexColor("#005C34")
TABLE_BORDER  = colors.HexColor("#C8E6D1")
WHITE         = colors.white

SEV_CRITICAL  = colors.HexColor("#D32F2F")
SEV_HIGH      = colors.HexColor("#E65100")
SEV_MEDIUM    = colors.HexColor("#F9A825")
SEV_LOW       = colors.HexColor("#388E3C")
SEV_PASS      = colors.HexColor("#1565C0")

PAGE_W, PAGE_H = A4
MARGIN = 20 * mm

# ── Page numbering canvas ──────────────────────────────────────────────────────
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        page_num = self._pageNumber
        if page_num == 1:
            return  # no number on cover
        self.saveState()
        self.setFillColor(MID_GRAY)
        self.setFont("Helvetica", 8)
        text = f"TurfGo Audit Report  ·  Page {page_num} of {page_count}"
        self.drawCentredString(PAGE_W / 2, 12 * mm, text)
        # thin footer rule
        self.setStrokeColor(TABLE_BORDER)
        self.setLineWidth(0.5)
        self.line(MARGIN, 17 * mm, PAGE_W - MARGIN, 17 * mm)
        self.restoreState()

# ── Style helpers ──────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()

def style(name, **kw):
    return ParagraphStyle(name, **kw)

H1 = style("H1", fontName="Helvetica-Bold", fontSize=22, textColor=DARK_GREEN,
           spaceAfter=6, spaceBefore=14)
H2 = style("H2", fontName="Helvetica-Bold", fontSize=14, textColor=DARK_GREEN,
           spaceAfter=4, spaceBefore=10)
H3 = style("H3", fontName="Helvetica-Bold", fontSize=11, textColor=DARK_GRAY,
           spaceAfter=3, spaceBefore=7)
BODY = style("BODY", fontName="Helvetica", fontSize=9.5, textColor=BLACK,
             spaceAfter=4, leading=14)
BODY_SMALL = style("BODY_SMALL", fontName="Helvetica", fontSize=8.5,
                   textColor=MID_GRAY, spaceAfter=3, leading=12)
LABEL = style("LABEL", fontName="Helvetica-Bold", fontSize=9, textColor=DARK_GRAY,
              spaceAfter=2)
ITALIC = style("ITALIC", fontName="Helvetica-Oblique", fontSize=9,
               textColor=MID_GRAY, spaceAfter=4, leading=13)
CENTER = style("CENTER", fontName="Helvetica", fontSize=9.5, textColor=BLACK,
               alignment=TA_CENTER, spaceAfter=4)
NOTE = style("NOTE", fontName="Helvetica-Oblique", fontSize=9,
             textColor=DARK_GREEN, spaceAfter=6, leading=13, borderPadding=(6,6,6,6))

def sev_color(sev):
    return {
        "CRITICAL": SEV_CRITICAL,
        "HIGH":     SEV_HIGH,
        "MEDIUM":   SEV_MEDIUM,
        "LOW":      SEV_LOW,
        "PASS":     SEV_PASS,
        "WRITTEN":  SEV_PASS,
        "MISSING":  SEV_CRITICAL,
        "PARTIAL":  SEV_MEDIUM,
        "COMPLETE": SEV_LOW,
        "NOT STARTED": MID_GRAY,
        "NOT ACTIVE": SEV_CRITICAL,
    }.get(sev.upper().strip(), BLACK)

def hex6(color_obj):
    """Return a 6-digit hex string (no prefix) suitable for ReportLab markup."""
    h = color_obj.hexval()          # e.g. '0x1565c0' or '0xd32f2f'
    return h.replace("0x", "").zfill(6)

def sev_para(text):
    col = sev_color(text)
    return Paragraph(f'<font color="#{hex6(col)}"><b>{text}</b></font>',
                     ParagraphStyle("sev", fontName="Helvetica-Bold", fontSize=8.5,
                                    alignment=TA_CENTER))

def score_para(score_str):
    return Paragraph(f'<b>{score_str}</b>',
                     ParagraphStyle("sc", fontName="Helvetica-Bold", fontSize=11,
                                    textColor=DARK_GREEN, alignment=TA_CENTER))

def section_rule():
    return HRFlowable(width="100%", thickness=1.2, color=BRAND_GREEN,
                      spaceAfter=8, spaceBefore=2)

def thin_rule():
    return HRFlowable(width="100%", thickness=0.4, color=TABLE_BORDER,
                      spaceAfter=6, spaceBefore=0)

def cell(text, bold=False, color=BLACK, align=TA_LEFT, size=9):
    s = ParagraphStyle("tc", fontName="Helvetica-Bold" if bold else "Helvetica",
                       fontSize=size, textColor=color, alignment=align, leading=12)
    return Paragraph(str(text), s)

def header_cell(text):
    return cell(text, bold=True, color=WHITE, align=TA_CENTER, size=9)

def make_table(headers, rows, col_widths, alt=True):
    data = [[header_cell(h) for h in headers]]
    for i, row in enumerate(rows):
        bg = ROW_ALT if (alt and i % 2 == 1) else WHITE
        data.append(row)
    ts = TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), TABLE_HEADER),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, ROW_ALT] if alt else [WHITE]),
        ("GRID", (0, 0), (-1, -1), 0.5, TABLE_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(ts)
    return t

# ── Cover page background ──────────────────────────────────────────────────────
class CoverBackground(Flowable):
    def __init__(self, w, h):
        Flowable.__init__(self)
        self.w, self.h = w, h
        self.width = w
        self.height = 0

    def draw(self):
        c = self.canv
        c.saveState()
        # Full dark green background
        c.setFillColor(DARKER_GREEN)
        c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

        # Decorative diagonal stripe
        c.setFillColor(DARK_GREEN)
        p = c.beginPath()
        p.moveTo(0, PAGE_H * 0.55)
        p.lineTo(PAGE_W, PAGE_H * 0.38)
        p.lineTo(PAGE_W, PAGE_H * 0.52)
        p.lineTo(0, PAGE_H * 0.69)
        p.close()
        c.drawPath(p, fill=1, stroke=0)

        # Bottom accent
        c.setFillColor(BRAND_GREEN)
        c.rect(0, 0, PAGE_W, 18 * mm, fill=1, stroke=0)

        # Accent circle decoration
        c.setFillColorRGB(0, 0.6, 0.35, alpha=0.18)
        c.circle(PAGE_W * 0.85, PAGE_H * 0.72, 80, fill=1, stroke=0)
        c.setFillColorRGB(0, 0.6, 0.35, alpha=0.10)
        c.circle(PAGE_W * 0.15, PAGE_H * 0.25, 55, fill=1, stroke=0)

        c.restoreState()

# ── Build the document ─────────────────────────────────────────────────────────
def build_pdf(path):
    doc = SimpleDocTemplate(
        path,
        pagesize=A4,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=22 * mm,
        title="TurfGo Mobile App Audit Report",
        author="TurfGo Audit",
    )

    story = []
    CW = PAGE_W - 2 * MARGIN   # content width

    # ── COVER PAGE ─────────────────────────────────────────────────────────────
    def cover_para(txt, size, bold=False, color=WHITE, top=0, align=TA_CENTER):
        return Paragraph(
            txt,
            ParagraphStyle("cp", fontName="Helvetica-Bold" if bold else "Helvetica",
                           fontSize=size, textColor=color, alignment=align,
                           spaceBefore=top, spaceAfter=0, leading=size * 1.3)
        )

    story.append(CoverBackground(PAGE_W, PAGE_H))
    story.append(Spacer(1, 95 * mm))
    story.append(cover_para("TURFGO", 42, bold=True, color=BRAND_GREEN))
    story.append(Spacer(1, 3 * mm))
    story.append(cover_para("Mobile App Audit Report", 22, color=WHITE))
    story.append(Spacer(1, 4 * mm))
    story.append(cover_para("Comprehensive Technical & Security Analysis", 12, color=colors.HexColor("#A8E6C4")))
    story.append(Spacer(1, 28 * mm))
    story.append(cover_para("March 2026", 11, color=colors.HexColor("#C8F0DC")))
    story.append(Spacer(1, 2 * mm))
    story.append(cover_para("Prepared for: Kavin R P, Founder", 11, color=colors.HexColor("#C8F0DC")))
    story.append(Spacer(1, 2 * mm))
    story.append(cover_para("Stack: Flutter · Firebase · Riverpod · GoRouter · Razorpay", 9,
                             color=colors.HexColor("#90D4B0")))

    story.append(PageBreak())

    # ── helper: section title ──────────────────────────────────────────────────
    def sec(title, score=None):
        if score:
            story.append(Table(
                [[Paragraph(title, H1), score_para(score)]],
                colWidths=[CW * 0.78, CW * 0.22],
                style=[("VALIGN", (0, 0), (-1, -1), "BOTTOM"),
                       ("ALIGN", (1, 0), (1, 0), "RIGHT"),
                       ("BOTTOMPADDING", (0, 0), (-1, -1), 0)]
            ))
        else:
            story.append(Paragraph(title, H1))
        story.append(section_rule())

    def bullet(txt):
        story.append(Paragraph(f"<bullet>&bull;</bullet> {txt}", BODY))

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 1 — EXECUTIVE SUMMARY
    # ══════════════════════════════════════════════════════════════════════════
    sec("Executive Summary")

    # overall score box
    score_box = Table(
        [[Paragraph('<font color="#00C96A"><b>Overall Health Score</b></font>', ParagraphStyle(
            "sb", fontName="Helvetica-Bold", fontSize=18, textColor=BRAND_GREEN, alignment=TA_CENTER)),
          Paragraph('<b>62 / 100</b>', ParagraphStyle(
            "sv", fontName="Helvetica-Bold", fontSize=28, textColor=DARK_GREEN, alignment=TA_CENTER)),
          Paragraph('<b>C+</b>', ParagraphStyle(
            "sg", fontName="Helvetica-Bold", fontSize=28, textColor=DARK_GREEN, alignment=TA_CENTER))]],
        colWidths=[CW * 0.45, CW * 0.30, CW * 0.25],
        style=[
            ("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
            ("BOX", (0, 0), (-1, -1), 1.5, BRAND_GREEN),
            ("INNERGRID", (0, 0), (-1, -1), 0.5, TABLE_BORDER),
            ("TOPPADDING", (0, 0), (-1, -1), 10),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]
    )
    story.append(score_box)
    story.append(Spacer(1, 8 * mm))

    story.append(Paragraph("Top 5 Strengths", H2))
    strengths = [
        "Production-grade Firestore security rules — better than most funded startups",
        "Correct architecture: Cloud Functions as sole payment security boundary, HMAC verification",
        "Centralized utilities (TurfDateUtils, AppColors, BookingStatus, AmenityUtils) — clean single source of truth",
        "Server-side amount recalculation — client can never manipulate payment amount",
        "Cross-turf exploit protection via pendingOrders verification — rare at this stage",
    ]
    for i, s in enumerate(strengths, 1):
        story.append(Paragraph(f"<b>{i}.</b> {s}", BODY))

    story.append(Spacer(1, 4 * mm))
    story.append(Paragraph("Top 5 Weaknesses", H2))
    weaknesses = [
        ('<font color="#D32F2F"><b>Cloud Functions not deployed</b></font> — payment flow completely non-functional',),
        ("No tests whatsoever — single default counter widget test",),
        ("No pagination — entire booking collections loaded into memory",),
        ('<font color="#E65100"><b>No App Check</b></font> — CF endpoints exposed to anyone with project ID',),
        ("Razorpay webhook missing — payment/booking mismatch possible",),
    ]
    for i, (w,) in enumerate(weaknesses, 1):
        story.append(Paragraph(f"<b>{i}.</b> {w}", BODY))

    story.append(Spacer(1, 5 * mm))
    story.append(Paragraph("Verdict", H2))
    verdict = (
        "TurfGo demonstrates exceptional security architecture for a solo developer project, "
        "with Firestore rules and Cloud Function design that rival funded startups. However, "
        "the app <b>cannot generate revenue today</b> because Cloud Functions are not deployed. "
        "The C+ grade reflects operational gaps, not architectural quality — the foundation is "
        "genuinely strong. <b>Two days of focused work</b> (Blaze activation + CF deployment + "
        "webhook) would push this to a B+ immediately."
    )
    story.append(Paragraph(verdict, BODY))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 2 — ARCHITECTURE
    # ══════════════════════════════════════════════════════════════════════════
    sec("Architecture & Project Structure", "7.5 / 10")

    arch_headers = ["Layer", "Implementation", "Quality"]
    arch_rows = [
        [cell("State Management"), cell("Riverpod + Provider pattern"), sev_para("PASS")],
        [cell("Navigation"), cell("GoRouter (partially mixed with Navigator.push)"), sev_para("MEDIUM")],
        [cell("Data Layer"), cell("Repository pattern, never direct Firestore from widgets"), sev_para("PASS")],
        [cell("Backend"), cell("Cloud Functions as sole write boundary for payments"), sev_para("PASS")],
        [cell("Utilities"), cell("TurfDateUtils, AppColors, BookingStatus, AmenityUtils, Sports"), sev_para("PASS")],
        [cell("Auth"), cell("Firebase Auth + phone OTP"), sev_para("PASS")],
    ]
    story.append(make_table(arch_headers, arch_rows, [CW*0.25, CW*0.55, CW*0.20]))
    story.append(Spacer(1, 5 * mm))

    story.append(Paragraph("Issues Found", H2))
    issues_headers = ["Severity", "Issue"]
    issues_rows = [
        [sev_para("MEDIUM"),
         cell("Navigator.push mixed with GoRouter in 15+ locations across booking_confirmation_screen.dart "
              "and others — breaks deep linking and back-navigation on web")],
        [sev_para("LOW"),
         cell("No service layer — business logic that doesn't fit in repository goes directly into widgets")],
    ]
    story.append(make_table(issues_headers, issues_rows, [CW*0.15, CW*0.85]))
    story.append(Spacer(1, 5 * mm))

    story.append(Paragraph("Folder Structure", H2))
    story.append(Paragraph(
        "lib/core/  ·  lib/data/repositories/  ·  lib/models/  ·  lib/providers/  ·  "
        "lib/screens/  ·  lib/router/  ·  lib/widgets/  ·  functions/src/index.ts",
        ParagraphStyle("mono", fontName="Courier", fontSize=8.5, textColor=DARK_GREEN,
                       backColor=ROW_ALT, borderPadding=(6, 6, 6, 6), leading=13)
    ))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 3 — CODE QUALITY
    # ══════════════════════════════════════════════════════════════════════════
    sec("Code Quality", "6.5 / 10")

    story.append(Paragraph("Completed Improvements", H2))
    cq_headers = ["Fix", "Files Changed", "Impact"]
    cq_rows = [
        [cell("TurfDateUtils centralization"), cell("8 files", align=TA_CENTER),
         cell("Eliminated duplicate date/format methods")],
        [cell("AppColors class"), cell("6+ files", align=TA_CENTER),
         cell("Eliminated magic hex Color(0xFF...) values")],
        [cell("BookingStatus.color/label"), cell("3+ screens", align=TA_CENTER),
         cell("Centralized status display logic")],
        [cell("AmenityUtils"), cell("3 files", align=TA_CENTER),
         cell("Single amenity icon source of truth")],
        [cell("UserRole/Sports constants"), cell("splash_screen, explore_screen", align=TA_CENTER),
         cell("Eliminated magic role strings")],
        [cell("Silent catch fixes"), cell("admin_revenue, admin_bookings_detail", align=TA_CENTER),
         cell("Production errors now logged")],
    ]
    story.append(make_table(cq_headers, cq_rows, [CW*0.30, CW*0.28, CW*0.42]))
    story.append(Spacer(1, 5 * mm))

    story.append(Paragraph("Remaining Issues", H2))
    rem_headers = ["Severity", "Issue"]
    rem_rows = [
        [sev_para("MEDIUM"), cell("9 silent catch(_){} blocks still across codebase — production failures invisible")],
        [sev_para("MEDIUM"), cell("Navigator.push in 15+ locations violates GoRouter-only rule")],
        [sev_para("LOW"),    cell("Some screens 400–600+ lines — god widgets (turf_detail_screen.dart)")],
        [sev_para("LOW"),    cell("Missing field-level documentation on repository methods")],
    ]
    story.append(make_table(rem_headers, rem_rows, [CW*0.15, CW*0.85]))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 4 — SECURITY ANALYSIS
    # ══════════════════════════════════════════════════════════════════════════
    sec("Security Analysis", "7.5 / 10")
    story.append(Paragraph(
        "Score rises to <b>8.5/10</b> once Cloud Functions are deployed.", ITALIC))

    def sec_layer(title, subtitle=""):
        story.append(Spacer(1, 3 * mm))
        story.append(Paragraph(title, H2))
        if subtitle:
            story.append(Paragraph(subtitle, ITALIC))

    sec_headers = ["Finding", "Status", "Severity"]

    sec_layer("Layer 1 — Firestore Rules", "9/10 · DEPLOYED")
    l1_rows = [
        [cell("Role escalation blocked at create AND update"), sev_para("PASS"), cell("")],
        [cell("CF-only write on bookings, slots, transactions, payouts, otpAttempts, referrals"), sev_para("PASS"), cell("")],
        [cell("Field whitelist on users create (hasOnly)"), sev_para("PASS"), cell("")],
        [cell("Users update locked to name/cityId only"), sev_para("PASS"), cell("")],
        [cell("cancelledAt == request.time enforced"), sev_para("PASS"), cell("")],
        [cell("Catch-all deny on unlisted collections"), sev_para("PASS"), cell("")],
        [cell("pendingOrders CF-only, user read own"), sev_para("PASS"), cell("")],
        [cell("ownerRequests CF-only, user/admin read"), sev_para("PASS"), cell("")],
    ]
    story.append(make_table(sec_headers, l1_rows, [CW*0.65, CW*0.20, CW*0.15]))

    sec_layer("Layer 2 — Cloud Functions", "Written, NOT deployed")
    l2_rows = [
        [cell("Auth check on every CF (request.auth)"), sev_para("WRITTEN"), cell("")],
        [cell("HMAC signature verification in createBooking"), sev_para("WRITTEN"), cell("")],
        [cell("Server-side amount recalculation from Firestore pricePerHour"), sev_para("WRITTEN"), cell("")],
        [cell("Cross-turf exploit protection via pendingOrders"), sev_para("WRITTEN"), cell("")],
        [cell("SlotIds deduplication via validateSlotIds()"), sev_para("WRITTEN"), cell("")],
        [cell("Atomic slot-lock + booking transaction"), sev_para("WRITTEN"), cell("")],
        [cell("submitOwnerRequest validate-first pattern"), sev_para("WRITTEN"), cell("")],
        [cell("SlotDate format validation (YYYY-MM-DD regex)"), sev_para("WRITTEN"), cell("")],
        [cell("CF DEPLOYMENT"), sev_para("NOT ACTIVE"), sev_para("CRITICAL")],
    ]
    story.append(make_table(sec_headers, l2_rows, [CW*0.65, CW*0.20, CW*0.15]))

    sec_layer("Layer 3 — Secret Management", "9/10")
    l3_rows = [
        [cell("Razorpay KEY_ID — returned by CF at runtime, never in binary"), sev_para("PASS"), cell("")],
        [cell("Razorpay KEY_SECRET — Firebase Secret Manager only"), sev_para("PASS"), cell("")],
        [cell("firebase_options.dart — gitignored"), sev_para("PASS"), cell("")],
        [cell(".secret.local — gitignored (local emulator only)"), sev_para("PASS"), cell("")],
    ]
    story.append(make_table(sec_headers, l3_rows, [CW*0.65, CW*0.20, CW*0.15]))

    sec_layer("Layer 4 — Client Side", "6/10")
    l4_rows = [
        [cell("Phone validation RegExp(r'^[6-9]\\d{9}$')"), sev_para("PASS"), cell("")],
        [cell("UserRole constants (no magic strings)"), sev_para("PASS"), cell("")],
        [cell("BookingStatus constants"), sev_para("PASS"), cell("")],
        [cell("Silent catch blocks remaining (9)"), sev_para("MISSING"), sev_para("MEDIUM")],
        [cell("Navigator.push mixed with GoRouter"), sev_para("MISSING"), sev_para("MEDIUM")],
    ]
    story.append(make_table(sec_headers, l4_rows, [CW*0.65, CW*0.20, CW*0.15]))

    sec_layer("Layer 5 — Missing Controls")
    l5_rows = [
        [cell("App Check not configured"), sev_para("MISSING"), sev_para("HIGH")],
        [cell("Razorpay webhook not implemented"), sev_para("MISSING"), sev_para("HIGH")],
        [cell("Rate limiting written but not deployed"), sev_para("MISSING"), sev_para("MEDIUM")],
        [cell("Error monitoring (Crashlytics)"), sev_para("MISSING"), sev_para("MEDIUM")],
    ]
    story.append(make_table(sec_headers, l5_rows, [CW*0.65, CW*0.20, CW*0.15]))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 5 — UI / UX
    # ══════════════════════════════════════════════════════════════════════════
    sec("UI / UX Review", "7.0 / 10")

    story.append(Paragraph("Strengths", H2))
    ux_s_headers = ["Feature", "Quality"]
    ux_s_rows = [
        [cell("Material Design 3 consistency"), sev_para("PASS")],
        [cell("Shimmer loading states"), sev_para("PASS")],
        [cell("AppColors token system"), sev_para("PASS")],
        [cell("Empty state handling"), sev_para("PASS")],
        [cell("Booking card design"), sev_para("PASS")],
        [cell("Error state feedback"), cell("Basic but functional")],
    ]
    story.append(make_table(ux_s_headers, ux_s_rows, [CW*0.70, CW*0.30]))

    story.append(Spacer(1, 5 * mm))
    story.append(Paragraph("Gaps", H2))
    ux_g_headers = ["Issue", "Severity", "File / Scope"]
    ux_g_rows = [
        [cell("No dark mode support"), sev_para("MEDIUM"), cell("Global theme")],
        [cell("No accessibility semantic labels"), sev_para("MEDIUM"), cell("All screens")],
        [cell("No deep link support (GoRouter underutilised)"), sev_para("MEDIUM"), cell("app_router.dart")],
        [cell("Form validation feedback weak in registration"), sev_para("LOW"), cell("owner_registration_screen.dart")],
        [cell("No retry button on network error states"), sev_para("LOW"), cell("Multiple screens")],
    ]
    story.append(make_table(ux_g_headers, ux_g_rows, [CW*0.50, CW*0.18, CW*0.32]))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 6 — PERFORMANCE
    # ══════════════════════════════════════════════════════════════════════════
    sec("Performance", "5.0 / 10")

    # Big warning box
    warn_tbl = Table(
        [[Paragraph(
            '<font color="#D32F2F"><b>CRITICAL: NO PAGINATION ANYWHERE</b></font><br/>'
            '<font size="9">ownerBookingsProvider loads ALL bookings for an owner — freezes at 500+ bookings.<br/>'
            'bookingsStreamProvider streams entire collections filtered client-side.<br/>'
            'admin screens group bookings in O(n) client-side loops.<br/>'
            'No Firestore composite indexes verified in firestore.indexes.json.</font>',
            ParagraphStyle("warn", fontName="Helvetica", fontSize=9.5, leading=14))]],
        colWidths=[CW],
        style=[
            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FFF3F3")),
            ("BOX", (0, 0), (-1, -1), 1.5, SEV_CRITICAL),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ]
    )
    story.append(warn_tbl)
    story.append(Spacer(1, 5 * mm))

    story.append(Paragraph("Positives", H2))
    perf_rows = [
        [cell("CachedNetworkImage"), cell("Used consistently — network images cached correctly")],
        [cell("Riverpod caching"), cell("Provider caching working correctly, no unnecessary rebuilds")],
        [cell("Shimmer skeletons"), cell("Improves perceived performance during loads")],
    ]
    story.append(make_table(["Component", "Status"], perf_rows, [CW*0.30, CW*0.70]))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 7 — TESTING & CI/CD
    # ══════════════════════════════════════════════════════════════════════════
    sec("Testing & CI/CD", "1.0 / 10")

    story.append(Paragraph("Test Coverage", H2))
    test_headers = ["Area", "Tests", "Coverage"]
    test_rows = [
        [cell("TurfDateUtils (date math)"),         cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("BookingStatus (color/label)"),        cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("AmenityUtils"),                       cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("Repository methods"),                 cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("Payment flow state machine"),         cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("Widget tests for real screens"),      cell("0", align=TA_CENTER), sev_para("0%")],
        [cell("Total meaningful tests", bold=True),  cell("0", align=TA_CENTER), sev_para("~0%")],
    ]
    story.append(make_table(test_headers, test_rows, [CW*0.55, CW*0.20, CW*0.25]))

    story.append(Spacer(1, 4 * mm))
    note_tbl = Table(
        [[Paragraph(
            '<b>Note:</b> 1 widget test exists — it tests a counter widget that no longer exists in the app. '
            'CI/CD: No GitHub Actions configured. Broken code can be pushed to main and deployed without '
            'any automated check.',
            ParagraphStyle("nt", fontName="Helvetica", fontSize=9, textColor=DARK_GRAY, leading=13))]],
        colWidths=[CW],
        style=[
            ("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
            ("BOX", (0, 0), (-1, -1), 1, BRAND_GREEN),
            ("TOPPADDING", (0, 0), (-1, -1), 7),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ]
    )
    story.append(note_tbl)

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 8 — COMPLETION TRACKER
    # ══════════════════════════════════════════════════════════════════════════
    sec("Feature Completion Tracker")

    def status_cell(s):
        c = {"Complete": SEV_LOW, "Partial": SEV_MEDIUM,
             "Not Started": MID_GRAY}.get(s, BLACK)
        return Paragraph(f'<font color="#{hex6(c)}"><b>{s}</b></font>',
                         ParagraphStyle("sc2", fontName="Helvetica-Bold", fontSize=8.5,
                                        alignment=TA_CENTER))

    comp_headers = ["Feature", "Status", "Effort Remaining"]
    comp_rows = [
        [cell("Auth (OTP login)"),               status_cell("Complete"),     cell("—")],
        [cell("Turf listing / explore"),          status_cell("Complete"),     cell("—")],
        [cell("Slot selection"),                  status_cell("Complete"),     cell("—")],
        [cell("Booking confirmation UI"),         status_cell("Complete"),     cell("—")],
        [cell("Payment flow end-to-end"),         status_cell("Partial"),      cell("1 day (needs CF deploy + Blaze)")],
        [cell("Owner dashboard"),                 status_cell("Complete"),     cell("—")],
        [cell("Owner bookings screen"),           status_cell("Complete"),     cell("—")],
        [cell("Owner turf management"),           status_cell("Complete"),     cell("—")],
        [cell("Admin dashboard"),                 status_cell("Complete"),     cell("—")],
        [cell("Admin revenue screen"),            status_cell("Complete"),     cell("—")],
        [cell("Admin bookings detail"),           status_cell("Complete"),     cell("—")],
        [cell("Admin turfs detail"),              status_cell("Complete"),     cell("—")],
        [cell("Admin users screen"),              status_cell("Complete"),     cell("—")],
        [cell("Owner registration"),              status_cell("Complete"),     cell("—")],
        [cell("Booking cancellation"),            status_cell("Partial"),      cell("3 hours (CF not written)")],
        [cell("Refunds"),                         status_cell("Not Started"),  cell("1–2 days")],
        [cell("Owner payouts"),                   status_cell("Not Started"),  cell("2–3 days")],
        [cell("Push notifications"),              status_cell("Not Started"),  cell("2 days")],
        [cell("Referral system"),                 status_cell("Not Started"),  cell("2 days")],
        [cell("Reviews (verified)"),              status_cell("Partial"),      cell("4 hours (CF not written)")],
        [cell("Razorpay webhook"),                status_cell("Not Started"),  cell("4–6 hours")],
        [cell("Real-time slot availability"),     status_cell("Not Started"),  cell("1 day")],
    ]
    story.append(make_table(comp_headers, comp_rows, [CW*0.42, CW*0.22, CW*0.36]))

    story.append(Spacer(1, 4 * mm))
    story.append(Table(
        [[Paragraph('<b>Overall Completion: 65%</b>',
                    ParagraphStyle("oc", fontName="Helvetica-Bold", fontSize=12,
                                   textColor=DARK_GREEN, alignment=TA_CENTER))]],
        colWidths=[CW],
        style=[("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
               ("BOX", (0, 0), (-1, -1), 1.5, BRAND_GREEN),
               ("TOPPADDING", (0, 0), (-1, -1), 8),
               ("BOTTOMPADDING", (0, 0), (-1, -1), 8)]
    ))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 9 — RISK REGISTER
    # ══════════════════════════════════════════════════════════════════════════
    sec("Risk Register")

    risk_headers = ["ID", "Risk", "Category", "Severity", "Fix", "Effort"]
    risk_rows = [
        [cell("R01"), cell("CF not deployed — zero payment security live"),
         cell("Infrastructure"), sev_para("CRITICAL"),
         cell("Activate Blaze, deploy CF"), cell("1 day")],
        [cell("R02"), cell("No App Check — CF endpoints open to anyone"),
         cell("Security"), sev_para("HIGH"),
         cell("Configure App Check"), cell("2 hours")],
        [cell("R03"), cell("No Razorpay webhook — payment/booking mismatch"),
         cell("Payments"), sev_para("HIGH"),
         cell("Implement webhook CF"), cell("4–6 hours")],
        [cell("R04"), cell("No pagination — memory crash at scale"),
         cell("Performance"), sev_para("MEDIUM"),
         cell("Add .limit() + cursor pagination"), cell("2 days")],
        [cell("R05"), cell("9 silent catch blocks — blind in production"),
         cell("Observability"), sev_para("MEDIUM"),
         cell("Replace with catch(e,st)+debugPrint"), cell("2 hours")],
        [cell("R06"), cell("Zero test coverage"),
         cell("Quality"), sev_para("MEDIUM"),
         cell("Write smoke tests for payment flow"), cell("1 day")],
        [cell("R07"), cell("Navigator.push mixed with GoRouter"),
         cell("Architecture"), sev_para("MEDIUM"),
         cell("Full GoRouter migration"), cell("3–4 hours")],
        [cell("R08"), cell("No error monitoring"),
         cell("Observability"), sev_para("MEDIUM"),
         cell("Add Crashlytics"), cell("1 hour")],
        [cell("R09"), cell("No CI/CD"),
         cell("Process"), sev_para("LOW"),
         cell("GitHub Actions basic pipeline"), cell("2 hours")],
    ]
    story.append(make_table(risk_headers, risk_rows,
                            [CW*0.06, CW*0.27, CW*0.13, CW*0.12, CW*0.28, CW*0.14]))

    story.append(PageBreak())

    # ══════════════════════════════════════════════════════════════════════════
    # PAGE 10 — FINAL SCORECARD & ACTION PLAN
    # ══════════════════════════════════════════════════════════════════════════
    sec("Final Scorecard & Action Plan")

    story.append(Paragraph("Scorecard", H2))
    sc_headers = ["Dimension", "Score", "Grade"]
    sc_data = [
        ("Architecture",  "7.5 / 10", "B"),
        ("Code Quality",  "6.5 / 10", "C+"),
        ("Security",      "7.5 / 10", "B  (8.5 post-CF deploy)"),
        ("UI / UX",       "7.0 / 10", "B-"),
        ("Performance",   "5.0 / 10", "D+"),
        ("Testing",       "1.0 / 10", "F"),
    ]
    sc_rows = [[cell(d, bold=(d=="OVERALL")),
                cell(s, bold=(d=="OVERALL"), align=TA_CENTER),
                cell(g, bold=(d=="OVERALL"), align=TA_CENTER)] for d, s, g in sc_data]
    sc_rows.append([
        cell("OVERALL", bold=True),
        score_para("62 / 100"),
        score_para("C+"),
    ])
    story.append(make_table(sc_headers, sc_rows, [CW*0.45, CW*0.27, CW*0.28]))

    story.append(Spacer(1, 6 * mm))
    story.append(Paragraph("Prioritised Action Plan", H2))

    def action_block(phase, items, color):
        hdr = Table(
            [[Paragraph(f'<b>{phase}</b>',
                        ParagraphStyle("ph", fontName="Helvetica-Bold", fontSize=10,
                                       textColor=WHITE, alignment=TA_LEFT))]],
            colWidths=[CW],
            style=[("BACKGROUND", (0, 0), (-1, -1), color),
                   ("TOPPADDING", (0, 0), (-1, -1), 5),
                   ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                   ("LEFTPADDING", (0, 0), (-1, -1), 10)]
        )
        story.append(hdr)
        for item in items:
            story.append(Paragraph(f"  {item}", BODY))
        story.append(Spacer(1, 3 * mm))

    action_block("IMMEDIATE — This Week", [
        "1. Activate Firebase Blaze plan (resolve payment issue)",
        "2. Deploy Cloud Functions: firebase deploy --only functions",
        "3. Implement Razorpay webhook CF",
        "4. Test end-to-end booking with real money",
    ], SEV_CRITICAL)

    action_block("SHORT-TERM — This Month", [
        "5. Configure Firebase App Check",
        "6. Add Firebase Crashlytics",
        "7. Add pagination to all booking list screens",
        "8. Fix remaining 9 silent catch blocks",
        "9. Add GitHub Actions CI pipeline",
    ], SEV_HIGH)

    action_block("MEDIUM-TERM — This Quarter", [
        "10. Full GoRouter migration (remove all Navigator.push)",
        "11. Write smoke tests for payment flow",
        "12. Add Firestore composite indexes",
        "13. Write cancellation + refund CF",
    ], SEV_MEDIUM)

    action_block("LONG-TERM — Backlog", [
        "14. Push notifications (FCM)",
        "15. Owner payout CF",
        "16. Referral redemption CF",
        "17. Dark mode",
        "18. Accessibility semantic labels",
        "19. Real-time slot availability indicators",
    ], SEV_LOW)

    story.append(Spacer(1, 5 * mm))
    story.append(thin_rule())

    dev_note = (
        "This audit reflects a codebase built entirely by a solo 17-year-old founder — and the security "
        "architecture is frankly impressive. The Firestore rules with field-level whitelists, CF-only write "
        "enforcement, HMAC verification, cross-turf exploit protection, and the pendingOrders pattern are "
        "decisions that experienced engineering teams at funded startups get wrong. The C+ grade is almost "
        "entirely driven by operational gaps (CF not deployed, no tests, no CI/CD) — not by fundamental "
        "design flaws. <b>The architecture is solid. The security foundation is real. Two focused days of "
        "work would push this from C+ to B+ immediately. Keep going.</b>"
    )
    story.append(Table(
        [[Paragraph(dev_note,
                    ParagraphStyle("dn", fontName="Helvetica", fontSize=9.5,
                                   textColor=DARK_GREEN, leading=14, alignment=TA_JUSTIFY))]],
        colWidths=[CW],
        style=[
            ("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
            ("BOX", (0, 0), (-1, -1), 1.5, BRAND_GREEN),
            ("TOPPADDING", (0, 0), (-1, -1), 10),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
            ("LEFTPADDING", (0, 0), (-1, -1), 12),
            ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ]
    ))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF saved to {path}")

if __name__ == "__main__":
    build_pdf("/Users/kavinrp/turfgo/TurfGo_Audit_Report.pdf")
