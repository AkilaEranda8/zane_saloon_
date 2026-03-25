"""
Async client that calls the existing Salon Node.js API endpoints.
All public endpoints — no auth token needed.
"""
import os
import httpx
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

SALON_BASE = os.getenv("SALON_API_URL", "http://localhost:5000/api")

_client = httpx.AsyncClient(timeout=10.0)


async def get_branches() -> list:
    try:
        r = await _client.get(f"{SALON_BASE}/public/branches")
        r.raise_for_status()
        return r.json()
    except Exception:
        return []


async def get_services() -> list:
    try:
        r = await _client.get(f"{SALON_BASE}/public/services")
        r.raise_for_status()
        return r.json()
    except Exception:
        return []


async def get_staff(branch_id: int | None = None) -> list:
    try:
        params = {}
        if branch_id:
            params["branchId"] = branch_id
        r = await _client.get(f"{SALON_BASE}/public/staff", params=params)
        r.raise_for_status()
        return r.json()
    except Exception:
        return []


async def get_availability(staff_id: int, date: str) -> list:
    """Returns list of already-booked HH:MM time strings for that staff+date."""
    try:
        r = await _client.get(
            f"{SALON_BASE}/public/availability",
            params={"staffId": staff_id, "date": date},
        )
        r.raise_for_status()
        return r.json()
    except Exception:
        return []


async def create_booking(payload: dict) -> dict:
    """
    payload: branch_id, service_id, staff_id, customer_name,
             phone, date, time, notes (optional)
    """
    try:
        r = await _client.post(f"{SALON_BASE}/public/bookings", json=payload)
        r.raise_for_status()
        return {"success": True, "data": r.json()}
    except httpx.HTTPStatusError as e:
        msg = "Booking failed"
        try:
            msg = e.response.json().get("message", msg)
        except Exception:
            pass
        return {"success": False, "error": msg}
    except Exception as e:
        return {"success": False, "error": str(e)}
