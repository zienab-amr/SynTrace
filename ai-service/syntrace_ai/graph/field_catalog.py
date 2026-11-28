"""
field_catalog.py
================
Dynamic Jira field discovery and type-preserving normalization of non-core fields.

Nothing here hardcodes a customfield_NNNNN id. A field's meaning comes from, in order:
  1. its /rest/api/3/field definition (schema.type, schema.items, schema.custom),
  2. the per-issue `names` map (expand=names) for the display name,
  3. the shape of the value itself (only when 1 and 2 are unavailable).
Different Jira sites / projects can therefore carry different custom fields; unknown fields
are kept (typed by shape), never dropped or guessed.

Outputs per issue (stored as JSON strings on the WorkItem because Neo4j properties cannot be maps):
  custom_fields      display name -> typed value (numbers stay numbers, dates stay dates,
                     option -> label, multi-option -> list of labels, user -> displayName,
                     ADF -> plain text, unknown objects -> the object itself, never str()-ed)
  custom_fields_raw  field id -> raw Jira value, unmodified (ids of options/users preserved)
  custom_field_defs  field id -> {name, kind, schema_type, schema_custom}
Values that do not match their declared schema (e.g. a non-numeric string in a number field)
are kept as-is and reported in `warnings` rather than coerced.
"""
import json
import os
import re

# kinds
SPRINT, RANK, NUMBER, DATE, DATETIME, STRING, TEXT, OPTION, OPTIONS, USER, USERS, LABELS, \
    VERSION, VERSIONS, BOOLEAN, URL, JSON_STRING, OBJECT, LIST, UNKNOWN = (
        "sprint", "rank", "number", "date", "datetime", "string", "text", "option", "options",
        "user", "users", "labels", "version", "versions", "boolean", "url", "json_string",
        "object", "list", "unknown")


def _atomic_write(path, text):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, path)


def meta_from_api(field_list):
    """/rest/api/3/field response -> {id: {name, custom, schema_type, schema_items,
    schema_custom, clause_names}} (superset of the legacy field_meta.json shape)."""
    meta = {}
    for f in field_list or []:
        if not isinstance(f, dict) or not f.get("id"):
            continue
        schema = f.get("schema") or {}
        meta[f["id"]] = {"name": f.get("name"), "custom": bool(f.get("custom")),
                         "schema_type": schema.get("type"), "schema_items": schema.get("items"),
                         "schema_custom": schema.get("custom"),
                         "clause_names": f.get("clauseNames") or []}
    return meta


def save_meta(meta, path):
    _atomic_write(path, json.dumps(meta, ensure_ascii=False, indent=2))


def kind_of(fid, meta, value=None):
    """Classify a field using its definition first, then the value's shape."""
    info = (meta or {}).get(fid) or {}
    st = info.get("schema_type")
    items = info.get("schema_items")
    sc = (info.get("schema_custom") or "").lower()
    tail = sc.rsplit(":", 1)[-1] if sc else ""
    if tail == "gh-sprint":
        return SPRINT
    if tail == "gh-lexo-rank":
        return RANK
    if st or tail:
        if st == "number" or tail == "float":
            return NUMBER
        if st == "date" or tail == "datepicker":
            return DATE
        if st == "datetime" or tail == "datetime":
            return DATETIME
        if tail in ("select", "radiobuttons", "cascadingselect") or st == "option":
            return OPTION
        if tail in ("multiselect", "multicheckboxes") or (st == "array" and items == "option"):
            return OPTIONS
        if st == "user" or tail == "userpicker":
            return USER
        if tail == "multiuserpicker" or (st == "array" and items == "user"):
            return USERS
        if tail == "labels" or (st == "array" and items == "string"):
            return LABELS
        if st == "version":
            return VERSION
        if st == "array" and items == "version":
            return VERSIONS
        if tail == "textarea":
            return TEXT
        if tail == "url":
            return URL
        if tail in ("textfield", "string") or st == "string":
            return STRING
        if st == "array":
            return LIST
    return _kind_from_value(value)


def _kind_from_value(v):
    if isinstance(v, bool):
        return BOOLEAN
    if isinstance(v, (int, float)):
        return NUMBER
    if isinstance(v, str):
        return STRING
    if isinstance(v, list):
        if v and all(isinstance(x, dict) and {"id", "name", "state"} <= set(x) for x in v):
            return SPRINT
        return LIST
    if isinstance(v, dict):
        if v.get("type") == "doc":
            return TEXT
        return OBJECT
    return UNKNOWN


_NUM = re.compile(r"^-?\d+(\.\d+)?$")


def _label(v):
    """Display label of a Jira object (option/user/version/...), else None."""
    if isinstance(v, dict):
        for k in ("displayName", "name", "value"):
            if v.get(k) is not None:
                return v[k]
    return None


def typed_value(fid, raw, meta, helpers, warnings):
    """raw Jira value -> typed value or None when it carries no information.
    helpers: {"adf_to_text": fn, "to_utc_iso": fn}. Never stringifies numbers/booleans/objects."""
    if raw is None:
        return None
    kind = kind_of(fid, meta, raw)
    if kind in (NUMBER,):
        if isinstance(raw, bool):
            return raw
        if isinstance(raw, (int, float)):
            return raw
        if isinstance(raw, str) and _NUM.match(raw.strip()):
            s = raw.strip()
            return float(s) if "." in s else int(s)
        warnings.append(f"type_mismatch:{fid}:number")
        return raw
    if kind == DATE:
        if isinstance(raw, str) and re.match(r"^\d{4}-\d{2}-\d{2}", raw):
            return raw[:10]
        warnings.append(f"type_mismatch:{fid}:date")
        return raw
    if kind == DATETIME:
        iso = helpers["to_utc_iso"](raw)
        if iso is None:
            warnings.append(f"type_mismatch:{fid}:datetime")
            return raw
        return iso
    if kind == BOOLEAN:
        return raw
    if kind in (OPTION, USER, VERSION):
        lab = _label(raw)
        if lab is None and isinstance(raw, dict):
            warnings.append(f"type_mismatch:{fid}:{kind}")
            return raw
        if isinstance(raw, dict) and raw.get("child"):
            return [lab, _label(raw["child"])]      # cascading select keeps both levels
        return lab if lab is not None else (raw if raw != "" else None)
    if kind in (OPTIONS, USERS, VERSIONS, LABELS, LIST):
        if not isinstance(raw, list):
            return raw
        out = []
        for x in raw:
            lab = _label(x)
            out.append(lab if lab is not None else x)
        out = [x for x in out if x not in (None, "")]
        return out or None
    if kind == TEXT:
        if isinstance(raw, dict) and raw.get("type") == "doc":
            return helpers["adf_to_text"](raw).strip() or None
        return raw if isinstance(raw, str) and raw.strip() else None
    if kind in (STRING, URL, RANK):
        if isinstance(raw, str):
            return raw if raw.strip() else None
        return raw                                    # unexpected shape: keep it, do not str()
    if isinstance(raw, dict):
        if raw.get("type") == "doc":
            return helpers["adf_to_text"](raw).strip() or None
        lab = _label(raw)
        return raw if lab is None else lab
    if isinstance(raw, str) and not raw.strip():
        return None
    return raw


def normalize_extra_fields(fields, names, meta, handled, noise, helpers):
    """Process every field not handled explicitly.
    Returns (typed_by_name, raw_by_id, defs_by_id, sprint_values_or_None, warnings)."""
    typed, raw_by_id, defs, warnings, sprint_values = {}, {}, {}, [], None
    names = names or {}
    for fid, value in (fields or {}).items():
        if fid in handled or fid in noise:
            continue
        kind = kind_of(fid, meta, value)
        info = (meta or {}).get(fid) or {}
        name = names.get(fid) or info.get("name") or fid
        if kind == SPRINT:
            sprint_values = (sprint_values or []) + list(value or [])
            if sprint_values is None:
                sprint_values = []
            continue
        if value is None:
            continue
        raw_by_id[fid] = value
        defs[fid] = {"name": name, "kind": kind, "schema_type": info.get("schema_type"),
                     "schema_custom": info.get("schema_custom")}
        tv = typed_value(fid, value, meta, helpers, warnings)
        if tv is None:
            continue
        label = name
        if label in typed:
            label = f"{name} ({fid})"
        typed[label] = tv
    return typed, raw_by_id, defs, sprint_values, warnings


def unknown_field_ids(fields, meta):
    """customfield ids present in a payload but absent from the loaded catalog."""
    return sorted(f for f in (fields or {}) if f.startswith("customfield_") and f not in (meta or {}))
