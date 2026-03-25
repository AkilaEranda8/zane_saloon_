"""
Conversation state machine — manages multi-step booking flow per session.
Each session_id gets its own ConversationState object.
"""
import re
from datetime import datetime, date, timedelta
from dataclasses import dataclass, field
from typing import Optional
import salon_api


# ── State names ──────────────────────────────────────────────────────────────
IDLE           = "idle"
AWAIT_SERVICE  = "await_service"
AWAIT_STAFF    = "await_staff"
AWAIT_DATE     = "await_date"
AWAIT_TIME     = "await_time"
AWAIT_NAME     = "await_name"
AWAIT_PHONE    = "await_phone"
AWAIT_CONFIRM  = "await_confirm"


@dataclass
class BookingDraft:
    branch_id:   Optional[int]   = None
    service_id:  Optional[int]   = None
    service_name: Optional[str]  = None
    staff_id:    Optional[int]   = None
    staff_name:  Optional[str]   = None
    date:        Optional[str]   = None   # YYYY-MM-DD
    time:        Optional[str]   = None   # HH:MM
    name:        Optional[str]   = None
    phone:       Optional[str]   = None


@dataclass
class ConversationState:
    state: str = IDLE
    draft: BookingDraft = field(default_factory=BookingDraft)
    # Cached data fetched from API
    services:  list = field(default_factory=list)
    staff:     list = field(default_factory=list)
    branches:  list = field(default_factory=list)


# In-memory session store  {session_id: ConversationState}
_sessions: dict[str, ConversationState] = {}


def get_session(session_id: str) -> ConversationState:
    if session_id not in _sessions:
        _sessions[session_id] = ConversationState()
    return _sessions[session_id]


def reset_session(session_id: str):
    _sessions[session_id] = ConversationState()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_date(text: str) -> Optional[str]:
    """Try to extract a date from user input. Returns YYYY-MM-DD or None."""
    today = date.today()
    t = text.lower().strip()

    if "today" in t or "today" in t:
        return today.isoformat()
    if "tomorrow" in t or "tomoro" in t or "tomrw" in t:
        return (today + timedelta(days=1)).isoformat()

    # Day names
    days = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]
    for i, d_name in enumerate(days):
        if d_name in t or d_name[:3] in t:
            target_wd = i
            current_wd = today.weekday()
            delta = (target_wd - current_wd) % 7
            if delta == 0:
                delta = 7
            return (today + timedelta(days=delta)).isoformat()

    # YYYY-MM-DD
    m = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if m:
        return m.group(1)

    # DD/MM or DD-MM
    m = re.search(r"(\d{1,2})[/-](\d{1,2})", text)
    if m:
        day, month = int(m.group(1)), int(m.group(2))
        year = today.year
        try:
            parsed = date(year, month, day)
            if parsed < today:
                parsed = date(year + 1, month, day)
            return parsed.isoformat()
        except ValueError:
            pass

    return None


def _parse_time(text: str) -> Optional[str]:
    """Extract HH:MM from user input."""
    t = text.lower()

    # "3pm", "3 pm", "15:00", "3:30pm"
    m = re.search(r"(\d{1,2}):(\d{2})\s*(am|pm)?", t)
    if m:
        h, mi = int(m.group(1)), int(m.group(2))
        suffix = m.group(3)
        if suffix == "pm" and h != 12:
            h += 12
        elif suffix == "am" and h == 12:
            h = 0
        if 0 <= h < 24 and 0 <= mi < 60:
            return f"{h:02d}:{mi:02d}"

    m = re.search(r"(\d{1,2})\s*(am|pm)", t)
    if m:
        h = int(m.group(1))
        suffix = m.group(2)
        if suffix == "pm" and h != 12:
            h += 12
        elif suffix == "am" and h == 12:
            h = 0
        if 0 <= h < 24:
            return f"{h:02d}:00"

    return None


def _parse_phone(text: str) -> Optional[str]:
    digits = re.sub(r"\D", "", text)
    if len(digits) >= 9:
        return digits
    return None


def _format_services(services: list) -> str:
    if not services:
        return "Sorry, no services available right now."
    lines = ["Here are our services:\n"]
    current_cat = None
    for i, s in enumerate(services, 1):
        cat = s.get("category", "Other")
        if cat != current_cat:
            lines.append(f"\n**{cat}**")
            current_cat = cat
        lines.append(f"  {i}. {s['name']} — Rs. {s['price']} ({s['duration_minutes']} mins)")
    return "\n".join(lines)


def _format_staff(staff: list) -> str:
    if not staff:
        return "No staff listed at the moment."
    lines = ["Our team:\n"]
    for i, s in enumerate(staff, 1):
        role = s.get("role_title", "Stylist")
        lines.append(f"  {i}. {s['name']} ({role})")
    return "\n".join(lines)


def _format_branches(branches: list) -> str:
    if not branches:
        return "No branches found."
    lines = ["Our branches:\n"]
    for b in branches:
        lines.append(f"  • **{b['name']}** — {b.get('address','')}")
        if b.get("phone"):
            lines.append(f"    📞 {b['phone']}")
    return "\n".join(lines)


# ── Main handler ─────────────────────────────────────────────────────────────

async def handle_message(session_id: str, text: str, intent: str) -> str:
    sess = get_session(session_id)

    # ── Always-available commands ─────────────────────────────────────────────
    if intent == "goodbye":
        reset_session(session_id)
        return "Thank you for visiting Zane Salon! See you soon 😊"

    if intent == "help":
        return (
            "I can help you with:\n"
            "• **Book an appointment** — just say \"book\"\n"
            "• **Services & prices** — say \"show services\"\n"
            "• **Branch locations** — say \"where are you\"\n"
            "• **Our staff** — say \"show staff\"\n"
            "• **Check availability** — say \"check availability\"\n\n"
            "How can I help you today?"
        )

    # ── Booking state machine ─────────────────────────────────────────────────
    if sess.state != IDLE:
        return await _handle_booking_flow(session_id, sess, text, intent)

    # ── Intents from idle state ───────────────────────────────────────────────
    if intent == "greet":
        return (
            "Hello! Welcome to **Zane Salon** 💇\n\n"
            "I can help you:\n"
            "• Book an appointment\n"
            "• Check our services & prices\n"
            "• Find our branches\n\n"
            "What would you like to do?"
        )

    if intent == "book_appointment":
        services = await salon_api.get_services()
        sess.services = services
        sess.state = AWAIT_SERVICE
        return (
            _format_services(services) +
            "\n\nWhich service would you like? "
            "(Type the number or service name)"
        )

    if intent == "check_services":
        services = await salon_api.get_services()
        return _format_services(services) + "\n\nWould you like to book one? Just say **book**!"

    if intent == "check_prices":
        services = await salon_api.get_services()
        lines = ["**Price List:**\n"]
        for s in services:
            lines.append(f"• {s['name']}: Rs. {s['price']}")
        return "\n".join(lines) + "\n\nWant to book? Say **book**!"

    if intent == "check_branches":
        branches = await salon_api.get_branches()
        return _format_branches(branches)

    if intent == "check_staff":
        staff = await salon_api.get_staff()
        return _format_staff(staff) + "\n\nWant to book with a specific stylist? Say **book**!"

    if intent == "check_availability":
        staff = await salon_api.get_staff()
        sess.staff = staff
        sess.state = AWAIT_STAFF
        sess.draft = BookingDraft()
        return (
            _format_staff(staff) +
            "\n\nWhich staff member would you like to check? "
            "(Type number or name)"
        )

    if intent == "cancel_appointment":
        return (
            "To cancel an appointment, please contact us directly:\n"
            "📞 Call or visit your nearest branch.\n\n"
            "Would you like to book a new appointment instead?"
        )

    # Fallback
    return (
        "I'm not sure I understood that. I can help with:\n"
        "• Booking an appointment — say **book**\n"
        "• Services & prices — say **services**\n"
        "• Our locations — say **branches**\n\n"
        "How can I help?"
    )


async def _handle_booking_flow(
    session_id: str, sess: ConversationState, text: str, intent: str
) -> str:

    # Allow user to restart at any point
    if intent == "book_appointment" and sess.state != AWAIT_CONFIRM:
        sess.state = AWAIT_SERVICE
        sess.draft = BookingDraft()
        services = await salon_api.get_services()
        sess.services = services
        return (
            _format_services(services) +
            "\n\nWhich service would you like? (Type number or name)"
        )

    # ── Step 1: Choose service ────────────────────────────────────────────────
    if sess.state == AWAIT_SERVICE:
        services = sess.services or await salon_api.get_services()
        sess.services = services

        chosen = _match_item(text, services, "name")
        if not chosen:
            return (
                "I couldn't find that service. Please type the number or name:\n"
                + _format_services(services)
            )
        sess.draft.service_id   = chosen["id"]
        sess.draft.service_name = chosen["name"]

        # Only 1 branch? auto-select it
        branches = await salon_api.get_branches()
        sess.branches = branches
        if len(branches) == 1:
            sess.draft.branch_id = branches[0]["id"]

        staff = await salon_api.get_staff(sess.draft.branch_id)
        sess.staff = staff
        sess.state = AWAIT_STAFF
        return (
            f"Great choice! **{chosen['name']}** — Rs. {chosen['price']}\n\n"
            + _format_staff(staff) +
            "\n\nWhich stylist would you prefer? "
            "(Type number/name, or say **any** for first available)"
        )

    # ── Step 2: Choose staff ──────────────────────────────────────────────────
    if sess.state == AWAIT_STAFF:
        staff = sess.staff or await salon_api.get_staff()

        if re.search(r"\bany\b|\bno preference\b|\bdont care\b|anyone", text, re.I):
            chosen = staff[0] if staff else None
        else:
            chosen = _match_item(text, staff, "name")

        if not chosen:
            return (
                "Couldn't find that stylist. Please pick from:\n"
                + _format_staff(staff)
                + "\n\n(Or say **any** for first available)"
            )

        sess.draft.staff_id   = chosen["id"]
        sess.draft.staff_name = chosen["name"]
        sess.state = AWAIT_DATE
        return (
            f"Booked with **{chosen['name']}**!\n\n"
            "What date would you like? "
            "(e.g. **tomorrow**, **Monday**, **25/04**, or **2026-04-25**)"
        )

    # ── Step 3: Choose date ───────────────────────────────────────────────────
    if sess.state == AWAIT_DATE:
        parsed = _parse_date(text)
        if not parsed:
            return (
                "Couldn't understand that date. Please try:\n"
                "• **tomorrow**\n• **Monday**\n• **25/04**\n• **2026-04-25**"
            )

        chosen_date = datetime.strptime(parsed, "%Y-%m-%d").date()
        if chosen_date < date.today():
            return "That date is in the past! Please choose today or a future date."

        sess.draft.date = parsed
        booked_times    = await salon_api.get_availability(sess.draft.staff_id, parsed)
        free_slots      = _get_free_slots(booked_times)

        if not free_slots:
            sess.state = AWAIT_DATE
            return (
                f"Sorry, **{chosen['name'] if (chosen := None) else 'that stylist'}** "
                f"has no free slots on **{parsed}**.\n"
                "Please choose another date."
            )

        sess.state = AWAIT_TIME
        slots_str = "  ".join(free_slots)
        return (
            f"Available slots on **{parsed}**:\n\n`{slots_str}`\n\n"
            "What time works for you? (e.g. **10:00**, **2pm**, **14:30**)"
        )

    # ── Step 4: Choose time ───────────────────────────────────────────────────
    if sess.state == AWAIT_TIME:
        parsed_time = _parse_time(text)
        if not parsed_time:
            return "Couldn't read that time. Try: **10:00**, **2pm**, or **14:30**"

        # Check still available
        booked = await salon_api.get_availability(sess.draft.staff_id, sess.draft.date)
        if parsed_time in booked:
            free_slots = _get_free_slots(booked)
            return (
                f"Sorry, **{parsed_time}** is already taken!\n"
                f"Free slots: `{'  '.join(free_slots)}`\n"
                "Please pick another time."
            )

        sess.draft.time = parsed_time
        sess.state      = AWAIT_NAME
        return "What is your **full name** for the booking?"

    # ── Step 5: Name ─────────────────────────────────────────────────────────
    if sess.state == AWAIT_NAME:
        name = text.strip()
        if len(name) < 2:
            return "Please enter your full name."
        sess.draft.name = name
        sess.state      = AWAIT_PHONE
        return f"Thanks, **{name}**! What is your **phone number**?"

    # ── Step 6: Phone ─────────────────────────────────────────────────────────
    if sess.state == AWAIT_PHONE:
        phone = _parse_phone(text)
        if not phone:
            return "Please enter a valid phone number (at least 9 digits)."
        sess.draft.phone = phone
        sess.state       = AWAIT_CONFIRM

        d = sess.draft
        return (
            "**Please confirm your booking:**\n\n"
            f"• Service:  **{d.service_name}**\n"
            f"• Stylist:  **{d.staff_name}**\n"
            f"• Date:     **{d.date}**\n"
            f"• Time:     **{d.time}**\n"
            f"• Name:     **{d.name}**\n"
            f"• Phone:    **{d.phone}**\n\n"
            "Type **yes** to confirm, or **no** to cancel."
        )

    # ── Step 7: Confirm ───────────────────────────────────────────────────────
    if sess.state == AWAIT_CONFIRM:
        if re.search(r"\byes\b|\bconfirm\b|\bok\b|\byep\b|\bsure\b|\bawa\b|\boy\b", text, re.I):
            d = sess.draft
            result = await salon_api.create_booking({
                "branch_id":     d.branch_id,
                "service_id":    d.service_id,
                "staff_id":      d.staff_id,
                "customer_name": d.name,
                "phone":         d.phone,
                "date":          d.date,
                "time":          d.time,
            })
            reset_session(session_id)
            if result["success"]:
                return (
                    "Booking confirmed! ✅\n\n"
                    f"Your appointment for **{d.service_name}** with **{d.staff_name}** "
                    f"is set for **{d.date}** at **{d.time}**.\n\n"
                    "We'll see you soon! 💇"
                )
            else:
                return (
                    f"Booking failed: {result.get('error','Unknown error')}\n"
                    "Please try again or contact us directly."
                )

        elif re.search(r"\bno\b|\bcancel\b|\bnope\b|\bna\b", text, re.I):
            reset_session(session_id)
            return "Booking cancelled. No problem! How else can I help you?"

        return "Please type **yes** to confirm or **no** to cancel."

    # Fallback
    reset_session(session_id)
    return "Something went wrong. Let's start over — how can I help you?"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _match_item(text: str, items: list, key: str):
    """Match by number (1-based) or partial name."""
    text = text.strip()

    # Number match
    m = re.match(r"^(\d+)$", text)
    if m:
        idx = int(m.group(1)) - 1
        if 0 <= idx < len(items):
            return items[idx]

    # Name match (partial, case-insensitive)
    t = text.lower()
    for item in items:
        if t in item[key].lower() or item[key].lower() in t:
            return item

    return None


def _get_free_slots(booked: list) -> list:
    """Return available 30-min slots between 8am–7pm excluding booked ones."""
    all_slots = []
    for h in range(8, 19):
        for m in (0, 30):
            all_slots.append(f"{h:02d}:{m:02d}")
    return [s for s in all_slots if s not in booked]
