"""Opaque local upload names with an owner binding for task submission."""

import hashlib
import re
import secrets
import uuid


_LOCAL_NAME = re.compile(r"(?P<owner>[0-9a-f]{64})-(?P<nonce>[0-9a-f]{32})(?P<suffix>\.[a-z0-9]{2,5})\Z")


def _owner_key(user_id: str) -> str:
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()


def new_local_upload_reference(user_id: str, suffix: str) -> tuple[str, str]:
    """Create a flat filename so existing orphan cleanup can find the file."""
    if not re.fullmatch(r"\.[a-z0-9]{2,5}", suffix):
        raise ValueError("Invalid uploaded video extension")
    filename = f"{_owner_key(user_id)}-{uuid.uuid4().hex}{suffix}"
    return filename, f"upload://{filename}"


def require_owned_local_upload(reference: str, user_id: str) -> str:
    """Validate the submitted reference before ffprobe, billing or task creation.

    The server itself creates names in this form; a client cannot rename an
    existing upload by changing the URL because no file exists at that name.
    """
    if not reference.startswith("upload://"):
        raise ValueError("Invalid local upload reference")
    filename = reference.removeprefix("upload://")
    match = _LOCAL_NAME.fullmatch(filename)
    if match is None:
        raise ValueError("Invalid local upload reference")
    if not secrets.compare_digest(match.group("owner"), _owner_key(user_id)):
        raise ValueError("Uploaded video does not belong to this user")
    return filename
